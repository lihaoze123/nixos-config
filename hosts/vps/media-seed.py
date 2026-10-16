#!/usr/bin/env python3
"""Seed qBittorrent once; later restarts preserve settings and changed passwords."""

import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import sys


def main():
    target = Path("/var/lib/media-stack/qbittorrent/qBittorrent/qBittorrent.conf")
    if target.exists():
        return
    credentials = json.loads(Path(sys.argv[1]).read_text())["qbittorrent"]
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha512", credentials["password"].encode(), salt, 100000)
    password_hash = ":".join(base64.b64encode(value).decode() for value in (salt, digest))
    target.parent.mkdir(parents=True, exist_ok=True)
    os.chown(target.parent, 995, 995)
    content = (
        "[LegalNotice]\nAccepted=true\n\n"
        "[BitTorrent]\n"
        "Session\\DefaultSavePath=/downloads/Bangumi\n"
        "Session\\TempPath=/downloads/incomplete\n"
        "Session\\TempPathEnabled=true\n"
        "Session\\Port=51413\n"
        "Session\\QueueingSystemEnabled=true\n"
        "Session\\MaxActiveDownloads=3\n"
        "Session\\MaxActiveUploads=3\n"
        "Session\\GlobalMaxRatio=1\n"
        "Session\\GlobalMaxSeedingMinutes=1440\n"
        "Session\\GlobalUPSpeedLimit=2048\n\n"
        "[Preferences]\n"
        f"WebUI\\Username={credentials['username']}\n"
        f'WebUI\\Password_PBKDF2="@ByteArray({password_hash})"\n'
        "WebUI\\LocalHostAuth=true\n"
        "WebUI\\AuthSubnetWhitelistEnabled=false\n"
        'WebUI\\ServerDomains="localhost;127.0.0.1;qbittorrent"\n'
        "WebUI\\HostHeaderValidation=true\n"
        "WebUI\\CSRFProtection=true\n"
        "Connection\\UPnP=false\n"
    )
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(content)
    os.chown(target, 995, 995)


if __name__ == "__main__":
    main()
