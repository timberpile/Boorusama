import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../config_widgets/website_logo.dart';
import '../../configs/config/types.dart';
import '../../configs/create/src/types/edit_booru_config_id.dart';
import '../../configs/manage/providers.dart';
import '../../content/anonymous_access_provider.dart';
import '../../content/types.dart';
import '../../router.dart';
import '../details/src/providers/viewer_source_access_provider.dart';
import '../details/src/types/viewer_entry.dart';
import '../details/src/widgets/mixed_post_details_page.dart';
import '../post/types.dart';
import 'boorusama_group_link.dart';

/// A portable address chooses one local actor once. Profile removal never
/// upgrades an open public route or silently lends it a different account.
class BoorusamaGroupLinkPage extends ConsumerStatefulWidget {
  const BoorusamaGroupLinkPage({required this.uri, super.key});
  final String uri;

  @override
  ConsumerState<BoorusamaGroupLinkPage> createState() =>
      _BoorusamaGroupLinkPageState();
}

class _BoorusamaGroupLinkPageState
    extends ConsumerState<BoorusamaGroupLinkPage> {
  ViewerSourceBinding? _binding;
  BooruConfig? _fallback;
  var _addingProfile = false;

  @override
  void didUpdateWidget(BoorusamaGroupLinkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _binding = null;
      _fallback = null;
      _addingProfile = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = BoorusamaGroupLink.tryParse(widget.uri);
    if (link == null) return _message(context.t.post.app_link.invalid);
    final reference = link.reference;
    final profiles = ref.watch(booruConfigProvider);
    if (_addingProfile)
      return _frame(const Center(child: CircularProgressIndicator()));
    final origin = PostOrigin.fromSource(
      booruType: reference.engine,
      booruId: 0,
      source: reference.site.toString(),
    );
    if (_binding == null) {
      final resolution = const PostOriginResolver().resolve(origin, profiles);
      switch (resolution) {
        case ResolvedPostOrigin(:final config):
          _bind(config);
        case AmbiguousPostOrigin():
          return _frame(
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.t.post.app_link.select_profile,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(reference.site.toString()),
                const SizedBox(height: 16),
                for (final profile in profiles.where(
                  (profile) =>
                      profile.auth.booruType == reference.engine &&
                      normalizePostSourceHost(profile.url) ==
                          reference.siteNamespace,
                ))
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
                    onTap: () => setState(() => _bind(profile)),
                  ),
              ],
            ),
          );
        case MissingPostOrigin():
          final publicSource = ref
              .watch(anonymousSourcePolicyProvider)
              .resolve(reference.engine, reference.site);
          if (publicSource == null) {
            return _message(
              context.t.post.app_link.missing_profile,
              site: reference.site.toString(),
              actions: [
                FilledButton.icon(
                  onPressed: () => _addProfile(reference),
                  icon: const Icon(Icons.add),
                  label: Text(context.t.booru.add_profile),
                ),
              ],
            );
          }
          _binding = ViewerSourceBinding.publicRead(origin);
      }
    }
    final access = ref.watch(viewerSourceAccessProvider(_binding!));
    _fallback ??= access?.config;
    // Loading policy is fail-closed. Keep the pinned binding through retries.
    if (_fallback == null) return _message(context.t.bookmark.pool_unavailable);
    return MixedPostDetailsPage(
      key: ValueKey(widget.uri),
      posts: const [],
      entries: [
        GroupViewerEntry(
          summary: ContentGroupSummary(reference: reference),
          source: _binding,
          occurrenceId: widget.uri,
        ),
      ],
      initialIndex: 0,
      initialThumbnailUrl: null,
      scrollController: null,
      disclaimer: null,
      fallbackConfig: _fallback,
    );
  }

  void _bind(BooruConfig config) {
    _binding = ViewerSourceBinding(config);
    _fallback = config;
  }

  Future<void> _addProfile(ContentReference reference) async {
    final uri = widget.uri;
    setState(() => _addingProfile = true);
    try {
      await GoRouter.of(context).push<void>(
        Uri(
          path: '/boorus/add',
          queryParameters: {
            ...EditBooruConfigId.newId(
              booruType: reference.engine,
              url: reference.site.toString(),
            ).toQueryParameters(),
            'setAsCurrent': 'false',
          },
        ).toString(),
      );
    } finally {
      if (mounted && widget.uri == uri) setState(() => _addingProfile = false);
    }
  }

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
