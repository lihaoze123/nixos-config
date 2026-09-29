#!/usr/bin/env python3
"""Run with Python + PyYAML: python3 home-manager/fcitx5/tests/test-xhup-lookup.py."""

import base64
import importlib.util
from pathlib import Path
import socket
import sys
import tempfile
import threading
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

spec = importlib.util.spec_from_file_location("xhup_lookup", Path(__file__).resolve().parents[1] / "scripts" / "xhup-lookup.py")
lookup = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = lookup
spec.loader.exec_module(lookup)


class LookupTests(unittest.TestCase):
    def setUp(self):
        self.entries = [
            lookup.Entry("鹤", ("eh", "hedn"), ("he",), 50),
            lookup.Entry("和", ("h", "hehk"), ("he", "huo"), 1000),
            lookup.Entry("黑", ("hw",), ("hei",), 2000),
            lookup.Entry("蛇", ("ue",), ("she",), 3000),
            lookup.Entry("丹顶鹤", ("ddhe",), (), 100),
            lookup.Entry("𠀀", ("ha",), (), 0),
        ]

    def words(self, query):
        return [row.word for row in lookup.search_entries(self.entries, query)[0]]

    def test_prefix_exact_and_frequency(self):
        self.assertEqual(self.words(" HE "), ["和", "鹤", "黑"])
        self.assertEqual(self.words("鹤"), ["鹤"])
        self.assertEqual(self.words("hed"), ["鹤"])
        self.assertEqual(self.words("huo"), ["和"])

    def test_globs_match_whole_fields_and_unicode(self):
        self.assertEqual(self.words("he*"), ["黑", "和", "鹤"])
        self.assertEqual(self.words("?e"), ["蛇", "和", "鹤"])
        self.assertEqual(self.words("[hs]e"), ["和", "鹤"])
        self.assertEqual(self.words("[!h]e"), ["蛇"])
        self.assertEqual(self.words("*鹤"), ["丹顶鹤", "鹤"])
        self.assertIn("𠀀", self.words("?"))
        self.assertEqual(self.words("["), [])
        self.assertEqual(self.words("*不存在*"), [])

    def test_limit_after_matching(self):
        selected, total = lookup.search_entries(self.entries, "he", 1)
        self.assertEqual((selected[0].word, total), ("和", 3))
        self.assertEqual(len(self.words("")), len(self.entries))

    def test_local_override_and_frequency_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data, user = root / "data", root / "user"
            def write(path, body, extra=""):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"---\nname: test\n{extra}...\n{body}")
            write(data / "xhup.dict.yaml", "", "import_tables: [local]\n")
            write(data / "local.dict.yaml", "旧\told\n")
            write(user / "local.dict.yaml", "和\thehk\t5\n词语\tciyu\t100\n")
            write(data / "cn_dicts/8105.dict.yaml", "和\the\t1000\n和\thuo\t20\n")
            write(data / "cn_dicts/base.dict.yaml", "词语\tci yu\t500\n无关\twu guan\t9000\n")
            entries = {e.word: e for e in lookup.load_entries(data, user)}
            self.assertEqual(set(entries), {"和", "词语"})
            self.assertEqual(entries["和"].frequency, 1000)
            self.assertEqual(entries["和"].readings, ("he", "huo"))
            self.assertEqual(entries["词语"].frequency, 500)

    def test_live_protocol_multiple_queries(self):
        parent, child = socket.socketpair()
        with parent, child:
            worker = threading.Thread(target=lookup.serve, args=(child, self.entries))
            worker.start()
            with parent.makefile("rb") as replies:
                for serial, query in enumerate(["he", "*鹤", "missing"], 1):
                    parent.sendall(f"{serial}\t".encode() + base64.b64encode(query.encode()) + b"\n")
                    response = replies.readline()
                    self.assertEqual(response, lookup.encode_response(serial, self.entries, query))
            parent.shutdown(socket.SHUT_WR)
            worker.join(timeout=2)
            self.assertFalse(worker.is_alive())


if __name__ == "__main__":
    unittest.main()
