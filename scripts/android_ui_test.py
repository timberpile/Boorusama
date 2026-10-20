#!/usr/bin/env python3
"""Prepare disposable Android app state and run small, live-data Maestro flows."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import uuid
import zipfile

from ui_test_export import pack, read_package

ROOT = Path(__file__).resolve().parents[1]
APP_ID = 'com.timberpile.boorusama.dev'
DEVICE_EXPORT = '/sdcard/Download/boorusama-ui-test.bsexport'
FLOWS = ROOT / '.maestro' / 'flows'


def execute(command: list[str], *, timeout: float = 90, capture: bool = False,
            check: bool = True) -> subprocess.CompletedProcess:
    """Bound each operation below the lease window; terminate children on interruption."""
    process = subprocess.Popen(
        command, cwd=ROOT, text=True, start_new_session=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )
    try:
        stdout, _ = process.communicate(timeout=timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
        # Supported hosts are Linux/macOS, matching emulator_lease.py.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.communicate()
        if isinstance(error, KeyboardInterrupt):
            raise
        raise TimeoutError(f'{Path(command[0]).name} exceeded its operation limit') from None
    if check and process.returncode:
        # Never echo arguments (lease tokens) or private device output in errors.
        raise RuntimeError(f'{Path(command[0]).name} failed with exit code {process.returncode}')
    return subprocess.CompletedProcess(command, process.returncode, stdout)


class Device:
    def __init__(self, serial: str, token: str):
        if not re.fullmatch(r'emulator-[0-9]+', serial) or not token.strip():
            raise ValueError('Use an exact emulator-NNNN serial and BOORUSAMA_EMULATOR_TOKEN')
        self.serial, self.token = serial, token

    def renew(self) -> None:
        execute([sys.executable, str(ROOT / 'scripts/emulator_lease.py'),
                 'renew', self.serial, '--token', self.token], capture=True)

    def adb(self, *arguments: str) -> str:
        self.renew()
        return execute(['adb', '-s', self.serial, *arguments], capture=True).stdout.strip()

    def check(self) -> None:
        if self.adb('get-state') != 'device':
            raise RuntimeError('The requested emulator is not online')
        if self.adb('shell', 'getprop', 'ro.kernel.qemu') != '1':
            raise RuntimeError('Refusing to use a non-emulator')
        if not self.adb('shell', 'pm', 'path', APP_ID).startswith('package:'):
            raise RuntimeError('Install the dev APK before preparing a scenario')
        self.adb('shell', 'run-as', APP_ID, 'id')


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def new_output(serial: str) -> Path:
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    return ROOT / 'build/android-ui-tests' / serial / f'{stamp}-{uuid.uuid4().hex[:8]}'


def prepare(device: Device, scenario: str, output: Path, confirm: bool) -> Path:
    if not confirm:
        raise ValueError('Pass --confirm-reset: this deletes ALL dev-app data, caches and logins')
    source = None
    if scenario != 'fresh':
        source = ROOT / '.maestro/scenarios/live-safe' if scenario == 'live-safe' else Path(scenario).resolve()
        if not source.exists():
            raise FileNotFoundError(source)
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {'device': device.serial, 'app_id': APP_ID, 'scenario': scenario,
              'status': 'preparing', 'started_at': datetime.now(timezone.utc).isoformat()}
    started = time.monotonic()
    try:
        archive = output / 'scenario.bsexport'
        if source is not None:
            if source.is_dir():
                pack(source, archive)
            else:
                read_package(source)
                shutil.copyfile(source, archive)
            read_package(archive)
        subflows = [FLOWS / 'common/launch.yaml']
        if source is not None:
            subflows.append(FLOWS / 'common/import-staged-export.yaml')
        if scenario == 'live-safe':
            subflows.append(FLOWS / 'verify-live-safe.yaml')
        for subflow in subflows:
            if not subflow.is_file():
                raise FileNotFoundError(subflow)
        # JSON-quoted strings are YAML strings too; no extra host dependency needed.
        flow = output / 'setup.yaml'
        flow.write_text(f'appId: {APP_ID}\n---\n' + ''.join(
            '- runFlow: ' + json.dumps(os.path.relpath(p, output)) + '\n' for p in subflows
        ), encoding='utf-8')
        device.check()
        print(f'Resetting {APP_ID} on {device.serial}; all app data and logins will be lost.')
        if device.adb('shell', 'pm', 'clear', APP_ID) != 'Success':
            raise RuntimeError('Android did not confirm a successful app-data reset')
        device.adb('shell', 'rm', '-f', DEVICE_EXPORT)
        if source is not None:
            device.adb('push', str(archive), DEVICE_EXPORT)
        # Staging is not UI verification. The generated flow must still succeed.
        report['status'] = 'staged'
        return flow
    except BaseException as error:
        report.update(status='failed', error_type=type(error).__name__)
        raise
    finally:
        report['duration_seconds'] = round(time.monotonic() - started, 3)
        write_json(output / 'prepare.json', report)


def run_flow(device: Device, flow: Path, output: Path) -> int:
    flow, output = Path(flow).resolve(), Path(output).resolve()
    if not flow.is_file():
        raise FileNotFoundError(flow)
    # Flows are trusted repository code, not a sandbox. Catch an obvious wrong target.
    if not re.search(r'^appId:\s*' + re.escape(APP_ID) + r'\s*$', flow.read_text(), re.MULTILINE):
        raise ValueError('The flow must explicitly target the fixed dev app ID')
    output.mkdir(parents=True, exist_ok=False)
    report = {'device': device.serial, 'app_id': APP_ID, 'flow': str(flow),
              'status': 'blocked', 'started_at': datetime.now(timezone.utc).isoformat()}
    started = time.monotonic()
    try:
        device.check()
        device.renew()
        result = execute([
            'maestro', f'--device={device.serial}', 'test', str(flow),
            '--format', 'junit', '--output', str(output / 'report.xml'),
            '--debug-output', str(output / 'debug'),
            '--test-output-dir', str(output / 'screenshots'),
        ], timeout=15 * 60, check=False)
        report.update(status='passed' if result.returncode == 0 else 'failed', exit_code=result.returncode)
        return result.returncode
    except BaseException as error:
        report['error_type'] = type(error).__name__
        raise
    finally:
        report['duration_seconds'] = round(time.monotonic() - started, 3)
        write_json(output / 'result.json', report)
        print(f'Results: {output}')


def doctor() -> int:
    print('Host support: Linux/macOS. UI flows require an English, unlocked phone emulator.')
    missing = False
    for tool in ('adb', 'maestro', 'fvm'):
        path = shutil.which(tool)
        print(f'{tool}: {path or "NOT FOUND"}')
        missing |= path is None
    print('Maestro CLI is only needed for --run/run; MCP can execute the generated setup flow instead.')
    print('Build/install with FVM separately. This script does not verify APK/source equivalence.')
    return int(missing)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('doctor')
    for name in ('prepare', 'run'):
        child = commands.add_parser(name)
        child.add_argument('--device', required=True)
        child.add_argument('--output', type=Path, help='New local result directory; defaults under build/')
        if name == 'prepare':
            child.add_argument('--scenario', default='live-safe', help='fresh, live-safe, export directory or .bsexport')
            child.add_argument('--confirm-reset', action='store_true')
            child.add_argument('--run', action='store_true', help='Also execute generated setup through Maestro CLI')
        else:
            child.add_argument('--flow', required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'doctor':
            return doctor()
        if os.name != 'posix':
            raise ValueError('This MVP uses the existing Linux/macOS emulator lease')
        device = Device(args.device, os.environ.get('BOORUSAMA_EMULATOR_TOKEN', ''))
        if not shutil.which('adb'):
            raise FileNotFoundError('adb is not installed')
        needs_cli = args.command == 'run' or args.run
        if needs_cli and not shutil.which('maestro'):
            raise FileNotFoundError('maestro is not installed; no reset performed')
        output = args.output or new_output(device.serial)
        if args.command == 'run':
            return run_flow(device, args.flow, output)
        flow = prepare(device, args.scenario, output, args.confirm_reset)
        print(f'Staged only. Setup flow: {flow}')
        return run_flow(device, flow, output / 'maestro') if args.run else 0
    except KeyboardInterrupt:
        print('Interrupted; device state may be partial. Retain the lease until cleanup.', file=sys.stderr)
        return 130
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, zipfile.BadZipFile) as error:
        print(f'BLOCKED: {type(error).__name__}: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
