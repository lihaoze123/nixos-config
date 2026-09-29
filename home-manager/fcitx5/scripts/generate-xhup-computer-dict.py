#!/usr/bin/env python3
"""Generate a supplemental Xiaohe fixed-code dictionary from THUOCL IT."""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path
from typing import Iterable

from xhup_common import is_allowed_term, phrase_code, phrase_code_from_units


SOURCE_NAME = "THUOCL_IT"
DICTIONARY_NAME = "xhup.user.computer"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--source-revision", required=True)
    parser.add_argument("--extra", action="append", default=[], type=Path)
    parser.add_argument("--exclude", action="append", default=[], type=Path)
    parser.add_argument("--pinyin-dictionary", action="append", default=[], type=Path)
    parser.add_argument("--pinyin-overrides", action="append", default=[], type=Path)
    parser.add_argument("--min-frequency", default=1000, type=int)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def self_test() -> None:
    expected_codes = {
        "双拼": "ulpb",
        "输入法": "urfa",
        "他乡遇故知": "txyv",
        "并发": "bkfa",
        "显式": "xmui",
        "客户端": "khdr",
        "IP地址": "ipdv",
        "C语言": "cyyj",
        "略过": "ltgo",
    }
    actual_codes = {term: phrase_code(term) for term in expected_codes}
    if actual_codes != expected_codes:
        raise RuntimeError(
            f"Xiaohe encoder self-test failed: expected {expected_codes!r}, "
            f"got {actual_codes!r}"
        )


def dictionary_files(path: Path) -> Iterable[Path]:
    if path.is_dir():
        yield from sorted(path.rglob("*.yaml"))
    else:
        yield path


def load_excluded_terms(paths: Iterable[Path]) -> set[str]:
    excluded: set[str] = set()
    for path in paths:
        for dictionary_file in dictionary_files(path):
            with dictionary_file.open(encoding="utf-8-sig") as source:
                for line in source:
                    fields = line.rstrip("\n").split("\t")
                    if len(fields) >= 2 and fields[0] and not fields[0].startswith("#"):
                        excluded.add(fields[0].strip().casefold())
    return excluded


def load_reference_pronunciations(paths: Iterable[Path]) -> dict[str, list[list[str]]]:
    pronunciations: dict[str, list[list[str]]] = {}
    for path in paths:
        for dictionary_file in dictionary_files(path):
            with dictionary_file.open(encoding="utf-8-sig") as source:
                for line in source:
                    fields = line.rstrip("\n").split("\t")
                    if len(fields) < 2 or not fields[0] or fields[0].startswith("#"):
                        continue
                    term = fields[0].strip()
                    units = fields[1].strip().split()
                    if len(term) < 2 or len(units) != len(term):
                        continue
                    try:
                        phrase_code_from_units(term, units)
                    except ValueError:
                        continue
                    term_pronunciations = pronunciations.setdefault(term.casefold(), [])
                    if units not in term_pronunciations:
                        term_pronunciations.append(units)
    return pronunciations


def load_pinyin_overrides(paths: Iterable[Path]) -> dict[str, list[list[str]]]:
    overrides: dict[str, list[list[str]]] = {}
    for path in paths:
        with path.open(encoding="utf-8-sig") as source:
            for line_number, line in enumerate(source, start=1):
                content = line.partition("#")[0].strip()
                if not content:
                    continue
                fields = content.split("\t")
                if len(fields) != 2:
                    raise ValueError(
                        f"{path}:{line_number}: expected term and space-separated pinyin"
                    )
                term = fields[0].strip()
                units = fields[1].strip().split()
                phrase_code_from_units(term, units)
                overrides[term.casefold()] = [units]
    return overrides


def load_extra_terms(paths: Iterable[Path]) -> Iterable[str]:
    for path in paths:
        with path.open(encoding="utf-8-sig") as source:
            for line in source:
                term = line.partition("#")[0].strip()
                if term:
                    yield term


def load_thuocl_terms(path: Path, min_frequency: int) -> Iterable[str]:
    with path.open(encoding="utf-8-sig") as source:
        for line_number, line in enumerate(source, start=1):
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 2:
                raise ValueError(
                    f"{path}:{line_number}: expected two tab-separated fields"
                )
            term = fields[0].strip()
            frequency = int(fields[1].strip())
            if frequency >= min_frequency:
                yield term


def add_terms(
    terms: Iterable[str],
    entries: list[tuple[str, str]],
    seen: set[str],
    reference_pronunciations: dict[str, list[list[str]]],
    stats: Counter[str],
    category: str,
) -> None:
    for term in terms:
        key = term.casefold()
        if key in seen:
            stats[f"{category}_existing_or_duplicate"] += 1
            continue
        if not is_allowed_term(term):
            stats[f"{category}_syntax"] += 1
            continue
        try:
            code = phrase_code(term)
            reference_codes = [
                phrase_code_from_units(term, units)
                for units in reference_pronunciations.get(key, [])
            ]
            if reference_codes and code not in reference_codes:
                code = reference_codes[0]
                stats[f"{category}_pronunciation_corrected"] += 1
        except ValueError as error:
            stats[f"{category}_encoding"] += 1
            print(error, file=sys.stderr)
            continue
        entries.append((term, code))
        seen.add(key)
        stats[f"{category}_added"] += 1


def write_dictionary(
    output: Path,
    entries: list[tuple[str, str]],
    source_revision: str,
    min_frequency: int,
    stats: Counter[str],
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    header = f"""# Rime dictionary
# encoding: utf-8
#
# Generated by generate-xhup-computer-dict.py; do not edit directly.
# Source: https://github.com/thunlp/THUOCL ({source_revision})
# Source license: MIT, Copyright (c) 2018 THUNLP
# Filter: document frequency >= {min_frequency}; Han and ASCII-letter/Han terms
# Entries: {len(entries)} ({stats["extra_added"]} local, {stats["thuocl_added"]} THUOCL)

---
name: {DICTIONARY_NAME}
version: "thuocl-{source_revision[:7]}-df{min_frequency}"
sort: original
use_preset_vocabulary: false
...

"""
    with output.open("w", encoding="utf-8", newline="\n") as destination:
        destination.write(header)
        for term, code in entries:
            destination.write(f"{term}\t{code}\n")


def main() -> int:
    args = parse_args()
    self_test()

    excluded = load_excluded_terms(args.exclude)
    reference_pronunciations = load_reference_pronunciations(args.pinyin_dictionary)
    reference_pronunciations.update(load_pinyin_overrides(args.pinyin_overrides))
    entries: list[tuple[str, str]] = []
    seen = set(excluded)
    stats: Counter[str] = Counter()

    add_terms(
        load_extra_terms(args.extra),
        entries,
        seen,
        reference_pronunciations,
        stats,
        "extra",
    )
    add_terms(
        load_thuocl_terms(args.source, args.min_frequency),
        entries,
        seen,
        reference_pronunciations,
        stats,
        "thuocl",
    )
    write_dictionary(
        args.output,
        entries,
        args.source_revision,
        args.min_frequency,
        stats,
    )

    summary = ", ".join(f"{key}={value}" for key, value in sorted(stats.items()))
    print(f"generated {len(entries)} entries: {summary}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
