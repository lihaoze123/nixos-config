"""Shared Xiaohe encoding and enabled Rime dictionary readers."""

from pathlib import Path
import hashlib
import io

INITIAL_CODES = {
    "zh": "v",
    "ch": "i",
    "sh": "u",
}

FINAL_CODES = {
    "iu": "q",
    "ei": "w",
    "uan": "r",
    "ue": "t",
    "ve": "t",
    "un": "y",
    "uo": "o",
    "ie": "p",
    "ong": "s",
    "iong": "s",
    "ing": "k",
    "uai": "k",
    "ai": "d",
    "en": "f",
    "eng": "g",
    "uang": "l",
    "iang": "l",
    "ang": "h",
    "ian": "m",
    "an": "j",
    "ou": "z",
    "ua": "x",
    "ia": "x",
    "iao": "n",
    "ao": "c",
    "ui": "v",
    "in": "b",
}

ZERO_INITIAL_CODES = {
    "a": "aa",
    "ai": "ai",
    "an": "an",
    "ang": "ah",
    "ao": "ao",
    "e": "ee",
    "ei": "ei",
    "en": "en",
    "eng": "eg",
    "er": "er",
    "o": "oo",
    "ou": "ou",
}


def is_han(character: str) -> bool:
    codepoint = ord(character)
    return (
        0x3400 <= codepoint <= 0x4DBF
        or 0x4E00 <= codepoint <= 0x9FFF
        or 0xF900 <= codepoint <= 0xFAFF
        or 0x20000 <= codepoint <= 0x2FA1F
    )


def is_ascii_letter(character: str) -> bool:
    return "A" <= character <= "Z" or "a" <= character <= "z"


def is_allowed_term(term: str) -> bool:
    return (
        len(term) >= 2
        and any(is_han(character) for character in term)
        and all(is_han(character) or is_ascii_letter(character) for character in term)
    )


def normalize_syllable(syllable: str) -> str:
    return syllable.lower().replace("u:", "v").replace("ü", "v")


def split_initial(syllable: str) -> tuple[str, str]:
    for initial in ("zh", "ch", "sh"):
        if syllable.startswith(initial):
            return initial, syllable[len(initial) :]

    if len(syllable) >= 2 and syllable[0] not in "aeo":
        return syllable[0], syllable[1:]

    return "", syllable


def initial_code(syllable: str) -> str:
    syllable = normalize_syllable(syllable)
    for initial, code in INITIAL_CODES.items():
        if syllable.startswith(initial):
            return code
    if not syllable or not is_ascii_letter(syllable[0]):
        raise ValueError(f"unsupported syllable: {syllable!r}")
    return syllable[0]


def double_pinyin_code(syllable: str) -> str:
    syllable = normalize_syllable(syllable)
    if syllable in ZERO_INITIAL_CODES:
        return ZERO_INITIAL_CODES[syllable]

    # A literal Latin letter is one unit in a mixed term. Doubling it gives
    # that unit the same two-key width as a Han syllable in a two-unit term.
    if len(syllable) == 1 and is_ascii_letter(syllable):
        return syllable * 2

    initial, final = split_initial(syllable)
    if not initial or not final:
        raise ValueError(f"unsupported syllable: {syllable!r}")

    initial = INITIAL_CODES.get(initial, initial)
    final = FINAL_CODES.get(final, final)
    code = initial + final
    if len(code) != 2 or not code.isascii() or not code.isalpha():
        raise ValueError(f"unsupported syllable: {syllable!r}")
    return code


def pinyin_units(term: str) -> list[str]:
    from pypinyin import Style, lazy_pinyin

    units = lazy_pinyin(
        term,
        style=Style.NORMAL,
        errors=lambda value: list(value),
        strict=False,
    )
    if len(units) != len(term):
        raise ValueError(f"unexpected pinyin segmentation for {term!r}: {units!r}")
    return units


def phrase_code_from_units(term: str, units: list[str]) -> str:
    if len(units) != len(term):
        raise ValueError(f"unexpected pinyin segmentation for {term!r}: {units!r}")
    if len(units) == 2:
        code = double_pinyin_code(units[0]) + double_pinyin_code(units[1])
    elif len(units) == 3:
        code = (
            initial_code(units[0])
            + initial_code(units[1])
            + double_pinyin_code(units[2])
        )
    else:
        code = "".join(initial_code(unit) for unit in units[:3]) + initial_code(
            units[-1]
        )

    if len(code) != 4 or not code.isascii() or not code.isalpha():
        raise ValueError(f"invalid code for {term!r}: {code!r}")
    return code.lower()


def phrase_code(term: str) -> str:
    return phrase_code_from_units(term, pinyin_units(term))


def read_dictionary(path, *, with_fingerprint=False):
    import yaml

    raw = path.read_bytes()
    with io.StringIO(raw.decode("utf-8-sig")) as stream:
        header = []
        for line in stream:
            if line.strip() == "...":
                break
            header.append(line)
        else:
            raise ValueError(f"Missing Rime dictionary header: {path}")
        try:
            metadata = yaml.safe_load("".join(header)) or {}
        except yaml.YAMLError as exc:
            raise ValueError(f"Invalid dictionary header: {path}: {exc}") from exc
        if not isinstance(metadata, dict):
            raise ValueError(f"Dictionary header must be a mapping: {path}")
        body = stream.read()
    if with_fingerprint:
        return metadata, body, hashlib.sha256(raw).digest()
    return metadata, body


def dictionary_rows(body):
    for line in body.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) >= 2:
            # Percentage weights are not corpus frequencies.
            weight = int(fields[2]) if len(fields) >= 3 and fields[2].isdigit() else 0
            yield fields[0], fields[1].casefold(), weight


def enabled_tables(data_dir, user_dir, *, with_fingerprints=False):
    """Yield (path, metadata, body), resolving local overrides and imports once."""
    visited = set()

    def visit(name):
        if name in visited:
            return
        visited.add(name)
        relative = Path(name + ".dict.yaml")
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"Invalid dictionary import: {name}")
        local = user_dir / relative
        path = local if local.is_file() else data_dir / relative
        metadata, body, fingerprint = read_dictionary(path, with_fingerprint=True)
        if with_fingerprints:
            yield path, metadata, body, fingerprint
        else:
            yield path, metadata, body
        imports = metadata.get("import_tables", [])
        if not isinstance(imports, list) or not all(isinstance(name, str) for name in imports):
            raise ValueError(f"Invalid import_tables: {path}")
        for imported in imports:
            yield from visit(imported)

    yield from visit("xhup")
