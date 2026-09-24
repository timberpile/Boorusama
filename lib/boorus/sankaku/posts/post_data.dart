// Package imports:
import 'package:booru_clients/sankaku.dart';
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/tags/tag/types.dart';

final class SankakuPostData extends Equatable implements BooruPostData {
  const SankakuPostData({
    required this.sankakuId,
    required this.isFavorited,
    required this.favoriteCount,
    required this.artistDetailsTags,
    required this.characterDetailsTags,
    required this.copyrightDetailsTags,
    required this.generalDetailsTags,
    required this.metaDetailsTags,
  });

  final SankakuPostIdData? sankakuId;
  final bool isFavorited;
  final int favoriteCount;
  final List<Tag> artistDetailsTags;
  final List<Tag> characterDetailsTags;
  final List<Tag> copyrightDetailsTags;
  final List<Tag> generalDetailsTags;
  final List<Tag> metaDetailsTags;

  @override
  String get typeKey => 'sankaku';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    sankakuId,
    isFavorited,
    favoriteCount,
    artistDetailsTags,
    characterDetailsTags,
    copyrightDetailsTags,
    generalDetailsTags,
    metaDetailsTags,
  ];
}

final class SankakuPostIdData extends Equatable {
  const SankakuPostIdData({required this.value, required this.isNumeric});

  final String value;
  final bool isNumeric;

  @override
  List<Object?> get props => [value, isNumeric];
}

extension SankakuPostDataX on Post {
  SankakuPostData? get sankakuData => switch (booruData) {
    final SankakuPostData data => data,
    _ => null,
  };

  SankakuId? get sankakuId => switch (sankakuData?.sankakuId) {
    SankakuPostIdData(value: final value, isNumeric: true) =>
      switch (int.tryParse(value)) {
        final parsed? => IntId(parsed),
        null => null,
      },
    SankakuPostIdData(value: final value) => StringId(value),
    null => null,
  };
  bool get isFavorited => sankakuData?.isFavorited ?? false;
  int get favoriteCount => sankakuData?.favoriteCount ?? 0;
  List<Tag> get artistDetailsTags => sankakuData?.artistDetailsTags ?? const [];
  List<Tag> get characterDetailsTags =>
      sankakuData?.characterDetailsTags ?? const [];
  List<Tag> get copyrightDetailsTags =>
      sankakuData?.copyrightDetailsTags ?? const [];
  List<Tag> get generalDetailsTags =>
      sankakuData?.generalDetailsTags ?? const [];
  List<Tag> get metaDetailsTags => sankakuData?.metaDetailsTags ?? const [];
  Set<String> get generalTags =>
      generalDetailsTags.map((tag) => tag.name).toSet();
  Set<String> get metaTags => metaDetailsTags.map((tag) => tag.name).toSet();
}
