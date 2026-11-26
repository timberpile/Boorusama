import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/configs/listing/types.dart';
import '../../../core/configs/manage/providers.dart';
import '../../../core/content/capabilities.dart';
import '../../../core/content/types.dart';
import '../../../core/navigation/destination_activity.dart';
import '../../../core/posts/favorites/src/widgets/favorite_post_button.dart';
import '../../../core/posts/favorites/src/widgets/quick_favorite_button.dart';
import '../../../core/posts/favorites/types.dart';
import '../../../core/widgets/adaptive_button_row.dart';
import 'account.dart';
import 'cache.dart';

final nhentaiFavoritesRevisionProvider = NotifierProvider.autoDispose
    .family<NhentaiFavoritesRevision, int, ContentAccessKey>(
      NhentaiFavoritesRevision.new,
    );

class NhentaiFavoritesRevision
    extends AutoDisposeFamilyNotifier<int, ContentAccessKey> {
  @override
  int build(ContentAccessKey key) => 0;

  void changed() => state++;
}

final _favoriteWriterProvider = Provider.autoDispose
    .family<
      Future<bool> Function(
        NhentaiFavoriteCache cache,
        int id,
        bool favorited,
      )?,
      ContentAccessKey
    >(
      (ref, access) {
        final client = ref.watch(nhentaiAccountClientProvider(access));
        if (client == null) return null;
        final token = CancelToken();
        ref.onDispose(token.cancel);
        return (cache, id, favorited) async {
          // The write stays owned by this account when the card scrolls away.
          final lease = ref.keepAlive();
          var acknowledged = false;
          try {
            final confirmed = await cache.setFavorite(
              id,
              favorited,
              confirm: () async {
                final actual = await client.setFavorite(
                  id,
                  favorited,
                  cancelToken: token,
                );
                if (token.isCancelled) return false;
                if (actual != favorited) {
                  throw FavoriteActionFailure.unconfirmed;
                }
                return acknowledged = true;
              },
            );
            if (token.isCancelled) return false;
            if (confirmed && acknowledged) {
              ref
                  .read(nhentaiFavoritesRevisionProvider(access).notifier)
                  .changed();
            }
            return confirmed;
          } finally {
            lease.close();
          }
        };
      },
      dependencies: [nhentaiAccountClientProvider],
    );

class NhentaiGalleryQuickFavorite extends ConsumerWidget {
  const NhentaiGalleryQuickFavorite({
    required this.access,
    required this.galleryId,
    super.key,
  });

  final ContentAccessContext access;
  final int galleryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = access.config?.auth;
    final profileId = access.key.profileId;
    if (profileId == null || auth == null || !isNhentaiApiKey(auth.apiKey)) {
      return const SizedBox.shrink();
    }
    final enabled = ref.watch(
      booruConfigProvider.select(
        (profiles) => profiles.any(
          (profile) =>
              profile.id == profileId &&
              profile.auth == auth &&
              profile.thumbnailActions.actions.contains(
                ThumbnailAction.defaultAction,
              ),
        ),
      ),
    );
    if (!enabled) return const SizedBox.shrink();
    return NhentaiFavoriteControl._thumbnail(
      key: ValueKey((access.key, galleryId)),
      access: access,
      galleryId: galleryId,
    );
  }
}

class NhentaiFavoriteControl extends ConsumerWidget {
  const NhentaiFavoriteControl({
    required this.access,
    required this.galleryId,
    this.isOwnerCurrent,
    this.builder,
    super.key,
  }) : _compact = false;

  const NhentaiFavoriteControl._thumbnail({
    required this.access,
    required this.galleryId,
    super.key,
  }) : _compact = true,
       isOwnerCurrent = null,
       builder = null;

  final ContentAccessContext access;
  final int galleryId;
  final bool Function()? isOwnerCurrent;
  final FavoriteActionRowBuilder? builder;
  final bool _compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool current() =>
        context.mounted &&
        NavigationActivity.of(context) &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        (isOwnerCurrent?.call() ?? true);
    Widget empty() =>
        builder?.call(context, const []) ?? const SizedBox.shrink();
    if (!current() ||
        ref.watch(nhentaiAccountClientProvider(access.key)) == null) {
      return empty();
    }
    final provider = nhentaiFavoriteCacheProvider(nhentaiFavoriteOwner(access));
    final (selected, pending) = ref.watch(
      provider.select(
        (state) =>
            (state.ids.contains(galleryId), state.pending.contains(galleryId)),
      ),
    );
    final label = selected
        ? context.t.post.action.unfavorite
        : context.t.post.action.favorite;
    Future<void> change(bool favorited) async {
      if (!current()) throw FavoriteActionFailure.unconfirmed;
      final writer = ref.read(_favoriteWriterProvider(access.key));
      if (writer == null ||
          !await writer(ref.read(provider.notifier), galleryId, favorited)) {
        throw FavoriteActionFailure.unconfirmed;
      }
    }

    Future<void> activate() async {
      try {
        await change(!selected);
      } catch (_) {
        if (context.mounted && current()) {
          Kurumi.showErrorToast(
            context,
            context.t.nhentai.favorite_failed,
          );
        }
      }
    }

    if (_compact) {
      return KurumiTooltip(
        message: label,
        child: QuickFavoriteButton(
          isFaved: selected,
          isCurrent: current,
          controlled: true,
          enabled: !pending,
          onFavToggle: (favorited) async {
            try {
              await change(favorited);
            } on DioException {
              rethrow;
            } catch (_) {
              throw FavoriteActionFailure.unconfirmed;
            }
          },
        ),
      );
    }

    return _button(
      context,
      label: label,
      selected: selected,
      onPressed: pending ? null : activate,
    );
  }

  Widget _button(
    BuildContext context, {
    required String label,
    required bool selected,
    Future<void> Function()? onPressed,
  }) {
    final button = FavoritePostButton(
      tooltip: label,
      isFaved: selected,
      isAuthorized: true,
      enabled: onPressed != null,
      addFavorite: onPressed ?? _noop,
      removeFavorite: onPressed ?? _noop,
    );
    final action = button.action(context);
    return builder?.call(context, [
          ButtonData(
            required: true,
            widget: button,
            title: label,
            icon: Icon(Symbols.favorite, fill: selected ? 1 : 0, size: 20),
            onTap: action,
            enabled: action != null,
          ),
        ]) ??
        button;
  }
}

Future<void> _noop() async {}
