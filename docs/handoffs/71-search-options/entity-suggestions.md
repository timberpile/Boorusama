# Entity suggestions follow-up

Refs #71. The graphical text editor now requests real Danbooru user/pool
suggestions from the existing authenticated autocomplete repository. User-role
filters reuse user lookup; ordered pool filters reuse pool lookup. Selection
changes only the local value; Apply still commits and Cancel/Back still discard.

The opening profile and ProviderContainer are captured before crossing the root
navigator, avoiding accidental lookup under the global profile. A separate
family is keyed by auth config, option and text. Requests are debounced for
250 ms, disposed timers are cancelled, old results cannot populate a new query,
non-entity rows are rejected, results are deduplicated and limited to eight.
An endpoint failure leaves manual entry available, never fabricated suggestions.

The next catalog expansion activates this for additional Danbooru role/pool
rows. Other engine entity endpoints have not been enabled speculatively.

Static review and endpoint/caller inspection only. The new parser tests and
widget/network-ordering tests must be run locally with FVM. Add deterministic
completer-driven tests for rapid input, profile switches and closing the sheet
while a request is pending. No claim of live-service or Flutter verification.
