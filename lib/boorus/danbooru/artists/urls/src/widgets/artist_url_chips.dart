import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import '../../../../../../core/config_widgets/website_logo.dart';
import '../../../../../../core/posts/sources/types.dart';
import '../../../../../../foundation/url_launcher.dart';
import '../types/artist_url_presentation.dart';

// Branding belongs to the site, including links that aren't profile URLs.
const _brandIcons = <String, FaIconData>{
  'x.com': FontAwesomeIcons.xTwitter,
  'twitter.com': FontAwesomeIcons.xTwitter,
  'youtube.com': FontAwesomeIcons.youtube,
  'youtu.be': FontAwesomeIcons.youtube,
  'tiktok.com': FontAwesomeIcons.tiktok,
  'threads.net': FontAwesomeIcons.threads,
  'threads.com': FontAwesomeIcons.threads,
  'pixiv.net': FontAwesomeIcons.pixiv,
  'pixiv.me': FontAwesomeIcons.pixiv,
  'reddit.com': FontAwesomeIcons.redditAlien,
  'redd.it': FontAwesomeIcons.redditAlien,
  'patreon.com': FontAwesomeIcons.patreon,
  'facebook.com': FontAwesomeIcons.facebookF,
  'fb.com': FontAwesomeIcons.facebookF,
  'instagram.com': FontAwesomeIcons.instagram,
  'bsky.app': FontAwesomeIcons.bluesky,
  'tumblr.com': FontAwesomeIcons.tumblr,
  'deviantart.com': FontAwesomeIcons.deviantart,
  'artstation.com': FontAwesomeIcons.artstation,
};

FaIconData? _brandIconForUrl(String url) {
  final host = Uri.parse(url).host.toLowerCase();
  for (final entry in _brandIcons.entries) {
    if (host == entry.key || host.endsWith('.${entry.key}')) return entry.value;
  }
  return null;
}

class DanbooruArtistUrlChips extends ConsumerStatefulWidget {
  const DanbooruArtistUrlChips({
    required this.artistUrls,
    super.key,
    this.alignment,
    this.showLabels = false,
    this.singleRow = false,
    this.onOverflowChanged,
  });

  final List<String> artistUrls;
  final WrapAlignment? alignment;
  final bool showLabels;
  final bool singleRow;
  final ValueChanged<bool>? onOverflowChanged;

  @override
  ConsumerState<DanbooruArtistUrlChips> createState() => _ArtistUrlChipsState();
}

class _ArtistUrlChipsState extends ConsumerState<DanbooruArtistUrlChips> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = math.min<double>(
        280,
        constraints.maxWidth * (widget.singleRow ? .85 : 1),
      );
      final children = [
        for (final url in validArtistProfileUrls(widget.artistUrls))
          _chip(context, artistUrlPresentation(url)!, maxWidth),
      ];
      if (widget.singleRow) {
        return NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) {
              widget.onOverflowChanged?.call(
                notification.metrics.maxScrollExtent > 0,
              );
            }
            return false;
          },
          // The page already handles safe areas. Applying the system bottom
          // inset again would paint this inline scrollbar over the chip labels.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: false,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return Wrap(
        spacing: widget.showLabels ? 4 : 8,
        runSpacing: widget.showLabels ? 0 : 8,
        alignment: widget.alignment ?? WrapAlignment.center,
        children: children,
      );
    },
  );

  Widget _chip(
    BuildContext context,
    ArtistUrlPresentation social,
    double maxWidth,
  ) {
    final strings = context.t.artist_page;
    final account = switch (social.accountKind) {
      ArtistUrlAccountKind.userId => strings.social_user_id(id: social.account),
      ArtistUrlAccountKind.channelId => strings.social_channel_id(
        id: social.account,
      ),
      ArtistUrlAccountKind.name => social.account,
    };
    final brandIcon = _brandIconForUrl(social.url);
    final label = brandIcon != null
        ? account
        : account.isEmpty
        ? social.platformLabel
        : '${social.platformLabel} · $account';
    void open() => launchExternalUrlString(
      social.url,
      launcher: ref.read(externalUrlLauncherProvider),
    );
    return Tooltip(
      message: social.url,
      child: widget.showLabels
          ? ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Semantics(
                link: true,
                label: social.url,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: const VisualDensity(vertical: -1),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: Kurumi.themeOf(context).textTheme.labelSmall,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: open,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: SizedBox.square(
                          dimension: 16,
                          child: brandIcon != null
                              ? FaIcon(brandIcon, size: 16)
                              : ConfigAwareWebsiteLogo(
                                  url: social.url,
                                  customIconUrl: getFavicon(
                                    Uri.parse(social.url).origin,
                                  ),
                                  size: 16,
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                      if (label.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          : InkWell(
              onTap: open,
              child: ConfigAwareWebsiteLogo(url: social.url, size: 24),
            ),
    );
  }
}
