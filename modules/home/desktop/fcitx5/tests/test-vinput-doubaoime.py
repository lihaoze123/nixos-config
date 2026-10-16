#!/usr/bin/env python3
"""Offline checks for the Doubao IME provider bridge."""

import asyncio
import base64
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import unittest


spec = importlib.util.spec_from_file_location(
    "ime_bridge", Path(__file__).parents[1] / "scripts/vinput-doubaoime.py")
ime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ime)


class ImeTests(unittest.TestCase):
    def test_errors_distinguish_silence_timeout_and_early_termination(self):
        for message, expected in [
            ("ValueError: No speech was recognized", "未识别到语音"),
            ("ValueError: Audio is empty", "录音为空"),
            ("RuntimeError: ASR session finished before the audio source ended", "提前结束会话"),
            ("ValueError: Audio received after finish", "协议时序异常"),
            ("TimeoutError: private endpoint or token", "请求超时"),
            ("ConnectionError: private endpoint or token", "网络连接失败"),
        ]:
            with self.subTest(message=message):
                result = ime.describe_error(message)
                self.assertIn(expected, result)
                self.assertNotIn("private", result)

    def test_streaming_protocol_remains_intact(self):
        pcm = b"\x00\x01" * 3200
        messages = [json.dumps({"type": "audio", "audio_base64": base64.b64encode(pcm).decode(),
                                "commit": True}).encode() + b"\n", b'{"type":"finish"}\n']
        events = []

        async def lines():
            for message in messages:
                yield message

        async def provider_run(source, emit, *, identity_path):
            self.assertEqual(identity_path, Path("identity.json"))
            self.assertEqual([line async for line in source], messages)
            emit({"type": "partial", "text": "测试"})
            emit({"type": "final", "text": "测试文本"})
            emit({"type": "closed"})
            return 0

        provider = SimpleNamespace(stdin_lines=lines, run_provider=provider_run)
        self.assertEqual(asyncio.run(ime.run(provider, Path("identity.json"), events.append)), 0)
        self.assertEqual([event["type"] for event in events], ["partial", "final", "closed"])
        self.assertEqual(events[1]["text"], "测试文本")

    def test_error_does_not_expose_upstream_details(self):
        async def lines():
            if False:
                yield b""

        async def provider_run(source, emit, **kwargs):
            emit({"type": "error", "message": "private identity or token"})
            emit({"type": "closed"})
            return 1

        events = []
        provider = SimpleNamespace(stdin_lines=lines, run_provider=provider_run)
        self.assertEqual(asyncio.run(ime.run(provider, Path("unused"), events.append)), 1)
        self.assertNotIn("private", json.dumps(events))


if __name__ == "__main__":
    unittest.main()
