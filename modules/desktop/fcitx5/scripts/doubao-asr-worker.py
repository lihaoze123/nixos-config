#!/usr/bin/env python3
"""VoCoType worker using Doubao ASR 2.0 unidirectional WebSocket API."""

import argparse
import asyncio
import gzip
import json
import os
from pathlib import Path
import sys
import struct
import subprocess
import time
import uuid
import wave

ENDPOINT = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_nostream"
RESOURCE_ID = "volc.seedasr.sauc.duration"


def load_credentials(path):
    if not path.exists():
        raise ValueError("agenix 豆包凭据尚未解密，请先应用 Home Manager 配置")
    if path.stat().st_mode & 0o077:
        raise ValueError("agenix 豆包凭据必须仅允许当前用户访问")
    config = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(config, dict):
        raise ValueError("agenix 豆包凭据必须为 JSON 对象")
    return config


def auth_headers(config):
    headers = {
        "X-Api-Resource-Id": RESOURCE_ID,
        "X-Api-Request-Id": str(uuid.uuid4()),
        "X-Api-Sequence": "-1",
    }
    if config.get("api_key"):
        headers["X-Api-Key"] = config["api_key"]
    elif config.get("app_id") and config.get("access_token"):
        headers["X-Api-App-Key"] = config["app_id"]
        headers["X-Api-Access-Key"] = config["access_token"]
    else:
        raise ValueError("请配置豆包语音 api_key，或 app_id 和 access_token")
    return headers


def remove_legacy_credentials(credentials_path, legacy_path):
    if not legacy_path.exists():
        return
    credentials = load_credentials(credentials_path)
    legacy = load_credentials(legacy_path)
    keys = ("api_key", "app_id", "access_token")
    if {key: credentials[key] for key in keys if credentials.get(key)} != {
        key: legacy[key] for key in keys if legacy.get(key)
    }:
        raise ValueError("旧豆包凭据与 agenix 不一致，保留旧文件，请手动确认")
    auth_headers(credentials)
    legacy_path.unlink()
    print("已移除迁移前的豆包明文配置", file=sys.stderr)


def make_frame(kind, payload, sequence, *, last=False, json_payload=False):
    payload = gzip.compress(payload)
    return (bytes([0x11, (kind << 4) | (3 if last else 1),
                   0x11 if json_payload else 0x01, 0])
            + struct.pack(">iI", -sequence if last else sequence, len(payload)) + payload)


def parse_frame(data):
    if not isinstance(data, bytes) or len(data) < 8 or data[0] >> 4 != 1:
        raise ValueError("豆包返回了无效的二进制协议帧")
    kind, flags = data[1] >> 4, data[1] & 0x0F
    offset = (data[0] & 0x0F) * 4
    if offset < 4 or offset > len(data) or kind not in (9, 15):
        raise ValueError("豆包返回了不支持的协议帧")

    def integer(signed=False):
        nonlocal offset
        if offset + 4 > len(data):
            raise ValueError("豆包返回的协议帧被截断")
        value = struct.unpack_from(">i" if signed else ">I", data, offset)[0]
        offset += 4
        return value

    sequence = integer(signed=True) if flags & 1 else 0
    if flags & 4:
        integer()  # Optional event ID.
    code = integer() if kind == 15 else 0
    size = integer()
    if len(data) - offset != size:
        raise ValueError("豆包返回的协议帧长度不匹配")
    if code:
        # Do not echo the server's error payload, which may contain credentials.
        raise ValueError(f"豆包识别失败：状态码 {code}；请检查语音服务权限及余额")
    payload = data[offset:]
    compression = data[2] & 0x0F
    if compression == 1:
        payload = gzip.decompress(payload)
    elif compression != 0:
        raise ValueError("豆包返回了不支持的压缩格式")
    if data[2] >> 4 != 1:
        raise ValueError("豆包返回了非 JSON 识别结果")
    result = json.loads(payload)
    if not isinstance(result, dict):
        raise ValueError("豆包识别结果必须为 JSON 对象")
    return result, bool(flags & 2) or sequence < 0


def read_audio(path):
    if path.stat().st_size > 25 * 1024 * 1024:
        raise ValueError("录音超过本地 25 MiB 上限，请分段听写")
    # Upstream resamples only the live preview; the final WAV preserves the
    # microphone's capture rate (normally 48 kHz). Normalize in memory here.
    try:
        with wave.open(str(path), "rb") as audio:
            if (audio.getframerate(), audio.getsampwidth(), audio.getnchannels()) == (16000, 2, 1):
                pcm = audio.readframes(audio.getnframes())
                if not pcm:
                    raise ValueError("录音为空")
                return pcm
    except (wave.Error, EOFError):
        pass  # FFmpeg also supports WAV formats Python's wave module cannot read.
    try:
        conversion = subprocess.run(
            ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error",
             "-i", str(path), "-vn", "-ac", "1", "-ar", "16000",
             "-c:a", "pcm_s16le", "-f", "s16le", "pipe:1"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=20,
        )
    except (OSError, subprocess.SubprocessError):
        raise ValueError("录音格式转换失败，请检查音频文件是否有效") from None
    pcm = conversion.stdout
    if not pcm:
        raise ValueError("录音为空")
    return pcm


async def recognize(pcm, request, headers, connect):
    payload = {
        "user": {"uid": "vocotype"},
        "audio": {"format": "pcm", "codec": "raw", "rate": 16000,
                  "bits": 16, "channel": 1},
        "request": {"model_name": "bigmodel", "enable_itn": request.get("itn", True),
                    "enable_punc": True, "result_type": "full"},
    }
    # Core already merges the user terminology dictionary and temporary
    # hotwords into a whitespace-separated string for each transcription.
    hotwords = request.get("hotwords", "")
    if not isinstance(hotwords, str):
        raise ValueError("热词必须是空白分隔的字符串")
    words = list(dict.fromkeys(hotwords.split()))[:5000]
    if words:
        # Doubao requires corpus.context to be a JSON string, not an object.
        payload["request"]["corpus"] = {
            "context": json.dumps({"hotwords": [{"word": word} for word in words]},
                                  ensure_ascii=False),
        }
    async with connect(ENDPOINT, additional_headers=headers, open_timeout=15,
                       close_timeout=2, max_size=2 * 1024 * 1024) as connection:
        await connection.send(make_frame(1, json.dumps(payload).encode(), 1, json_payload=True))

        async def send_audio():
            # 200 ms of 16 kHz PCM per packet. Capture has already completed;
            # send buffered audio while concurrently consuming server responses.
            for offset in range(0, len(pcm), 6400):
                chunk = pcm[offset:offset + 6400]
                await connection.send(make_frame(2, chunk, offset // 6400 + 2,
                                                last=offset + len(chunk) == len(pcm)))
                await asyncio.sleep(0)  # Let the receiver run even on fast sockets.

        async def receive_result():
            latest = None
            while True:
                response, final = parse_frame(await connection.recv())
                if isinstance(response.get("result", {}).get("text"), str):
                    latest = response
                if final:
                    if latest is None:
                        raise ValueError("豆包最终结果缺少 result.text")
                    return latest

        sender = asyncio.create_task(send_audio())
        receiver = asyncio.create_task(receive_result())
        try:
            _, result = await asyncio.gather(sender, receiver)
            return result
        finally:
            for task in (sender, receiver):
                task.cancel()
            await asyncio.gather(sender, receiver, return_exceptions=True)


def transcribe(request, config, connect=None):
    headers = auth_headers(config)
    pcm = read_audio(Path(request["audio_path"]))
    if connect is None:
        from websockets.asyncio.client import connect
    from websockets.exceptions import InvalidStatus, WebSocketException

    started = time.monotonic()

    async def run():
        async with asyncio.timeout(60):
            return await recognize(pcm, request, headers, connect)

    try:
        result = asyncio.run(run())
    except InvalidStatus as error:
        raise ValueError(f"豆包 WebSocket 握手失败：HTTP {error.response.status_code}；请检查语音服务凭据及权限") from None
    except (OSError, TimeoutError, WebSocketException):
        raise ValueError("豆包连接失败或超时，请检查网络；可关闭 programs.vocotype.doubao.enable 切回本地识别") from None
    text = result.get("result", {}).get("text")
    if not isinstance(text, str):
        raise ValueError("豆包返回的数据缺少 result.text")
    return {"success": True, "text": text, "raw_text": text,
            "latency_ms": (time.monotonic() - started) * 1000,
            "snippet_time": result.get("audio_info", {}).get("duration", 0) / 1000,
            "result_count": 1, "backend": "doubao"}


def emit(value):
    print(json.dumps(value, ensure_ascii=False), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--credentials", type=Path, required=True)
    parser.add_argument("--enabled", action="store_true", help="由 Nix 配置控制云端后端开关")
    parser.add_argument("--remove-legacy", type=Path, help="agenix 解密成功后清理已迁移的明文配置")
    parser.add_argument("--local-worker", required=True)
    parser.add_argument("--transcribe", type=Path, help="直接测试 WAV 文件，无需启动输入法")
    args, local_args = parser.parse_known_args()
    try:
        if args.remove_legacy:
            remove_legacy_credentials(args.credentials, args.remove_legacy)
            return 0
        if args.transcribe:
            config = load_credentials(args.credentials)
            emit(transcribe({"audio_path": str(args.transcribe)}, config))
            return 0
        if not args.enabled:
            os.execv(args.local_worker, [args.local_worker, *local_args])
        config = load_credentials(args.credentials)
        auth_headers(config)
    except (OSError, ValueError) as error:
        emit({"type": "ready", "success": False, "error": str(error)})
        return 1
    emit({"type": "ready", "success": True, "backend": "doubao",
          "contextual_hotword": True, "punctuation": True, "vad": False})
    for line in sys.stdin:
        try:
            request = json.loads(line)
            kind = request.get("type")
            if kind == "transcribe":
                # Reload credentials without logging them or requiring a rebuild.
                config = load_credentials(args.credentials)
                response = transcribe(request, config)
            elif kind in ("prepare", "ping", "stop"):
                response = {"success": True, "prepared": kind == "prepare"}
            else:
                response = {"success": False, "error": "unknown_request"}
        except Exception as error:
            # Never echo server bodies or request headers, which can contain secrets.
            response = {"success": False, "error": str(error) if isinstance(error, ValueError)
                        else "豆包识别失败（" + type(error).__name__ + "）"}
        emit(response)
        if response.get("success") and kind == "stop":
            return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
