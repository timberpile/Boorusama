import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../config_widgets/website_logo.dart';
import '../../configs/config/types.dart';
import '../../configs/create/src/types/edit_booru_config_id.dart';
import '../../configs/manage/providers.dart';
import '../../configs/manage/widgets.dart';
import '../../router.dart';
import '../../search/search/src/pages/search_page.dart';
import '../../search/search/src/routes/params.dart';
import 'boorusama_search_link.dart';

typedef LinkedSearchBuilder = Widget Function(
  BuildContext context,
  SearchParams params,
  BooruConfig profile,
);

/// Resolves the receiver's local profile without switching the active profile.
class BoorusamaSearchLinkPage extends ConsumerStatefulWidget {
  const BoorusamaSearchLinkPage({
    required this.uri,
    this.searchBuilder = _buildSearch,
    super.key,
  });

  final String uri;
  final LinkedSearchBuilder searchBuilder;

  static Widget _buildSearch(
    BuildContext context,
    SearchParams params,
    BooruConfig profile,
  ) => CurrentBooruConfigScope(
    config: profile,
    child: InheritedInitialSearchQuery(
      params: params,
      child: const SearchPage(),
    ),
  );

  @override
  ConsumerState<BoorusamaSearchLinkPage> createState() =>
      _BoorusamaSearchLinkPageState();
}

class _BoorusamaSearchLinkPageState
    extends ConsumerState<BoorusamaSearchLinkPage> {
  String? _selectedId;
  var _addingProfile = false;

  @override
  void didUpdateWidget(BoorusamaSearchLinkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _selectedId = null;
      _addingProfile = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = BoorusamaSearchLink.tryParse(widget.uri);
    if (link == null) return _message(context.t.search.app_link.invalid);
    final matches = link.matchingProfiles(ref.watch(booruConfigProvider));

    if (_addingProfile) {
      return _frame(const Center(child: CircularProgressIndicator()));
    }
    if (matches.isEmpty) {
      return _message(
        context.t.search.app_link.missing_profile,
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
    if (selected != null) {
      return widget.searchBuilder(context, link.searchParams, selected);
    }
    return _frame(
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.t.search.app_link.select_profile,
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

  Future<void> _addProfile(BoorusamaSearchLink link) async {
    final originalUri = widget.uri;
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
      if (mounted && widget.uri == originalUri) {
        setState(() => _addingProfile = false);
      }
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
        context.t.search.app_link.open,
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
