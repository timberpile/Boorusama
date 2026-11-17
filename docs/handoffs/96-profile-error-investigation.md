# Transient Danbooru profile errors (#96)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/96-transient-profile-errors`. No runtime fix is claimed.

The current production router wraps each destination Navigator in
`DestinationProfileScope`, which resolves the destination UUID and supplies all
compatibility overrides through `CurrentBooruConfigScope`. The Browse builder
then reads that scoped authentication. Navigators have stable outer branch keys.
The displayed section-error message comes from the global Flutter error widget;
it is not an ordinary post-loading error. Neither an account mismatch nor the
exception that triggers this fallback was established on this base. Suppressing
that fallback or reordering global profile writes would therefore be speculative
and could conceal genuine failures or disturb retained navigation history.

Attempted short control:

```
timeout 60s fvm flutter test --no-pub --concurrency=6 test/application/config_switch_flow_test.dart test/core/navigation/source_scope_test.dart
```

The command reached test compilation but exceeded its 60-second guard (exit 124),
with no completed test results. It is **incomplete**, not a pass. It was stopped
under the owner's short-test budget. `git diff --check` passed for this report.

Not run: Android/emulator/Maestro, live Danbooru/account requests, APK build,
full suite or device visual checks. The existing controls also use fake engine
boundaries and would not prove the actual Danbooru page initialization path.

Waiting for a reproducible error/exception on the current base: switch repeatedly
between a non-Danbooru profile and Danbooru, capture the exception associated with
the section fallback, and identify the exact destination/build. Preserve private
account data outside shared reports. Once identified, add a narrow regression
at that boundary. This documentation-only branch is retained for handoff and is
not included in the cumulative bugfix preview.
