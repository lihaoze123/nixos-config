# Rime (Xiaohe/rime-crane) data shared by rime.nix and xhup.nix.
{ pkgs, lib, homeDirectory }:
let
  # Keep Python entry points beside their shared module in the store.
  xhup-script-bundle = name: files: pkgs.runCommand name { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n"
      (file: "cp ${./scripts + "/${file}"} $out/${file}")
      ([ "xhup_common.py" ] ++ files)}
  '';
  xhup-encoder-scripts = xhup-script-bundle "xhup-encoder-scripts" [ "generate-xhup-computer-dict.py" ];
  xhup-lookup-scripts = xhup-script-bundle "xhup-lookup-scripts" [ "xhup-lookup.py" ];
  xhup-add-scripts = xhup-script-bundle "xhup-add-scripts" [ "xhup-add-word.py" ];
  rime-crane-rev = "71f3add6a39d58a8e8b35abc7ca9c998d766b274";
  thuocl-it-rev = "a30ce79d895d01ab5132a5c74c29703ff7efb4cc";
  # Words added by xhup-add-word live in a separate private repository, so
  # adding one changes neither this configuration nor the system build.
  rime-user-dictionaries = [
    "xhup.user.dict.yaml"
    "xhup.user.chat.dict.yaml"
    "xhup.user.coding.dict.yaml"
    "xhup.user.work.dict.yaml"
  ];
  rime-user-dictionary-repo = "git@github.com:lihaoze123/xhup-dicts.git";
  rime-crane-config-id = builtins.hashString "sha256" ''
    ${rime-crane-rev}
    ${xhup-computer-dictionary}
    ${xhup-reverse-dictionary}
    ${builtins.readFile ./config/default.custom.yaml}
    ${builtins.readFile ./config/xhup.custom.yaml}
    ${builtins.readFile ./patches/rime-crane-shortcuts.patch}
  '';
  rime-crane-src = pkgs.fetchFromGitHub {
    owner = "kchen0x";
    repo = "rime-crane";
    rev = rime-crane-rev;
    hash = "sha256-+eZ82uy8XJ8L9Mm/Kj1kVgBEMg2IUN2lrrmhiHcLpLM=";
  };
  thuocl-it-src = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/thunlp/THUOCL/${thuocl-it-rev}/data/THUOCL_IT.txt";
    hash = "sha256-6M1CyfVVlzX6O/uRUVy+BR+ZHv1KgDA4odXA2oWvNSY=";
  };

  xhup-computer-dictionary = pkgs.runCommand "xhup-user-computer-dictionary"
    {
      nativeBuildInputs = [
        (pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pypinyin ]))
      ];
    } ''
    mkdir -p $out/share/rime-data/xhup_dicts
    python ${xhup-encoder-scripts}/generate-xhup-computer-dict.py \
      --source ${thuocl-it-src} \
      --source-revision ${thuocl-it-rev} \
      --extra ${./dictionaries/computer-terms.txt} \
      --pinyin-dictionary ${rime-crane-src}/cn_dicts \
      --pinyin-overrides ${./dictionaries/computer-pinyin-overrides.txt} \
      --exclude ${rime-crane-src}/xhup_dicts \
      --min-frequency 1000 \
      --output $out/share/rime-data/xhup_dicts/xhup.user.computer.dict.yaml
  '';

  xhup-reverse-dictionary = pkgs.runCommand "xhup-weighted-reverse-dictionary"
    {
      nativeBuildInputs = [ pkgs.python3 ];
    } ''
    mkdir -p $out/share/rime-data
    python ${./scripts/generate-xhup-reverse-dict.py} \
      --reverse-dictionary ${rime-crane-src}/xhup_reverse.dict.yaml \
      --frequency-dictionary ${rime-crane-src}/cn_dicts/8105.dict.yaml \
      --output $out/share/rime-data/xhup_reverse.dict.yaml
  '';

  rime-crane = pkgs.stdenvNoCC.mkDerivation {
    pname = "rime-crane";
    version = builtins.substring 0 7 rime-crane-rev;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.patch (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/rime-data
      cp -r ${rime-crane-src}/. $out/share/rime-data/
      chmod -R u+w $out/share/rime-data
      # Upstream shortcut tables omit Linux/Others (NixOS). Keep ordinary
      # translation and candidate selection working on unsupported systems.
      patch -d "$out/share/rime-data" -p1 < ${./patches/rime-crane-shortcuts.patch}
      cp -r ${xhup-computer-dictionary}/share/rime-data/. $out/share/rime-data/
      install -Dm644 \
        ${xhup-reverse-dictionary}/share/rime-data/xhup_reverse.dict.yaml \
        $out/share/rime-data/xhup_reverse.dict.yaml
      install -Dm644 ${./dictionaries/THUOCL-LICENSE.txt} $out/share/licenses/rime-crane/THUOCL.txt
      # Preserve our existing priority: upstream tables, manual user tables,
      # then generated computer terms. Parse YAML instead of matching comments.
      python - "$out/share/rime-data/xhup.dict.yaml" <<'PY'
      from pathlib import Path
      import sys
      import yaml

      path = Path(sys.argv[1])
      header, separator, body = path.read_text(encoding="utf-8").partition("\n...")
      if not separator:
          raise ValueError("xhup.dict.yaml is missing its dictionary header separator")
      metadata = yaml.safe_load(header)
      tables = metadata["import_tables"]
      if tables.count("xhup_dicts/xhup.user") != 1:
          raise ValueError("expected exactly one upstream user dictionary import")
      local_tables = [
          "xhup_dicts/xhup.user",
          "xhup_dicts/xhup.user.work",
          "xhup_dicts/xhup.user.coding",
          "xhup_dicts/xhup.user.chat",
          "xhup_dicts/xhup.user.computer",
      ]
      metadata["import_tables"] = [table for table in tables if table not in local_tables] + local_tables
      path.write_text(
          "# Rime dictionary; local user tables follow upstream tables.\n"
          + yaml.safe_dump(metadata, allow_unicode=True, sort_keys=False, explicit_start=True, explicit_end=True)
          + body.lstrip("\n"),
          encoding="utf-8",
      )
      PY

      runHook postInstall
    '';
  };

  fcitx5-rime-crane = pkgs.fcitx5-rime.override {
    rimeDataPkgs = [ rime-crane ];
  };
in
{
  inherit rime-crane fcitx5-rime-crane rime-crane-config-id
    rime-user-dictionaries rime-user-dictionary-repo
    xhup-lookup-scripts xhup-add-scripts;
  rime-user-data-dir = "${homeDirectory}/.local/share/fcitx5/rime";
  rime-user-dictionary-dir = "${homeDirectory}/src/xhup-dicts";
}
