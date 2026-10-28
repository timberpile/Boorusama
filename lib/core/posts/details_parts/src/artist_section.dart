// Package imports:
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../foundation/html.dart';
import '../../../../foundation/url_launcher.dart';
import '../../../artists/types.dart';
import '../../../comments/types.dart';
import '../../sources/types.dart';
import 'source_link.dart';

enum TranlationState {
  original,
  translated,
}

class ArtistSection extends ConsumerStatefulWidget {
  const ArtistSection({
    required this.commentary,
    required this.artistTags,
    required this.source,
    this.inlineAction,
    this.onArtistTap,
    super.key,
  });

  final ArtistCommentary commentary;
  final Set<String> artistTags;
  final PostSource source;
  final Widget? inlineAction;
  final ValueChanged<String>? onArtistTap;

  @override
  ConsumerState<ArtistSection> createState() => _ArtistSectionState();
}

class _ArtistSectionState extends ConsumerState<ArtistSection> {
  late var display = widget.commentary.isTranslated
      ? TranlationState.translated
      : TranlationState.original;

  void onChanged(TranlationState state) {
    setState(() {
      display = state;
    });
  }

  ArtistCommentary get commentary => widget.commentary;
  Set<String> get artistTags =>
      widget.artistTags.where((tag) => tag.trim().isNotEmpty).toSet();

  @override
  Widget build(BuildContext context) {
    final url = widget.source.url;
    final uri = Uri.tryParse(url ?? '');
    final usableUrl =
        uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? url
        : null;
    return Container(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Wrap(
        children: [
          if (artistTags.isNotEmpty)
            _Link(
              commentary: commentary,
              display: display,
              artistTags: artistTags,
              url: usableUrl,
              inlineAction: widget.inlineAction,
              onArtistTap: widget.onArtistTap,
              onChanged: onChanged,
            ),
          KurumiAnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: commentary.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: AppHtml(
                      style: {
                        'body': Style(
                          whiteSpace: WhiteSpace.pre,
                          margin: Margins.zero,
                        ),
                        'h2': Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.only(top: 4, bottom: 8),
                        ),
                      },
                      data: getDescriptionText(display, commentary),
                      onLinkTap: (url, attributes, element) => url != null
                          ? launchExternalUrl(
                              Uri.parse(url),
                              launcher: ref.read(externalUrlLauncherProvider),
                            )
                          : null,
                    ),
                  ),
            crossFadeState: commentary.isEmpty
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 80),
          ),
        ],
      ),
    );
  }
}

String getDescriptionText(
  TranlationState currentState,
  ArtistCommentary commentary,
) {
  final titleTranslated = commentary.translatedTitle != ''
      ? '<h2>${commentary.translatedTitle}</h2>'
      : '';
  final titleOriginal = commentary.originalTitle != ''
      ? '<h2>${commentary.originalTitle}</h2>'
      : '';

  return parseTextToHtml(
    currentState == TranlationState.translated
        ? '$titleTranslated${commentary.translatedDescription}'
        : '$titleOriginal${commentary.originalDescription}',
  );
}

class _Link extends StatelessWidget {
  const _Link({
    required this.commentary,
    required this.display,
    required this.artistTags,
    required this.onChanged,
    this.inlineAction,
    this.onArtistTap,
    this.url,
  });

  final ArtistCommentary commentary;
  final TranlationState display;
  final Set<String> artistTags;
  final String? url;
  final void Function(TranlationState state) onChanged;
  final Widget? inlineAction;
  final ValueChanged<String>? onArtistTap;

  @override
  Widget build(BuildContext context) {
    return SourceLink(
      name: artistTags.first,
      title: Text(artistTags.join(' ')),
      url: url,
      avatarBuilder: onArtistTap == null
          ? null
          : (avatar) {
              final label = context.t.post.action.view_artist;
              if (artistTags.length == 1) {
                final artist = artistTags.single;
                return IconButton(
                  tooltip: '$label: $artist',
                  padding: const EdgeInsets.all(4),
                  iconSize: 40,
                  icon: avatar,
                  onPressed: () => onArtistTap!(artist),
                );
              }
              final artists = artistTags.toList()..sort();
              return Tooltip(
                message: label,
                child: KurumiPopupMenuButton(
                  semanticLabel: label,
                  maxWidth: 320,
                  items: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .5,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final artist in artists)
                              KurumiPopupMenuItem(
                                title: Text(artist),
                                onTap: () => onArtistTap!(artist),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(child: avatar),
                  ),
                ),
              );
            },
      actionBuilder: () {
        final actions = <Widget>[
          if (commentary.isTranslated)
            KurumiPopupMenuButton(
              icon: const Icon(Symbols.keyboard_arrow_down),
              iconPadding: EdgeInsets.zero,
              items: [
                switch (display) {
                  TranlationState.original => KurumiPopupMenuItem(
                    title: Text(context.t.post.detail.show_translated),
                    onTap: () => onChanged(TranlationState.translated),
                  ),
                  TranlationState.translated => KurumiPopupMenuItem(
                    title: Text(context.t.post.detail.show_original),
                    onTap: () => onChanged(TranlationState.original),
                  ),
                },
              ],
            ),
          ?inlineAction,
        ];

        return switch (actions) {
          [] => const SizedBox.shrink(),
          [final action] => action,
          _ => Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: actions,
          ),
        };
      },
    );
  }
}
