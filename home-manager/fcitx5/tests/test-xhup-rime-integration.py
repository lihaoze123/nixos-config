#!/usr/bin/env python3
"""Run on a private bus: dbus-run-session -- python3 this-file --help.

Requires Python + PyYAML + pypinyin and a compiled rime-candidate-probe.c.
All dictionaries and Fcitx settings are copied to a temporary HOME.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fcitx', type=Path, required=True)
    parser.add_argument('--data-dir', type=Path, required=True)
    parser.add_argument('--plugin', type=Path, required=True)
    parser.add_argument('--probe', type=Path, required=True)
    args = parser.parse_args()
    # Fail closed on a live session bus. dbus-run-session creates an address
    # under /tmp; never send even test Deploy calls to the normal user bus.
    address = os.environ.get('DBUS_SESSION_BUS_ADDRESS', '')
    if not address.startswith('unix:path=/tmp/dbus-'):
        parser.error('Run under dbus-run-session (a private /tmp/dbus-* bus)')
    source = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(source / 'scripts'))
    spec = importlib.util.spec_from_file_location('xhup_add_integration', source / 'scripts/xhup-add-word.py')
    add = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = add
    spec.loader.exec_module(add)
    with tempfile.TemporaryDirectory(prefix='xhup-add-integration-') as tmp:
        root = Path(tmp)
        home = root / 'home'
        home.mkdir()
        os.environ.update(HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
                          XDG_DATA_HOME=str(home / '.local/share'), XDG_CACHE_HOME=str(home / '.cache'),
                          XDG_STATE_HOME=str(home / '.local/state'))
        for key in ('WAYLAND_DISPLAY', 'DISPLAY', 'FCITX_ADDON_DIRS', 'SKIP_FCITX_USER_PATH'):
            os.environ.pop(key, None)
        user = home / '.local/share/fcitx5/rime'
        (user / 'xhup_dicts').mkdir(parents=True)
        dictionaries = root / 'dictionaries'
        shutil.copytree(source / 'dictionaries', dictionaries)
        for file in dictionaries.glob('xhup.user*.dict.yaml'):
            (user / 'xhup_dicts' / file.name).symlink_to(file)
        for file in ('default.custom.yaml', 'xhup.custom.yaml'):
            shutil.copy(source / 'config' / file, user / file)
        (home / '.config/fcitx5').mkdir(parents=True)
        shutil.copy(source / 'config/profile', home / '.config/fcitx5/profile')
        with (root / 'fcitx.log').open('w') as log:
            process = subprocess.Popen([str(args.fcitx), '--disable=all', '--enable=dbus,rime,keyboard', '--keep'],
                                       stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 90
                while True:
                    try:
                        add.deploy_owner(args.plugin, user)
                        if (user / 'build/xhup.table.bin').exists():
                            break
                    except add.DeployError:
                        pass
                    if time.monotonic() > deadline or process.poll() is not None:
                        raise RuntimeError('Fcitx initialization failed')
                    time.sleep(.25)
                # A brief settling period is a test aid, not a success assertion.
                time.sleep(2)
                repo = add.Repository(args.data_dir, user, dictionaries, root / 'state')
                preview = repo.preview('鹤词测试隔离词', 'zzzz', 'common')
                assert not preview.duplicate
                table = user / 'build/xhup.table.bin'
                before = table.stat().st_mtime_ns
                result, status = add.finish(repo, preview, argparse.Namespace(expected_plugin=args.plugin, user_dir=user), False)
                print(json.dumps(result, ensure_ascii=False))
                assert status == 0 and result['status'] == 'deploy_requested'
                deadline = time.monotonic() + 90
                while table.stat().st_mtime_ns == before:
                    if time.monotonic() > deadline:
                        raise RuntimeError('Rime compilation timed out')
                    time.sleep(.25)
            except BaseException:
                print((root / 'fcitx.log').read_text()[-6000:], file=sys.stderr)
                raise
            finally:
                # Graceful shutdown joins maintenance before the second client
                # opens these files; do not run two deployers on one user dir.
                process.terminate()
                try:
                    process.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                    raise
        result = subprocess.run([str(args.probe), str(args.data_dir), str(user), 'zzzz', '鹤词测试隔离词'],
                                capture_output=True, text=True)
        assert result.returncode == 0, result.stderr[-5000:]
        assert '鹤词测试隔离词' in result.stdout
        print(result.stdout + 'Fcitx deployment + actual Rime candidate: PASS')


if __name__ == '__main__':
    main()
