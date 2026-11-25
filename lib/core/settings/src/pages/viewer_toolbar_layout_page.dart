import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../config_widgets/website_logo.dart';
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/create/src/pages/unsaved_alert_dialog.dart';
import '../../../configs/manage/providers.dart';
import '../../../posts/details_parts/src/toolbars/viewer_toolbar_profile_actions.dart';
import '../types/viewer_toolbar_layout.dart';
import '../widgets/viewer_toolbar_editor.dart';

class ViewerToolbarLayoutPage extends ConsumerStatefulWidget {
  const ViewerToolbarLayoutPage({super.key});

  @override
  ConsumerState<ViewerToolbarLayoutPage> createState() =>
      _ViewerToolbarLayoutPageState();
}

class _ViewerToolbarLayoutPageState
    extends ConsumerState<ViewerToolbarLayoutPage> {
  BooruConfig? _draftProfile;
  ViewerToolbarLayout? _draft;
  String? _profileId;
  var _saving = false;
  var _failed = false;

  void _select(String id) => setState(() {
    _profileId = id;
    _draftProfile = null;
    _draft = null;
    _failed = false;
  });

  Future<void> _save(
    BooruConfig profile,
    ViewerToolbarLayout? layout, {
    String? selectAfter,
  }) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final saved = await ref
          .read(booruConfigProvider.notifier)
          .updateViewerToolbarLayout(
            profile: profile,
            layout: layout,
          );
      if (!mounted) return;
      if (saved == null) {
        setState(() => _failed = true);
      } else {
        _select(selectAfter ?? saved.id);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changeProfile(BooruConfig? editing, BooruConfig target) {
    if (_saving || editing?.id == target.id) return;
    final draft = _draft;
    if (editing == null || draft == null) {
      _select(target.id);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => UnsavedAlertDialog(
        onSave: () => _save(editing, draft, selectAfter: target.id),
        onDiscard: () => _select(target.id),
      ),
    );
  }

  Widget _icon(BooruConfig profile) => SizedBox.square(
    dimension: 24,
    child: ConfigAwareWebsiteLogo.fromConfig(
      profile.auth,
      width: 24,
      height: 24,
      customIconUrl: profile.profileIcon?.url,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings =
        context.t.booru.appearance.image_viewer_layout.toolbar_editor;
    final profiles = ref
        .watch(booruConfigProvider)
        .where(
          (profile) =>
              profile.anonymousReadScope == null &&
              supportsViewerToolbarLayout(profile.auth.booruType),
        )
        .toList();
    final preferredId =
        _profileId ?? (profiles.isEmpty ? null : ref.watchConfig.id);
    final profile =
        profiles.where((profile) => profile.id == preferredId).firstOrNull ??
        profiles.firstOrNull;
    final draftProfile = profile != null && _draftProfile?.id == profile.id
        ? _draftProfile
        : null;
    final draft = draftProfile == null ? null : _draft;
    final stored = profile?.viewerConfigs?.toolbarLayout;
    final native = profile == null
        ? null
        : ref.watch(viewerToolbarProfileLayoutProvider(profile));

    String label(BooruConfig profile) {
      if (profile.name.isEmpty) return profile.url;
      if (profiles
              .where((candidate) => candidate.name == profile.name)
              .length ==
          1) {
        return profile.name;
      }
      return '${profile.name} · ${profile.url}';
    }

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: KurumiAppBar(
          title: Text(context.t.post.detail.widgets.toolbar),
          actions: [
            IconButton(
              key: const Key('toolbar-apply'),
              tooltip: context.t.generic.action.apply,
              onPressed: !_saving && draftProfile != null && draft != null
                  ? () => _save(draftProfile, draft)
                  : null,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: profile == null || native == null
              ? Center(child: Text(strings.no_profiles))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: KurumiPopupMenuButton(
                        key: const Key('toolbar-profile-picker'),
                        semanticLabel: strings.edit_profile,
                        items: [
                          for (final candidate in profiles)
                            KurumiPopupMenuItem(
                              key: ValueKey('toolbar-profile-${candidate.id}'),
                              icon: _icon(candidate),
                              title: Text(label(candidate)),
                              trailing: candidate.id == profile.id
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () =>
                                  _changeProfile(draftProfile, candidate),
                            ),
                        ],
                        buttonBuilder: (context, open) => OutlinedButton(
                          onPressed: _saving ? null : open,
                          child: Row(
                            children: [
                              _icon(profile),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label(profile),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_saving) const LinearProgressIndicator(),
                    if (_failed)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          context.t.post.action.operation_failed,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Expanded(
                      child: IgnorePointer(
                        ignoring: _saving,
                        child: ViewerToolbarEditor(
                          key: ValueKey(profile.id),
                          layout: draft ?? stored ?? native,
                          availableActions: {...native.toolbar, ...native.more},
                          onChanged: (value) => setState(() {
                            _profileId = profile.id;
                            _draftProfile = draftProfile ?? profile;
                            _draft = value;
                          }),
                          footer: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: OutlinedButton.icon(
                              key: const Key('toolbar-reset'),
                              onPressed:
                                  _saving || (stored == null && draft == null)
                                  ? null
                                  : () => stored == null
                                        ? _select(profile.id)
                                        : _save(draftProfile ?? profile, null),
                              icon: const Icon(Icons.restart_alt),
                              label: Text(context.t.generic.action.reset),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
