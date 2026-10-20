import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import android_ui_test as ui


class DeviceTests(unittest.TestCase):
    def test_rejects_physical_serial_and_missing_token(self):
        for serial, token in [('R58ABC', 'token'), ('emulator-5554;reboot', 'token'), ('emulator-5554', '')]:
            with self.assertRaises(ValueError):
                ui.Device(serial, token)

    @patch.object(ui, 'execute')
    def test_renews_before_every_adb_command(self, execute):
        execute.return_value = subprocess.CompletedProcess([], 0, 'device\n')
        device = ui.Device('emulator-5554', 'lease-secret')
        device.adb('get-state')
        device.adb('shell', 'getprop', 'ro.kernel.qemu')
        calls = [call.args[0] for call in execute.call_args_list]
        self.assertEqual([c[2] for c in calls[::2]], ['renew', 'renew'])
        self.assertEqual(calls[1], ['adb', '-s', 'emulator-5554', 'get-state'])
        self.assertEqual(calls[3][:3], ['adb', '-s', 'emulator-5554'])

    @patch.object(ui, 'execute', side_effect=RuntimeError('Lease renewal failed'))
    def test_failed_renewal_prevents_adb(self, execute):
        with self.assertRaises(RuntimeError):
            ui.Device('emulator-5554', 'secret').adb('shell', 'pm', 'clear', ui.APP_ID)
        self.assertEqual(execute.call_count, 1)

    @patch.object(ui.Device, 'adb')
    def test_rejects_non_emulator_and_missing_app_before_reset(self, adb):
        for responses in [('device', '0'), ('device', '1', '')]:
            adb.reset_mock()
            adb.side_effect = responses
            with self.assertRaises(RuntimeError):
                ui.Device('emulator-5554', 'secret').check()
            self.assertFalse(any('clear' in c.args for c in adb.call_args_list))

    @patch.object(ui.Device, 'adb')
    def test_requires_debuggable_installed_dev_app(self, adb):
        adb.side_effect = ['device', '1', 'package:/data/app/base.apk', RuntimeError('not debuggable')]
        with self.assertRaises(RuntimeError):
            ui.Device('emulator-5554', 'secret').check()
        self.assertEqual(adb.call_args.args, ('shell', 'run-as', ui.APP_ID, 'id'))


class PrepareTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name) / 'run'

    @patch.object(ui.Device, 'adb')
    @patch.object(ui.Device, 'check')
    def test_reset_needs_explicit_confirmation(self, check, adb):
        with self.assertRaises(ValueError):
            ui.prepare(ui.Device('emulator-5554', 't'), 'fresh', self.output, False)
        check.assert_not_called()
        adb.assert_not_called()

    @patch.object(ui.Device, 'adb')
    @patch.object(ui.Device, 'check')
    def test_invalid_scenario_never_touches_device(self, check, adb):
        with self.assertRaises(FileNotFoundError):
            ui.prepare(ui.Device('emulator-5554', 't'), str(self.output / 'missing'), self.output, True)
        check.assert_not_called()
        adb.assert_not_called()

    @patch.object(ui.Device, 'adb', return_value='Success')
    @patch.object(ui.Device, 'check')
    def test_fresh_reset_is_fixed_package_and_does_not_run_ui(self, check, adb):
        flow = ui.prepare(ui.Device('emulator-5554', 't'), 'fresh', self.output, True)
        calls = [c.args for c in adb.call_args_list]
        self.assertEqual(calls[0], ('shell', 'pm', 'clear', ui.APP_ID))
        self.assertEqual(calls[1], ('shell', 'rm', '-f', ui.DEVICE_EXPORT))
        self.assertEqual(len(calls), 2)
        self.assertIn('launch.yaml', flow.read_text())
        self.assertNotIn('import-staged-export', flow.read_text())
        self.assertEqual(json.loads((self.output / 'prepare.json').read_text())['status'], 'staged')

    @patch.object(ui.Device, 'adb', return_value='Failed')
    @patch.object(ui.Device, 'check')
    def test_failed_reset_stops_before_push(self, check, adb):
        with self.assertRaises(RuntimeError):
            ui.prepare(ui.Device('emulator-5554', 't'), 'fresh', self.output, True)
        self.assertEqual(adb.call_count, 1)
        self.assertEqual(json.loads((self.output / 'prepare.json').read_text())['status'], 'failed')

    @patch.object(ui.Device, 'adb', return_value='Success')
    @patch.object(ui.Device, 'check')
    def test_live_scenario_is_validated_packed_and_pushed_after_clear(self, check, adb):
        flow = ui.prepare(ui.Device('emulator-5554', 't'), 'live-safe', self.output, True)
        calls = [c.args for c in adb.call_args_list]
        self.assertEqual(calls[0], ('shell', 'pm', 'clear', ui.APP_ID))
        self.assertEqual(calls[-1][0], 'push')
        self.assertEqual(calls[-1][-1], ui.DEVICE_EXPORT)
        manifest, _ = ui.read_package(self.output / 'scenario.bsexport')
        self.assertFalse(manifest['containsCredentials'])
        self.assertIn('import-staged-export.yaml', flow.read_text())
        self.assertIn('verify-live-safe.yaml', flow.read_text())


class RunTests(unittest.TestCase):
    @patch.object(ui.Device, 'check')
    @patch.object(ui.Device, 'renew')
    @patch.object(ui, 'execute')
    def test_maestro_failure_is_recorded_without_implicit_reset(self, execute, renew, check):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            flow = root / 'smoke.yaml'
            flow.write_text('appId: ' + ui.APP_ID + '\n---\n- assertVisible: Menu\n')
            execute.return_value = subprocess.CompletedProcess([], 7, '')
            code = ui.run_flow(ui.Device('emulator-5554', 'secret'), flow, root / 'artifacts')
            self.assertEqual(code, 7)
            renew.assert_called_once()
            cmd = execute.call_args.args[0]
            self.assertEqual(cmd[:4], ['maestro', '--device=emulator-5554', 'test', str(flow)])
            self.assertNotIn('secret', str(cmd))
            report = json.loads((root / 'artifacts/result.json').read_text())
            self.assertEqual(report['exit_code'], 7)
            self.assertEqual(report['status'], 'failed')

    @patch.object(ui.Device, 'check')
    @patch.object(ui.Device, 'renew')
    @patch.object(ui, 'execute', side_effect=TimeoutError('test timeout'))
    def test_timeout_is_reported_not_passed(self, execute, renew, check):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            flow = root / 'smoke.yaml'
            flow.write_text('appId: ' + ui.APP_ID + '\n---\n- assertVisible: Menu\n')
            with self.assertRaises(TimeoutError):
                ui.run_flow(ui.Device('emulator-5554', 'secret'), flow, root / 'artifacts')
            report = json.loads((root / 'artifacts/result.json').read_text())
            self.assertEqual(report['status'], 'blocked')

    def test_execute_preserves_exit_code_and_bounds_hangs(self):
        result = ui.execute([sys.executable, '-c', 'print("ok")'], capture=True)
        self.assertEqual(result.stdout.strip(), 'ok')
        failed = ui.execute([sys.executable, '-c', 'raise SystemExit(9)'], check=False)
        self.assertEqual(failed.returncode, 9)
        with self.assertRaises(TimeoutError):
            ui.execute([sys.executable, '-c', 'import time; time.sleep(3600)'], timeout=0.1)


if __name__ == '__main__':
    unittest.main()
