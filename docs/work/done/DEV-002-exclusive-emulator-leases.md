# Reserve Android emulators across agent sessions

Priority: High
Affected feature: Agent workflow and Android emulator testing

Agent/session: Codex `/root`, 2026-10-03
Work branch: `feature/dev-002-exclusive-emulator-leases`
Dedicated worktree: `.worktrees/dev-002-exclusive-emulator-leases`
Implementer/session: Codex `/root/dev002_impl`, 2026-10-03

## Problem

Agents working in separate worktrees and independent sessions can select the
same running emulator. Explicit Maestro `device_id` and ADB `-s` arguments target
a device, but do not prevent another agent from installing, launching, or
testing on it at the same time.

## Expected behavior

One agent session owns a given emulator at a time. Claiming, renewing, and
releasing ownership uses short commands and a shared directory on the host.
Maestro, ADB, and Flutter continue to access the device directly; there is no
daemon, background heartbeat, or command proxy.

## Acceptance criteria

- [x] Provide a small, standard-library-only CLI with `claim`, `renew`,
  `release`, and `status` operations. Use one human-readable lease file per
  exact emulator serial in a fixed directory under `/tmp` shared by all
  Boorusama worktrees of the same OS user. Record a hash of a unique lease
  token, owner session/worktree label, and expiration time. Do not record
  credentials.
- [x] Serialize each lease read-modify-write operation with a short-lived
  filesystem lock. Two simultaneous claims for one serial yield exactly one
  owner. Different serials can be owned by different sessions.
- [x] A claim of an unexpired lease reports the current owner and expiration
  without changing ownership. An expired lease can be replaced atomically.
  `renew` succeeds only for the matching, unexpired token; `release` cannot
  remove a lease acquired by someone else after expiration.
- [x] A claim or renewal grants 30 minutes. Agents renew before each
  device-affecting operation and stop using a device if renewal fails. Each
  individual device operation must be bounded to less than 20 minutes; split
  longer Maestro flows into steps with renewal between them. Building an APK
  without device access does not need a lease.
- [x] Document the claim/use/renew/release procedure in `AGENTS.md` and the
  development workflow. Agents first discover available serials, then claim
  one exact serial. Every Maestro call specifies its `device_id`; every ADB
  device command uses `-s`, and Flutter device commands specify the claimed
  device. A busy device is never used as a fallback.
- [x] Automated concurrency checks run two independent processes from
  different worktrees or working directories: same-serial contention, separate
  serials, renewal, expiration and reclaim, and rejection of an old owner's
  renewal or release after reclaim. Check the documented procedure on an
  available Android emulator without changing shared account data.

## Design and limits

Use a lease file plus a brief `flock` around metadata changes. The lock is held
only while a CLI operation runs; no process remains alive to hold it. A random
token prevents one session from renewing or releasing another session's lease.
Expiry recovers reservations abandoned by interrupted sessions. Because there
is no running heartbeat, safety depends on keeping each device operation shorter
than the lease remaining after renewal. Long-running interactive Flutter or
Maestro sessions must be broken into bounded operations or use a separately
approved ownership method.

This coordinates compliant agents using the same host and OS user. It does not
alter the emulator, Maestro server, or application state.

## Context and dependencies

- [Agent instructions](../../../AGENTS.md)
- [Development workflow](../../development_workflow.md)
- [Prior four-emulator QA](../done/QA-001-confirmed-emulator-regressions.md)

Dependencies: None.

## Progress

- Added `scripts/emulator_lease.py`, a Python standard-library CLI with one
  JSON lease and `flock` lock per exact serial in a fixed per-user `/tmp`
  directory. Claim and renewal grant 30 minutes; only a SHA-256 token digest
  is persisted, while the random raw token appears only in claim output.
  Tokens guard renewal and release. The CLI rejects unsafe serials and
  symlinked lease files.
- Documented discover, claim, renew before each bounded device operation,
  explicit device targeting, and release in `AGENTS.md` and the development
  workflow.

## Completion evidence

- Eight Python standard-library tests passed. They launch independent CLI
  processes from two working directories to check same-serial contention and
  simultaneous different-serial claims, plus renewal, expiration, reclaim,
  wrong/old-token rejection, raw-token non-disclosure in lease/status/busy
  output, serial validation, and symlink rejection. The same-serial test holds
  the target `flock` first and confirms both independent claimants wait.
- After rebasing onto local `develop` (`98d31ceb4`), all eight focused tests
  passed again. The diff against `develop` contains only DEV-002 files;
  `AGENTS.md` retains the coordinator and credential rules with a short link
  to the workflow, and the ticket exists only under `done/`.
- `git diff --check` passed. The change has no Dart or Flutter code, so no
  Flutter build or test was needed.
- On 2026-10-03, `adb devices -l` discovered `emulator-5554` and
  `emulator-5556`. The documented claim, status, renew, targeted
  `adb -s emulator-5554 shell getprop ro.product.model`, release, and final
  available-status sequence succeeded on `emulator-5554`. The only device
  command read a system property; no shared account data was changed.

### Five-agent live check (2026-10-03 UTC)

- Five distinct subagents (`lease_live_a`, `lease_live_b`, `lease_live_c`,
  `lease_live_e`, `lease_live_f`) participated. The runtime allowed only three
  simultaneous children: a fourth spawn hit the limit, so A was reused for
  the first contender; E and F were spawned later.
- A, B, and C discovered `emulator-5558`, `emulator-5560`, and
  `emulator-5562` through ADB and Maestro, then held separate leases at the
  same time. Each renewed before targeted read-only
  `adb -s <serial> shell getprop ro.product.model` and Maestro
  `inspect_screen` with the exact `device_id`. The model was
  `sdk_gphone64_x86_64` and each screen showed Android Launcher.
- On `emulator-5560`, A's second run received `BUSY` under B at 11:59:58
  and 12:00:14. B released at 12:00:19; A claimed at 12:00:25, renewed,
  used, and released by 12:01:01. Status was available at 12:01:15.
- On `emulator-5562`, C released before E's first claim, so that attempt
  did not prove contention. E claimed at 12:02:50 and held the lease after
  read-only checks. F received `BUSY` under E at 12:04:29. E released at
  12:04:50; F claimed at 12:04:53, renewed, used, and released by 12:05:53.
  Status was available at 12:05:56.
- An independent coordinator check found all three serials available at the
  end. No agent used a busy device as fallback, changed shared account data,
  or edited source during the live check. These results cover cooperative
  same-UID leases; they do not test crash expiry, forced interruption, long
  operations, or Flutter installs.
