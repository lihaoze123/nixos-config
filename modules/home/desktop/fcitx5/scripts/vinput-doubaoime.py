#!/usr/bin/env python3
"""Run the pinned Doubao IME provider with sanitized error messages."""

import argparse
import asyncio
import importlib.util
import json
from pathlib import Path
import sys


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def describe_error(message):
    category, _, detail = str(message).partition(":")
    reasons = {
        "No speech was recognized": "未识别到语音，请检查麦克风输入与录音音量",
        "Audio is empty": "录音为空，请按住 F9 说话后再松开",
        "Audio received after finish": "录音结束后仍收到音频，协议时序异常",
        "ASR session finished before the audio source ended": "识别服务提前结束会话，请重新录音",
        "Audio buffer exceeded 10 seconds while the provider was unavailable": "连接建立过慢，音频缓存已超过 10 秒",
    }
    if detail.strip() in reasons:
        return "豆包输入法：" + reasons[detail.strip()]
    if category == "TimeoutError":
        return "豆包输入法请求超时，请稍后重试"
    if category in {"ConnectionError", "ConnectionResetError", "BrokenPipeError", "gaierror", "URLError", "SSLError"}:
        return "豆包输入法网络连接失败或中断，请稍后重试"
    if category == "ASRError":
        return "豆包输入法服务端拒绝了识别请求"
    return "豆包输入法识别失败：未分类的协议或运行错误"


async def run(provider, identity, emit):
    def output(event):
        if event.get("type") == "error":
            event = {"type": "error", "message": describe_error(event.get("message", ""))}
        emit(event)

    return await provider.run_provider(provider.stdin_lines(), output, identity_path=identity)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", type=Path, required=True)
    parser.add_argument("--identity", type=Path, required=True)
    args = parser.parse_args()
    provider = load_module("doubaoime_streaming_upstream", args.provider)
    return asyncio.run(run(provider, args.identity,
                           lambda event: print(json.dumps(event, ensure_ascii=False), flush=True)))


if __name__ == "__main__":
    sys.exit(main())
