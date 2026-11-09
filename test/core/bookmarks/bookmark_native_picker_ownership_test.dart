import 'dart:async';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_picker_actions.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_picker_request.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'server_favorites/test_support.dart';

void main() {
  for (final operation in ['save', 'create', 'remove']) {
    for (final revoke in [false, true]) {
      test(
        'queued native $operation preserves Hive when ${revoke ? 'source is revoked' : 'picker is dismissed'}',
        () async {
          final h = FavoriteHarness();
          late ContentAccessContext access;
          var revoked = false;
          await h.open(
            unifiedOrganization: true,
            extraOverrides: (_) => [
              contentAccessContextProvider.overrideWith(
                (ref, key) => revoked ? null : access,
              ),
            ],
          );
          addTearDown(h.close);
          access = ContentAccessContext.profile(
            config: h.profile,
            authEpoch: 1,
            policyEpoch: 1,
          );
          final draft = ContentGroupBookmark(
            id: 0,
            snapshot: StoredGroupSnapshot(
              summary: ContentGroupSummary(
                reference: const ContentReferenceCodec().parse(
                  engine: access.key.engine,
                  site: Uri.parse(h.profile.url),
                  kind: ContentKind.group,
                  sourceKey: 'pool:42',
                ),
                title: 'Fixture group',
                memberCount: 3,
              ),
            ),
            createdAt: DateTime.utc(2026),
            observedAt: DateTime.utc(2026),
            sourceProfileHint: h.profile.id,
          );
          final library = h.container.read(bookmarkLibraryProvider.notifier);
          final target = await library.createGroup('Target');
          if (operation == 'remove') {
            await library.toggleContentGroupTarget(draft, groupId: target.id);
          }
          final before = await library.snapshotForExport();
          final held = Completer<void>();
          final release = Completer<void>();
          addTearDown(() {
            if (!release.isCompleted) release.complete();
          });
          final blocker = h.bookmarkStorage.coordinator.runExclusive(() async {
            held.complete();
            await release.future;
          });
          await held.future.timeout(const Duration(seconds: 10));
          final requested = Completer<void>();
          var active = true;
          final actions = BookmarkPickerActions(
            container: h.container,
            request: ContentGroupBookmarkPickerRequest(
              draft: draft,
              source: h.profile,
              access: access.key,
            ),
            isActive: () {
              if (operation != 'create' && !requested.isCompleted) {
                requested.complete();
              }
              return active;
            },
          );
          addTearDown(actions.dispose);
          final action = operation == 'create'
              ? actions.createGroup(
                  'Must not appear',
                  null,
                  beforeCommit: requested.complete,
                )
              : actions.toggle(target.id, onRemoved: (_) {}).then<void>((_) {});
          final rejected = expectLater(action, throwsStateError);
          await requested.future.timeout(const Duration(seconds: 10));
          // The picker request reached the notifier while another real mutation
          // owns the coordinator; revoke ownership before its queued commit runs.
          if (revoke) {
            revoked = true;
            h.container.invalidate(contentAccessContextProvider(access.key));
          } else {
            active = false;
          }
          release.complete();
          await Future.wait([blocker, rejected])
              .timeout(const Duration(seconds: 10));
          expect(await library.snapshotForExport(), before);
          await library.refresh();
          expect(
            await library.snapshotForExport(),
            before,
            reason: 'The rejected request must preserve persisted records, groups and memberships',
          );
          expect(
            (await library.snapshotForExport()).groupsById.values.any(
              (group) => group.name == 'Must not appear',
            ),
            isFalse,
          );
        },
      );
    }
  }
}
