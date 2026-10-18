# Viewer diagnostics transformation fixtures

These inputs make the overlay tests independent of local Git object retention.
Production revision and clean-worktree guards in `apply_viewer_diagnostics.py`
remain unchanged.

- `legacy/`: six authentic Dart files copied byte for byte using `git show`
  from `a46521eced78ae2f31a5c2517a43fc2e4e4a6072`.
- `bounded/`: the four changed Dart inputs copied byte for byte from
  `f3ce8bc4cc3900f577a2f2e6dd88004201ff594f`. Both commits were present and inspected locally on 2026-10-17.
  The remaining two Dart files match the legacy revision exactly and are reused.
  No production optimization or diagnostics code was reconstructed or stripped.
- The EN/DE JSON files are small representative synthetic pre-overlay catalogs,
  containing an unrelated sentinel. They are not historical translation dumps.
  Overlay translations come from the current repository, as in production.

Dart inputs use a `.dart.fixture` suffix so static analysis does not treat
historical snippets with relative imports as current application sources. Their
bytes remain identical to the recorded revisions. Test fixtures are
transformation inputs, not runnable replacement application sources. Tests retain legacy/bounded behavior assertions, complete installation,
unknown/dirty-revision rejection, and atomic no-write failure behavior.
