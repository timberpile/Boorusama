import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The source belongs to the operation, independently of the Browse selection.
final class PageSourceContext extends Equatable {
  const PageSourceContext({required this.profileId, this.originatingTopicId});
  final String profileId;
  final String? originatingTopicId;

  @override
  List<Object?> get props => [profileId, originatingTopicId];
}

final explicitPageSourceProvider = Provider<PageSourceContext?>(
  (ref) => null,
  dependencies: const [],
);
