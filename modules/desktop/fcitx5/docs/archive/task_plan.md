# Task Plan: Add a computer terminology dictionary

## Goal
Add a reproducible, filtered THUOCL IT dictionary to the existing Rime Xiaohe fixed-code configuration and verify that it builds correctly.

## Phases
- [x] Phase 1: Inspect the repository and Xiaohe encoding rules
- [x] Phase 2: Design and document the source, filtering, and generation process
- [x] Phase 3: Generate and integrate the dictionary
- [x] Phase 4: Validate the generated data and Nix configuration
- [x] Phase 5: Review and deliver

## Key Questions
1. How should pinyin be obtained accurately enough to generate Xiaohe phrase codes?
2. How can the upstream source and generated output remain reproducible under Nix?
3. Which filters minimize stale or noisy candidates without discarding useful technical terms?

## Decisions Made
- Use THUOCL_IT as the primary source because it is a focused 16,000-entry IT lexicon with an MIT license and frequency data.
- Keep the computer dictionary separate from manually maintained coding terms.
- Generate standard Xiaohe phrase codes: 2-character words use 2+2, 3-character words use 1+1+2, and longer words use the first three and final initials.
- Preserve the user's staged `default.nix` and split-dictionary changes; make only additive working-tree edits on top of them.
- Pin the THUOCL raw IT file at commit `a30ce79d895d01ab5132a5c74c29703ff7efb4cc` with its Nix content hash.
- Keep THUOCL terms with document frequency at least 1,000; accept Han-only and mixed ASCII-letter/Han terms, but exclude terms containing digits or punctuation.
- Use pypinyin from the flake-pinned nixpkgs, with built-in Xiaohe mapping self-tests and phrase-aware pronunciation.
- Emit an `original`-order dictionary without explicit weights, import it after existing and manual tables, and exclude existing terms case-insensitively to preserve current fixed-code priority.
- Keep modern Nix, DevOps, Rust, and LLM terminology in a small local source list that is generated with the same rules.

## Errors Encountered
- The formatter/linter executables were not present in the active PATH. Run the flake-pinned tools through `nix shell` instead.
- Cross-checking 4,721 generated entries against Rime Ice's annotated dictionaries found 51 pypinyin polyphone mismatches, such as `命令行` and `重定向`. Use Rime Ice pronunciations when available and retain pypinyin only as a fallback.
- The first package build could not copy the generated dictionary into the copied upstream `xhup_dicts` directory because its Nix-store-derived permissions were read-only. Make the build output writable immediately after copying upstream data.
- The initial Nix patch accidentally included a literal `+` in a generated command separator. Removed it before evaluation; the first corrective patch did not match the escaped line, so the exact byte sequence was patched on the second attempt.
- Launching `python3` and `python3Packages.pypinyin` as separate `nix shell` inputs did not add pypinyin to Python's import path. Use a `python3.withPackages` wrapper instead.

## Status
**Complete** - The generated dictionary, Nix integration, documentation, and full build/deployment validation are finished.
