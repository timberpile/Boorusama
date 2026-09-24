// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../../configs/config/types.dart';

sealed class PostOriginResolution extends Equatable {
  const PostOriginResolution();
}

final class ResolvedPostOrigin extends PostOriginResolution {
  const ResolvedPostOrigin(this.config);

  final BooruConfig config;

  @override
  List<Object?> get props => [config];
}

final class MissingPostOrigin extends PostOriginResolution {
  const MissingPostOrigin();

  @override
  List<Object?> get props => const [];
}

final class AmbiguousPostOrigin extends PostOriginResolution {
  const AmbiguousPostOrigin();

  @override
  List<Object?> get props => const [];
}
