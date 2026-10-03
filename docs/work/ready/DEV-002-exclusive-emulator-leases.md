# Reserve Android emulators across agent sessions

Priority: High
Affected feature: Agent workflow and Android emulator testing

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

- [ ] Provide a small, standard-library-only CLI with `claim`, `renew`,
  `release`, and `status` operations. Use one human-readable lease file per
  exact emulator serial in a fixed directory under `/tmp` shared by all
  Boorusama worktrees of the same OS user. Record a unique lease token, owner
  session/worktree label, and expiration time. Do not record credentials.
- [ ] Serialize each lease read-modify-write operation with a short-lived
  filesystem lock. Two simultaneous claims for one serial yield exactly one
  owner. Different serials can be owned by different sessions.
- [ ] A claim of an unexpired lease reports the current owner and expiration
  without changing ownership. An expired lease can be replaced atomically.
  `renew` succeeds only for the matching, unexpired token; `release` cannot
  remove a lease acquired by someone else after expiration.
- [ ] A claim or renewal grants 30 minutes. Agents renew before each
  device-affecting operation and stop using a device if renewal fails. Each
  individual device operation must be bounded to less than 20 minutes; split
  longer Maestro flows into steps with renewal between them. Building an APK
  without device access does not need a lease.
- [ ] Document the claim/use/renew/release procedure in `AGENTS.md` and the
  development workflow. Agents first discover available serials, then claim
  one exact serial. Every Maestro call specifies its `device_id`; every ADB
  device command uses `-s`, and Flutter device commands specify the claimed
  device. A busy device is never used as a fallback.
- [ ] Automated concurrency checks run two independent processes from
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
