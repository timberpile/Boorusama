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
   Never fall back to a busy or untargeted device. Use Maestro MCP for UI control.
5. After the final operation, release with
   `python3 scripts/emulator_lease.py release emulator-NNNN --token <token>`.

A device-free APK build needs no lease. Test accounts are already signed in;
follow the `.test_credentials` confidentiality rules in [AGENTS.md](../AGENTS.md).
