#!/usr/bin/env python3
"""Receive static CMS/preview archives through a restricted SSH forced command."""

import fcntl
import gzip
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tarfile
import tempfile

MAX_BYTES = 256 * 1024 * 1024
MAX_FILES = 20000


class LimitedReader:
    """Bound decompressed tar headers as well as file contents."""

    def __init__(self, stream, limit):
        self.stream = stream
        self.remaining = limit

    def read(self, size=-1):
        size = self.remaining + 1 if size < 0 else min(size, self.remaining + 1)
        data = self.stream.read(size)
        self.remaining -= len(data)
        if self.remaining < 0:
            raise ValueError("Archive stream exceeds the upload size limit")
        return data


def parse_command(command):
    match = re.fullmatch(
        r"publish (cms|preview ([1-9][0-9]{0,8})) "
        r"([1-9][0-9]{0,11})\.([1-9][0-9]{0,5}) ([0-9a-f]{40})",
        command,
    )
    if match:
        return (
            "publish",
            f"pr-{match[2]}" if match[2] else "cms",
            (int(match[3]), int(match[4])),
            match[5],
        )
    match = re.fullmatch(
        r"remove preview ([1-9][0-9]{0,8}) "
        r"([1-9][0-9]{0,11})\.([1-9][0-9]{0,5})",
        command,
    )
    if match:
        return "remove", f"pr-{match[1]}", (int(match[2]), int(match[3])), None
    raise ValueError("Unsupported upload command")


def unpack(stream, destination):
    """Extract regular files only, without trusting paths or tar ownership/modes."""
    size = 0
    decompressed = LimitedReader(gzip.GzipFile(fileobj=stream), MAX_BYTES + MAX_FILES * 1024)
    with tarfile.open(fileobj=decompressed, mode="r|") as archive:
        for count, member in enumerate(archive, 1):
            parts = PurePosixPath(member.name)
            if (
                count > MAX_FILES
                or parts.is_absolute()
                or ".." in parts.parts
                or "\\" in member.name
                or not (member.isfile() or member.isdir())
            ):
                raise ValueError("Archive contains an invalid entry")
            if not parts.parts:
                if member.isdir():
                    continue
                raise ValueError("Empty file name")
            target = destination.joinpath(*parts.parts)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True, mode=0o750)
                continue
            size += member.size
            if size > MAX_BYTES:
                raise ValueError("Archive exceeds the upload size limit")
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o750)
            # Reject duplicate file names, including directory/file collisions.
            with archive.extractfile(member) as source, target.open("xb") as output:
                shutil.copyfileobj(source, output)
            target.chmod(0o640)
    if not (destination / "index.html").is_file():
        raise ValueError("A static site must contain index.html")


def receive(root, command, stream):
    action, name, sequence, sha = parse_command(command)
    state_dir = root / "state"
    site = root / "cms" if name == "cms" else root / "previews" / name
    state_file = state_dir / f"{name}.json"
    # One lock also serializes cleanup with uploads already in flight.
    with (state_dir / "upload.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        previous = json.loads(state_file.read_text()) if state_file.exists() else None
        if previous:
            last_sequence = tuple(previous["sequence"])
            if sequence < last_sequence or (
                sequence == last_sequence and previous["removed"] and action != "remove"
            ):
                raise ValueError("Upload was superseded by a newer workflow run")
            if sequence == last_sequence and action == "publish" and previous["sha"] != sha:
                raise ValueError("A workflow run cannot publish two different commits")

        if action == "remove":
            if site.exists():
                shutil.rmtree(site)
        else:
            with tempfile.TemporaryDirectory(dir=root / "staging") as staging:
                content = Path(staging) / "content"
                content.mkdir(mode=0o750)
                unpack(stream, content)
                site.mkdir(parents=True, exist_ok=True, mode=0o750)
                releases = site / "releases"
                releases.mkdir(exist_ok=True, mode=0o750)
                release = releases / f"{sequence[0]}.{sequence[1]}-{sha}"
                # Retries publish to a fresh directory, preserving atomic replacement.
                release = Path(tempfile.mkdtemp(prefix=release.name + "-", dir=releases))
                release.rmdir()
                content.rename(release)
                link = site / "next"
                link.unlink(missing_ok=True)
                link.symlink_to(release.relative_to(site), target_is_directory=True)
                link.replace(site / "current")
                for old in releases.iterdir():
                    if old != release:
                        shutil.rmtree(old)

        state = {"sequence": sequence, "sha": sha, "removed": action == "remove"}
        temporary = state_file.with_suffix(".next")
        temporary.write_text(json.dumps(state) + "\n")
        temporary.replace(state_file)
    print(f"{action}: {name}")


if __name__ == "__main__":
    os.umask(0o027)
    try:
        receive(Path(sys.argv[1]), os.environ.get("SSH_ORIGINAL_COMMAND", ""), sys.stdin.buffer)
    except (ValueError, OSError, EOFError, tarfile.TarError) as error:
        print(f"Upload refused: {error}", file=sys.stderr)
        sys.exit(1)
