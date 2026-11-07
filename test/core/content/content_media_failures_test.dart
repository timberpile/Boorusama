import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/content/content_media_failures.dart';
import 'package:boorusama/core/posts/details/src/types/post_presentation_fallback_reason.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _site = 'https://safebooru.donmai.us';
const _bookmarkId = 94;
final _activeKey = StateProvider<ContentAccessKey?>((ref) => null);
final _activeBookmarkId = StateProvider<int?>((ref) => null);

ContentAccessContext _context({int authEpoch = 1, int policyEpoch = 2}) {
  final config = BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': '11111111-1111-4111-8111-111111111111',
    'booruId': BooruType.danbooru.id,
    'booruIdHint': BooruType.danbooru.id,
    'url': _site,
    'login': 'fixture-login',
    'apiKey': 'fixture-key',
  });
  return ContentAccessContext.profile(
    config: config,
    authEpoch: authEpoch,
    policyEpoch: policyEpoch,
  );
}

ContentMediaFailureKey _request(ContentAccessContext context) => (
  access: context.key,
  bookmarkId: _bookmarkId,
);

ProviderContainer _container(
  ContentAccessContext context, {
  ContentAccessContext? otherContext,
}) => ProviderContainer(
  overrides: [
    _activeKey.overrideWith((ref) => context.key),
    _activeBookmarkId.overrideWith((ref) => _bookmarkId),
    currentContentAccessKeyProvider.overrideWith(
      (ref) => ref.watch(_activeKey),
    ),
    currentContentBookmarkIdProvider.overrideWith(
      (ref) => ref.watch(_activeBookmarkId),
    ),
    contentAccessContextProvider(context.key).overrideWithValue(context),
    if (otherContext != null)
      contentAccessContextProvider(otherContext.key).overrideWithValue(
        otherContext,
      ),
  ],
);

void main() {
  test(
    'terminal failures deduplicate and valid success or retry clears them',
    () {
      final context = _context();
      final request = _request(context);
      final container = _container(context);
      addTearDown(container.dispose);
      final notifier = container.read(contentMediaFailuresProvider.notifier);

      notifier.record(request, failed: true);
      final first = container.read(contentMediaFailuresProvider);
      expect(first, {request: PostPresentationFallbackReason.refreshFailed});
      notifier.record(request, failed: true);
      expect(container.read(contentMediaFailuresProvider), same(first));

      notifier.record(request, failed: false);
      expect(container.read(contentMediaFailuresProvider), isEmpty);
      notifier.record(request, failed: true);
      notifier.retry([request]);
      expect(container.read(contentMediaFailuresProvider), isEmpty);

      notifier.record(
        request,
        failed: true,
        reason: PostPresentationFallbackReason.unavailableEngine,
      );
      expect(
        container.read(contentMediaFailuresProvider),
        {request: PostPresentationFallbackReason.unavailableEngine},
      );
      notifier.retry([request]);
      expect(
        container.read(contentMediaFailuresProvider),
        {request: PostPresentationFallbackReason.unavailableEngine},
        reason: 'only temporary refresh failures may be retried',
      );
      notifier.record(request, failed: false);
      expect(container.read(contentMediaFailuresProvider), isEmpty);
    },
  );

  test(
    'revoked failure context cannot publish or clear a recorded failure',
    () {
      final context = _context();
      final request = _request(context);
      final activeContext = StateProvider<ContentAccessContext?>(
        (ref) => context,
      );
      final container = ProviderContainer(
        overrides: [
          contentAccessContextProvider(context.key).overrideWith(
            (ref) => ref.watch(activeContext),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(contentMediaFailuresProvider.notifier);

      notifier.record(request, failed: true);
      expect(container.read(contentMediaFailuresProvider), hasLength(1));
      container.read(activeContext.notifier).state = null;
      notifier.record(request, failed: false);
      notifier.retry([request]);
      expect(container.read(contentMediaFailuresProvider), hasLength(1));
    },
  );

  testWidgets(
    'loading is ignored and observed terminal failure then success updates counts',
    (
      tester,
    ) async {
      final context = _context();
      final container = _container(context);
      addTearDown(container.dispose);
      Widget build(bool? failed, {PostPresentationFallbackReason? reason}) =>
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ContentMediaOutcome(
                  failed: failed,
                  reason:
                      reason ?? PostPresentationFallbackReason.refreshFailed,
                  child: const Text('media'),
                ),
              ),
            ),
          );

      await tester.pumpWidget(build(null));
      expect(container.read(contentMediaFailuresProvider), isEmpty);
      await tester.pumpWidget(build(true));
      expect(
        container.read(contentMediaFailuresProvider),
        {_request(context): PostPresentationFallbackReason.refreshFailed},
      );
      await tester.pumpWidget(
        build(true, reason: PostPresentationFallbackReason.unavailableEngine),
      );
      expect(
        container.read(contentMediaFailuresProvider),
        {_request(context): PostPresentationFallbackReason.unavailableEngine},
      );
      await tester.pumpWidget(build(false));
      expect(container.read(contentMediaFailuresProvider), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale post-frame outcome cannot publish after the access key changes',
    (
      tester,
    ) async {
      final oldContext = _context();
      final newContext = _context(authEpoch: 2);
      final container = _container(oldContext, otherContext: newContext);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: _ChangeKeyBeforeOutcomeReport(
                container: container,
                nextKey: newContext.key,
                child: const ContentMediaOutcome(
                  failed: true,
                  child: Text('media'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(container.read(currentContentAccessKeyProvider), newContext.key);
      expect(container.read(contentMediaFailuresProvider), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy outcome without a provider scope is a no-op', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ContentMediaOutcome(failed: true, child: Text('legacy')),
      ),
    );
    await tester.pump();
    expect(find.text('legacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ChangeKeyBeforeOutcomeReport extends StatefulWidget {
  const _ChangeKeyBeforeOutcomeReport({
    required this.container,
    required this.nextKey,
    required this.child,
  });

  final ProviderContainer container;
  final ContentAccessKey nextKey;
  final Widget child;

  @override
  State<_ChangeKeyBeforeOutcomeReport> createState() =>
      _ChangeKeyBeforeOutcomeReportState();
}

class _ChangeKeyBeforeOutcomeReportState
    extends State<_ChangeKeyBeforeOutcomeReport> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.container.read(_activeKey.notifier).state = widget.nextKey;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
