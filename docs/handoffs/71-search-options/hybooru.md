# Hybooru and typed-value review

Refs #71. Added documented Hybooru ordering, numeric rating service values and
closed ranges, and system inbox/archive/trash predicates. Numeric ratings are
not adult-content ratings. Custom tag-sort presets remain text input because
they are configured per server, not a global list.

Source: https://github.com/funmaker/Hybooru#searching-query-syntax
Inspected 2026-10-23; the linked demo identifies itself as v1.17.0.
Hybooru supports only its documented system predicates, not Hydrus's entire
predicate vocabulary. Its numeric rating maximum depends on the imported
service. Do not invent a universal five-star limit.

The shared value editor now honors an option's supported comparison operators
and decodes engine-specific wire values on reopening. FREE decoration retains
custom validation and serialization instead of accidentally turning subclasses
back into generic Danbooru syntax. Date picker initial values are clamped to
its visible calendar bounds to avoid assertions for older/future raw values;
typing those dates still preserves the draft. External value updates reload
the draft controls without resetting them on each ordinary keystroke.

Added tests for rating range round-trips, unsupported operators and serializer
decoration. Local Flutter/widget, enlarged-text/calendar and service-backed
verification remain required; none were executed here.
