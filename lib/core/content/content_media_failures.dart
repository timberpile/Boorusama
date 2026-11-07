import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../posts/details/src/types/post_presentation_fallback_reason.dart';
import 'content_access.dart';
import 'content_access_provider.dart';
import 'content_media_access.dart';

typedef ContentMediaFailureKey = ({ContentAccessKey access, int bookmarkId});

void reportContentMediaOutcome(
  BuildContext context, {
  required bool failed,
  PostPresentationFallbackReason reason =
      PostPresentationFallbackReason.refreshFailed,
}) {
  if (!context.mounted) return;
  final container = context
      .getInheritedWidgetOfExactType<UncontrolledProviderScope>()
      ?.container;
  if (container == null) return;
  final key = container.read(currentContentAccessKeyProvider);
  final id = container.read(currentContentBookmarkIdProvider);
  if (key == null || id == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted ||
        context
                .getInheritedWidgetOfExactType<UncontrolledProviderScope>()
                ?.container !=
            container ||
        container.read(currentContentAccessKeyProvider) != key ||
        container.read(currentContentBookmarkIdProvider) != id)
      return;
    container
        .read(contentMediaFailuresProvider.notifier)
        .record(
          (access: key, bookmarkId: id),
          failed: failed,
          reason: reason,
        );
  });
}

/// Only observed failures are retained, without URLs, response text or secrets.
/// Loading a group cannot start remote probes through this projection.
final contentMediaFailuresProvider =
    NotifierProvider<
      ContentMediaFailures,
      Map<ContentMediaFailureKey, PostPresentationFallbackReason>
    >(ContentMediaFailures.new);

class ContentMediaFailures
    extends
        Notifier<Map<ContentMediaFailureKey, PostPresentationFallbackReason>> {
  @override
  Map<ContentMediaFailureKey, PostPresentationFallbackReason> build() =>
      const {};

  void record(
    ContentMediaFailureKey request, {
    required bool failed,
    PostPresentationFallbackReason reason =
        PostPresentationFallbackReason.refreshFailed,
  }) {
    if (ref.read(contentAccessContextProvider(request.access)) == null) return;
    final next = Map.of(state)..remove(request);
    if (failed) {
      if (state[request] == reason) return;
      if (next.length >= 512) next.remove(next.keys.first);
      next[request] = reason;
    } else if (!state.containsKey(request)) {
      return;
    }
    state = Map.unmodifiable(next);
  }

  void retry(Iterable<ContentMediaFailureKey> requests) {
    final next = Map.of(state);
    for (final request in requests) {
      if (ref.read(contentAccessContextProvider(request.access)) != null &&
          state[request] == PostPresentationFallbackReason.refreshFailed)
        next.remove(request);
    }
    if (next.length != state.length) state = Map.unmodifiable(next);
  }
}

/// Mount this only for a terminal media outcome. Reporting after the frame
/// avoids provider mutations during layout and rejects disposed source scopes.
class ContentMediaOutcome extends StatefulWidget {
  const ContentMediaOutcome({
    required this.failed,
    required this.child,
    this.reason = PostPresentationFallbackReason.refreshFailed,
    super.key,
  });
  final bool? failed;
  final Widget child;
  final PostPresentationFallbackReason reason;
  @override
  State<ContentMediaOutcome> createState() => _ContentMediaOutcomeState();
}

class _ContentMediaOutcomeState extends State<ContentMediaOutcome> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(ContentMediaOutcome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.failed != widget.failed || oldWidget.reason != widget.reason)
      _report();
  }

  void _report() {
    final failed = widget.failed;
    if (failed != null)
      reportContentMediaOutcome(context, failed: failed, reason: widget.reason);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
