#!/usr/bin/env python3
"""Regression tests for restricted uploads, atomic releases and PR cleanup races."""

import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    "blog_upload", Path(__file__).resolve().parents[1] / "blog-upload.py"
)
UPLOAD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(UPLOAD)
SHA = "a" * 40


def archive(entries):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w:gz") as output:
        for name, content in entries.items():
            info = tarfile.TarInfo(name)
            if isinstance(content, tarfile.TarInfo):
                output.addfile(content)
            else:
                encoded = content.encode()
                info.size = len(encoded)
                output.addfile(info, io.BytesIO(encoded))
    stream.seek(0)
    return stream


class UploadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for folder in ("cms", "previews", "staging", "state"):
            (self.root / folder).mkdir()

    def publish(self, sequence="1.1", entries=None, number=42):
        UPLOAD.receive(
            self.root, f"publish preview {number} {sequence} {SHA}",
            archive(entries or {"index.html": "draft", "uploads/a.png": "image"}),
        )

    def test_publish_and_replace_atomically(self):
        self.publish()
        site = self.root / "previews/pr-42/current"
        self.assertEqual((site / "index.html").read_text(), "draft")
        self.assertEqual((site / "uploads/a.png").stat().st_mode & 0o777, 0o640)
        self.publish("2.1", {"index.html": "new draft"})
        self.assertEqual((site / "index.html").read_text(), "new draft")
        self.assertFalse((site / "uploads/a.png").exists())
        self.assertEqual(len(list((site.parent / "releases").iterdir())), 1)

    def test_invalid_upload_preserves_previous_site_and_state(self):
        self.publish()
        with self.assertRaises(ValueError):
            self.publish("2.1", {"other.html": "missing index"})
        self.assertEqual((self.root / "previews/pr-42/current/index.html").read_text(), "draft")
        self.assertEqual(json.loads((self.root / "state/pr-42.json").read_text())["sequence"], [1, 1])
        self.assertEqual(list((self.root / "staging").iterdir()), [])

    def test_cleanup_rejects_inflight_old_upload_and_allows_reopened_pr(self):
        self.publish()
        UPLOAD.receive(self.root, "remove preview 42 3.1", io.BytesIO())
        self.assertFalse((self.root / "previews/pr-42").exists())
        for sequence in ("1.1", "2.1", "3.1"):
            with self.subTest(sequence=sequence), self.assertRaises(ValueError):
                self.publish(sequence)
        self.publish("4.1")
        self.assertTrue((self.root / "previews/pr-42/current/index.html").exists())

    def test_old_upload_or_cleanup_cannot_replace_newer_run(self):
        self.publish("3.1")
        with self.assertRaises(ValueError):
            self.publish("2.9")
        with self.assertRaises(ValueError):
            UPLOAD.receive(self.root, "remove preview 42 2.1", io.BytesIO())
        self.assertTrue((self.root / "previews/pr-42/current/index.html").exists())

    def test_same_run_retry_and_later_attempt(self):
        self.publish("3.1")
        self.publish("3.1")
        self.publish("3.2")
        with self.assertRaises(ValueError):
            self.publish("3.1")

    def test_previews_are_isolated_from_each_other_and_cms(self):
        self.publish(number=41)
        self.publish(number=42)
        UPLOAD.receive(self.root, f"publish cms 3.1 {SHA}", archive({"index.html": "cms"}))
        UPLOAD.receive(self.root, "remove preview 42 4.1", io.BytesIO())
        self.assertEqual((self.root / "cms/current/index.html").read_text(), "cms")
        self.assertTrue((self.root / "previews/pr-41/current/index.html").exists())

    def test_rejects_traversal_absolute_paths_and_links(self):
        for name in ("../escape", "/tmp/escape", "a/../../escape", "a\\escape"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.publish(entries={"index.html": "ok", name: "bad"})
        for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.CHRTYPE, tarfile.FIFOTYPE):
            info = tarfile.TarInfo("bad")
            info.type = kind
            info.linkname = "/etc/passwd"
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                self.publish(entries={"index.html": "ok", "bad": info})

    def test_upload_size_and_file_count_limits(self):
        old_size, old_count = UPLOAD.MAX_BYTES, UPLOAD.MAX_FILES
        self.addCleanup(setattr, UPLOAD, "MAX_BYTES", old_size)
        self.addCleanup(setattr, UPLOAD, "MAX_FILES", old_count)
        UPLOAD.MAX_BYTES = 3
        with self.assertRaises(ValueError):
            self.publish()
        UPLOAD.MAX_BYTES = old_size
        UPLOAD.MAX_FILES = 1
        with self.assertRaises(ValueError):
            self.publish()

    def test_rejects_shell_and_invalid_arguments(self):
        for command in (
            "", "bash", "scp -t /srv/blog", "remove preview ../cms 1.1",
            f"publish preview 0 1.1 {SHA}", f"publish cms 1.1 {SHA}; id",
            f"publish cms 1.1 {'x' * 40}", f"publish cms -1.1 {SHA}",
        ):
            with self.subTest(command=command), self.assertRaises(ValueError):
                UPLOAD.parse_command(command)


if __name__ == "__main__":
    unittest.main()
