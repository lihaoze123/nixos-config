#!/usr/bin/env python3
"""Bridge the pinned Vinput provider to agenix and the existing terminology file."""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def load_credentials(path):
    if path.stat().st_mode & 0o077:
        raise ValueError("豆包凭据必须仅允许当前用户访问")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("豆包凭据必须为 JSON 对象")
    if data.get("api_key"):
        return {"X-Api-Key": data["api_key"]}
    if data.get("app_id") and data.get("access_token"):
        return {"X-Api-App-Key": data["app_id"], "X-Api-Access-Key": data["access_token"]}
    raise ValueError("请配置豆包 api_key，或 app_id 和 access_token")


def load_terms(parser):
    base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    path = Path(os.environ.get("VOCOTYPE_TERMS_FILE") or base / "vocotype/terms.yaml")
    legacy = base / "vocotype/user-dictionary.yaml"
    if not path.exists() and not os.environ.get("VOCOTYPE_TERMS_FILE") and legacy.exists():
        path = legacy
    if not path.exists():
        return [], []
    result = subprocess.run([parser], input=path.read_text(encoding="utf-8"),
                            text=True, capture_output=True, timeout=5)
    if result.returncode:
        raise ValueError("语音词库格式错误，请检查 terms.yaml")
    terms = json.loads(result.stdout)["terms"]
    hotwords = list(dict.fromkeys(word for term in terms for word in term["hotwords"]
                                 if 0 < len(word) <= 10 and not any(c.isspace() for c in word)))[:1000]
    aliases = [(alias, term["canonical"]) for term in terms for alias in term["aliases"]]
    return hotwords, aliases


def normalize_text(text, aliases):
    # One pass avoids cascading substitutions; Latin aliases match whole words.
    if aliases:
        replacements = dict(aliases)
        patterns = []
        for alias in sorted(replacements, key=len, reverse=True):
            pattern = re.escape(alias)
            if alias[0].isascii() and alias[0].isalnum():
                pattern = r"(?<![A-Za-z0-9_])" + pattern
            if alias[-1].isascii() and alias[-1].isalnum():
                pattern += r"(?![A-Za-z0-9_])"
            patterns.append(pattern)
        text = re.sub("|".join(patterns), lambda match: replacements[match.group()], text)
    return text.rstrip().rstrip("。.")


def load_provider(path):
    spec = importlib.util.spec_from_file_location("vinput_doubao_upstream", path)
    provider = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = provider
    spec.loader.exec_module(provider)
    return provider


def configure_provider(provider, credentials, hotwords, aliases):
    # The registry provider currently expects app_id/access_key. Keep all of its
    # framing/streaming code and replace only authentication at the socket edge.
    provider.resolve_credentials = lambda: (credentials.get("X-Api-App-Key", "vinput"), "")
    original_client = provider.WebSocketClient

    class CredentialClient(original_client):
        def __init__(self, url, headers, timeout):
            headers = {key: value for key, value in headers.items()
                       if key not in {"X-Api-App-Key", "X-Api-Access-Key", "X-Api-Key"}}
            super().__init__(url, {**headers, **credentials}, timeout)

    provider.WebSocketClient = CredentialClient
    original_payload = provider.build_request_payload

    def build_payload(model, user_id):
        payload = original_payload(model, user_id)
        if hotwords:
            payload["request"].setdefault("corpus", {})["context"] = json.dumps(
                {"hotwords": [{"word": word} for word in hotwords]}, ensure_ascii=False)
        return payload

    provider.build_request_payload = build_payload
    original_output = provider.write_stdout

    def emit(event):
        if event.get("type") in {"final", "final_timestamps"} and isinstance(event.get("text"), str):
            event = {**event, "text": normalize_text(event["text"], aliases)}
        if event.get("type") == "error":
            event = {"type": "error", "message": "豆包识别失败，请检查网络、凭据及服务权限"}
        original_output(event)

    provider.write_stdout = emit
    # Upstream exceptions can include server response bodies. Never log them.
    provider.write_stderr = lambda message: print(
        "豆包识别失败，请检查网络、凭据及服务权限", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", type=Path, required=True)
    parser.add_argument("--credentials", type=Path, required=True)
    parser.add_argument("--parser", required=True)
    args = parser.parse_args()
    try:
        credentials = load_credentials(args.credentials)
        hotwords, aliases = load_terms(args.parser)
        provider = load_provider(args.provider)
        configure_provider(provider, credentials, hotwords, aliases)
        return provider.main()
    except Exception:
        print("Vinput 豆包后端启动失败，请检查 agenix 凭据和语音词库", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
