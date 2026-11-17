# Export Bookmark folder labels (#121)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/121-export-folder-labels`.

Export presentation omitted Bookmark folder nodes although the selector retained
their stable `group-folder:` IDs. Resolve names from the live Bookmark folder
catalog, including nested folders and renames. Missing folder nodes use the
existing localized Folder label rather than an internal ID. Storage, templates,
selection identity and the .bsexport schema are unchanged.

Checks:

- `fvm dart format lib/core/backups/export_import/export/export_flow_notifier.dart lib/core/backups/export_import/widgets/selection_tree.dart test/core/backups/export_import/export_folder_labels_test.dart`: passed.
- `timeout 75s fvm flutter test --no-pub --concurrency=6 test/core/backups/export_import/export_folder_labels_test.dart test/core/backups/export_import/export_selection_test.dart`: 11 passed; nested names, live rename with retained selection ID, localized missing-folder widget fallback and existing selection/template semantics.
- `timeout 30s fvm dart analyze lib/core/backups/export_import/export/export_flow_notifier.dart lib/core/backups/export_import/widgets/selection_tree.dart test/core/backups/export_import/export_folder_labels_test.dart`: zero errors/warnings, 8 informational lint findings.
- `git diff --check`: passed.

Not run: emulator/Maestro, live APIs, APK build/install, complete regression suite,
Android manual/visual acceptance or actual user export files. Owner QA: expand
nested Bookmark folders in Custom Export, restore a selection after renaming a
folder and confirm readable labels. Full develop-integration verification remains
deferred; this branch is for owner acceptance.
