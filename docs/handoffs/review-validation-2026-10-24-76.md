# Review validation: issue #76

Branch: `bug/76-realbooru-original-metadata`
Reviewed parent: `d0ad03adbd5eab51df8271ed29e047f0fe25aa91`

## Finding and change

Confirmed a parser coverage defect, not a reproduced live-site failure: selecting
only the first existing metadata container hides fields in other already-supported
containers. Search each metadata field across `#post-info`, `#stats`, and `#tagLink`
in the existing precedence order. Keep each container's text separate so unrelated
fragments cannot manufacture a dimension pair. Original-link scope, image attribute
precedence, unknown metadata, video handling and network requests are unchanged.

Added six synthetic regression cases covering split fields, an empty earlier
container, independent dimension pairs, and untrusted text outside metadata blocks.
These fixtures demonstrate the input contract; they are not captured live HTML.

## Verification and continuation

Source and call-path review only. FVM, Flutter/Dart tests, formatting and analyzer
were unavailable in this environment and have NOT run. Continue the earlier
handoffs' live-HTML and application consumer checks. Run the complete
`packages/booru_clients` suite, affected Gelbooru V2 application tests, and
`fvm dart format` on the two changed Dart files. Inspect the focused diff before
running the complete regression suite on the final integration candidate.

No merge, issue closure or integration-readiness claim is authorized by this fix.
