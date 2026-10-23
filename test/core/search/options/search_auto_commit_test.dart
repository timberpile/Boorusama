import 'package:boorusama/core/search/options/search_auto_commit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'coalesces a compound mutation and ignores a duplicate notification',
    () {
      var query = 'old';
      var applied = 'old';
      final callbacks = <void Function()>[];
      final requests = <String>[];
      final commit = SearchAutoCommit(
        readQuery: () => query,
        readApplied: () => applied,
        commit: () {
          applied = query;
          requests.add(query);
        },
        schedule: callbacks.add,
      );
      query = '';
      commit.changed();
      query = 'new rating:q';
      commit.changed();
      expect(callbacks, hasLength(1));
      callbacks.removeAt(0)();
      expect(requests, ['new rating:q']);
      commit.changed();
      callbacks.removeAt(0)();
      expect(requests, hasLength(1));
    },
  );

  test('refreshes an empty search after the last item is removed', () {
    var query = 'cat';
    var applied = query;
    final callbacks = <void Function()>[];
    final requests = <String>[];
    final commit = SearchAutoCommit(
      readQuery: () => query,
      readApplied: () => applied,
      commit: () {
        applied = query;
        requests.add(query);
      },
      schedule: callbacks.add,
    );
    query = '';
    commit.changed();
    callbacks.single();
    expect(requests, ['']);
  });

  test('does not duplicate a request already applied by an explicit path', () {
    var query = 'cat';
    var applied = '';
    var requests = 0;
    final callbacks = <void Function()>[];
    final commit = SearchAutoCommit(
      readQuery: () => query,
      readApplied: () => applied,
      commit: () => requests++,
      schedule: callbacks.add,
    );
    commit.changed();
    applied = query;
    callbacks.single();
    expect(requests, 0);
    query = 'dog';
    callbacks.clear();
    commit.changed();
    commit.dispose();
    callbacks.single();
    expect(requests, 0);
  });
}
