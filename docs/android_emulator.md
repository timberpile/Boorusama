# Android emulator coordination

Read this before any emulator operation. Use `python3 scripts/emulator_lease.py`
to claim one exact serial; retain the returned token. Leases expire after
30 minutes, so renew before every device operation.

1. Discover serials with `adb devices -l`; discovery does not reserve a device.
2. Claim with `python3 scripts/emulator_lease.py claim emulator-NNNN --owner
   "<agent-session> <worktree-path>"`. Proceed only on success; never use a busy
   device. Inspect ownership with `status emulator-NNNN` when needed.
3. Before **every** device-affecting command or Maestro call, run
   `python3 scripts/emulator_lease.py renew emulator-NNNN --token <token>`.
   Stop if renewal fails. Each operation must finish in less than 20 minutes;
   split longer flows and renew between operations.
4. Set `device_id: "emulator-NNNN"` on every Maestro call, use
   `adb -s emulator-NNNN ...`, and use `fvm flutter ... -d emulator-NNNN`.
   Never fall back to a busy or untargeted device. Use Maestro MCP for interactive
   UI control. For the [disposable Android pilot](android_ui_testing.md), saved
   YAML may also run through `scripts/android_ui_test.py`; it renews before each
   device command and targets the claimed serial explicitly. Direct MCP calls
   still require manual renewal.
5. After the final operation, release with
   `python3 scripts/emulator_lease.py release emulator-NNNN --token <token>`.

A device-free APK build needs no lease. Existing test accounts may be signed in;
follow the `.test_credentials` confidentiality rules in [AGENTS.md](../AGENTS.md).
Only the explicitly disposable pilot permits a full dev-app reset with
`prepare --confirm-reset`. It destroys those logins and app caches; it is not a
factory reset of the emulator or shared Downloads. Do not reset a preserved
signed-in environment just to make a flow pass.
