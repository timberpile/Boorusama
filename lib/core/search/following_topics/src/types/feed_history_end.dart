import 'package:equatable/equatable.dart';

/// The oldest source post reached by a successful, exhaustive history request.
/// A null identity means that the source was empty when checked.
class FeedHistoryEnd extends Equatable {
  const FeedHistoryEnd({required this.oldestPostIdentity});

  final String? oldestPostIdentity;

  @override
  List<Object?> get props => [oldestPostIdentity];
}
