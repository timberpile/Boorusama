# Typed values checkpoint

Refs #71. The shared option editor now supports explicitly declared numeric
ranges, decimals, calendar dates, file sizes with units, ratios and duration
units. Presets fill the same local draft as manual controls. Validation rejects
compound input, reversed numeric/date ranges, impossible dates and zero ratio
denominators. Calendar-relative mixed duration units are not converted using an
invented fixed month/year length. Date selection is another modal Back layer.

The original conservative catalogs are unchanged in this checkpoint; later
catalog commits opt fields into these types. Existing age and score comparison
negation is intentionally preserved. Prefix-negatable range fields can exclude
the complete range. Unknown/manual native queries are not constrained by these
validators.

New metadata labels use search_options.ext keys. A missing translation falls
back to the native key/value instead of throwing. The following catalog commits
supply additive translation inputs and document their application. No new
translated prose is hardcoded in application widgets.

New validation tests are committed. Flutter formatting/analysis/widget tests
remain unrun because the toolchain is absent. Local review must include narrow
width, 2x text, keyboard-open fields, calendar cancellation and pending entity
lookup. Existing presets and applied-query semantics must not regress.
