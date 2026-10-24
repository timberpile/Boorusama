# Entity suggestion endpoint follow-up

Refs #71. Added user suggestions for e621/e926 and Moebooru, and user/pool
suggestions for Szurubooru. Danbooru retains its native entity autocomplete.
The active profile transport/auth is reused. Requests are debounced; direct
HTTP requests are cancelled on disposal. Responses are bounded, null-safe and
deduplicated. Empty input never downloads all users. A pool label resolves to
its numeric ID where required; ordinary tag results are not accepted as users.
A failed/forbidden endpoint leaves manual entry available.

Primary evidence inspected 2026-10-23:
- e621ng User.search, `search[name_matches]` and `search[order]=name`:
  https://github.com/e621ng/e621ng/blob/master/app/models/user.rb
- Moebooru UserController.autocomplete_name, `term`, minimum two characters:
  https://github.com/moebooru/moebooru/blob/master/app/controllers/user_controller.rb
- Szurubooru `/users` and `/pools`, named search and selected response fields:
  https://github.com/rr-/szurubooru/blob/master/doc/API.md

Local checks still required: run the entity tests in `test/core/search/options`,
then test rapid edits, dismissal during a request, profile switching, permission
errors and selection followed by Cancel/Apply with actual endpoints. Tests were
added but cannot run here (no FVM/Flutter). Source review is not runtime evidence.
Gelbooru/Rule34 are not assigned a fictional user-autocomplete endpoint.
