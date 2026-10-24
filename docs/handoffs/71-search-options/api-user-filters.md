# Account filters using existing API parameters

Refs #71. e-shuushuu exposes exact uploader ID (`user_id`) and favoriting user
ID (`favorited_by_user_id`). Anime-Pictures exposes favoriting user ID
(`stars_by`). The corresponding parameters already existed in the current
fork's clients, but ordinary search did not pass them through. They now have
guided exact-ID fields; no comparison, exclusion or fabricated username lookup
is offered. e-shuushuu resolves only actual tag terms, and retains its existing
empty-resolution behavior rather than broadening to an unfiltered user feed.

Evidence: `EShuushuuClient.getPosts` and
`AnimePicturesClient.getPostsWithTotal` at the starting runtime source. These
are existing request contracts, not claims of a fresh live API test. The GUI
websites expose additional search controls, but not every one has an established
parameter mapping in this client. Those remain explicit coverage gaps rather
than being sent as fictional `tags` strings.

Only supported standalone positive-ID items are consumed. Unknown/negated,
malformed and grouped input is retained unchanged. An opaque flattened query
is not parsed into API parameters; typed history/share paths must be verified.
The current e-shuushuu tag-ID resolver still has its pre-existing partial/fuzzy
resolution behavior; this change does not silently claim to fix that separate
boundary. Required local tests include request-interceptor assertions for both
providers, known-user live searches, combined tags, empty resolution and profile
switching. The new parser/catalog tests were added but not run here.
