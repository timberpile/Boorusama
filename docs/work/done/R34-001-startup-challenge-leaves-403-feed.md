# Rule34 startup challenge can leave a 403 HTML error in the feed

Claim: coordinator `/root`, 2026-10-03; implementer `/root/audit_rule34`; branch `fix/r34-001-startup-challenge`; worktree `.worktrees/r34-001-startup-challenge`.
Priority: Normal
Affected feature: Rule34.xxx home feed, CAPTCHA/challenge handling

## Problem and reproduction

Reported by the user: With Rule34.xxx selected, starting the app sometimes briefly shows a CAPTCHA screen that closes by itself. The initial feed then shows a `403 Access denied` HTML page. This happens on each reported start; manually refreshing the feed makes it load normally. Live reproduction confirmed the failing request is the automatic replay of the Rule34 post-index API call after the challenge solver reports completion.

## Expected behavior and acceptance criteria

- After an automatically completed challenge, the initial Rule34 feed loads without requiring a manual refresh when the retried API request succeeds.
- A challenge dialog must not disappear as though the feed recovered if the request still receives 403. In that case, show a concise, actionable error with Retry, not the raw HTML response body.
- Neither the initial request nor a retry enters an endless CAPTCHA or request loop. A manual refresh remains usable; unrelated sites are unaffected.
- Reproduce and identify whether the failing response is the first API request, its automatic replay, or another startup request before selecting a fix. Cover the observed sequence and failure fallback with focused tests.

## Context and dependencies

Current code automatically refreshes the post grid on entry. The protection interceptor retries a request once after a challenge is reported solved; a later 403 is passed on. The CAPTCHA solver can report completion on a new clearance cookie, while the post error path passes a string response body into the feed error view. Live diagnostics confirmed the replay returns 403 while a manual refresh shortly afterward succeeds. The replay and successful refresh both lacked a clearance cookie header in the observed runs, so cookie presence did not explain the difference; timing is the supported explanation. Avoid recording cookie values, credentials, or full sensitive response bodies in diagnostics.

This is separate from IDEA-007's API rate-limit coordination; that work alone should not be assumed to resolve challenge/session handling. The implemented fix makes one delayed second replay only for the Rule34 GET post-index endpoint after a solved challenge and a 403 replay. A persistent 403 is shown without HTML and with Retry.

## Completion evidence (2026-10-03)

- On an exclusively leased Android emulator with a disposable Rule34.xxx profile, the cold start produced an initial 403 on `/index.php`, the challenge solver completed, and the immediate automatic replay received 403. The feed showed the raw error before the fix. A manual refresh about 1.5 seconds later succeeded with 200. Diagnostics recorded only request phase, path, status, retry flag, and clearance-cookie presence; temporary instrumentation was removed.
- After installing the Dev build with the fix and preserving app data, a cold start with the same Rule34 profile loaded a populated feed without manual refresh or a visible 403. A manual pull-to-refresh completed and the feed remained populated. The profile was confirmed as Rule34 before cleanup, then the prior Danbooru selection was restored, the disposable profile was deleted, and the emulator lease was released. Live checks establish the visible recovery; post-fix HTTP phases were covered by deterministic tests rather than retained diagnostics.
- Focused tests cover immediate success, 403 followed by delayed recovery, persistent 403 with final-error propagation and working manual retry, unrelated hosts, mutation requests, and cancellation during the delay. A widget test covers the concise 403 view and Retry action. All seven tests pass. Targeted Dart analysis reports no issues, the Dev debug APK builds, and `git diff --check` passes.
