#!/usr/bin/env python3
"""Offline tests for Vinput's buffered PCM provider."""

import gzip
import importlib.util
import io
import json
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "batch", Path(__file__).parents[1] / "scripts/vinput-doubao-batch.py")
batch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(batch)


class BatchTests(unittest.TestCase):
    def test_gain_applied_once_and_clamped(self):
        pcm = struct.pack("<hhhhh", 100, -100, 12000, -12000, 0)
        self.assertEqual(struct.unpack("<hhhhh", batch.apply_gain(pcm, 3)),
                         (300, -300, 32767, -32768, 0))
        self.assertEqual(batch.apply_gain(pcm, 1), pcm)
        for invalid in (b"", b"x", b"\0" * (batch.MAX_AUDIO_BYTES + 2)):
            with self.assertRaises(ValueError):
                batch.apply_gain(invalid, 1)
        for gain in (0, 11, float("nan"), float("inf")):
            with self.assertRaises(ValueError):
                batch.apply_gain(pcm, gain)

    def test_nostream_protocol_and_aliases(self):
        pcm = b"\x01\x02" * 8000
        sent = []

        class Connection:
            async def __aenter__(self):
                return self

            async def __aexit__(self, *args):
                pass

            async def send(self, frame):
                sent.append(frame)

            async def recv(self):
                body = gzip.compress(json.dumps({"result": {"text": "尼克斯。"}}).encode())
                return b"\x11\x93\x11\0" + struct.pack(">iI", -1, len(body)) + body

        def connect(endpoint, **kwargs):
            self.assertTrue(endpoint.endswith("/bigmodel_nostream"))
            self.assertEqual(kwargs["additional_headers"]["X-Api-Key"], "test-key")
            return Connection()

        text = batch.transcribe(pcm, {"api_key": "test-key"}, ["NixOS"],
                                [("尼克斯", "NixOS")], connect)
        self.assertEqual(text, "NixOS")
        request = json.loads(gzip.decompress(sent[0][12:]))
        self.assertEqual(json.loads(request["request"]["corpus"]["context"]),
                         {"hotwords": [{"word": "NixOS"}]})
        self.assertEqual(b"".join(gzip.decompress(frame[12:]) for frame in sent[1:]), pcm)
        self.assertEqual(sent[-1][1] & 3, 3)


    def test_main_reads_complete_pcm_and_outputs_only_text(self):
        pcm = struct.pack("<hh", 100, -200)
        source = io.BytesIO(pcm)
        output = io.StringIO()

        def recognize(actual, *args):
            self.assertEqual(source.tell(), len(pcm))
            self.assertEqual(actual, pcm)
            return "识别结果"

        with patch.object(sys, "argv", ["batch", "--credentials", "unused", "--parser", "unused"]), \
                patch.object(sys, "stdin", type("Input", (), {"buffer": source})()), \
                patch.object(sys, "stdout", output), \
                patch.object(batch.worker, "load_credentials", return_value={"api_key": "fake"}), \
                patch.object(batch.bridge, "load_terms", return_value=([], [])), \
                patch.object(batch, "transcribe", side_effect=recognize):
            self.assertEqual(batch.main(), 0)
        self.assertEqual(output.getvalue(), "识别结果\n")


if __name__ == "__main__":
    unittest.main()
