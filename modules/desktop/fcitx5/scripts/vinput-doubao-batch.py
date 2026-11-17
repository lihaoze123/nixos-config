#!/usr/bin/env python3
"""Vinput batch provider: raw PCM on stdin, recognized text on stdout."""

import argparse
import array
import asyncio
import importlib.util
import math
from pathlib import Path
import sys

MAX_AUDIO_BYTES = 25 * 1024 * 1024


def load_module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


bridge = load_module("vinput_bridge", "vinput-doubao.py")
worker = load_module("doubao_worker", "doubao-asr-worker.py")


def apply_gain(pcm, gain):
    if not pcm or len(pcm) % 2 or len(pcm) > MAX_AUDIO_BYTES:
        raise ValueError("录音为空、格式无效或超过 25 MiB")
    if not math.isfinite(gain) or not 0.1 <= gain <= 10:
        raise ValueError("输入增益必须在 0.1 到 10 之间")
    values = array.array("h", pcm)
    if sys.byteorder != "little":
        values.byteswap()
    for index, value in enumerate(values):
        values[index] = max(-32768, min(32767, round(value * gain)))
    if sys.byteorder != "little":
        values.byteswap()
    return values.tobytes()


def transcribe(pcm, credentials, hotwords, aliases, connect=None):
    headers = worker.auth_headers(credentials)
    if connect is None:
        from websockets.asyncio.client import connect

    async def recognize():
        async with asyncio.timeout(55):
            return await worker.recognize(pcm, {"hotwords": " ".join(hotwords)}, headers, connect)

    result = asyncio.run(recognize())
    text = result.get("result", {}).get("text")
    if not isinstance(text, str) or not text.strip():
        raise ValueError("豆包未返回识别文字")
    return bridge.normalize_text(text, aliases)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--credentials", type=Path, required=True)
    parser.add_argument("--parser", required=True)
    parser.add_argument("--gain", type=float, default=1.0)
    args = parser.parse_args()
    try:
        # Vinput's buffered backend sends the complete capture only after release.
        # That capture precedes Vinput's live input gain, so apply gain here once.
        pcm = apply_gain(sys.stdin.buffer.read(MAX_AUDIO_BYTES + 1), args.gain)
        credentials = worker.load_credentials(args.credentials)
        hotwords, aliases = bridge.load_terms(args.parser)
        print(transcribe(pcm, credentials, hotwords, aliases), flush=True)
        return 0
    except Exception:
        print("豆包整句识别失败，请检查录音、网络、凭据和服务权限", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
