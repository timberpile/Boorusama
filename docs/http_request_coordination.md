# Booru data request coordination

The app owns one `ApiRequestCoordinator` for its lifetime. A quota belongs to
an actual HTTP origin: lowercase scheme and hostname plus effective port.
Profiles, engine identities, database origin aliases, caller `Origin` headers,
proxies and alternate clients do not create independent budgets. Absolute URLs
and safe redirects use their actual destination origins.

Unknown origins have no invented active requests-per-second/minute ceiling.
All origins share at most four data transports in flight, with at most two
passive transports. Automatic and preload work additionally use an app-local
rolling budget of 12 starts per minute. Active work does not consume that local
budget; passive work still consumes applicable documented server allowances.
Priority is interactive, user initiated, bulk data transfer, automatic, then
preload. Equal priorities are FIFO among eligible requests. A waiter blocked
only by a scoped server rule cannot impose that rule on an unrelated endpoint.
Running work is never preempted; sustained interaction may starve passive work.

Known policies are declared centrally in `ApiQuotaPolicy.forOrigin`, for exact
HTTPS origins with the default port:

- [Danbooru API help](https://danbooru.donmai.us/wiki_pages/help:api) publishes
  ten reads/second for short bursts and recommends approximately one/second
  sustained. Main and safe origins use a rolling ten/second read window plus
  a token bucket of ten, refilling one/second. This bucket is the app's explicit
  implementation of the recommendation, not the server's unpublished global
  algorithm. Mutations conservatively use one/second without tier assumptions.
- [e621 API help](https://e621.net/help/show/api) publishes a hard two/second
  and recommends at most one; e621.net and e926.net use one/second.
- [Derpibooru API documentation](https://derpibooru.org/pages/api) publishes
  30/five seconds generally and 20/ten seconds for `/api/v1/json/search*`.
  Both rules count the same origin's applicable traffic; search is not a second
  independent allowance and unrelated endpoints do not inherit its window.
- [Zerochan API documentation](https://www.zerochan.net/api) publishes
  60/minute. The rule applies to the actual www API origin, including final
  admitted redirect hops.

No synthetic 24/minute add-on remains. Other installations do not inherit an
engine's numeric policy: AiBooru, Ponybooru and Asiachan are separate documented
or unknown cases. Unknown does not imply unlimited upstream capacity. Server
account/IP counters may include other apps and devices; absence of rate headers
is not an allowance. Danbooru action-bucket headers are not interpreted as the
global read limit. Sources were checked on 2026-10-06.

## Transport and cancellation boundary

Configured booru Dio factories, anonymous Shimmie discovery, secondary Moebooru
post transport, injected Gelbooru/Hybooru HTML crawlers, Nozomi binary indexes
and absolute post JSON, and logger-free OAuth/auth exchanges share admission.
The decorator wraps the selected adapter after authentication preparation.
A permit lasts until the response stream finishes or upstream cancellation is
acknowledged; obtaining response headers alone does not release it.

Data redirects disable native following. Safe GET/HEAD hops are drained and
admitted separately, with original query parameters cleared. Cross-origin hops
inherit only ordinary accept/language/encoding, user-agent and range headers;
engine-specific and custom credential headers are removed. URI userinfo and
non-HTTP destinations are rejected. POST and mutation redirects are returned
without automatic replay because a consumed request stream cannot be reused.
Media retains its existing redirect behavior.

Account-level auth refresh has aggregate live ownership. Request context uses
the normalized Dio cancel token, including explicit caller Options. Cancelling
one waiter leaves other owners intact. If all owners disappear while the
exchange is queued, admission is cancelled. Once credential rotation is
physically dispatched it finishes and persists the replacement credentials.
Refresh errors are transported as settled values and raised in each waiter's
Zone: sharing a failing Future between Dio's separate error zones can otherwise
leave a waiter hanging. Authentication and Cloudflare bounded safe-read
negotiation still use the owning decorated client; data permits are released
before nested retries so four concurrent 401 responses cannot deadlock refresh.

Media is classified by explicit caller purpose (`apiMediaRequestKey`) in image,
AVIF, video HEAD/cache and share/download paths. Extensions and byte response
types do not classify requests: Nozomi binary API indexes count as data and
signed extensionless image URLs remain media. Image decoder cache changes,
video playback bytes, image loads, downloads, favicons and donation artwork are
outside this coordinator. Announcements, backup transport, CLI requests,
proxy diagnostics, external YouTube page lookup and interactive Cloudflare
WebView challenge traffic are also outside booru data admission.

## Cooldown and refresh consumers

HTTP 429 and the existing Pixiv decoded rate-limit envelope produce a shared
`retryAt`. Retry-After supports positive integer seconds and HTTP dates;
otherwise progressive jittered waits use 30s, 120s, 600s and 1800s. Simultaneous
responses from one episode do not repeatedly increase the penalty. Decoded
success gradually reduces it; Pixiv 200 rate envelopes do not count as success.
Generic 500/501/503 responses are not reliable limiter signals. Documented
e621503 and Derpi middleware response shapes can overlap outages; automatic
classification is deferred until a stable affirmative limiter signature is
available. These errors retain their ordinary handling.

Safe reads receive at most one generic transient retry, or one brief cooldown
retry of at most two seconds where allowed. Generic retries cannot multiply
existing auth/Cloudflare negotiation. Mutations never automatically replay,
including Gelbooru GET favorites and Shimmie token rejection. Manual refresh
sets `allowCooldownRetry: false`: a click during cooldown returns the remaining
wait and cannot become a delayed action.

`runWithApiRequestContext` scopes lazy asynchronous execution. Consumers supply
live owner priority, cancellation, a final `canStart` guard, an optional separate
`canAdmit` deadline guard, and `onStarted` callback. Admission expiry prevents new
physical dispatches, including retries, while a valid already-dispatched read
may finish and commit. An ordinary failure whose optional retry exceeds that
deadline keeps its original failure outcome.
Pinned/following source refresh uses lifecycle and source-revision guards and
checks cancellation/lifecycle again inside the serialized repository write
boundary, and returns `SearchRefreshDeferred(retryAt)` without changing attempt/checkpoint,
previews or NEW state. The scheduler remembers deferral in memory until retryAt;
it is not a persisted failed attempt. The conservative foreground automatic
policy uses these contexts, snapshots and admission deadlines. The existing
three-operation refresh gate remains a
feature-level guard in addition to the app-wide physical transport limits.

A queued shared auth operation follows its strongest live owner's priority.
Owner join/detach and policy change notifications wake admission immediately;
a manual owner need not inherit a passive minute wait. Removing that owner
restores the remaining passive eligibility. After reservation, active/passive classification is rechecked immediately
before physical dispatch. A changed classification abandons and reacquires
only that undispatched reservation; it cannot borrow a cancelled manual
owner's passive exemption. Once dispatched, classification and debit remain
fixed through completion or acknowledged cancellation. Credential rotation
is never restarted to change priority. Shared live ownership and account identity remain independent of
individual caller cancellation.

A shared source or auth operation resolves queued priority from live owners;
joining manual work promotes it and explicitly wakes admission. Source-definition
guards remain separate from individual owner cancellation. A live manual owner
can finish when the automatic owner pauses, and makes adaptive interval outcomes
inert at the guarded commit. Once manual work joins, brief delayed cooldown replay
stays disabled. When a new manual caller finds the actual current data quota in
cooldown, it returns Deferred immediately: a pending physical read may still
finish, while a between-attempt cooldown wait is interrupted. Unrelated origins
and completed auth quotas do not establish a source data cooldown. Shared auth
retains aggregate ownership, credential rotation, and cross-Zone settlement.

Detached Danbooru favorite-status and vote metadata requests use `preload`,
inherit cancellation/eligibility, and request immediate deferral when no
capacity is available. They do not queue behind an exhausted local/server
budget, occupied streams or older eligible work, and are not replayed later.
Typed deferral/cancellation/cooldown is consumed at the detached boundary and
leaves unknown favorite/vote status uncached. This prevents a minute-long
speculative backlog during rapid pagination. Explicit visible status actions,
automatic refresh and mutations retain their ordinary admission semantics;
local cached preload does not use transport.

`ApiQuotaSnapshot` distinguishes passive occupancy and queued wait reasons
(server window/pacing, passive budget, concurrency or priority). These are
admission/permit diagnostics, not byte-transfer measurements: the physical
adapter may not yet have started. Debug overlay UI/settings and separate media
or native download observers belong to DEV-003.

Favorite mutations restore their exact prior unknown/true/false state when
interrupted before acknowledgement. A confirmed Danbooru favorite removal
remains successful if its separate vote cleanup is interrupted; cleanup is not
replayed and its prior vote state stays intact until acknowledged. The scoped
shared UI action boundary allows confirmed-success callbacks to finish, then
shows the cleanup wait from the owning page even if the initiating item was
removed. Cancellation is quiet, and a removed owning route gets no late toast.

Overlapping actions on the same post keep a confirmed base separately from
optimistic display. Interrupted operations cannot restore another operation's
unconfirmed optimism or erase a newer acknowledged intent. This tracks only
pending actions; it does not queue or replay favorite mutations.
