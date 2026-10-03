# Rule34 startup challenge can leave a 403 HTML error in the feed

Priority: Normal
Affected feature: Rule34.xxx home feed, CAPTCHA/challenge handling

## Problem and reproduction

Reported by the user: With Rule34.xxx selected, starting the app sometimes briefly shows a CAPTCHA screen that closes by itself. The initial feed then shows a `403 Access denied` HTML page. This happens on each reported start; manually refreshing the feed makes it load normally. The exact challenge response and the cause of the subsequent 403 have not yet been reproduced or confirmed in a live session.

## Expected behavior and acceptance criteria

- After an automatically completed challenge, the initial Rule34 feed loads without requiring a manual refresh when the retried API request succeeds.
- A challenge dialog must not disappear as though the feed recovered if the request still receives 403. In that case, show a concise, actionable error with Retry, not the raw HTML response body.
- Neither the initial request nor a retry enters an endless CAPTCHA or request loop. A manual refresh remains usable; unrelated sites are unaffected.
- Reproduce and identify whether the failing response is the first API request, its automatic replay, or another startup request before selecting a fix. Cover the observed sequence and failure fallback with focused tests.

## Context and dependencies

Current code automatically refreshes the post grid on entry. The protection interceptor retries a request once after a challenge is reported solved; a later 403 is passed on. The CAPTCHA solver can report completion on a new clearance cookie, while the post error path passes a string response body into the feed error view. These are investigation leads, not a verified root cause for Rule34.xxx. Avoid recording cookie values, credentials, or full sensitive response bodies in diagnostics.

This is separate from IDEA-007's API rate-limit coordination; that work alone should not be assumed to resolve challenge/session handling. No product-code change is part of creating this ticket.
