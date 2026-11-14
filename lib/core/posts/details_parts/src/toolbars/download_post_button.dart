// Dart imports:
import 'dart:math';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../content/content_access_provider.dart';
import '../../../../content/content_media_access.dart';
import '../../../../downloads/downloader/providers.dart';
import '../../../../downloads/urls/providers.dart';
import '../../../../downloads/urls/types.dart';
import '../../../post/types.dart';

class DownloadPostButton extends ConsumerStatefulWidget {
  const DownloadPostButton({
    required this.post,
    super.key,
    this.small = false,
  });

  final Post post;
  final bool small;

  @override
  ConsumerState<DownloadPostButton> createState() => _DownloadPostButtonState();
}

class _DownloadPostButtonState extends ConsumerState<DownloadPostButton> {
  final _controller = AnchorController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watchConfigAuth;
    if (auth.anonymousReadScope != null) {
      return const SizedBox.shrink();
    }
    final access = watchContentMediaAccess(ref, auth, post: widget.post);
    if (!access.allowed) return const SizedBox.shrink();
    final key = access.key;
    bool current() =>
        key == null ||
        (mounted &&
            ref.read(currentContentAccessKeyProvider) == key &&
            ref.read(contentAccessContextProvider(key))?.config?.auth == auth &&
            (ref
                    .read(
                      contentPostVisibilityProvider((
                        access: key,
                        post: widget.post,
                      )),
                    )
                    .asData
                    ?.value ==
                true));
    final guard = key == null ? null : current;

    final notifier = ref.watch(
      downloadNotifierProvider(
        ref.watch(
          downloadNotifierParamsProvider((
            ref.watchConfigAuth,
            ref.watchConfigDownload,
          )),
        ),
      ).notifier,
    );
    final downloadSources = ref.watch(
      downloadSourceProvider(ref.watchConfigAuth),
    );
    final List<DownloadSource>? sources =
        downloadSources?.getDownloadSources(context, widget.post);
    final hasAlternatives = sources?.isNotEmpty ?? false;

    return _PopupMenuButton(
      enable: hasAlternatives,
      controller: _controller,
      items: [
        ...?sources?.map(
          (e) => KurumiPopupMenuItem(
            title: Text(e.name),
            onTap: () {
              notifier.download(
                widget.post,
                quality: e.quality,
                overrideUrl: e.url,
                isCurrent: guard,
              );
            },
          ),
        ),
      ],
      child: KurumiActionIconButton(
        tooltip: context.t.download.download,
        iconSize: widget.small ? 20 : 24,
        showDropdown: hasAlternatives,
        onPressed: () => notifier.download(widget.post, isCurrent: guard),
        onLongPress: hasAlternatives ? _controller.show : null,
        icon: const Icon(Symbols.download),
      ),
    );
  }
}

class _PopupMenuButton extends ConsumerWidget {
  const _PopupMenuButton({
    required this.items,
    required this.controller,
    required this.enable,
    required this.child,
  });

  final List<Widget> items;
  final Widget child;
  final AnchorController controller;
  final bool enable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enable) return child;

    return KurumiAnchor(
      controller: controller,
      overlayBuilder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(context.t.settings.download.quality),
            ),
            const SizedBox(width: 200, child: Divider()),
            Container(
              constraints: BoxConstraints(
                maxWidth: min(MediaQuery.widthOf(context), 200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}
