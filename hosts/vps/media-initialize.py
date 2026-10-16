#!/usr/bin/env python3
"""Initialize private media services before enabling their reverse proxies."""

import http.client
import http.cookiejar
import json
from pathlib import Path
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


class Client:
    def __init__(self, base):
        self.base = base
        self.headers = {}
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
        )

    def request(self, path, data=None, *, form=False):
        headers = self.headers.copy()
        if data is not None:
            if form:
                data = urllib.parse.urlencode(data).encode()
                headers["Content-Type"] = "application/x-www-form-urlencoded"
            else:
                data = json.dumps(data).encode()
                headers["Content-Type"] = "application/json"
        request = urllib.request.Request(self.base + path, data=data, headers=headers)
        with self.opener.open(request, timeout=20) as response:
            body = response.read().decode()
            if "application/json" in response.headers.get("Content-Type", "") and body:
                return json.loads(body)
            return body

    def wait(self, path, *, allow_unauthorized=False):
        for attempt in range(90):
            try:
                return self.request(path)
            except (
                urllib.error.URLError,
                TimeoutError,
                ConnectionError,
                http.client.HTTPException,
            ) as error:
                if (
                    allow_unauthorized
                    and isinstance(error, urllib.error.HTTPError)
                    and error.code in (401, 403)
                ):
                    return None
                if attempt == 89:
                    raise RuntimeError(f"Service did not become ready: {self.base}") from None
                time.sleep(2)


def emby_setup_complete():
    configuration = Path("/var/lib/media-stack/emby/config/system.xml")
    return (
        configuration.exists()
        and ET.parse(configuration).findtext("IsStartupWizardCompleted") == "true"
    )


def main():
    credentials = json.loads(Path(sys.argv[1]).read_text())
    marker = Path("/var/lib/media-stack/.initialized")
    ab = Client("http://127.0.0.1:7892")
    emby = Client("http://127.0.0.1:8096/emby")
    ab.wait("/health")
    emby.wait("/System/Info/Public")
    if not marker.exists():
        print("Initializing downloader connection.", flush=True)
        qb = Client("http://127.0.0.1:8080")
        qb.wait("/api/v2/app/version", allow_unauthorized=True)
        result = qb.request("/api/v2/auth/login", credentials["qbittorrent"], form=True)
        if result.strip() not in ("", "Ok."):
            raise RuntimeError("Downloader authentication failed")
        qb.request("/api/v2/app/version")

        print("Initializing AutoBangumi account.", flush=True)
        if ab.request("/api/v1/setup/status")["need_setup"]:
            # Also permits resuming after an interrupted first-run wizard.
            try:
                ab.request("/api/v1/auth/login", credentials["autobangumi"], form=True)
            except urllib.error.HTTPError as error:
                if error.code != 401:
                    raise
            result = ab.request("/api/v1/setup/complete", {
                **credentials["autobangumi"],
                "downloader_host": "qbittorrent:8080",
                "downloader_username": credentials["qbittorrent"]["username"],
                "downloader_password": credentials["qbittorrent"]["password"],
                "downloader_path": "/downloads/Bangumi",
            })
            if not result["status"]:
                raise RuntimeError("AutoBangumi setup failed")
        ab.request("/api/v1/auth/login", credentials["autobangumi"], form=True)
        ab.request("/api/v1/auth/me")
        if ab.request("/api/v1/check/downloader") is not True:
            raise RuntimeError("AutoBangumi cannot connect to the downloader")

        print("Initializing Emby account and library.", flush=True)
        if not emby_setup_complete():
            configuration = emby.request("/Startup/Configuration")
            configuration["UICulture"] = "zh-CN"
            emby.request("/Startup/Configuration", configuration)
            emby.request("/Startup/User", {
                "Name": credentials["emby"]["username"],
                "Password": credentials["emby"]["password"],
            })
            emby.request("/Startup/RemoteAccess", {"EnableAutomaticPortMapping": False})
            emby.request("/Startup/Complete", {})

        emby.headers["X-Emby-Authorization"] = (
            'Emby Client="NixOS setup", Device="VPS", DeviceId="nixos-media-setup", Version="1"'
        )
        session = emby.request("/Users/AuthenticateByName", {
            "Username": credentials["emby"]["username"],
            "Pw": credentials["emby"]["password"],
        })
        emby.headers["X-Emby-Token"] = session["AccessToken"]
        libraries = emby.request("/Library/VirtualFolders/Query")
        libraries = libraries.get("Items", []) if isinstance(libraries, dict) else libraries
        if not any("/media/Bangumi" in library.get("Locations", []) for library in libraries):
            emby.request("/Library/VirtualFolders", {
                "Name": "番剧",
                "CollectionType": "tvshows",
                "RefreshLibrary": True,
                "Paths": ["/media/Bangumi"],
                "LibraryOptions": {
                    "EnableRealtimeMonitor": True,
                    "PreferredMetadataLanguage": "zh",
                    "MetadataCountryCode": "CN",
                    "SaveLocalMetadata": False,
                },
            })
        emby.request("/Sessions/Logout", {})
        marker.touch(mode=0o600)
        print("Media accounts, downloader connection and library initialized.")

    if ab.request("/api/v1/setup/status")["need_setup"]:
        raise RuntimeError("AutoBangumi setup is incomplete")
    if not emby_setup_complete():
        raise RuntimeError("Emby setup is incomplete")
    ready = Path("/run/media-stack/ready")
    ready.touch()
    ready.chmod(0o644)
    print("Media services are ready for authenticated access.")


if __name__ == "__main__":
    main()
