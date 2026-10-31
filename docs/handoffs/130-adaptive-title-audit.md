# Adaptive title surface audit (#130)

Reviewed against develop `de5928283aa39f0d67d6a834e42d4fa5e9369b86`.
The adoption changes existing title hosts; it introduces no title framework.

| Surface | Result and reason |
| --- | --- |
| Normal and sliver page app bars | Existing KurumiAppBar/KurumiSliverAppBar already fit plain Text titles through KurumiToolbarTitleScope. Preserved without another fitter. Custom selection titles already fit explicitly because their title is a ListenableBuilder rather than Text. |
| Settings cards | KurumiSettingsCardTitle now gives the title the width remaining beside its trailing control and uses KurumiFittedText. Bounded cards fit; loose vertical sections retain accessible wrapping. Covers app settings and favorite-tag editing consumers. |
| Editable sheets | KurumiBottomSheetHeader fits within the existing 52 dp action height. Close/Confirm retain their hit targets, tooltip and loading behavior. Covers favorite-tag editor and label management. |
| Searchable option sheets | KurumiOptionSearchableSheet fits the heading within a quarter of the keyboard-adjusted body height. Search and results retain the rest; heading semantics are preserved. The app wrapper inherits this for all option-sheet consumers. |
| Notice cards | KurumiTemplateContainer fits within its existing 40 dp header beside icon and expand action. Info/Warning consumers inherit it; body text and expansion semantics are unchanged. |
| Custom form dialogs | FollowTopicDialog and PostsPerPageDialog fit their headings within a third of the available dialog content height. Content and actions remain scrollable. FollowTopicDialog now applies the actual keyboard inset, matching PostsPerPageDialog: the stronger geometry test found its action at y=588 behind a keyboard starting at y=400 before that correction. The local bound preserves room for editing; titles do not reserve a fixed number of lines. |
| Server Favorites dialog | Already uses KurumiFittedText with explicit bounds and an information action. Preserved. |
| Bookmark batch title | Separately corrected in #108; not copied into this branch. |
| Context-menu section dividers | Intentionally retain one-line ellipsis at the existing labelSmall size: compact separators already have half-menu width bounds; reducing this small label further would impair readability. Full label semantics remain available. Menu action labels remain ordinary action text. |
| Material AlertDialog/SimpleDialog titles | Preserve normal wrapping in intrinsic dialog layout (for example BookmarkGroupNameDialog, profile removal and selected-tag editing). KurumiFittedText uses LayoutBuilder, which cannot answer the intrinsic-width sizing these dialogs require. Blind wrapping would break layout. These scrollable/wrapping title hosts have no fixed toolbar rectangle that needs fitting. |
| Scroll-flow headings | Preserve normal text in backup/import/export pages, post-detail sections, tag details, changelog and descriptive help. These have unbounded scrolling height and readable text is preferable to shrinking. Share-sheet heading likewise flows with its scrollable contents. |
| Values and ordinary rows | Cache-size values, result counts, setting/list titles and body labels remain text. They are not bounded page/dialog headers; fitting them would alter ordinary accessible content. |

Validation includes the complete Kurumi suite (existing app-bar/fitter and popup
coverage), new real shared-host tests at 320 dp, 2x text, keyboard insets and both
themes, plus app form and shared-component consumers. The final branch handoff
records exact final-source commands, results and device limits; this audit alone
is not a completion claim.
