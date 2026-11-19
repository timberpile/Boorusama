import 'package:collection/collection.dart';
import 'package:kurumi/material.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/manage/widgets.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/types.dart';
import '../../../core/images/booru_image.dart';
import '../../../core/navigation/destination_activity.dart';
import '../following/presentation.dart';

/// Keep the artist row's exact image provider alive for the small viewer window.
class PixivWorkAvatarWindow extends StatelessWidget {
  const PixivWorkAvatarWindow({
    required this.creators,
    required this.child,
    super.key,
  });

  final List<({CreatorRef creator, ContentAccessContext access})> creators;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final byImage = {
      for (final entry in creators)
        if (pixivFollowingImageUrl(entry.creator.avatar?.toString())
            case final url?)
          (entry.access.key, url): entry,
    };
    return _PreparedWorkAvatars(
      keys: byImage.keys.toSet(),
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.passthrough,
        children: [
          child,
          for (final entry in byImage.entries)
            Positioned(
              key: ValueKey(entry.key),
              left: 0,
              top: 0,
              child: Offstage(
                child: _WorkCreatorAvatar(
                  creator: entry.value.creator,
                  access: entry.value.access,
                  placeholder: const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreparedWorkAvatars extends InheritedWidget {
  const _PreparedWorkAvatars({required this.keys, required super.child});
  final Set<(ContentAccessKey, String)> keys;

  static bool contains(
    BuildContext context,
    ContentAccessKey key,
    String url,
  ) =>
      context
          .dependOnInheritedWidgetOfExactType<_PreparedWorkAvatars>()
          ?.keys
          .contains((key, url)) ??
      false;

  @override
  bool updateShouldNotify(_PreparedWorkAvatars oldWidget) =>
      !const SetEquality<(ContentAccessKey, String)>().equals(
        keys,
        oldWidget.keys,
      );
}

/// Only Pixiv Work rows opt in to the supplied, validated creator image.
Widget Function(String, Widget) pixivWorkCreatorAvatarBuilder({
  required List<CreatorRef> creators,
  required ContentAccessContext? access,
}) =>
    (name, placeholder) => _WorkCreatorAvatar(
      creator: creators.firstWhereOrNull(
        (creator) => creator.displayName == name,
      ),
      access: access,
      placeholder: placeholder,
    );

class _WorkCreatorAvatar extends StatelessWidget {
  const _WorkCreatorAvatar({
    required this.creator,
    required this.access,
    required this.placeholder,
  });

  final CreatorRef? creator;
  final ContentAccessContext? access;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    final url = pixivFollowingImageUrl(creator?.avatar?.toString());
    final image = switch (access?.config?.auth) {
      final config?
          when config.booruType == BooruType.pixiv &&
              url != null &&
              (NavigationActivity.of(context) &&
                      TickerMode.valuesOf(context).enabled ||
                  _PreparedWorkAvatars.contains(context, access!.key, url)) =>
        CurrentBooruConfigScope(
          config: access!.config!,
          accessKey: access!.key,
          requireAccess: true,
          child: BooruImage(
            key: ValueKey((access!.key, config, url)),
            config: config,
            imageUrl: url,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.zero,
            placeholderWidget: placeholder,
            errorWidget: placeholder,
          ),
        ),
      _ => placeholder,
    };
    return SizedBox.square(
      dimension: 40,
      child: ClipOval(child: image),
    );
  }
}
