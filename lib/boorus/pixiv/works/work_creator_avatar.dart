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

class _WorkCreatorAvatar extends StatefulWidget {
  const _WorkCreatorAvatar({
    required this.creator,
    required this.access,
    required this.placeholder,
  });

  final CreatorRef? creator;
  final ContentAccessContext? access;
  final Widget placeholder;

  @override
  State<_WorkCreatorAvatar> createState() => _WorkCreatorAvatarState();
}

class _WorkCreatorAvatarState extends State<_WorkCreatorAvatar> {
  ({ContentAccessContext access, String url})? _mountedImage;

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    final config = access?.config;
    final url = pixivFollowingImageUrl(widget.creator?.avatar?.toString());
    final mountedImage = _mountedImage;
    _mountedImage = null;
    var image = widget.placeholder;
    if (access != null &&
        config != null &&
        config.auth.booruType == BooruType.pixiv &&
        url != null) {
      final active =
          NavigationActivity.of(context) &&
          TickerMode.valuesOf(context).enabled;
      final prepared = _PreparedWorkAvatars.contains(context, access.key, url);
      // A popup can suspend input and preloading while the selected row
      // remains visible. Keep an existing image under the same authorization.
      final retained =
          NavigationActivity.selectionChromeOf(context) &&
          mountedImage != null &&
          mountedImage.url == url &&
          mountedImage.access.hasSameAuthorization(access);
      if (active || prepared || retained) {
        _mountedImage = (access: access, url: url);
        image = CurrentBooruConfigScope(
          config: config,
          accessKey: access.key,
          requireAccess: true,
          child: BooruImage(
            key: ValueKey((access.key, config.auth, url)),
            config: config.auth,
            imageUrl: url,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.zero,
            placeholderWidget: widget.placeholder,
            errorWidget: widget.placeholder,
          ),
        );
      }
    }
    return SizedBox.square(
      dimension: 40,
      child: ClipOval(child: image),
    );
  }
}
