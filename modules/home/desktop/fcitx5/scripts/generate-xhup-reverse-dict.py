#!/usr/bin/env python3
"""Add Rime Ice character-frequency weights to the Xiaohe reverse dictionary."""

from __future__ import annotations

import argparse
from pathlib import Path


def dictionary_body(path: Path) -> tuple[list[str], list[str]]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    try:
        separator = lines.index("...")
    except ValueError as error:
        raise ValueError(f"missing YAML body separator in {path}") from error
    return lines[: separator + 1], lines[separator + 1 :]


def read_character_frequencies(path: Path) -> dict[str, int]:
    _, body = dictionary_body(path)
    frequencies: dict[str, int] = {}
    for line_number, line in enumerate(body, start=1):
        if not line or line.lstrip().startswith("#"):
            continue
        columns = line.split("\t")
        if len(columns) < 3 or len(columns[0]) != 1:
            continue
        try:
            frequency = int(columns[-1])
        except ValueError as error:
            raise ValueError(
                f"invalid character frequency at {path}:{line_number}: {line}"
            ) from error
        character = columns[0]
        frequencies[character] = max(frequencies.get(character, 0), frequency)
    if not frequencies:
        raise ValueError(f"no single-character frequencies found in {path}")
    return frequencies


def add_weights(
    reverse_dictionary: Path, frequencies: dict[str, int]
) -> tuple[list[str], int, int]:
    header, body = dictionary_body(reverse_dictionary)
    output: list[str] = []
    weighted_count = 0
    row_count = 0
    for line_number, line in enumerate(body, start=1):
        if not line or line.lstrip().startswith("#"):
            output.append(line)
            continue
        columns = line.split("\t")
        if len(columns) != 2:
            raise ValueError(
                f"expected character and code at {reverse_dictionary}:{line_number}: {line}"
            )
        character, code = columns
        weight = frequencies.get(character, 0)
        weighted_count += weight > 0
        row_count += 1
        output.append(f"{character}\t{code}\t{weight}")

    if not row_count:
        raise ValueError(f"no reverse dictionary entries found in {reverse_dictionary}")

    sort_lines = [index for index, line in enumerate(header) if line.startswith("sort:")]
    if len(sort_lines) != 1:
        raise ValueError(f"expected one sort setting in {reverse_dictionary}")
    header[sort_lines[0]] = "sort: by_weight"
    header.insert(
        sort_lines[0] + 1,
        "# Character weights use the maximum frequency in Rime Ice 8105; other characters use 0.",
    )
    return header + output, row_count, weighted_count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reverse-dictionary", required=True, type=Path)
    parser.add_argument("--frequency-dictionary", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    frequencies = read_character_frequencies(args.frequency_dictionary)
    lines, row_count, weighted_count = add_weights(args.reverse_dictionary, frequencies)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(
        f"Wrote {row_count} reverse entries; "
        f"{weighted_count} have Rime Ice frequency weights, "
        f"{row_count - weighted_count} use fallback weight 0."
    )


if __name__ == "__main__":
    main()
