# Remove persistent folder-access guidance

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`. Requested wording removal, not a storage-permission change.

## Located presentation

[AutoBackupSection](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/backups/auto/widgets.dart) renders `context.t.settings.auto_backup.folder_access_hint` in a separate 12 dp Padding whenever the platform is Android. It is not conditional on a missing destination or a failed permission check, so it remains visible even after a folder has been selected.

The same component separately provides the location row and Select/Change action, an invalid-location banner, and contextual failure messages. [AutoBackupRepositoryAndroid](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/backups/auto/repo_android.dart) owns the native folder picker and `prepare` call; its `isTree` check establishes URI shape, not proof of a still-valid persisted permission grant.

## Proposed change

Remove the unconditional Android `folder_access_hint` widget and its padding. This is the identified persistent-help surface corresponding to the reported 'Choose a folder and allow access in...' guidance; confirm its locale value when making the small edit. Do not replace it with another permanently visible explanation.

Keep the Select/Change action, selected location, actual folder picker and native permission confirmation. Preserve contextual missing-location and revoked-permission recovery. Do not remove `folder_access_error`, weaken `prepare`, treat a syntactically valid content URI as authorization, or change backup scheduling/retention to silence the text.

Remove the obsolete localization key from translation inputs only after checking its remaining consumers. Regenerate localization output only if those inputs change, following the repository workflow; do not hand-edit generated translations. No settings or backup migration is needed.

## Verification

A focused widget test should cover Android with no location, a selected location and a real access failure: the persistent hint is absent in all three, the Select/Change control remains, and the failure message is still visible when needed. Verify no empty padded row remains and non-Android layout is unchanged. A native permission test is required only if the implementation touches the permission boundary, which this proposal does not require.

No UI string, permission behavior or runtime code was changed by this investigation.
