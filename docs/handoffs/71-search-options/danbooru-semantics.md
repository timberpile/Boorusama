# Danbooru semantic review

Refs #71. The public `PostQueryBuilder::METATAGS` vocabulary is covered by typed
editors. The old blanket native-only entries were an incomplete conservative
first pass, not an inherent limitation of the API. `newpool` is a post-edit
operation, not a current public post-search filter; `locked` is also absent
from the current parser. Neither is invented as a supported search option.

Fixed review findings: excluding an age/score range now uses predicate negation
instead of failing Apply. Simple comparisons still use readable exact inverse
bounds. `limit`/`random` accept exact counts only, without comparison/range/NOT
controls. Danbooru declares order/ordfav/ordvote/ordfavgroup/ordpool as one
exclusive family. Guided selection replaces competing typed items in that
family, including when editing an existing item. Other profiles do not inherit
this rule unless their catalog declares the complete same ordering vocabulary.
Opaque raw expressions are left untouched except an explicitly selected edit.

Sources inspected 2026-10-23:
- https://github.com/danbooru/danbooru/blob/master/app/logical/post_query_builder.rb
- https://github.com/danbooru/danbooru/blob/master/app/logical/post_query.rb
- https://safebooru.donmai.us/wiki_pages/help:cheatsheet

Added public-vocabulary, range, count and ordering-family tests. They remain
unrun in this environment. Raw Boolean groups, multiword quoted native text,
comma ID lists/custom order and role restrictions require local acceptance;
typed editors cover their documented basic forms, not a full Boolean AST UI.
