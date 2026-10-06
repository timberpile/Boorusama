// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../settings/types.dart';
import '../../../../settings/widgets.dart';
import '../../../config/types.dart';
import '../../../create/providers.dart';
import '../../../gesture/types.dart';
import '../widgets/tooltip_toggle.dart';

// Flutter imports:

const kDefaultPreviewImageButtonAction = {
  '',
  null,
  kToggleBookmarkAction,
  kDownloadAction,
  kViewArtistAction,
};

class DefaultBooruConfigListingView extends ConsumerWidget {
  const DefaultBooruConfigListingView({
    super.key,
    this.tooltipToggle,
  });

  final Widget? tooltipToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BooruConfigListingView(
      postPreviewQuickActionButtonActions: kDefaultPreviewImageButtonAction,
      describePostPreviewQuickAction: null,
      tooltipToggle: tooltipToggle ?? const ListingTooltipToggle(),
    );
  }
}

class BooruConfigListingView extends ConsumerWidget {
  const BooruConfigListingView({
    required this.postPreviewQuickActionButtonActions,
    required this.describePostPreviewQuickAction,
    this.tooltipToggle,
    super.key,
  });

  final Set<String?> postPreviewQuickActionButtonActions;
  final String Function(String? action)? describePostPreviewQuickAction;
  final Widget? tooltipToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing =
        ref.watch(
          editBooruConfigProvider(
            ref.watch(editBooruConfigIdProvider),
          ).select((value) => value.listingTyped),
        ) ??
        ListingConfigs.undefined();
    final enable = listing.enable;
    final settings = listing.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Theme(
        data: Kurumi.themeOf(context).copyWith(
          listTileTheme: Kurumi.themeOf(context).listTileTheme.copyWith(
            contentPadding: EdgeInsets.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: Text(context.t.booru.listing.thumbnail_button),
              subtitle: Text(
                context.t.booru.listing.thumbnail_button_description,
              ),
              trailing: KurumiOptionDropDownButton(
                backgroundColor: Colors.transparent,
                alignment: AlignmentDirectional.centerStart,
                value: ref.watch(
                  editBooruConfigProvider(
                    ref.watch(editBooruConfigIdProvider),
                  ).select((value) => value.defaultPreviewImageButtonAction),
                ),
                onChanged: (value) => ref.editNotifier
                    .updateDefaultPreviewImageButtonAction(value),
                items: postPreviewQuickActionButtonActions
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          describePostPreviewQuickAction != null
                              ? describePostPreviewQuickAction!(value)
                              : describeImagePreviewQuickAction(value, context),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(),
            KurumiSwitchListTile(
              title: Text(
                context.t.booru.listing.enable_profile_specific_settings,
              ),
              subtitle: Text(
                context
                    .t
                    .booru
                    .listing
                    .enable_profile_specific_settings_description,
              ),
              value: enable,
              onChanged: (value) => ref.editNotifier.updateListing(
                listing.copyWith(enable: value),
              ),
            ),
            KurumiGrayedOut(
              grayedOut: !enable,
              child: ImageListingSettingsSection(
                listing: settings,
                onUpdate: (change) {
                  final current =
                      ref
                          .read(
                            editBooruConfigProvider(
                              ref.read(editBooruConfigIdProvider),
                            ),
                          )
                          .listingTyped ??
                      ListingConfigs.undefined();
                  ref.editNotifier.updateListing(
                    current.copyWith(settings: change(current.settings)),
                  );
                },
              ),
            ),
            if (tooltipToggle case final toggle?) ...[
              const Divider(),
              toggle,
            ],
          ],
        ),
      ),
    );
  }
}
