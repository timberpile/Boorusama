# e621 and Moebooru catalog checkpoint

Refs #71. e621/e926 and Konachan.com/.net, Yande.re and Sakugabooru no longer
expose only rating. Catalogs cover the declared native search grammar using
common graphical editors, comparisons, ranges and presets.

Primary evidence inspected on 2026-10-23:
- https://raw.githubusercontent.com/e621ng/e621ng/master/app/logical/tag_query.rb
- https://raw.githubusercontent.com/e621ng/e621ng/master/app/logical/parse_value.rb
- https://raw.githubusercontent.com/moebooru/moebooru/master/app/models/tag/parse_methods.rb
- https://konachan.com/help/cheatsheet

Notable distinctions: e621 file sizes accept bytes/kb/mb, not a fabricated gb
suffix; ratios normalize slash input to a colon. e621's locks and Boolean
fields are not copied from Danbooru. Its staff-only fields remain permission
controlled by the site. Moebooru only supports prefix negation for selected
fields; numeric comparisons use complements instead. Its negative vote payload
has different semantics, so the generic Exclude control is deliberately absent.
Existing manual raw input remains available for special expressions.

Source inspection and new regression tests are committed, not runtime-verified.
Current upstream source is evidence of engine grammar, not proof that every
host deploys the same revision. Local acceptance should cover each listed host,
particularly Sakugabooru media types and moderation/account-only controls.
