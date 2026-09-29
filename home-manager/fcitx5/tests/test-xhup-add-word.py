#!/usr/bin/env python3
"""Isolated tests; never touch the real user dictionaries or session bus."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("xhup_add_word", SCRIPTS / "xhup-add-word.py")
add = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = add
spec.loader.exec_module(add)


class AddTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.data, self.user, self.dicts = [self.root / n for n in ("data", "user", "dicts")]
        self.state = self.root / "state"
        self.dicts.mkdir()
        self.data.mkdir()
        (self.user / "xhup_dicts").mkdir(parents=True)
        for name in add.CATEGORIES.values():
            path = self.dicts / f"{name}.dict.yaml"
            path.write_text(f'# retained comment\n---\nname: {name}\nversion: "1"\nsort: by_weight\n...\n# body comment\n已有词\tyyci\t100\n')
            (self.user / "xhup_dicts" / path.name).symlink_to(path)
        self.target = self.dicts / "xhup.user.dict.yaml"
        self.original = self.target.read_bytes()
        (self.data / "xhup.dict.yaml").write_text('---\nname: xhup\nimport_tables:\n' + ''.join(f'  - xhup_dicts/{n}\n' for n in add.CATEGORIES.values()) + '...\n冲突词\tcsci\t200\n')
        self.repo = add.Repository(self.data, self.user, self.dicts, self.state)
        self.args = argparse.Namespace(expected_plugin=Path("/expected/plugin.so"), user_dir=self.user,
                                       word="测试词", category="common", code="csci", command="add", save_only=False)

    def preview(self, word="测试词", code="csci"):
        return self.repo.preview(word, code, "common")

    def test_save_preserves_symlink_comments_mode_and_backup(self):
        self.target.chmod(0o640)
        status, backup = self.repo.save(self.preview())
        self.assertEqual(status, "saved_only")
        self.assertEqual(Path(backup).read_bytes(), self.original)
        self.assertTrue((self.user / "xhup_dicts" / self.target.name).is_symlink())
        saved = self.target.read_text()
        self.assertIn('# retained comment', saved)
        self.assertIn('# body comment\n已有词\tyyci\t100', saved)
        self.assertIn('version: "user-', saved)
        self.assertTrue(saved.endswith('测试词\tcsci\t100\n'))
        self.assertEqual(self.target.stat().st_mode & 0o777, 0o640)
        self.assertEqual(self.repo.save(self.preview())[0], "already_exists")
        self.assertEqual(self.target.read_text().count('测试词\t'), 1)

    def test_conflicts_and_duplicate_across_enabled_tables(self):
        p = self.preview()
        self.assertEqual(p.collisions[0].word, "冲突词")
        self.assertEqual(p.collisions[0].weight, 200)
        self.assertTrue(self.preview("冲突词").duplicate)
        self.assertFalse(self.preview("已有词", "abcd").duplicate)
        self.assertTrue(self.preview("已有词", "yyci").duplicate)

    def test_changed_dictionary_requires_review(self):
        p = self.preview()
        self.target.write_bytes(self.original + b'# external edit\n')
        with self.assertRaises(add.ChangedError):
            self.repo.save(p)
        self.assertNotIn('测试词', self.target.read_text())

    def test_changed_other_table_requires_review(self):
        p = self.preview()
        with (self.data / "xhup.dict.yaml").open("a") as stream:
            stream.write('新冲突\tcsci\t999\n')
        with self.assertRaises(add.ChangedError):
            self.repo.save(p)

    def test_atomic_replace_failure_keeps_original(self):
        with patch.object(add.os, "replace", side_effect=OSError("disk error")):
            with self.assertRaises(add.WriteError) as error:
                self.repo.save(self.preview())
        self.assertFalse(error.exception.saved)
        self.assertEqual(self.target.read_bytes(), self.original)
        self.assertFalse(list(self.dicts.glob('.*')))

    def test_edit_after_revalidation_is_not_overwritten(self):
        preview = self.preview()
        original_preview = self.repo.preview
        def edit_after_preview(*args):
            result = original_preview(*args)
            self.target.write_bytes(self.original + b'# last moment edit\n')
            return result
        with patch.object(self.repo, 'preview', side_effect=edit_after_preview):
            with self.assertRaises(add.ChangedError):
                self.repo.save(preview)
        self.assertTrue(self.target.read_text().endswith('# last moment edit\n'))
        self.assertNotIn('测试词', self.target.read_text())

    def test_bad_header_and_readonly_target(self):
        self.target.write_text('---\nname: [broken\n...\n')
        with self.assertRaisesRegex(ValueError, 'Invalid dictionary header'):
            self.preview()
        self.target.write_bytes(self.original)
        with patch.object(add.os, 'access', return_value=False):
            with self.assertRaisesRegex(ValueError, '不可写'):
                self.preview()

    def test_concurrent_tool_lock(self):
        with self.repo.locked():
            with self.assertRaisesRegex(ValueError, '另一加词'):
                self.repo.save(self.preview())

    def test_wrong_link_and_disabled_target(self):
        link = self.user / "xhup_dicts" / self.target.name
        link.unlink()
        link.symlink_to(self.dicts / "xhup.user.work.dict.yaml")
        with self.assertRaisesRegex(ValueError, '链接'):
            self.preview()
        link.unlink()
        link.symlink_to(self.target)
        (self.data / 'xhup.dict.yaml').write_text('---\nname: xhup\n...\n')
        with self.assertRaisesRegex(ValueError, '未被'):
            self.preview()

    def test_input_validation_and_manual_single_character(self):
        for word in ('', ' ', '词\n', '词\t', 'a\0b', '#注释', '字' * 129):
            with self.subTest(word=word), self.assertRaises(ValueError):
                add.validate_word(word)
        self.assertEqual(add.validate_word('  C++ 开发  '), 'C++ 开发')
        self.assertEqual(add.validate_code(' AbCd '), 'abcd')
        for code in ('', '*', 'ab12', 'abcde', 'Ａ'):
            with self.assertRaises(ValueError):
                add.validate_code(code)
        self.assertEqual(self.preview('鹤', 'hedn').code, 'hedn')
        self.assertEqual(add.suggest_readings('鹤', self.data), [])

    def test_reading_encoding(self):
        examples = [('双拼', 'shuang pin', 'ulpb'), ('输入法', 'shu ru fa', 'urfa'),
                    ('他乡遇故知', 'ta xiang yu gu zhi', 'txyv'), ('C语言', 'c yu yan', 'cyyj'),
                    ('女儿', 'nü er', 'nver'), ('长安', 'chang an', 'ihan')]
        for word, reading, expected in examples:
            self.assertEqual(add.code_from_reading(word, reading), expected)
        for word, reading in [('多音字', 'duo yin'), ('示例词语', 'shi li xxx yu'), ('C语言', 'b yu yan')]:
            with self.assertRaises(ValueError):
                add.code_from_reading(word, reading)

    def test_corpus_reading_precedes_fallback(self):
        (self.data / 'cn_dicts').mkdir()
        (self.data / 'cn_dicts/base.dict.yaml').write_text('---\nname: base\n...\n长安\tchang an\t100\n')
        self.assertEqual(add.suggest_readings('长安', self.data), [['chang', 'an']])

    def test_deploy_failure_retains_word(self):
        with patch.object(add, 'request_deploy', side_effect=add.DeployError('no owner')):
            result, code = add.finish(self.repo, self.preview(), self.args, False)
        self.assertEqual((result['status'], code), ('saved_deploy_failed', 4))
        self.assertIn('测试词\tcsci', self.target.read_text())
        self.assertTrue(Path(result['backup']).exists())

    def test_deploy_request_is_not_completion(self):
        with patch.object(add, 'request_deploy') as request:
            result, code = add.finish(self.repo, self.preview(), self.args, False)
        request.assert_called_once()
        self.assertEqual((result['status'], code), ('deploy_requested', 0))
        with patch.object(add, 'request_deploy') as request:
            self.assertEqual(add.finish(self.repo, self.preview(), self.args, False)[0]['status'], 'already_exists')
        request.assert_not_called()

    def test_save_only_never_contacts_bus(self):
        with patch.object(add, 'request_deploy') as request:
            self.assertEqual(add.finish(self.repo, self.preview(), self.args, True)[0]['status'], 'saved_only')
        request.assert_not_called()

    def test_escape_every_step_does_not_write(self):
        for answers in ([None], ['测试词', None], ['测试词', 'csci', None],
                        ['测试词', 'csci', '修改读音并重新编码', None],
                        ['测试词', 'csci', '切换词库', None]):
            with patch.object(add, 'menu', side_effect=answers), patch.object(add, 'deploy_owner', return_value=':1.42'):
                self.assertEqual(add.interactive(self.repo, self.args)[0]['status'], 'cancelled')
            self.assertEqual(self.target.read_bytes(), self.original)
            self.assertFalse(self.state.exists())

    def test_cli_dry_run_has_no_writes(self):
        result = subprocess.run([sys.executable, str(SCRIPTS / 'xhup-add-word.py'),
                                 '--data-dir', str(self.data), '--user-dir', str(self.user),
                                 '--dictionary-dir', str(self.dicts), '--expected-plugin', '/unused',
                                 '--state-dir', str(self.state), 'add', '测试词', '--code', 'csci', '--dry-run'],
                                capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout)['status'], 'preview')
        self.assertEqual(self.target.read_bytes(), self.original)
        self.assertFalse(self.state.exists())


class DeployTests(unittest.TestCase):
    def test_unique_owner_and_empty_variant(self):
        with patch.object(add, 'deploy_owner', return_value=':1.42'), patch.object(add, 'bus_call') as call:
            add.request_deploy(Path('/plugin'), Path('/user'))
        self.assertEqual(call.call_args.args, (':1.42', '/controller', add.CONTROLLER, 'SetConfig', 'sv',
                                               'fcitx://config/addon/rime/deploy', 'a{sv}', '0'))

    def test_timeout_and_refused_bus_call(self):
        for response in (subprocess.TimeoutExpired('busctl', 20), OSError('missing busctl')):
            with patch.object(add.subprocess, 'run', side_effect=response), self.assertRaises(add.DeployError):
                add.bus_call('d', '/p', 'i', 'm')
        with patch.object(add.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'no owner')):
            with self.assertRaisesRegex(add.DeployError, 'no owner'):
                add.bus_call('d', '/p', 'i', 'm')

    def test_old_plugin_and_wrong_user_directory(self):
        responses = ['s ":1.42"', 'u 123']
        with (patch.object(add, 'bus_call', side_effect=responses),
              patch.object(Path, 'resolve', return_value=Path('/new/plugin')),
              patch.object(Path, 'read_text', return_value='123 r-xp 000 00 1 /old/plugin')):
            with self.assertRaisesRegex(add.DeployError, '预期 Rime'):
                add.deploy_owner(Path('/new/plugin'), Path('/user'))

        # The plugin can match while the process uses another user's data dir.
        with tempfile.TemporaryDirectory() as tmp:
            plugin = Path(tmp) / 'librime.so'
            plugin.touch()
            with (patch.object(add, 'bus_call', side_effect=responses),
                  patch.object(Path, 'read_text', return_value=f'123 r-xp 000 00 1 {plugin}'),
                  patch.object(Path, 'read_bytes', return_value=b'HOME=/another/home\0')):
                with self.assertRaisesRegex(add.DeployError, '目录不一致'):
                    add.deploy_owner(plugin, Path('/user'))


if __name__ == '__main__':
    unittest.main()
