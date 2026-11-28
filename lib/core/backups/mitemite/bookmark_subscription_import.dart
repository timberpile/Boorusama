import 'package:flutter/foundation.dart';

import '../export_import/import/import_progress.dart';
import 'protocol.dart';

final class BookmarkSubscriptionCancelled implements Exception {
  const BookmarkSubscriptionCancelled();
}

typedef BookmarkSubscriptionImportState = ({
  ImportProgressValue? progress,
  ({int checked, int total})? groups,
  bool cancelling,
  bool saving,
});

/// One interactive subscription, owned by the current MiteMite service.
final class BookmarkSubscriptionImport
    extends ValueNotifier<BookmarkSubscriptionImportState> {
  BookmarkSubscriptionImport({
    required this.collection,
    required this.name,
    required this.publisherName,
  }) : super((progress: null, groups: null, cancelling: false, saving: false));

  final SyncCollectionId collection;
  final String name;
  final String publisherName;
  final _checkedGroups = <String>{};
  var _waitingForProjection = false;
  bool get waitingForProjection => _waitingForProjection;

  void deferProjection() {
    _waitingForProjection = true;
    notifyListeners();
  }

  late final progress = ImportProgress(
    (sample) => value = (
      progress: sample,
      groups: value.groups,
      cancelling: value.cancelling,
      saving: value.saving,
    ),
    cancelled: () => value.cancelling,
  );

  void setGroupsToCheck(Set<String> sources) {
    // A retry can widen the receive unit when sources share a record. Keep
    // checks already completed against the same catalog in the new total.
    _checkedGroups.retainAll(sources);
    _reportGroups(sources.length);
  }

  void groupChecked(String source) {
    if (value.groups case final groups? when _checkedGroups.add(source)) {
      _reportGroups(groups.total);
    }
  }

  void _reportGroups(int total) {
    value = (
      progress: value.progress,
      groups: (checked: _checkedGroups.length, total: total),
      cancelling: value.cancelling,
      saving: value.saving,
    );
  }

  void cancel() {
    if (value.saving || value.cancelling) return;
    value = (
      progress: value.progress,
      groups: value.groups,
      cancelling: true,
      saving: false,
    );
  }

  void checkCancelled() {
    if (value.cancelling) throw const BookmarkSubscriptionCancelled();
  }

  void beginSaving() {
    checkCancelled();
    value = (
      progress: value.progress,
      groups: value.groups,
      cancelling: false,
      saving: true,
    );
    progress.show(ImportProgressPhase.saving);
  }
}
