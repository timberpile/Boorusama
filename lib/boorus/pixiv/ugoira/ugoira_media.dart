import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/content_media_access.dart';
import '../../../core/posts/details/src/types/viewer_entry.dart';
import '../posts/types.dart';
import 'ugoira_player.dart';
import 'ugoira_preparation.dart';

Widget buildPixivUgoiraMedia({
  required Post post,
  required BooruConfig config,
  required bool active,
  required Widget poster,
}) {
  final illustId = pixivUgoiraIllustId(post);
  if (illustId == null || config.anonymousReadScope != null) {
    return poster;
  }
  return _PixivUgoiraMedia(
    key: ValueKey(illustId),
    post: post,
    config: config,
    active: active,
    poster: poster,
  );
}

int? pixivUgoiraIllustId(Post? post) => switch (post?.pixivData) {
  PixivPostData(isUgoira: true, isRestricted: false, :final illustId)
      when illustId > 0 =>
    illustId,
  _ => null,
};

PixivUgoiraRequest? watchPixivUgoiraRequest(
  WidgetRef ref,
  Post post,
  ContentAccessContext? access,
) {
  final illustId = pixivUgoiraIllustId(post);
  final config = access?.config;
  if (illustId == null ||
      config == null ||
      access!.key.profileId != config.id) {
    return null;
  }
  final allowed = watchContentMediaAccess(
    ref,
    config.auth,
    key: access.key,
    post: post,
  ).allowed;
  return allowed ? (access: access.key, illustId: illustId) : null;
}

class _PixivUgoiraMedia extends ConsumerStatefulWidget {
  const _PixivUgoiraMedia({
    required super.key,
    required this.post,
    required this.config,
    required this.active,
    required this.poster,
  });

  final Post post;
  final BooruConfig config;
  final bool active;
  final Widget poster;

  @override
  ConsumerState<_PixivUgoiraMedia> createState() => _PixivUgoiraMediaState();
}

class _PixivUgoiraMediaState extends ConsumerState<_PixivUgoiraMedia>
    with WidgetsBindingObserver {
  late final ViewerSourceBinding _binding;
  late bool _foreground;

  @override
  void initState() {
    super.initState();
    // Pin the viewer's actor before activation, even for an offscreen entry.
    _binding = ViewerSourceBinding(widget.config);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground != _foreground) setState(() => _foreground = foreground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  PixivUgoiraRequest? _activeRequest() {
    if (!_foreground ||
        !widget.active ||
        _binding.resolve([widget.config]) == null) {
      return null;
    }

    final scoped = ref.watch(currentContentAccessKeyProvider);
    final id = widget.config.id;
    final hint = widget.post.origin.profileIdHint;
    if (scoped == null && hint != null && hint != id) return null;
    final access = scoped == null
        ? ref.watch(contentProfileAccessProvider(id))
        : ref.watch(contentAccessContextProvider(scoped));
    if (access?.config?.id != id ||
        access?.config?.auth != widget.config.auth) {
      return null;
    }
    return watchPixivUgoiraRequest(ref, widget.post, access);
  }

  @override
  Widget build(BuildContext context) {
    final request = _activeRequest();
    final preparation = request == null
        ? null
        : ref.watch(pixivUgoiraPreparationProvider(request));
    return PixivUgoiraPlayer(
      active: request != null,
      prepared: preparation?.isLoading == false
          ? preparation?.asData?.value
          : null,
      downloadProgress: request != null && (preparation?.isLoading ?? false)
          ? ref.watch(pixivUgoiraDownloadProgressProvider(request))
          : null,
      failed: preparation?.hasError ?? false,
      onRetry: request == null ? null : () => retryPixivUgoira(ref, request),
      poster: widget.poster,
    );
  }
}
