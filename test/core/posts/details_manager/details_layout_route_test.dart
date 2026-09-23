import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/defaults/widgets.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/details_manager/routes.dart';
import 'package:boorusama/core/posts/details_manager/src/providers/details_layout_provider.dart';
import 'package:boorusama/core/posts/details_manager/types.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = [
    (
      label: 'preview layout',
      open: goToDetailsLayoutManagerForPreviewWidgets,
      savedParts: (LayoutConfigs? layout) => layout?.previewDetails,
    ),
    (
      label: 'full layout',
      open: goToDetailsLayoutManagerForFullWidgets,
      savedParts: (LayoutConfigs? layout) => layout?.details,
    ),
  ];

  for (final testCase in cases) {
    testWidgets(
      'saving scoped profile B ${testCase.label} leaves global profile A selected',
      (tester) async {
        final global = _config(id: 1, url: 'https://a.example');
        final scoped = _config(id: 2, url: 'https://b.example');
        final harness = await _pumpEditor(
          tester,
          global: global,
          edited: scoped,
          open: testCase.open,
        );
        addTearDown(harness.dispose);
        const parts = [CustomDetailsPartKey('info')];

        harness.params.onUpdate(parts);
        await tester.pump();

        final saved = harness.container
            .read(booruConfigProvider)
            .singleWhere((config) => config.id == scoped.id);
        expect(testCase.savedParts(saved.layout), parts);
        expect(harness.container.read(currentBooruConfigProvider), global);
        expect(harness.currentUpdates, 0);
      },
    );

    testWidgets(
      'saving global profile A ${testCase.label} refreshes its current state',
      (tester) async {
        final global = _config(id: 1, url: 'https://a.example');
        final other = _config(id: 2, url: 'https://b.example');
        final harness = await _pumpEditor(
          tester,
          global: global,
          edited: global,
          configs: [global, other],
          open: testCase.open,
        );
        addTearDown(harness.dispose);
        const parts = [CustomDetailsPartKey('info')];

        harness.params.onUpdate(parts);
        await tester.pump();

        final current = harness.container.read(currentBooruConfigProvider);
        expect(testCase.savedParts(current.layout), parts);
        expect(current.id, global.id);
        expect(harness.currentUpdates, 1);
      },
    );
  }
}

Future<_EditorHarness> _pumpEditor(
  WidgetTester tester, {
  required BooruConfig global,
  required BooruConfig edited,
  required void Function(WidgetRef ref) open,
  List<BooruConfig>? configs,
}) async {
  late DetailsLayoutManagerParams params;
  late _RecordingCurrentConfigNotifier currentNotifier;
  late GoRouter router;
  router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => _OpenEditor(edited: edited, open: open),
      ),
      GoRoute(
        path: '/details_manager',
        builder: (_, state) {
          params = state.extra! as DetailsLayoutManagerParams;
          return const Scaffold(body: Text('layout editor'));
        },
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      booruConfigProvider.overrideWith(
        () => _RecordingBooruConfigNotifier(
          configs ?? [global, edited],
        ),
      ),
      currentBooruConfigProvider.overrideWith(
        () => currentNotifier = _RecordingCurrentConfigNotifier(global),
      ),
      booruBuilderProvider.overrideWith((ref, config) => _DetailsBuilder()),
      routerProvider.overrideWithValue(router),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.tap(find.text('customize'));
  await tester.pumpAndSettle();
  expect(find.text('layout editor'), findsOneWidget);

  return _EditorHarness(
    container: container,
    router: router,
    params: params,
    currentNotifier: currentNotifier,
  );
}

class _OpenEditor extends StatelessWidget {
  const _OpenEditor({required this.edited, required this.open});

  final BooruConfig edited;
  final void Function(WidgetRef ref) open;

  @override
  Widget build(BuildContext context) => CurrentBooruConfigScope(
    config: edited,
    child: Consumer(
      builder: (context, ref, _) => Scaffold(
        body: TextButton(
          onPressed: () => open(ref),
          child: const Text('customize'),
        ),
      ),
    ),
  );
}

class _RecordingBooruConfigNotifier extends BooruConfigNotifier {
  _RecordingBooruConfigNotifier(List<BooruConfig> configs)
    : super(initialConfigs: configs);

  @override
  Future<void> update({
    required BooruConfigData booruConfigData,
    required int oldConfigId,
    void Function(String message)? onFailure,
    void Function(BooruConfig booruConfig)? onSuccess,
  }) async {
    final updated = booruConfigData.toBooruConfig(id: oldConfigId)!;
    state = [
      for (final config in state)
        if (config.id == oldConfigId) updated else config,
    ];
    onSuccess?.call(updated);
  }
}

class _RecordingCurrentConfigNotifier extends CurrentBooruConfigNotifier {
  _RecordingCurrentConfigNotifier(this.initial);

  final BooruConfig initial;
  var updates = 0;

  @override
  BooruConfig build() => initial;

  @override
  Future<void> update(BooruConfig booruConfig) async {
    updates++;
    state = booruConfig;
  }
}

class _DetailsBuilder extends BaseBooruBuilder {
  @override
  PostDetailsUIBuilder get postDetailsUIBuilder => const PostDetailsUIBuilder(
    preview: {DetailsPart.info: _empty},
    full: {DetailsPart.info: _empty},
  );
}

Widget _empty(BuildContext context) => const SizedBox.shrink();

BooruConfig _config({required int id, required String url}) =>
    BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: url,
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': id,
    });

class _EditorHarness {
  const _EditorHarness({
    required this.container,
    required this.router,
    required this.params,
    required this.currentNotifier,
  });

  final ProviderContainer container;
  final GoRouter router;
  final DetailsLayoutManagerParams params;
  final _RecordingCurrentConfigNotifier currentNotifier;

  int get currentUpdates => currentNotifier.updates;

  void dispose() {
    router.dispose();
    container.dispose();
  }
}
