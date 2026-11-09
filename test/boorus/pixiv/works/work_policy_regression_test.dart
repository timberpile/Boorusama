import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/boorus/pixiv/works/work_source.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'work_test_fixtures.dart';

void main() {
  test('cached seeded and fetched Work envelopes recheck captured policy on every read', () async {
    for (final seeded in [true, false]) {
      final blacklist = <String>{};
      final access = workAccess();
      var fetches = 0;
      final source = PixivWorkSource(
        access: access,
        blacklist: blacklist,
        fetchWork: (_) async {
          fetches++;
          return work();
        },
      );
      addTearDown(source.dispose);
      if (seeded) source.seedWork(work());
      final reference = pixivWorkReference(access, 120);
      expect((await source.loadDetails(reference).run()).isRight(), isTrue);
      expect(fetches, seeded ? 0 : 1);
      blacklist.add('fixture');
      expect((await source.loadSummary(reference).run()).isLeft(), isTrue);
      expect((await source.loadDetails(reference).run()).isLeft(), isTrue);
      expect(
        (await source.loadMembers(GroupMemberQuery(reference: reference)).run())
            .isLeft(),
        isTrue,
      );
      expect(
        fetches,
        seeded ? 0 : 1,
        reason: 'The denied envelope was cached; policy must still be checked',
      );
    }
  });

  test('cover tag coverage survives full metadata codec and legacy covers remain compatible', () {
    final codec = GroupMetadataCodec();
    final access = workAccess();
    for (final dto in [
      work(),
      work(omitTags: true),
      work(tags: [null]),
    ]) {
      final details = pixivWorkDetails(dto, access);
      final roundtrip = codec.decodeDetails(codec.encodeDetails(details));
      expect(
        roundtrip.summary.cover!.visibility!.tagCoverage,
        details.summary.cover!.visibility!.tagCoverage,
      );
      expect(
        roundtrip.summary.cover!.visibility,
        details.summary.cover!.visibility,
      );
    }
    expect(
      pixivWorkTags(work(tags: [null]))!.coverage,
      MetadataCoverage.partial,
    );
    expect(pixivWorkTags(work(tags: [null]))!.values, isEmpty);
    final legacy = GroupCoverVisibility(
      tags: const ['known'],
      rating: 'general',
      deleted: false,
      banned: false,
    ).toJson()..remove('tagCoverage');
    expect(
      GroupCoverVisibility.fromJson(legacy).tagCoverage,
      MetadataCoverage.complete,
    );
    final future = {...legacy, 'tagCoverage': 'future'};
    expect(
      GroupCoverVisibility.fromJson(future).tagCoverage,
      MetadataCoverage.unknown,
    );
  });
}
