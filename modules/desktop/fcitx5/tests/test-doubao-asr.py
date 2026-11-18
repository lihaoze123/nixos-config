#!/usr/bin/env python3
"""Test binary ASR protocol, local WebSocket exchange and worker handoff."""
import asyncio
import gzip
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import wave

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/doubao-asr-worker.py"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("doubao", SCRIPT)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


def server_frame(payload, sequence=1, final=False, compressed=True):
    data = json.dumps(payload).encode()
    if compressed:
        data = gzip.compress(data)
    flags = 3 if final else 1
    return (bytes([0x11, 0x90 | flags, 0x10 | int(compressed), 0])
            + struct.pack(">iI", -sequence if final else sequence, len(data)) + data)


def write_wav(path, pcm=b"\x00\x01" * 8000, rate=16000, channels=1, width=2):
    with wave.open(str(path), "wb") as audio:
        audio.setnchannels(channels)
        audio.setsampwidth(width)
        audio.setframerate(rate)
        audio.writeframes(pcm)


class WorkerTests(unittest.TestCase):
    def test_auth(self):
        headers = worker.auth_headers({"app_id": "123", "access_token": "secret"})
        self.assertEqual(headers["X-Api-App-Key"], "123")
        self.assertEqual(headers["X-Api-Resource-Id"], "volc.seedasr.sauc.duration")
        self.assertNotIn("X-Api-Key", headers)
        self.assertEqual(worker.auth_headers({"api_key": "test"})["X-Api-Key"], "test")
        with self.assertRaises(ValueError):
            worker.auth_headers({})

    def test_frame_variants(self):
        for compressed in (True, False):
            result, final = worker.parse_frame(server_frame({"result": {"text": "最终结果"}},
                                                          final=True, compressed=compressed))
            self.assertTrue(final)
            self.assertEqual(result["result"]["text"], "最终结果")
        body = b'{"result":{"text":""}}'
        result, final = worker.parse_frame(b"\x11\x92\x10\x00" + struct.pack(">I", len(body)) + body)
        self.assertTrue(final)
        self.assertEqual(result["result"]["text"], "")
        for data in (b"", b"\x11\x91\x11\x00", server_frame({})[:-1], "not-binary"):
            with self.assertRaises(ValueError):
                worker.parse_frame(data)

    def test_server_error_does_not_echo_payload(self):
        body = b"secret-token"
        frame = b"\x11\xf0\x10\x00" + struct.pack(">II", 45000030, len(body)) + body
        with self.assertRaisesRegex(ValueError, "45000030") as error:
            worker.parse_frame(frame)
        self.assertNotIn("secret", str(error.exception))

    def test_audio_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            audio = Path(tmp) / "audio.wav"
            write_wav(audio)
            self.assertEqual(len(worker.read_audio(audio)), 16000)
            write_wav(audio, pcm=b"")
            with self.assertRaisesRegex(ValueError, "录音为空"):
                worker.read_audio(audio)

    def test_capture_audio_conversion(self):
        with tempfile.TemporaryDirectory() as tmp:
            audio = Path(tmp) / "capture.wav"
            for rate, channels, width in ((48000, 1, 2), (44100, 2, 2), (48000, 2, 3)):
                # One second of constant samples: verifies duration, stereo
                # mixing and bit-depth conversion through the real resampler.
                sample = (1000 << (8 * (width - 2))).to_bytes(width, "little", signed=True)
                write_wav(audio, sample * rate * channels, rate, channels, width)
                original = audio.read_bytes()
                pcm = worker.read_audio(audio)
                self.assertEqual(len(pcm), 32000)
                self.assertAlmostEqual(struct.unpack_from("<h", pcm, 16000)[0], 1000, delta=2)
                self.assertEqual(audio.read_bytes(), original)
            audio.write_bytes(b"invalid audio file")
            with self.assertRaisesRegex(ValueError, "格式转换失败"):
                worker.read_audio(audio)

    def test_local_websocket_exchange(self):
        from websockets.asyncio.client import connect
        from websockets.asyncio.server import serve

        async def run():
            pcm = b"\x01\x02" * 8000  # Multiple 200 ms packets, with a shorter final packet.
            cases = [
                ({"itn": False, "hotwords": " NixOS 豆包\tNixOS\nVoCoType "},
                 ["NixOS", "豆包", "VoCoType"]),
                ({"itn": False, "hotwords": "更新词库"}, ["更新词库"]),
                ({"itn": False, "hotwords": " \t\n"}, []),
                ({"itn": False}, []),
            ]
            expected_words = iter(words for _, words in cases)

            async def handler(connection):
                self.assertEqual(connection.request.headers["X-Api-Key"], "test-key")
                self.assertEqual(connection.request.headers["X-Api-Resource-Id"], worker.RESOURCE_ID)
                initial = await connection.recv()
                self.assertEqual(initial[:4], b"\x11\x11\x11\x00")
                self.assertEqual(struct.unpack_from(">i", initial, 4)[0], 1)
                metadata = json.loads(gzip.decompress(initial[12:]))
                self.assertEqual(metadata["audio"]["format"], "pcm")
                self.assertFalse(metadata["request"]["enable_itn"])
                self.assertEqual(metadata["request"]["result_type"], "full")
                words = next(expected_words)
                if words:
                    context = metadata["request"]["corpus"]["context"]
                    self.assertIsInstance(context, str)
                    self.assertEqual(json.loads(context),
                                     {"hotwords": [{"word": word} for word in words]})
                else:
                    self.assertNotIn("corpus", metadata["request"])
                await connection.send(server_frame({"result": {"text": ""}}))
                received = bytearray()
                sequence = 2
                while True:
                    frame = await connection.recv()
                    last = bool(frame[1] & 2)
                    self.assertEqual(frame[1] >> 4, 2)
                    self.assertEqual(frame[2], 1)  # Raw audio, gzip compression.
                    self.assertEqual(struct.unpack_from(">i", frame, 4)[0], -sequence if last else sequence)
                    self.assertEqual(struct.unpack_from(">I", frame, 8)[0], len(frame) - 12)
                    chunk = gzip.decompress(frame[12:])
                    self.assertLessEqual(len(chunk), 6400)
                    received.extend(chunk)
                    sequence += 1
                    if last:
                        break
                self.assertEqual(bytes(received), pcm)
                # Full snapshots must replace previous text, never concatenate.
                await connection.send(server_frame({"result": {"text": "测试 Nix"}}))
                await connection.send(server_frame({"result": {"text": "测试 NixOS。"},
                                                    "audio_info": {"duration": 500}}, final=True))

            async with serve(handler, "127.0.0.1", 0) as server:
                port = server.sockets[0].getsockname()[1]

                def local_connect(endpoint, **kwargs):
                    self.assertEqual(endpoint, worker.ENDPOINT)
                    self.assertTrue(endpoint.endswith("/bigmodel_nostream"))
                    return connect(f"ws://127.0.0.1:{port}", **kwargs)

                for request, _ in cases:
                    result = await asyncio.wait_for(worker.recognize(pcm, request,
                        worker.auth_headers({"api_key": "test-key"}), local_connect), 5)
                    self.assertEqual(result["result"]["text"], "测试 NixOS。")

        asyncio.run(run())

    def test_invalid_hotwords_fail_before_connecting(self):
        def unexpected_connect(*args, **kwargs):
            self.fail("Invalid hotwords must not start a cloud request")

        with self.assertRaisesRegex(ValueError, "热词必须"):
            asyncio.run(worker.recognize(b"pcm", {"hotwords": ["NixOS"]},
                                        {}, unexpected_connect))

    def test_connection_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            audio = Path(tmp) / "audio.wav"
            write_wav(audio)

            def failed_connect(*args, **kwargs):
                raise OSError("secret-token")

            with self.assertRaisesRegex(ValueError, "连接失败或超时") as error:
                worker.transcribe({"audio_path": str(audio)}, {"api_key": "test"}, failed_connect)
            self.assertNotIn("secret", str(error.exception))

    def test_worker_protocol_and_local_handoff(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "config.json"
            command = [sys.executable, str(SCRIPT), "--credentials", str(config),
                       "--local-worker", sys.executable]
            local = subprocess.run(command + ["-c", "print('local-worker')"],
                                   capture_output=True, text=True, check=True)
            self.assertEqual(local.stdout.strip(), "local-worker")
            config.write_text(json.dumps({"api_key": "test"}))
            config.chmod(0o600)
            process = subprocess.run(command + ["--enabled"], input='{"type":"prepare"}\n{"type":"stop"}\n',
                                     capture_output=True, text=True, check=True)
            replies = [json.loads(line) for line in process.stdout.splitlines()]
            self.assertEqual(replies[0]["backend"], "doubao")
            self.assertTrue(replies[0]["contextual_hotword"])
            self.assertTrue(replies[1]["prepared"])
            config.chmod(0o644)
            with self.assertRaisesRegex(ValueError, "仅允许当前用户访问"):
                worker.load_credentials(config)

    def test_missing_agenix_credentials(self):
        with tempfile.TemporaryDirectory() as tmp:
            credentials = Path(tmp) / "not-decrypted.json"
            command = [sys.executable, str(SCRIPT), "--enabled", "--credentials", str(credentials),
                       "--local-worker", sys.executable]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(json.loads(result.stdout)["success"])
            self.assertIn("尚未解密", result.stdout)

    def test_legacy_cleanup_only_after_matching_decryption(self):
        with tempfile.TemporaryDirectory() as tmp:
            secret, legacy = Path(tmp) / "agenix", Path(tmp) / "legacy.json"
            legacy.write_text(json.dumps({"enabled": True, "api_key": "test"}))
            legacy.chmod(0o600)
            with self.assertRaisesRegex(ValueError, "尚未解密"):
                worker.remove_legacy_credentials(secret, legacy)
            self.assertTrue(legacy.exists())
            secret.write_text(json.dumps({"api_key": "other"}))
            secret.chmod(0o400)
            with self.assertRaisesRegex(ValueError, "不一致"):
                worker.remove_legacy_credentials(secret, legacy)
            self.assertTrue(legacy.exists())
            secret.chmod(0o600)
            secret.write_text(json.dumps({"api_key": "test"}))
            secret.chmod(0o400)
            worker.remove_legacy_credentials(secret, legacy)
            self.assertFalse(legacy.exists())
            worker.remove_legacy_credentials(secret, legacy)


if __name__ == "__main__":
    unittest.main()
