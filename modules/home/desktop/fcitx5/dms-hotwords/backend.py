#!/usr/bin/env python3
"""DMS quick-add service over the existing VoCoType terminology dictionary."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


def terms_path():
    override = os.environ.get("VOCOTYPE_TERMS_FILE")
    if override:
        return Path(override).expanduser().resolve()
    base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config").expanduser()
    preferred = base / "vocotype/terms.yaml"
    legacy = base / "vocotype/user-dictionary.yaml"
    return (legacy if not preferred.exists() and legacy.exists() else preferred).resolve()


def scalar(value):
    if not value or any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise ValueError("词条不能为空或包含控制字符")
    # The native parser strips enclosing quotes but does not decode escapes.
    if "'" not in value:
        return "'" + value + "'"
    if '"' not in value and "\\" not in value:
        return '"' + value + '"'
    raise ValueError("词条含有无法安全写入的引号组合，请在设置中心维护")


def parse_query(query):
    word, separator, tail = query.partition("=")
    word = word.strip()
    if not word or len(word) > 10 or any(c.isspace() for c in word):
        raise ValueError("热词需为 1–10 个字符且不含空格，例如 NixOS、豆包")
    scalar(word)
    aliases = list(dict.fromkeys(a.strip() for a in tail.split("|")
                                if a.strip() and a.strip() != word)) if separator else []
    for alias in aliases:
        if len(alias) > 128:
            raise ValueError("每条别名最多 128 个字符")
        scalar(alias)
    return word, aliases


class Service:
    def __init__(self, parser, state_dir=None):
        self.parser = parser
        self.state_dir = Path(state_dir or
                              Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
                              / "vocotype-hotwords")

    def parse(self, content):
        result = subprocess.run([self.parser], input=content, text=True,
                                capture_output=True, timeout=5)
        if result.returncode:
            raise ValueError("词库格式错误，未修改：" + result.stderr.strip())
        return json.loads(result.stdout)

    def snapshot(self):
        path = terms_path()
        content = path.read_text(encoding="utf-8") if path.exists() else ""
        document = self.parse(content or "terms: []\nprotect: []\n")
        fingerprint = hashlib.sha256((str(path) + "\0" + content).encode()).hexdigest()
        return path, content, document, fingerprint

    def preview(self, query):
        word, aliases = parse_query(query)
        path, _, document, fingerprint = self.snapshot()
        existing = next((t for t in document["terms"]
                         if t["canonical"].lower() == word.lower()), None)
        conflicts = [t["canonical"] for t in document["terms"]
                     if t["canonical"].lower() != word.lower()
                     and any(a.lower() in {word.lower(), *(v.lower() for v in aliases)}
                             for a in [t["canonical"], *t["aliases"]])]
        if conflicts:
            raise ValueError("词语或别名与已有词条冲突：" + "、".join(conflicts))
        return {"word": word, "aliases": aliases, "path": str(path),
                "fingerprint": fingerprint, "existing": existing}

    def save(self, query, fingerprint):
        self.state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (self.state_dir / "write.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            preview = self.preview(query)
            if preview["fingerprint"] != fingerprint:
                raise ValueError("词库已变化，请重新输入以刷新预览后保存")
            if preview["existing"]:
                return {"status": "already_exists", "word": preview["word"]}
            path, content, _, current_fingerprint = self.snapshot()
            if current_fingerprint != fingerprint:
                raise ValueError("词库已变化，请刷新后重试")
            word, aliases = preview["word"], preview["aliases"]
            block = "  - canonical: " + scalar(word) + "\n"
            if aliases:
                block += "    aliases:\n" + "".join("      - " + scalar(a) + "\n" for a in aliases)
            block += "    hotword: true\n    protect: true\n"
            updated = append_term(content, block)
            parsed = self.parse(updated)
            # Check round-trip values against the native parser, not generic YAML.
            new = next(t for t in parsed["terms"] if t["canonical"] == word)
            if new["aliases"] != aliases or new["hotwords"] != [word] or not new["protect"]:
                raise ValueError("词条无法正确解析，未保存")
            path.parent.mkdir(parents=True, exist_ok=True)
            backup = None
            if content:
                backup_dir = self.state_dir / "backups"
                backup_dir.mkdir(exist_ok=True, mode=0o700)
                backup = backup_dir / f"terms-{time.time_ns()}.yaml"
                with backup.open("x", encoding="utf-8") as output:
                    os.chmod(backup, 0o600)
                    output.write(content)
            fd, temporary = tempfile.mkstemp(prefix=".terms-", dir=path.parent)
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as output:
                    output.write(updated)
                    output.flush()
                    os.fsync(output.fileno())
                if self.snapshot()[3] != fingerprint:
                    raise ValueError("保存期间词库已变化，请刷新后重试")
                os.replace(temporary, path)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
            return {"status": "saved", "word": word, "path": str(path),
                    "backup": str(backup) if backup else None}


def append_term(content, block):
    # Only insert the new block; leave existing comments, spelling and sections intact.
    match = re.search(r"^terms:([^\n]*)(?:\n|$)", content, re.MULTILINE)
    if not match:
        return content + ("\n" if content and not content.endswith("\n") else "") + "terms:\n" + block
    value, _, comment = match.group(1).partition("#")
    if value.strip() == "[]":
        header = "terms:" + (" #" + comment if comment else "") + "\n"
        return content[:match.start()] + header + block + content[match.end():]
    if value.strip():
        raise ValueError("terms 必须是列表")
    following = re.search(r"^[^\s#][^\n]*:", content[match.end():], re.MULTILINE)
    end = match.end() + following.start() if following else len(content)
    prefix = content[:end]
    return prefix + ("" if prefix.endswith("\n") else "\n") + block + content[end:]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--parser", required=True)
    args = parser.parse_args()
    service = Service(args.parser)
    print(json.dumps({"event": "ready"}), flush=True)
    for line in sys.stdin:
        request = {}
        try:
            request = json.loads(line)
            if request["op"] == "preview":
                result = service.preview(request["query"])
            elif request["op"] == "save":
                result = service.save(request["query"], request["fingerprint"])
            else:
                raise ValueError("不支持的操作")
            response = {"id": request.get("id"), "ok": True, **result}
        except Exception as error:
            response = {"id": request.get("id") if isinstance(request, dict) else None,
                        "ok": False, "error": str(error)}
        print(json.dumps(response, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
