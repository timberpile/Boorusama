import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../config_widgets/website_logo.dart';
import '../../configs/config/types.dart';
import '../../configs/create/src/types/edit_booru_config_id.dart';
import '../../configs/manage/providers.dart';
import '../../errors/types.dart';
import '../../router.dart';
import '../details/routes.dart';
import '../details/widgets.dart';
import '../post/types.dart';
import 'boorusama_post_link.dart';
import 'boorusama_artist_link_page.dart';
import 'boorusama_search_link_page.dart';
import 'linked_post_provider.dart';

typedef LinkedPostBuilder = Widget Function(
  BuildContext context,
  Post post,
  BooruConfig profile,
);

/// A route keeps the pending address alive while profile setup is on top of it.
/// It never changes the globally selected browsing profile.
class BoorusamaPostLinkPage extends ConsumerStatefulWidget {
  const BoorusamaPostLinkPage({
    required this.uri,
    this.postBuilder = _buildPost,
    super.key,
  });

  final String uri;
  final LinkedPostBuilder postBuilder;

  @override
  ConsumerState<BoorusamaPostLinkPage> createState() =>
      _BoorusamaPostLinkPageState();

  static Widget _buildPost(
    BuildContext context,
    Post post,
    BooruConfig profile,
  ) => InheritedDetailsContext<Post>(
    context: DetailsRouteContext<Post>(
      initialIndex: 0,
      posts: [post],
      scrollController: null,
      isDesktop: false,
      hero: false,
      initialThumbnailUrl: null,
      config: profile,
      useMixedViewer: true,
    ),
    child: const PayloadPostDetailsPage<Post>(),
  );
}

class _BoorusamaPostLinkPageState extends ConsumerState<BoorusamaPostLinkPage> {
  String? _selectedId;
  var _addingProfile = false;

  @override
  void didUpdateWidget(BoorusamaPostLinkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _selectedId = null;
      _addingProfile = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = BoorusamaPostLink.tryParse(widget.uri);
    if (link == null) return _message(context.t.post.app_link.invalid);
    final matches = link.matchingProfiles(ref.watch(booruConfigProvider));
    if (_addingProfile) return _loading();
    if (matches.isEmpty) {
      return _message(
        context.t.post.app_link.missing_profile,
        site: link.site.toString(),
        actions: [
          FilledButton.icon(
            onPressed: () => _addProfile(link),
            icon: const Icon(Icons.add),
            label: Text(context.t.booru.add_profile),
          ),
        ],
      );
    }
    final selected =
        matches.where((profile) => profile.id == _selectedId).firstOrNull ??
        (matches.length == 1 ? matches.single : null);
    if (selected == null) {
      return _frame(
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.t.post.app_link.select_profile,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              link.site.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final profile in matches)
              ListTile(
                key: ValueKey(profile.id),
                leading: ConfigAwareWebsiteLogo.fromConfig(
                  profile.auth,
                  width: 32,
                  height: 32,
                  customIconUrl: profile.profileIcon?.url,
                ),
                title: Text(
                  profile.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: (profile.login?.isNotEmpty ?? false)
                    ? Text(profile.login!)
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _selectedId = profile.id),
              ),
          ],
        ),
      );
    }
    final request = (link, selected);
    final result = ref.watch(linkedPostProvider(request));
    return result.when(
      skipLoadingOnRefresh: false,
      loading: _loading,
      error: (error, _) => _message(
        _errorMessage(error),
        actions: _retryActions(request, matches.length),
      ),
      data: (post) => post == null
          ? _message(
              context.t.post.app_link.not_found,
              actions: _retryActions(request, matches.length),
            )
          : widget.postBuilder(context, post, selected),
    );
  }

  List<Widget> _retryActions(
    (BoorusamaPostLink, BooruConfig) request,
    int count,
  ) => [
    FilledButton(
      onPressed: () => ref.invalidate(linkedPostProvider(request)),
      child: Text(context.t.post.action.retry),
    ),
    if (count > 1)
      TextButton(
        onPressed: () => setState(() => _selectedId = null),
        child: Text(context.t.post.app_link.change_profile),
      ),
  ];

  Future<void> _addProfile(BoorusamaPostLink link) async {
    final uri = widget.uri;
    setState(() => _addingProfile = true);
    try {
      await GoRouter.of(context).push<void>(
        Uri(
          path: '/boorus/add',
          queryParameters: {
            ...EditBooruConfigId.newId(
              booruType: link.booruType,
              url: link.site.toString(),
            ).toQueryParameters(),
            'setAsCurrent': 'false',
          },
        ).toString(),
      );
    } finally {
      if (mounted && widget.uri == uri) setState(() => _addingProfile = false);
    }
  }

  String _errorMessage(Object error) => switch (error) {
    ServerError(httpStatusCode: 404 || 410) =>
      context.t.post.app_link.not_found,
    final ServerError error => DefaultAppErrorTranslator().translateServerError(
      context,
      error,
    ),
    final AppError error => DefaultAppErrorTranslator().translateAppError(
      context,
      error,
    ),
    _ => context.t.post.app_link.load_failed,
  };

  Widget _loading() => _frame(const Center(child: CircularProgressIndicator()));

  Widget _message(
    String message, {
    String? site,
    List<Widget> actions = const [],
  }) => _frame(
    Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              if (site != null) ...[
                const SizedBox(height: 12),
                SelectableText(site, textAlign: TextAlign.center),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _frame(Widget body) => Scaffold(
    appBar: KurumiAppBar(
      title: Text(
        context.t.post.app_link.open,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: IconButton(
        tooltip: context.t.post.action.cancel,
        icon: const Icon(Icons.close),
        onPressed: () {
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else {
            router.go('/');
          }
        },
      ),
    ),
    body: SafeArea(child: body),
  );
}

GoRoute boorusamaPostLinkRoute() => GoRoute(
  path: BoorusamaPostLink.routePath.substring(1),
  builder: (context, state) => switch ((state.uri.scheme, state.uri.host)) {
    ('boorusama', 'artist') => BoorusamaArtistLinkPage(
      key: ValueKey(state.uri.toString()),
      uri: state.uri.toString(),
    ),
    ('boorusama', 'search') => BoorusamaSearchLinkPage(
      key: ValueKey(state.uri.toString()),
      uri: state.uri.toString(),
    ),
    _ => BoorusamaPostLinkPage(
      key: ValueKey(state.uri.toString()),
      uri: state.uri.toString(),
    ),
  },
);
