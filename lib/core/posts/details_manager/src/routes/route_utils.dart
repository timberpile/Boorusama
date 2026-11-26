// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/data.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../content/content_access_provider.dart';
import '../../../../content/types.dart';
import '../../../../router.dart';
import '../../../details_parts/types.dart';
import '../providers/details_layout_provider.dart';
import '../types/custom_details.dart';

void goToDetailsLayoutManagerPage(
  WidgetRef ref, {
  required DetailsLayoutManagerParams params,
}) {
  ref.pushRoute(
    '/details_manager',
    extra: params,
  );
}

void goToGalleryDetailsLayoutManager(
  WidgetRef ref, {
  required ContentAccessContext access,
  required PostDetailsUIBuilder uiBuilder,
}) {
  final key = access.key;
  final owner = ref.read(contentAccessContextProvider(key));
  final profile = ref
      .read(booruConfigProvider)
      .where(
        (config) =>
            config.id == key.profileId && config.auth == access.config?.auth,
      )
      .firstOrNull;
  if (owner == null || profile == null || !access.hasSameAuthorization(owner)) {
    return;
  }
  final defaults = uiBuilder.full.keys.toSet();
  final stored =
      profile.layout?.galleryDetails
          ?.where((part) => defaults.contains(parseDetailsPart(part.name)))
          .toList() ??
      const [];
  final sourceContext = ref.context;
  final container = ProviderScope.containerOf(sourceContext, listen: false);
  final profiles = container.read(booruConfigProvider.notifier);

  goToDetailsLayoutManagerPage(
    ref,
    params: DetailsLayoutManagerParams(
      details: stored.isEmpty ? convertDetailsParts(defaults.toList()) : stored,
      availableParts: defaults,
      defaultParts: defaults,
      onUpdate: (parts) {
        if (!sourceContext.mounted) return;
        final live = container.read(contentAccessContextProvider(key));
        if (live == null || !access.hasSameAuthorization(live)) return;
        profiles.updateGalleryDetailsLayout(profile: profile, parts: parts);
      },
    ),
  );
}

void goToDetailsLayoutManagerForPreviewWidgets(WidgetRef ref) {
  final layout = ref.watchLayoutConfigs ?? const LayoutConfigs.undefined();
  final uiBuilder = ref
      .watch(booruBuilderProvider(ref.watchConfigAuth))
      ?.postDetailsUIBuilder;

  if (uiBuilder == null) return;

  final previewDetails =
      layout.previewDetails ??
      convertDetailsParts(uiBuilder.preview.keys.toList());

  final notifier = ref.watch(booruConfigProvider.notifier);
  final currentConfigNotifier = ref.watch(
    currentBooruConfigProvider.notifier,
  );
  final config = ref.watchConfig;

  goToDetailsLayoutManagerPage(
    ref,
    params: DetailsLayoutManagerParams(
      details: previewDetails,
      availableParts: uiBuilder.buildablePreviewParts.toSet(),
      defaultParts: uiBuilder.preview.keys.toSet(),
      onUpdate: (parts) {
        notifier.update(
          booruConfigData: config
              .copyWith(
                layout: () => layout.copyWith(
                  previewDetails: () => parts,
                ),
              )
              .toBooruConfigData(),
          oldConfigId: config.id,
          onSuccess: (booruConfig) {
            currentConfigNotifier.updateIfCurrent(booruConfig);
          },
        );
      },
    ),
  );
}

void goToDetailsLayoutManagerForFullWidgets(WidgetRef ref) {
  final layout = ref.watchLayoutConfigs ?? const LayoutConfigs.undefined();
  final uiBuilder = ref
      .watch(booruBuilderProvider(ref.watchConfigAuth))
      ?.postDetailsUIBuilder;

  if (uiBuilder == null) return;

  final details =
      layout.details ?? convertDetailsParts(uiBuilder.full.keys.toList());

  final notifier = ref.watch(booruConfigProvider.notifier);
  final currentConfigNotifier = ref.watch(
    currentBooruConfigProvider.notifier,
  );
  final config = ref.watchConfig;

  goToDetailsLayoutManagerPage(
    ref,
    params: DetailsLayoutManagerParams(
      details: details,
      availableParts: uiBuilder.full.keys.toSet(),
      defaultParts: uiBuilder.full.keys.toSet(),
      onUpdate: (parts) {
        notifier.update(
          booruConfigData: config
              .copyWith(
                layout: () => layout.copyWith(
                  details: () => parts,
                ),
              )
              .toBooruConfigData(),
          oldConfigId: config.id,
          onSuccess: (booruConfig) {
            currentConfigNotifier.updateIfCurrent(booruConfig);
          },
        );
      },
    ),
  );
}
