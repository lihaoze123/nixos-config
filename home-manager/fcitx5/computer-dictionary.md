# Computer terminology dictionary

The `xhup.user.computer` table supplements the fixed-code Xiaohe dictionary with
computer terminology while keeping the upstream and manually maintained tables
ahead of it.

## Contents

- 5,155 filtered terms from
  [THUOCL_IT](https://github.com/thunlp/THUOCL/blob/master/data/THUOCL_IT.txt).
- 73 locally curated terms covering Nix, reproducible builds, DevOps, Rust, and
  language models.
- 5,228 generated entries in total at the currently pinned source revision.

The generated YAML is a Nix build output and is intentionally not checked into
the repository.

## Generation policy

- The THUOCL source is pinned by Git revision and SHA-256 in `default.nix`.
- THUOCL terms must have document frequency of at least 1,000.
- Terms must contain at least one Han character and otherwise contain only Han
  characters or ASCII letters. Terms containing digits, spaces, or punctuation
  are excluded because the active Xiaohe schema accepts four lowercase letters.
- Existing upstream and manual terms are removed case-insensitively.
- Rime Ice's annotated dictionaries provide preferred pronunciations. Pypinyin
  is used only when a term has no annotated Rime Ice entry.
- Exceptional readings are recorded in `computer-pinyin-overrides.txt`.
- The generated table uses `sort: original` and has no explicit weights. It is
  imported after all existing tables so that it does not replace established
  fixed-code candidates.

The Xiaohe phrase rules are:

- Two characters: both characters' complete double-pinyin codes (2 + 2).
- Three characters: the first two initials and the last complete code (1 + 1 + 2).
- Four or more characters: the first three initials and the final initial.

`generate-xhup-computer-dict.py` runs built-in known-code checks before writing
the dictionary.

## Maintaining the dictionary

- Add current terminology to `computer-terms.txt`, one term per line.
- Add a pronunciation correction to `computer-pinyin-overrides.txt` as a term,
  a tab, and space-separated full pinyin.
- To update THUOCL, change `thuocl-it-rev` and recompute the raw-file hash:

  ```bash
  nix store prefetch-file --json \
    https://raw.githubusercontent.com/thunlp/THUOCL/REV/data/THUOCL_IT.txt
  ```

- Validate without activating:

  ```bash
  nixos-rebuild build --flake .#home
  ```

- Apply after a successful build:

  ```bash
  sudo nixos-rebuild switch --flake .#home
  ```

THUOCL is distributed under the MIT license. Its copyright and license notice
are kept in `THUOCL-LICENSE.txt` and installed with the generated Rime package.
