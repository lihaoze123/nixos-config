#!/usr/bin/env python3
"""Offline Xiaohe prefix/glob lookup with a live wofi frontend."""

import argparse
import base64
from collections import defaultdict
from dataclasses import dataclass
import fnmatch
import heapq
import os
from pathlib import Path
import re
import socket
import subprocess

from xhup_common import dictionary_rows, enabled_tables, read_dictionary


@dataclass(frozen=True)
class Entry:
    word: str
    codes: tuple[str, ...]
    readings: tuple[str, ...]
    frequency: int

    @property
    def fields(self):
        return (self.word.casefold(), *self.codes, *self.readings)

    @property
    def label(self):
        return f"{self.word}  │  {' / '.join(self.codes)}  │  {' / '.join(self.readings)}"

    @property
    def action(self):
        return " / ".join(self.codes)


def load_entries(data_dir, user_dir):
    codes = defaultdict(set)
    frequencies = defaultdict(int)
    for _, _, body in enabled_tables(data_dir, user_dir):
        for word, code, weight in dictionary_rows(body):
            codes[word].add(code)
            frequencies[word] = max(frequencies[word], weight)

    pronunciations = defaultdict(set)
    # Use the same maximum-per-character policy as generate-xhup-reverse-dict.py.
    # Phrase weights come from the bundled Rime Ice base corpus, not word length.
    for filename in ("8105.dict.yaml", "base.dict.yaml"):
        _, body = read_dictionary(data_dir / "cn_dicts" / filename)
        for word, pinyin, weight in dictionary_rows(body):
            if word not in codes:
                continue
            frequencies[word] = max(frequencies[word], weight)
            if len(word) == 1:
                pronunciations[word].add(pinyin)

    return [
        Entry(word, tuple(sorted(word_codes, key=lambda code: (len(code), code))),
              tuple(sorted(pronunciations[word])), frequencies[word])
        for word, word_codes in codes.items()
    ]


def search_entries(entries, query, limit=None):
    """Literal input is a field prefix; glob input matches a whole field."""
    query = query.strip().casefold()
    glob = any(char in query for char in "*?[")
    pattern = re.compile(fnmatch.translate(query)) if glob else None

    def ranked():
        for item in entries:
            fields = item.fields
            matched = (any(pattern.fullmatch(field) for field in fields) if glob
                       else any(field.startswith(query) for field in fields))
            if matched:
                # Exact field matches precede prefix matches, then frequency.
                # Glob matches form one frequency-sorted group.
                exact = not glob and query in fields
                yield (not exact, -item.frequency, item.word), item

    matches = list(ranked())
    selected = sorted(matches) if limit is None else heapq.nsmallest(limit, matches)
    return [item for _, item in selected], len(matches)


def encode_response(serial, entries, query, limit=200):
    matches, total = search_entries(entries, query, limit)
    # Each packet is a single line. Base64 keeps Unicode, tabs and newlines out
    # of framing; actions and labels themselves are normalized to single lines.
    rows = "\n".join(
        f"{' '.join(item.action.split())}\t{' '.join(item.label.split())}"
        for item in matches
    )
    encoded = base64.b64encode(rows.encode()).decode()
    return f"{serial}\t{total}\t{encoded}\n".encode()


def serve(channel, entries):
    with channel.makefile("rb") as requests:
        for request in requests:
            serial, encoded = request.rstrip(b"\n").split(b"\t", 1)
            query = base64.b64decode(encoded, validate=True).decode()
            channel.sendall(encode_response(int(serial), entries, query))


def menu(entries):
    parent, child = socket.socketpair()
    command = [
        "wofi", "--dmenu", "--prompt", "小鹤反查：前缀 / glob（* ? []）",
        "--width=760", "--height=520", "--no-custom-entry",
        "--cache-file=/dev/null", "--define=allow_markup=false",
        "--define=allow_images=false", "--define=filter_rate=60",
        "--define=exec_search=false", "--define=key_copy=Ctrl-c",
        "--define=pre_display_cmd=", "--define=use_search_box=false",
    ]
    with parent, child:
        process = subprocess.Popen(
            command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, text=True,
            pass_fds=(child.fileno(),),
            env={**os.environ, "WOFI_LOOKUP_FD": str(child.fileno())},
        )
        child.close()
        try:
            serve(parent, entries)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Escape/selection may close wofi while a query is in flight.
        except BaseException:
            if process.poll() is None:
                process.terminate()
            process.wait()
            raise
        output, _ = process.communicate()
    if process.returncode == 0 and output.rstrip("\n"):
        selected = output.rstrip("\n")
        if selected in {item.action for item in entries}:
            subprocess.run(["wl-copy", "--", selected], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--user-dir", type=Path, required=True)
    parser.add_argument("--query", help="Print prefix/glob results without opening wofi")
    args = parser.parse_args()
    entries = load_entries(args.data_dir, args.user_dir)
    if args.query is not None:
        for item in search_entries(entries, args.query)[0]:
            print(item.label)
    else:
        menu(entries)


if __name__ == "__main__":
    main()
