import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/types.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/images/booru_image.dart';
import '../../../core/navigation/destination_activity.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../client_provider.dart';
import '../favorites/control.dart';
import 'information.dart';
import 'mapper.dart';
import 'open.dart';
import 'source.dart';

final _randomGalleryProvider = FutureProvider.autoDispose
    .family<ContentGroupSummary, ContentAccessKey>(
      (ref, key) async {
        final token = CancelToken();
        ref.onDispose(token.cancel);
        final access = ref.watch(contentAccessContextProvider(key));
        final source = await ref.watch(
          contentGroupSourceStateProvider(key).future,
        );
        if (access == null || source is! NhentaiGallerySource) {
          throw StateError('Gallery source unavailable');
        }
        bool current() =>
            !token.isCancelled &&
            ref.read(contentAccessContextProvider(key)) != null;
        return runWithApiRequestContext(
          ApiRequestContext(
            cancelToken: token,
            replaySafety: ApiReplaySafety.safeRead,
            canStart: current,
            canAdmit: current,
            allowCooldownRetry: false,
          ),
          () async {
            final client = ref.read(nhentaiClientProvider(access.config!.auth));
            final id = await client.getRandomGalleryId(cancelToken: token);
            final gallery = await source.gallery(
              nhentaiGalleryReference(access, id),
            );
            final policy = await source.mediaPolicy();
            if (!current()) throw StateError('Gallery access changed');
            return nhentaiGalleryDetails(gallery, access, policy).summary;
          },
        );
      },
      dependencies: [
        contentAccessContextProvider,
        contentGroupSourceStateProvider,
      ],
    );

class NhentaiRandomPage extends ConsumerStatefulWidget {
  const NhentaiRandomPage({required this.config, super.key});
  final BooruConfig config;

  @override
  ConsumerState<NhentaiRandomPage> createState() => _NhentaiRandomPageState();
}

class _NhentaiRandomPageState extends ConsumerState<NhentaiRandomPage> {
  ContentAccessKey? _key;
  ContentGroupSummary? _current;
  var _requesting = true;
  var _openFirstResult = true;

  bool get _active =>
      NavigationActivity.of(context) &&
      (ModalRoute.isCurrentOf(context) ?? true);

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(contentProfileAccessProvider(widget.config.id));
    final key = access?.key;
    if (key != _key) {
      _key = key;
      _current = null;
      _requesting = true;
    }
    final active = _active;
    final provider = key == null ? null : _randomGalleryProvider(key);
    final result = provider != null && active && _requesting
        ? ref.watch(provider)
        : null;
    final failed = result != null && !result.isLoading && result.hasError;
    final loading = result != null && !failed;

    void shuffle() {
      if (provider == null || !_active || _key != key) return;
      if (_requesting) {
        final latest = ref.read(provider);
        if (latest.isLoading || !latest.hasError) return;
      }
      setState(() => _requesting = true);
      ref.invalidate(provider);
    }

    if (result case AsyncData(value: final summary, isLoading: false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_active ||
            !_requesting ||
            _key != key ||
            !identical(ref.read(provider!).asData?.value, summary) ||
            !_canOpen(access!)) {
          return;
        }
        final open = _openFirstResult;
        setState(() {
          _current = summary;
          _requesting = false;
          _openFirstResult = false;
        });
        if (open) openNhentaiGalleries(ref, access, [summary], 0);
      });
    }

    final summary = _current;
    final retry = failed
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.t.nhentai.random_unavailable,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: shuffle,
                  child: Text(context.t.generic.action.retry),
                ),
              ],
            ),
          )
        : null;
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text(context.t.nhentai.randomizer_title),
        actions: [
          IconButton(
            tooltip: context.t.nhentai.next_random,
            onPressed: access != null && active && !loading ? shuffle : null,
            icon: const Icon(Symbols.shuffle),
          ),
        ],
      ),
      body: switch ((access, summary)) {
        (null, _) => Center(
          child: Text(context.t.navigation.unavailable_profile),
        ),
        (_, null) => Center(
          child: retry ?? (loading ? const CircularProgressIndicator() : null),
        ),
        (final access?, final summary?) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: ValueKey((access.key, summary.reference)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox(
                          width: 320,
                          height: 344,
                          child: PoolGridItem(
                            category: context.t.content_viewer.gallery,
                            name: summary.title,
                            total: summary.memberCount,
                            showKindIcon: false,
                            image: switch (summary.cover) {
                              final cover? => BooruImage(
                                config: access.config!.auth,
                                imageUrl: cover.thumbnail.toString(),
                                fit: BoxFit.contain,
                              ),
                              _ => const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            },
                            trailingAction: NhentaiGalleryQuickFavorite(
                              access: access,
                              galleryId: nhentaiIdFromReference(
                                summary.reference,
                              ),
                            ),
                            onTap: () {
                              if (_requesting && !failed || !_canOpen(access)) {
                                return;
                              }
                              openNhentaiGalleries(ref, access, [summary], 0);
                            },
                          ),
                        ),
                      ),
                      if (loading) const LinearProgressIndicator(),
                      ?retry,
                      NhentaiGalleryTags(
                        tags: summary.previewTags,
                        access: access,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      },
    );
  }

  bool _canOpen(ContentAccessContext access) =>
      mounted &&
      _active &&
      (ref
              .read(contentAccessContextProvider(access.key))
              ?.hasSameAuthorization(access) ??
          false);
}
