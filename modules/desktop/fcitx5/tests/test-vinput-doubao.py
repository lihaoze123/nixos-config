#!/usr/bin/env python3
"""Offline checks for credential bridging and terminology handling."""

import importlib.util
import base64
import json
import os
from pathlib import Path
import subprocess
import struct
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "bridge", Path(__file__).parents[1] / "scripts/vinput-doubao.py")
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class BridgeTests(unittest.TestCase):
    def test_slow_provider_does_not_block_audio_pipe(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            chunks = [struct.pack("<h", i) * 2048 for i in range(32)]
            lines = [json.dumps({"type": "audio", "audio_base64": base64.b64encode(pcm).decode(),
                                 "commit": i == len(chunks) - 1}) + "\n"
                     for i, pcm in enumerate(chunks)]
            lines.append('{"type":"finish"}\n')
            read_fd, write_fd = os.pipe()

            def send():
                with os.fdopen(write_fd, "w") as output:
                    output.writelines(lines)

            with os.fdopen(read_fd) as source:
                incoming = bridge.ProviderInput(source)
                sender = threading.Thread(target=send, daemon=True)
                sender.start()
                # No provider consumes input yet (e.g. TLS handshake is stuck).
                self.assertTrue(incoming.finished.wait(3), "audio pipe stalled behind provider")
                sender.join(3)
                self.assertFalse(sender.is_alive())
                self.assertEqual(list(incoming), lines)
            self.assertEqual(list(root.iterdir()), [])


    def test_credentials_and_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "credentials.json"
            path.write_text(json.dumps({"api_key": "test-key"}))
            path.chmod(0o600)
            self.assertEqual(bridge.load_credentials(path), {"X-Api-Key": "test-key"})
            path.write_text(json.dumps({"app_id": "test-app", "access_token": "test-token"}))
            self.assertEqual(bridge.load_credentials(path), {
                "X-Api-App-Key": "test-app", "X-Api-Access-Key": "test-token"})
            path.chmod(0o644)
            with self.assertRaises(ValueError):
                bridge.load_credentials(path)

    def test_alias_boundaries_and_non_cascading_replacements(self):
        aliases = [("nix os", "NixOS"), ("尼克斯", "NixOS"), ("foo", "bar"), ("bar", "baz")]
        self.assertEqual(bridge.normalize_text("尼克斯 nix os foo bar foobar。", aliases),
                         "NixOS NixOS bar baz foobar")
        self.assertEqual(bridge.normalize_text("版本 2.4.1。", []), "版本 2.4.1")
        self.assertEqual(bridge.normalize_text("真的吗？", []), "真的吗？")

    def test_provider_auth_payload_and_output(self):
        connections, events = [], []

        class Client:
            def __init__(self, url, headers, timeout):
                connections.append(headers)

        provider = SimpleNamespace(
            WebSocketClient=Client,
            build_request_payload=lambda model, user: {"request": {"model_name": model}},
            write_stdout=events.append,
        )
        bridge.configure_provider(provider, {"X-Api-Key": "test-key"}, ["NixOS"], [("尼克斯", "NixOS")])
        provider.WebSocketClient("wss://example.invalid", {
            "X-Api-App-Key": "old", "X-Api-Access-Key": "old",
            "X-Api-Resource-Id": "resource", "X-Api-Connect-Id": "connection"}, 60)
        self.assertEqual(connections[0], {"X-Api-Key": "test-key",
                                         "X-Api-Resource-Id": "resource",
                                         "X-Api-Connect-Id": "connection"})
        payload = provider.build_request_payload("bigmodel", "vinput")
        self.assertEqual(json.loads(payload["request"]["corpus"]["context"]),
                         {"hotwords": [{"word": "NixOS"}]})
        provider.write_stdout({"type": "partial", "text": "尼克斯。"})
        provider.write_stdout({"type": "final", "text": "尼克斯。", "segment_final": True})
        provider.write_stdout({"type": "error", "message": "sensitive server response"})
        self.assertEqual(events[0]["text"], "尼克斯。")
        self.assertEqual(events[1]["text"], "NixOS")
        self.assertTrue(events[1]["segment_final"])
        self.assertNotIn("sensitive", events[2]["message"])

    def test_terms_filter_and_legacy_path(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            (base / "vocotype").mkdir()
            (base / "vocotype/user-dictionary.yaml").write_text("terms: []")
            parsed = {"terms": [{"canonical": "NixOS", "aliases": ["尼克斯"],
                                 "hotwords": ["NixOS", "NixOS", "two words", "x" * 11]}]}
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": directory}, clear=True), \
                    patch.object(bridge.subprocess, "run", return_value=SimpleNamespace(
                        returncode=0, stdout=json.dumps(parsed))):
                self.assertEqual(bridge.load_terms("parser"), (["NixOS"], [("尼克斯", "NixOS")]))

    def test_pinned_provider_contract(self):
        path = os.environ.get("VINPUT_TEST_PROVIDER")
        if not path:
            self.skipTest("set VINPUT_TEST_PROVIDER to the pinned registry entry.py")
        provider = bridge.load_provider(Path(path))
        bridge.configure_provider(provider, {"X-Api-Key": "test-key"}, ["NixOS"], [])
        self.assertEqual(provider.resolve_credentials(), ("vinput", ""))
        payload = provider.build_request_payload("bigmodel", "vinput")
        frame = provider.build_full_client_request(payload)
        self.assertEqual(frame[0], 0x11)
        # No microphone, network connection, or actual secret is needed.
        with patch.object(provider.sys, "stdin", []), patch.object(provider, "write_stdout"):
            self.assertEqual(provider.main(), 0)

    def test_built_wrapper_uses_runtime_credentials(self):
        wrapper = os.environ.get("VINPUT_TEST_WRAPPER")
        if not wrapper:
            self.skipTest("set VINPUT_TEST_WRAPPER to the built provider executable")
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            (base / "agenix").mkdir()
            credentials = base / "agenix/doubao-asr"
            credentials.write_text(json.dumps({"api_key": "offline-test-key"}))
            credentials.chmod(0o600)
            result = subprocess.run([wrapper], input="", text=True, capture_output=True,
                                    timeout=10, env={**os.environ,
                                                    "XDG_RUNTIME_DIR": directory,
                                                    "XDG_CONFIG_HOME": str(base / "config"),
                                                    "VOCOTYPE_TERMS_FILE": str(base / "absent.yaml")})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), {"type": "closed"})
            self.assertNotIn("offline-test-key", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
