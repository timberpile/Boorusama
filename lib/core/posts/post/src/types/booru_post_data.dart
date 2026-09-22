// Package imports:
import 'package:equatable/equatable.dart';

abstract interface class BooruPostData {
  String get typeKey;
  int get schemaVersion;
}

abstract interface class BooruPostDataCodec<D extends BooruPostData> {
  String get typeKey;
  int get currentVersion;
  bool supports(BooruPostData data);
  Map<String, Object?> encode(D data);
  D decode(Map<String, Object?> json, {required int version});
}

class EmptyPostDataCodec implements BooruPostDataCodec<EmptyPostData> {
  const EmptyPostDataCodec(this.typeKey);

  @override
  final String typeKey;

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) =>
      data is EmptyPostData && data.typeKey == typeKey;

  @override
  Map<String, Object?> encode(EmptyPostData data) {
    if (!supports(data)) {
      throw ArgumentError.value(data, 'data', 'Incompatible empty post data');
    }
    return const {};
  }

  @override
  EmptyPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != currentVersion || json.isNotEmpty) {
      throw const FormatException('Invalid empty post data');
    }
    return EmptyPostData(typeKey: typeKey);
  }
}

final class EmptyPostData extends Equatable implements BooruPostData {
  const EmptyPostData({required this.typeKey, this.schemaVersion = 1});

  @override
  final String typeKey;

  @override
  final int schemaVersion;

  @override
  List<Object?> get props => [typeKey, schemaVersion];
}

final class LegacyPostData extends Equatable implements BooruPostData {
  const LegacyPostData({
    required this.typeKey,
    required this.custom,
    this.schemaVersion = 1,
  });

  @override
  final String typeKey;

  @override
  final int schemaVersion;

  final Map<String, Object?> custom;

  @override
  List<Object?> get props => [typeKey, schemaVersion, custom];
}

enum UnknownPostDataReason {
  unavailableCodec,
  unsupportedVersion,
  malformedData,
  incompatiblePayload,
}

final class UnknownPostData extends Equatable implements BooruPostData {
  const UnknownPostData({
    required this.typeKey,
    required this.schemaVersion,
    required this.custom,
    required this.reason,
  });

  @override
  final String typeKey;

  @override
  final int schemaVersion;

  final Map<String, Object?> custom;
  final UnknownPostDataReason reason;

  @override
  List<Object?> get props => [typeKey, schemaVersion, custom, reason];
}
