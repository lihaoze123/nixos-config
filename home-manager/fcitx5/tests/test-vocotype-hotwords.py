#!/usr/bin/env python3
"""Exercise writes with the same native terms parser as VoCoType."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[1] / "dms-hotwords/backend.py"
spec = importlib.util.spec_from_file_location("hotwords", SCRIPT)
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)
PARSER = os.environ["VOCOTYPE_TEST_PARSER"]


class HotwordTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.path = self.root / "config/vocotype/terms.yaml"
        self.environment = patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.root / "config"),
                                                  "XDG_STATE_HOME": str(self.root / "state-root"),
                                                  "VOCOTYPE_TERMS_FILE": ""})
        self.environment.start()
        self.service = backend.Service(PARSER, self.root / "state")

    def tearDown(self):
        self.environment.stop()
        self.tmp.cleanup()

    def write(self, content):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(content)

    def save(self, query):
        preview = self.service.preview(query)
        return self.service.save(query, preview["fingerprint"])

    def test_new_dictionary_aliases_and_hotword_roundtrip(self):
        result = self.save("NixOS = 尼克斯 | nix os | 尼克斯")
        self.assertEqual(result["status"], "saved")
        self.assertEqual(self.service.parse(self.path.read_text())["terms"], [
            {"canonical": "NixOS", "aliases": ["尼克斯", "nix os"],
             "hotwords": ["NixOS"], "protect": True}])
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_existing_content_comments_backup_and_symlink(self):
        content = "# 我的词库\nterms: [] # 新词\nprotect:\n  - 一加手机\n"
        real = self.root / "real.yaml"
        real.write_text(content)
        self.path.parent.mkdir(parents=True)
        self.path.symlink_to(real)
        result = self.save("豆包")
        self.assertTrue(self.path.is_symlink())
        self.assertEqual(Path(result["backup"]).read_text(), content)
        updated = real.read_text()
        self.assertIn("# 我的词库\nterms: # 新词\n", updated)
        self.assertIn("protect:\n  - 一加手机\n", updated)

    def test_append_preserves_existing_entries_and_legacy_format(self):
        legacy = self.path.with_name("user-dictionary.yaml")
        legacy.parent.mkdir(parents=True)
        content = "replace:\n  Ghostty: [鬼斯提]\nprotect:\n  - 一加手机\n"
        legacy.write_text(content)
        result = self.save("豆包")
        self.assertEqual(result["path"], str(legacy))
        self.assertTrue(legacy.read_text().startswith(content))
        self.assertFalse(self.path.exists())
        second = self.save("NixOS")
        self.assertEqual(second["status"], "saved")
        self.assertEqual(len(self.service.parse(legacy.read_text())["terms"]), 3)

    def test_duplicate_and_alias_conflict_do_not_write(self):
        self.save("NixOS = 尼克斯")
        original = self.path.read_bytes()
        self.assertEqual(self.save("nixos")["status"], "already_exists")
        for query in ("尼克斯", "豆包 = 尼克斯", "豆包 = NixOS"):
            with self.assertRaisesRegex(ValueError, "冲突"):
                self.service.preview(query)
        self.assertEqual(self.path.read_bytes(), original)

    def test_stale_preview_and_invalid_dictionary_do_not_write(self):
        preview = self.service.preview("豆包")
        self.write("terms: []\n# 外部修改\n")
        with self.assertRaisesRegex(ValueError, "变化"):
            self.service.save("豆包", preview["fingerprint"])
        self.write("terms: [broken]\n")
        with self.assertRaisesRegex(ValueError, "词库格式错误"):
            self.service.preview("豆包")
        self.assertEqual(self.path.read_text(), "terms: [broken]\n")

    def test_invalid_input_and_yaml_special_characters(self):
        for query in ("", "many words", "abcdefghijk", "豆包 = 错\n词"):
            with self.assertRaises(ValueError):
                self.service.preview(query)
        for query in ("#tag", "C++", "a:b", 'say"hi', "it's"):
            self.assertEqual(self.save(query)["status"], "saved")
        parsed = self.service.parse(self.path.read_text())
        self.assertEqual([t["canonical"] for t in parsed["terms"]],
                         ["#tag", "C++", "a:b", 'say"hi', "it's"])

    def test_failed_atomic_replace_keeps_original(self):
        self.write("terms: []\n")
        original = self.path.read_bytes()
        with patch.object(backend.os, "replace", side_effect=OSError("模拟写入失败")):
            with self.assertRaises(OSError):
                self.save("豆包")
        self.assertEqual(self.path.read_bytes(), original)
        self.assertFalse(list(self.path.parent.glob(".terms-*")))

    def test_json_service_protocol(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--parser", PARSER],
                                input='{"id":1,"op":"preview","query":"豆包"}\n',
                                capture_output=True, text=True, check=True)
        ready, preview = map(json.loads, result.stdout.splitlines())
        self.assertEqual(ready["event"], "ready")
        self.assertTrue(preview["ok"])
        self.assertEqual(preview["id"], 1)
        self.assertFalse(self.path.exists())

    def test_concurrent_saves_require_fresh_preview(self):
        self.service = backend.Service(PARSER)
        fingerprint = self.service.preview("豆包")["fingerprint"]
        processes = []
        for word in ("豆包", "NixOS"):
            process = subprocess.Popen([sys.executable, str(SCRIPT), "--parser", PARSER],
                                       stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, text=True)
            process.stdin.write(json.dumps({"id": 1, "op": "save", "query": word,
                                           "fingerprint": fingerprint}) + "\n")
            process.stdin.flush()
            processes.append(process)
        replies = []
        for process in processes:
            output, errors = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, errors)
            replies.append(json.loads(output.splitlines()[1]))
        self.assertEqual(sum(reply["ok"] for reply in replies), 1)
        self.assertEqual(len(self.service.parse(self.path.read_text())["terms"]), 1)


if __name__ == "__main__":
    unittest.main()
