#!/usr/bin/env python3
"""Add Xiaohe words to editable dictionaries, with a wofi frontend."""

import argparse
from contextlib import contextmanager
from dataclasses import asdict, dataclass
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import unicodedata
import uuid

from xhup_common import (
    dictionary_rows, enabled_tables, is_allowed_term, is_han,
    normalize_syllable, phrase_code_from_units, pinyin_units, read_dictionary,
)

CATEGORIES = {"common": "xhup.user", **{
    name: f"xhup.user.{name}" for name in ("work", "coding", "chat")
}}
CONTROLLER = "org.fcitx.Fcitx.Controller1"


class ChangedError(ValueError):
    pass


class DeployError(RuntimeError):
    pass


class WriteError(OSError):
    def __init__(self, message, saved=False):
        super().__init__(message)
        self.saved = saved


def validate_word(word):
    # Validate before stripping: pasted tabs/newlines must not disappear silently.
    if any(unicodedata.category(c).startswith("C") for c in word):
        raise ValueError("词语不能包含换行、制表符或控制字符")
    word = word.strip()
    if not word or len(word) > 128 or word.startswith("#"):
        raise ValueError("请输入 1–128 个字符的词语，且不能以 # 开头")
    return word


def validate_code(code):
    code = code.strip().lower()
    if not re.fullmatch(r"[a-z]{1,4}", code):
        raise ValueError("编码须为 1–4 个英文字母")
    return code


def suggest_readings(word, data_dir):
    if not is_allowed_term(word):
        return []
    readings = []
    for path in sorted((data_dir / "cn_dicts").glob("*.dict.yaml")):
        # Avoid building a second complete corpus index for just one word.
        with path.open(encoding="utf-8-sig") as stream:
            for line in stream:
                if line.startswith(word + "\t"):
                    units = line.split("\t")[1].strip().split()
                    try:
                        phrase_code_from_units(word, units)
                    except ValueError:
                        continue
                    if units not in readings:
                        readings.append(units)
    return readings or [pinyin_units(word)]


def code_from_reading(word, reading):
    if not is_allowed_term(word):
        raise ValueError("该词不能自动组码，请手填编码")
    units = [normalize_syllable(unit) for unit in reading.split()]
    if len(units) != len(word):
        raise ValueError("请为每个汉字或英文字母填写一个读音单元，用空格分隔")
    # Validate every syllable, including middle characters omitted from a long code.
    from pypinyin.constants import PINYIN_DICT
    from pypinyin.contrib.tone_convert import to_normal
    valid = {to_normal(p).replace("ü", "v")
             for readings in PINYIN_DICT.values() for p in readings.split(",")}
    for char, unit in zip(word, units):
        if (is_han(char) and unit not in valid) or (not is_han(char) and unit != char.lower()):
            raise ValueError(f"无效读音：{char} → {unit}；使用无声调拼音（ü 可写 v）")
    return phrase_code_from_units(word, units)


@dataclass(frozen=True)
class Row:
    word: str
    code: str
    weight: int
    source: str


@dataclass
class Preview:
    word: str
    code: str
    category: str
    target: str
    fingerprint: str
    target_fingerprint: str
    existing: list
    collisions: list

    @property
    def duplicate(self):
        return any(row.code == self.code for row in self.existing)


class Repository:
    def __init__(self, data_dir, user_dir, dictionary_dir, state_dir):
        self.data_dir = data_dir
        self.user_dir = user_dir
        self.dictionary_dir = dictionary_dir.resolve()
        self.state_dir = state_dir

    def preview(self, word, code, category):
        word, code = validate_word(word), validate_code(code)
        if category not in CATEGORIES:
            raise ValueError("未知词库分类")
        name = CATEGORIES[category]
        source = self.dictionary_dir / (name + ".dict.yaml")
        target = source.resolve(strict=True)
        link = self.user_dir / "xhup_dicts" / source.name
        if link.resolve(strict=True) != target:
            raise ValueError(f"用户词库链接未指向仓库源文件：{link}")
        metadata, _ = read_dictionary(target)
        if metadata.get("name") != name or metadata.get("columns", ["text", "code", "weight"]) != ["text", "code", "weight"]:
            raise ValueError(f"词库表头不符合预期：{target}")
        if not os.access(target, os.W_OK) or not os.access(target.parent, os.W_OK):
            raise ValueError(f"词库不可写：{target}")
        rows, active, digest = [], False, hashlib.sha256()
        target_fingerprint = ""
        for path, _, body, fingerprint in enabled_tables(self.data_dir, self.user_dir, with_fingerprints=True):
            resolved = path.resolve(strict=True)
            active |= resolved == target
            if resolved == target:
                target_fingerprint = fingerprint.hex()
            digest.update(str(resolved).encode())
            digest.update(fingerprint)
            for term, key, weight in dictionary_rows(body):
                if term == word or key == code:
                    rows.append(Row(term, key, weight, str(path)))
        if not active:
            raise ValueError(f"目标词库未被 xhup 导入：{name}")
        order = lambda row: (-row.weight, row.word, row.code, row.source)
        return Preview(word, code, category, str(target), digest.hexdigest(), target_fingerprint,
                       sorted([r for r in rows if r.word == word], key=order),
                       sorted([r for r in rows if r.code == code and r.word != word], key=order))

    def known_codes(self, word):
        return sorted({code for _, _, body in enabled_tables(self.data_dir, self.user_dir)
                       for term, code, _ in dictionary_rows(body)
                       if term == word and re.fullmatch(r"[a-z]{1,4}", code)},
                      key=lambda code: (len(code), code))

    @contextmanager
    def locked(self):
        self.state_dir.mkdir(parents=True, exist_ok=True)
        identity = hashlib.sha256(str(self.dictionary_dir).encode()).hexdigest()[:20]
        with (self.state_dir / f"{identity}.lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise ValueError("另一加词操作正在写入，请稍后重试") from exc
            try:
                yield
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)

    def save(self, preview):
        with self.locked():
            current = self.preview(preview.word, preview.code, preview.category)
            if current.duplicate:
                return "already_exists", None
            if (current.fingerprint, current.target) != (preview.fingerprint, preview.target):
                raise ChangedError("词库在确认期间有修改，请重新检查候选并确认")
            target = Path(current.target)
            original = target.read_bytes()
            if hashlib.sha256(original).hexdigest() != current.target_fingerprint:
                raise ChangedError("词库在写入前发生修改，请重新确认")
            text = original.decode("utf-8-sig")
            header, sep, body = text.partition("\n...")
            if not sep:
                raise ValueError("词库缺少 ... 表头结束标记")
            version = f'"user-{uuid.uuid4().hex}"'
            header, count = re.subn(r"(?m)^version:[^\n]*$", f"version: {version}", header)
            if count != 1:
                raise ValueError("词库必须包含一个 version 字段")
            updated = header + sep + body
            updated += ("" if updated.endswith("\n") else "\n") + f"{current.word}\t{current.code}\t100\n"
            payload = (b"\xef\xbb\xbf" if original.startswith(b"\xef\xbb\xbf") else b"") + updated.encode()
            backup_dir = self.state_dir / "backups"
            backup_dir.mkdir(parents=True, exist_ok=True)
            backup = backup_dir / f"{target.name}.{uuid.uuid4().hex}.bak"
            temporary, saved = None, False
            try:
                with backup.open("xb") as stream:
                    os.chmod(backup, 0o600)
                    stream.write(original)
                    stream.flush()
                    os.fsync(stream.fileno())
                with tempfile.NamedTemporaryFile(dir=target.parent, prefix=f".{target.name}.", delete=False) as stream:
                    temporary = Path(stream.name)
                    os.fchmod(stream.fileno(), stat.S_IMODE(target.stat().st_mode))
                    stream.write(payload)
                    stream.flush()
                    os.fsync(stream.fileno())
                if target.read_bytes() != original:
                    raise ChangedError("词库在写入前发生修改，请重新确认")
                os.replace(temporary, target)
                saved = True
                directory = os.open(target.parent, os.O_RDONLY | os.O_DIRECTORY)
                try:
                    os.fsync(directory)
                finally:
                    os.close(directory)
            except OSError as exc:
                raise WriteError(f"{'已替换词库，但刷新目录失败' if saved else '写入失败'}：{exc}；备份：{backup}", saved) from exc
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
            return "saved_only", str(backup)


def bus_call(destination, path, interface, method, *args):
    try:
        result = subprocess.run(["busctl", "--user", "--timeout=15s", "call", destination,
                                 path, interface, method, *args],
                                capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise DeployError(f"D-Bus 调用失败或超时（结果可能未知）：{exc}") from exc
    if result.returncode:
        raise DeployError(result.stderr.strip() or "D-Bus 请求被拒绝")
    return result.stdout.strip()


def deploy_owner(expected_plugin, user_dir):
    dbus = "org.freedesktop.DBus"
    response = bus_call(dbus, "/org/freedesktop/DBus", dbus, "GetNameOwner", "s", "org.fcitx.Fcitx5")
    try:
        owner = json.loads(response.removeprefix("s "))
        pid = int(bus_call(dbus, "/org/freedesktop/DBus", dbus,
                           "GetConnectionUnixProcessID", "s", owner).removeprefix("u "))
        maps = Path(f"/proc/{pid}/maps").read_text()
        plugin = str(expected_plugin.resolve(strict=True))
        if not any(line.split(maxsplit=5)[-1] == plugin for line in maps.splitlines()):
            raise DeployError("当前 Fcitx5 未加载预期 Rime 插件；请完成配置应用和服务交接，或选择仅保存")
        environ = dict(item.split(b"=", 1) for item in Path(f"/proc/{pid}/environ").read_bytes().split(b"\0") if b"=" in item)
        home = Path(os.fsdecode(environ[b"HOME"]))
        data = Path(os.fsdecode(environ.get(b"XDG_DATA_HOME", b""))) if environ.get(b"XDG_DATA_HOME") else home / ".local/share"
        if (data / "fcitx5/rime").resolve() != user_dir.resolve() or environ.get(b"SKIP_FCITX_USER_PATH") == b"1":
            raise DeployError("当前输入法的用户数据目录与加词目录不一致")
    except (ValueError, KeyError, OSError) as exc:
        raise DeployError(f"无法核实当前输入法实例：{exc}") from exc
    return owner


def request_deploy(expected_plugin, user_dir):
    owner = deploy_owner(expected_plugin, user_dir)
    # Address the unique owner, avoiding a race with another instance taking over.
    bus_call(owner, "/controller", CONTROLLER, "SetConfig", "sv",
             "fcitx://config/addon/rime/deploy", "a{sv}", "0")


def notify(message):
    try:
        subprocess.run(["notify-send", "小鹤加词", message], timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired):
        pass


def menu(prompt, choices=(), initial="", editable=False):
    command = ["wofi", "--conf=/dev/null", "--dmenu", "--width=920", "--height=520",
               "--prompt", prompt, "--cache-file=/dev/null", "--define=allow_markup=false",
               "--define=allow_images=false", "--define=pre_display_cmd=", "--search", initial]
    command += ["--exec-search"] if editable else ["--no-custom-entry"]
    result = subprocess.run(command, input="\n".join(choices), capture_output=True, text=True)
    if result.returncode == 1:
        return None  # Escape
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "wofi 启动失败")
    return result.stdout.removesuffix("\n")


def finish(repo, preview, args, save_only):
    status, backup = repo.save(preview)
    result = {"status": status, "word": preview.word, "code": preview.code, "backup": backup}
    if status == "already_exists" or save_only:
        return result, 0
    try:
        request_deploy(args.expected_plugin, args.user_dir)
        result["status"] = "deploy_requested"
        return result, 0
    except DeployError as exc:
        result.update(status="saved_deploy_failed", error=str(exc), retry="xhup-add-word deploy")
        return result, 4


def interactive(repo, args):
    word = args.word if args.command == "add" else ""
    category, code = args.category, args.code
    while True:
        word = menu("词语（单行；Esc 取消）", initial=word, editable=True)
        if word is None:
            return {"status": "cancelled"}, 0
        try:
            word = validate_word(word)
            break
        except ValueError as exc:
            notify(str(exc))
    readings = suggest_readings(word, repo.data_dir)
    reading = " ".join(readings[0]) if readings else ""
    known = repo.known_codes(word)
    code = code or (known[0] if known else phrase_code_from_units(word, readings[0]) if readings else "")
    edit_code = True
    while True:
        if edit_code:
            code = menu(f"{word} │ 读音：{reading or '需手填编码'} │ 已有码：{' / '.join(known) or '无'}", initial=code, editable=True)
            if code is None:
                return {"status": "cancelled"}, 0
        try:
            preview = repo.preview(word, code, category)
        except ValueError as exc:
            notify(str(exc))
            edit_code = True
            continue
        edit_code = False
        try:
            deploy_owner(args.expected_plugin, args.user_dir)
            readiness = "部署可用"
        except DeployError as exc:
            readiness = str(exc)
        info = [f"词语：{word}  编码：{preview.code}  读音：{reading or '—'}",
                f"词库：{category}  权重：100（不保证首选）", f"部署：{readiness}"]
        info += [f"已有：{r.word} │ {r.code} │ {r.weight} │ {Path(r.source).name}" for r in preview.existing]
        info += [f"重码：{r.word} │ {r.code} │ {r.weight} │ {Path(r.source).name}" for r in preview.collisions]
        save = "已存在，关闭" if preview.duplicate else "保存并部署"
        actions = [save, "仅保存", "修改编码", "修改读音并重新编码", "切换词库", "取消"]
        choice = menu(f"确认：{word} → {preview.code} │ {category} │ 重码 {len(preview.collisions)} 项", actions + info)
        if choice is None or choice == "取消":
            return {"status": "cancelled"}, 0
        if choice == "修改编码":
            edit_code = True
        elif choice == "修改读音并重新编码":
            value = menu("无声调拼音，空格分隔（中英混合词逐字母）", initial=reading, editable=True)
            if value is None:
                return {"status": "cancelled"}, 0
            try:
                code = code_from_reading(word, value)
                reading = value
            except ValueError as exc:
                notify(str(exc))
        elif choice == "切换词库":
            value = menu("选择词库", CATEGORIES)
            if value is None:
                return {"status": "cancelled"}, 0
            if value in CATEGORIES:
                category = value
        elif choice in (save, "仅保存"):
            try:
                return finish(repo, preview, args, choice == "仅保存" or args.save_only)
            except ChangedError as exc:
                notify(str(exc))


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--data-dir", type=Path, required=True)
    result.add_argument("--user-dir", type=Path, required=True)
    result.add_argument("--dictionary-dir", type=Path, required=True)
    result.add_argument("--expected-plugin", type=Path, required=True)
    result.add_argument("--state-dir", type=Path, default=Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "xhup-add-word")
    result.set_defaults(word=None, code=None, category="common", yes=False, dry_run=False, save_only=False)
    commands = result.add_subparsers(dest="command")
    add = commands.add_parser("add")
    add.add_argument("word")
    add.add_argument("--code")
    add.add_argument("--category", choices=CATEGORIES, default="common")
    options = add.add_mutually_exclusive_group()
    options.add_argument("--yes", action="store_true")
    options.add_argument("--dry-run", action="store_true")
    add.add_argument("--save-only", action="store_true")
    commands.add_parser("deploy")
    return result


def main():
    args = parser().parse_args()
    gui = args.command != "deploy" and not (args.yes or args.dry_run)
    repo = Repository(args.data_dir, args.user_dir, args.dictionary_dir, args.state_dir)
    try:
        if args.command == "deploy":
            request_deploy(args.expected_plugin, args.user_dir)
            result, status = {"status": "deploy_requested"}, 0
        elif gui:
            result, status = interactive(repo, args)
        else:
            word = validate_word(args.word)
            readings = suggest_readings(word, args.data_dir)
            known = repo.known_codes(word) if not args.code else []
            code = args.code or (known[0] if known else phrase_code_from_units(word, readings[0]) if readings else "")
            preview = repo.preview(word, code, args.category)
            if args.dry_run:
                result, status = {"status": "preview", **asdict(preview), "readings": readings, "duplicate": preview.duplicate}, 0
            else:
                result, status = finish(repo, preview, args, args.save_only)
    except WriteError as exc:
        result, status = {"status": "saved_only" if exc.saved else "write_failed", "error": str(exc)}, 3
    except DeployError as exc:
        result, status = {"status": "deploy_failed", "error": str(exc)}, 4
    except (ValueError, OSError, RuntimeError) as exc:
        result, status = {"status": "error", "error": str(exc)}, 2
    print(json.dumps(result, ensure_ascii=False))
    if gui and result["status"] != "cancelled":
        messages = {"already_exists": "同词同码已存在，未重复添加", "saved_only": "已保存，尚未请求部署",
                    "deploy_requested": "已保存，已请求部署；请留意 Rime 的完成通知",
                    "saved_deploy_failed": "已保存，部署请求失败；可运行 xhup-add-word deploy 重试"}
        notify(messages.get(result["status"], "操作失败") + ("\n" + result["error"] if "error" in result else ""))
    return status


if __name__ == "__main__":
    sys.exit(main())
