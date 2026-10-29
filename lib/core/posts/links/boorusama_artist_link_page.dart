import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../boorus/danbooru/artists/artist/widgets.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../configs/manage/widgets.dart';
import '../../configs/create/src/types/edit_booru_config_id.dart';
import '../../boorus/booru/types.dart';
import '../../router.dart';
import 'boorusama_artist_link.dart';
import 'link_file_labels.dart';

typedef LinkedArtistBuilder = Widget Function(
  BuildContext context,
  String name,
  BooruConfig profile,
);

class BoorusamaArtistLinkPage extends ConsumerStatefulWidget {
  const BoorusamaArtistLinkPage({
    required this.uri,
    this.artistBuilder = _artist,
    super.key,
  });
  final String uri;
  final LinkedArtistBuilder artistBuilder;

  static Widget _artist(
    BuildContext context,
    String name,
    BooruConfig profile,
  ) => DanbooruArtistPage(artistName: name);

  @override
  ConsumerState<BoorusamaArtistLinkPage> createState() =>
      _BoorusamaArtistLinkPageState();
}

class _BoorusamaArtistLinkPageState
    extends ConsumerState<BoorusamaArtistLinkPage> {
  String? _selectedId;
  var _adding = false;

  @override
  void didUpdateWidget(BoorusamaArtistLinkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _selectedId = null;
      _adding = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = BoorusamaArtistLink.tryParse(widget.uri);
    if (link == null) return _frame(Text(context.t.post.app_link.invalid));
    final matches = link.matchingProfiles(ref.watch(booruConfigProvider));
    if (_adding)
      return _frame(const Center(child: CircularProgressIndicator()));
    final selected =
        matches.where((profile) => profile.id == _selectedId).firstOrNull ??
        (matches.length == 1 ? matches.single : null);
    if (selected != null) {
      return CurrentBooruConfigScope(
        key: ValueKey((link.uri, selected.id, selected.auth)),
        config: selected,
        child: Builder(
          builder: (context) =>
              widget.artistBuilder(context, link.artistName, selected),
        ),
      );
    }
    return _frame(
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(link.artistName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SelectableText(link.site.toString()),
          const SizedBox(height: 16),
          Text(
            matches.isEmpty
                ? context.t.navigation.unavailable_profile
                : context.t.navigation.choose_profile,
          ),
          for (final profile in matches)
            ListTile(
              key: ValueKey(profile.id),
              title: Text(profile.name),
              subtitle: (profile.login?.isNotEmpty ?? false)
                  ? Text(profile.login!)
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _selectedId = profile.id),
            ),
          if (matches.isEmpty)
            FilledButton.icon(
              onPressed: () => _addProfile(link),
              icon: const Icon(Icons.add),
              label: Text(context.t.booru.add_profile),
            ),
        ],
      ),
    );
  }

  Future<void> _addProfile(BoorusamaArtistLink link) async {
    final uri = widget.uri;
    setState(() => _adding = true);
    try {
      await GoRouter.of(context).push<void>(
        Uri(
          path: '/boorus/add',
          queryParameters: {
            ...EditBooruConfigId.newId(
              booruType: BooruType.danbooru,
              url: link.site.toString(),
            ).toQueryParameters(),
            'setAsCurrent': 'false',
          },
        ).toString(),
      );
    } finally {
      if (mounted && widget.uri == uri) setState(() => _adding = false);
    }
  }

  Widget _frame(Widget body) => Scaffold(
    appBar: KurumiAppBar(
      title: Text(context.openLinkFileLabel),
      leading: IconButton(
        tooltip: context.t.generic.action.cancel,
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
