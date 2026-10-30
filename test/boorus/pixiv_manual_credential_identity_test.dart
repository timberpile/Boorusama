import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/boorus/pixiv/configs/widgets.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/create/providers.dart';
import 'package:boorusama/core/configs/create/src/providers/internal_providers.dart';
import 'package:boorusama/core/configs/create/src/types/edit_booru_config_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

const _id = EditBooruConfigId.newId(
  booruType: BooruType.pixiv,
  url: 'https://www.pixiv.net/',
);
const _oldIdentity = PixivExtraData(userId: '100', userName: 'Account A');

void main() {
  setUpAll(() async => ensureI18nInitialized('en-US'));

  for (final token in ['refresh-test-b', '']) {
    testWidgets('manual replacement clears the previous identity: $token', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tester.enterText(find.byType(EditableText), token);
      await tester.pump();

      final data = container.read(editBooruConfigProvider(_id));
      expect(data.apiKey, token);
      expect(data.login, isEmpty);
      expect(data.passHash, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unchanged manual credential retains its verified identity', (
    tester,
  ) async {
    final container = await _pump(tester);
    await tester.enterText(find.byType(EditableText), 'refresh-test-a');
    await tester.pump();

    final data = container.read(editBooruConfigProvider(_id));
    expect(data.login, 'account-a');
    expect(data.passHash, _oldIdentity.toPassHash());
    expect(tester.takeException(), isNull);
  });

  testWidgets('programmatic token updates do not clear paired OAuth metadata', (
    tester,
  ) async {
    final container = await _pump(tester);
    const newIdentity = PixivExtraData(userId: '200', userName: 'Account B');
    container.read(editBooruConfigProvider(_id).notifier)
      ..updateLogin('account-b')
      ..updateApiKey('refresh-test-b')
      ..updatePassHash(newIdentity.toPassHash());
    await tester.pump();

    final data = container.read(editBooruConfigProvider(_id));
    expect(data.login, 'account-b');
    expect(data.apiKey, 'refresh-test-b');
    expect(data.passHash, newIdentity.toPassHash());
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'refresh-test-b',
    );
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        editBooruConfigIdProvider.overrideWithValue(_id),
        editBooruConfigProvider(_id).overrideWith(_SeededEditNotifier.new),
      ],
      child: BooruLocalization(
        child: MaterialApp(
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: const Scaffold(body: PixivAuthConfigView()),
        ),
      ),
    ),
  );
  await tester.ensureVisible(find.byType(EditableText));
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(PixivAuthConfigView)),
  );
}

class _SeededEditNotifier extends EditBooruConfigNotifier {
  @override
  BooruConfigData build(EditBooruConfigId arg) => BooruConfig.defaultConfig(
    booruType: arg.booruType,
    url: arg.url,
    customDownloadFileNameFormat: null,
  ).toBooruConfigData().copyWith(
    login: 'account-a',
    apiKey: 'refresh-test-a',
    passHash: () => _oldIdentity.toPassHash(),
  );
}
