// Opt-in VM allocation probe. Copy unchanged with fixtures.dart to both trees.
// Run with fvm flutter test --no-pub --concurrency=1 --enable-vmservice <path>.
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test('profile repeated one-row bookmark publication', () async {
    const count = 25000;
    const publications = 30;
    final base = scalabilityLibrary([
      for (var id = 1; id <= count; id++) scalabilityBookmark(id),
    ]);
    final changed = scalabilityBookmark(count ~/ 2, savedAt: scalabilityEpoch);
    BookmarkLibraryState publish() => base.applyCommittedChanges(
      upserts: [changed],
      groups: base.groups,
      folders: base.folders,
    );
    for (var i = 0; i < 10; i++) {
      expect(publish().bookmarksById[changed.id], same(changed));
    }
    final info = await developer.Service.getInfo();
    final uri = info.serverUri;
    if (uri == null) throw StateError('Run with --enable-vmservice');
    final isolateId = developer.Service.getIsolateId(Isolate.current)!;
    final before = await _profile(uri, isolateId, reset: true);
    final results = <BookmarkLibraryState>[];
    final started = developer.Timeline.now;
    for (var i = 0; i < publications; i++) {
      results.add(publish());
    }
    final ended = developer.Timeline.now;
    final stats = await _profile(
      uri,
      isolateId,
      traceStart: started,
      traceEnd: ended,
    );
    expect(results, hasLength(publications));
    expect(
      results.every(
        (state) => identical(state.bookmarksById[changed.id], changed),
      ),
      isTrue,
    );
    // The helper isolate decodes VM-service responses outside this measured
    // isolate. Retain structural-container counters before and after the work.
    print(
      'PUBLICATION_ALLOCATIONS ${jsonEncode({
        'bookmarks': count,
        'publications': publications,
        'before': before,
        'after': stats,
      })}',
    );
  });
}

Future<Map<String, dynamic>> _profile(
  Uri uri,
  String isolateId, {
  bool reset = false,
  int? traceStart,
  int? traceEnd,
}) => Isolate.run(() async {
  final client = HttpClient();
  Future<Map<String, dynamic>> rpc(
    String method,
    Map<String, String> params,
  ) async {
    final request = await client.getUrl(
      uri.resolve(method).replace(queryParameters: params),
    );
    final response = await request.close();
    final json = jsonDecode(
      await utf8.decoder.bind(response).join(),
    ) as Map<String, dynamic>;
    if (json['error'] != null) throw StateError('${json['error']}');
    return json['result'] as Map<String, dynamic>;
  }

  try {
    final profile = await rpc('getAllocationProfile', {
      'isolateId': isolateId,
      if (reset) 'reset': 'true',
      if (reset) 'gc': 'true',
    });
    const traced = {'_Map', 'UnmodifiableMapView', 'BookmarkLibraryState'};
    const containers = {...traced, '_List', '_Uint32List', '_GrowableList'};
    final members = [
      for (final row in profile['members'] as List)
        if (containers.contains((row['class'] as Map)['name'])) row,
    ];
    final traces = <String, dynamic>{};
    for (final row in members) {
      final type = row['class'] as Map;
      if (!traced.contains(type['name'])) continue;
      await rpc('setTraceClassAllocation', {
        'isolateId': isolateId,
        'classId': type['id'] as String,
        'enable': reset.toString(),
      });
      if (!reset) {
        traces[type['name'] as String] = await rpc('getAllocationTraces', {
          'isolateId': isolateId,
          'classId': type['id'] as String,
          'timeOriginMicros': traceStart.toString(),
          'timeExtentMicros': (traceEnd! - traceStart!).toString(),
        });
      }
    }
    // Transfer only selected classes. Full profile decoding stays in this helper.
    // Retained snapshots prevent dead-state elimination. Trace samples supplement
    // GC-sensitive heap counters; neither is a universal peak-allocation measure.
    return {
      'dateLastAccumulatorReset': profile['dateLastAccumulatorReset'],
      'dateLastServiceGC': profile['dateLastServiceGC'],
      'memoryUsage': profile['memoryUsage'],
      'members': members,
      'allocation_traces': traces,
    };
  } finally {
    client.close(force: true);
  }
});
