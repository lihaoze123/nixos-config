# Notes: Computer terminology dictionary

## Sources

### THUOCL IT
- URL: https://github.com/thunlp/THUOCL
- Raw data: https://raw.githubusercontent.com/thunlp/THUOCL/master/data/THUOCL_IT.txt
- License: MIT
- Entries: 16,000
- Fields: term and document frequency
- Last dataset update stated by upstream: 2016-12-24

### Existing Rime computer dictionary
- URL: https://github.com/mutoe/rime/blob/master/luna_pinyin.computer.dict.yaml
- Approximately 9,655 entries; old and not encoded for Xiaohe fixed-code input.

### Sogou specialized dictionaries
- General computer dictionary: https://pinyin.sogou.com/dict/detail/index/15117
- Developer dictionary: https://pinyin.sogou.com/dict/detail/index/75228/
- AI programming dictionary: https://pinyin.sogou.com/dict/detail/index/176192
- Useful as optional supplements, but licensing and redistribution terms are less explicit than THUOCL.

## Local Findings
- The active `xhup` schema uses a four-character table translator and does not automatically consume the bundled pinyin dictionaries.
- Existing custom dictionaries use `word<TAB>four-letter-code<TAB>weight`.
- Initial comparison found only about 169 THUOCL IT terms in the pinned Xiaohe fixed-code tables.
- The official phrase rules are 2+2 for two characters, 1+1+2 for three characters, and first/second/third/final initials for four or more characters.
- The current `default.nix` and split user dictionaries are staged user changes and must be preserved.
- `python3Packages.pypinyin` 0.55.0 is available from the configured nixpkgs.
- THUOCL master currently resolves to commit `a30ce79d895d01ab5132a5c74c29703ff7efb4cc`.

## Synthesized Findings
- A generated Xiaohe table is required; copying a pinyin Rime dictionary directly will not work.
- The source revision and derivation inputs should be pinned in Nix so dictionary updates are explicit and reproducible.
- With a DF threshold of 1,000, THUOCL contributes 5,501 candidates before syntax filtering: 4,873 Han-only terms and 628 single-character or mixed terms.
- Mixed ASCII-letter/Han terms such as `Java代码` can use literal Latin initials plus Xiaohe initials; punctuation/digit-bearing terms are excluded because the active schema only accepts lowercase letters and has a four-code limit.
- The generated table should use `sort: original` and omit weights so it supplements rather than outranks the pinned Xiaohe tables.
- Source hash: `sha256-6M1CyfVVlzX6O/uRUVy+BR+ZHv1KgDA4odXA2oWvNSY=`.
- The generator accepts existing dictionaries as exclusions, runs known-code self-tests, uses phrase-aware pypinyin conversion, and emits a separate `xhup.user.computer` table.
- The generated table is copied into the pinned rime-crane package and imported after all manually maintained user tables.
- A pronunciation audit matched 4,721 generated entries against Rime Ice and found 51 pypinyin polyphone errors. The generator now consumes Rime Ice's annotated `cn_dicts` as its preferred pronunciation source and falls back to pypinyin only for unmatched terms.
- Local terminology is also audited separately; `computer-pinyin-overrides.txt` records explicit corrections such as `重排序模型` (`chong pai xu mo xing`).

## Validation Results
- Generated entries: 5,228 total (5,155 THUOCL, 73 local).
- Removed as already present or duplicated: 271 THUOCL terms and 1 local term.
- Rejected by syntax policy: 75 THUOCL terms.
- Corrected through Rime Ice pronunciation data: 51 terms.
- Structural checks: zero malformed entries, zero duplicate terms, zero overlap with the pinned Xiaohe tables, and all codes are four lowercase ASCII letters.
- Pronunciation cross-check: 4,721 annotated Rime Ice matches with zero final code mismatches.
- Package build: the customized `fcitx5-rime` package built successfully.
- Full build: `nixos-rebuild build --flake path:/home/chumeng/nixos-config#home` succeeded.
- Runtime-style deployment: `rime_deployer --build` compiled `xhup.table.bin`, reverse table, schema, and prism successfully with all four manual user dictionaries present.
