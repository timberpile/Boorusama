// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/navigation/destination_activity.dart';
import '../../../../../../core/navigation/navigation_controller.dart';
import '../../../../../../core/configs/manage/providers.dart';
import '../../../../../../core/boorus/booru/types.dart';
import '../../../../../../foundation/platform.dart';
import '../../../../../../foundation/loggers.dart';
import '../../../../../../core/router.dart';
import '../../../../../../core/posts/cross_profile_lookup/types.dart';
import '../../../../../../core/posts/shares/src/incoming_shared_text_source.dart';
import '../../../../../../foundation/url_launcher.dart';
import '../../../../configs/providers.dart';

class UploadToDanbooru extends ConsumerStatefulWidget {
  const UploadToDanbooru({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<UploadToDanbooru> createState() => _UploadToDanbooruState();
}

class _UploadToDanbooruState extends ConsumerState<UploadToDanbooru> {
  StreamSubscription<String>? _sharedMediaSubscription;
  IncomingSharedTextSource? _sharedTextSource;
  final _openArtworks = <String>{};

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Only support Android for now
    if (!ref.read(appPlatformProvider).isAndroid) return;

    final source = ref.read(incomingSharedTextSourceProvider);
    _sharedTextSource = source;
    _sharedMediaSubscription = source.texts.listen(
      _onSharedTextsReceived,
      onError: (Object error) => _reportFailure('receive_text', error),
    );

    // Initial delivery waits for the router to mount; the same artwork received
    // through the warm stream cannot open a second results page in the meantime.
    try {
      final initialText = await source.initialText();
      if (initialText != null && mounted) {
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) _onSharedTextsReceived(initialText);
      }
    } catch (error) {
      _reportFailure('read_initial_text', error);
    }
    // The initial plugin call also orders this after EventChannel subscription.
    // Release buffered native shares only after the launch share/router frame.
    if (mounted) {
      try {
        await source.resumeWarmDelivery();
      } catch (error) {
        _reportFailure('resume_text_delivery', error);
      }
    }
  }

  void _reportFailure(String operation, Object error) {
    if (!mounted) return;
    ref
        .read(loggerProvider)
        .warn('Shared Text', '$operation; error=${error.runtimeType}');
  }

  void _onSharedTextsReceived(String text) {
    if (!mounted || !NavigationActivity.of(context)) return;
    final artwork = PixivArtworkReference.parseSharedText(text);
    if (artwork != null) {
      unawaited(_openSharedArtwork(artwork));
      return;
    }
    final destination = ref
        .read(navigationControllerProvider.notifier)
        .binding
        ?.currentDestination;
    final owner = ref
        .read(booruConfigProvider)
        .where((c) => c.id == destination?.profileId)
        .firstOrNull;
    if (owner == null || owner.auth.booruType != BooruType.danbooru) return;
    final config = owner.auth;
    final loginDetails = ref.read(danbooruLoginDetailsProvider(config));
    final booruUrl = config.url;

    if (loginDetails.hasStrictSFW) return;

    final uri = Uri.tryParse(text);
    final isHttp = uri?.scheme == 'http' || uri?.scheme == 'https';

    if (uri != null && isHttp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !NavigationActivity.of(context)) return;

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Upload to Danbooru'.hc),
              content: Text(
                'Are you sure you want to upload to Danbooru?\n\n$text \n\nYou need to be logged in the browser to upload.'
                    .hc,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(context.t.generic.action.cancel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);

                    if (!ref
                        .read(booruConfigProvider)
                        .any((c) => c.id == owner.id && c.auth == config))
                      return;
                    final encodedUri = Uri.encodeFull(uri.toString());
                    final url = '${booruUrl}uploads/new?url=$encodedUri';
                    launchExternalUrlString(
                      url,
                      launcher: ref.read(externalUrlLauncherProvider),
                    );
                  },
                  child: Text(context.t.generic.action.ok),
                ),
              ],
            );
          },
        );
      });
    }
  }

  Future<void> _openSharedArtwork(PixivArtworkReference artwork) async {
    if (!_openArtworks.add(artwork.id)) return;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await ref.pushRoute<void>('/cross-profile-lookup', extra: artwork);
    } catch (error) {
      _reportFailure('open_artwork_lookup', error);
    } finally {
      _openArtworks.remove(artwork.id);
    }
  }

  @override
  void dispose() {
    final source = _sharedTextSource;
    if (source != null) {
      unawaited(
        source.pauseWarmDelivery().catchError(
          (Object error) => _reportFailure('pause_text_delivery', error),
        ),
      );
    }
    _sharedMediaSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
