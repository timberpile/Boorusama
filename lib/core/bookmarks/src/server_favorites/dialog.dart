import 'dart:async';
import 'dart:math' as math;

import 'package:anchor_ui/anchor_ui.dart' show AnchorData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../config_widgets/website_logo.dart';
import '../../../configs/config/types.dart';
import '../../../groups/folder_tree.dart';
import '../../../navigation/navigation_catalog_provider.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark_group.dart';
import '../widgets/bookmark_group_label.dart';
import 'binding.dart';
import 'controller.dart';
import 'fetch_runner.dart';
import 'presentation.dart';
import 'settings_provider.dart';
import 'source.dart';
import 'target_picker.dart';
import 'target_settings.dart';

Future<void> showServerFavoritesDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (_) => const ServerFavoritesDialog(),
    );

class ServerFavoritesDialog extends ConsumerStatefulWidget {
  const ServerFavoritesDialog({super.key});

  @override
  ConsumerState<ServerFavoritesDialog> createState() =>
      _ServerFavoritesDialogState();
}

class _ServerFavoritesDialogState extends ConsumerState<ServerFavoritesDialog> {
  ServerFavoriteSettings? _baseline;
  late ServerFavoriteSettings _draft;
  List<BooruConfig> _accounts = const [];
  var _saving = false;
  ServerFavoriteProblem? _problem;

  void _load(ServerFavoriteSettings settings, List<BooruConfig> profiles) {
    _baseline = settings;
    _draft = settings;
    _accounts = List.of(profiles);
    _problem = null;
  }

  String _name(BooruConfig profile) => profile.name.isNotEmpty
      ? profile.name
      : Uri.tryParse(profile.url)?.host ?? profile.url;

  String _groupLabel(String? id) {
    final t = context.t.bookmark.server_favorites;
    if (id == null) return t.none;
    final library = ref.read(bookmarkLibraryProvider).valueOrNull;
    final group = library?.groupsById[id];
    if (group == null) return t.targetMissing;
    final path = FolderTree(library!.folders).path(group.folderId);
    return path.isEmpty
        ? group.displayName(context)
        : '$path / ${group.displayName(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.bookmark.server_favorites;
    final settings = ref.watch(serverFavoriteSettingsProvider);
    final library = ref.watch(bookmarkLibraryProvider);
    final profiles = ref.watch(navigationProfilesProvider);
    final progress = ref.watch(serverFavoriteFetchProvider);
    if (_baseline == null) {
      if (settings.valueOrNull case final value?) _load(value, profiles);
    }
    final changed =
        _baseline != null && !serverFavoriteAccountsMatch(_accounts, profiles);
    final running = progress.values.any((p) => p.running);
    final ready = !_saving && !changed && settings.hasValue;
    final enabled = ready && !running;
    final availability = {
      for (final profile in profiles)
        profile.id: ref.watch(serverFavoriteAvailabilityProvider(profile.auth)),
    };
    final available = profiles
        .where((p) => availability[p.id] == null)
        .toList();
    final unavailable = profiles
        .where((p) => availability[p.id] != null)
        .toList();
    final configured = _baseline == null
        ? <BooruConfig>[]
        : available
              .where(
                (profile) =>
                    _draft.resolve(profile.id) != null &&
                    (library.valueOrNull?.groupsById.containsKey(
                          _draft.resolve(profile.id),
                        ) ??
                        false),
              )
              .toList();
    final problem = changed ? ServerFavoriteProblem.accountChanged : _problem;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: _ServerFavoritesTitle(title: t.title, onInfo: _showInfo),
      content: SizedBox(
        width: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.description),
            const SizedBox(height: 12),
            if (settings.isLoading || library.isLoading)
              const LinearProgressIndicator(),
            if (settings.hasError || library.hasError) ...[
              Text(t.localFailure),
              TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        if (settings.hasError) {
                          ref.invalidate(serverFavoriteSettingsProvider);
                        }
                        if (library.hasError) {
                          ref.invalidate(bookmarkLibraryProvider);
                        }
                      },
                child: Text(context.t.generic.action.retry),
              ),
            ],
            if (_baseline != null) ...[
              _targetField(
                key: const ValueKey('server-favorites-global'),
                label: t.default_group,
                value: _groupLabel(_draft.globalGroupId),
                onTap: enabled && library.hasValue ? () => _choose() : null,
              ),
              SwitchListTile(
                key: const ValueKey('server-favorites-ignore-bookmark-status'),
                contentPadding: EdgeInsets.zero,
                title: Text(t.ignore_bookmark_status),
                subtitle: Text(t.ignore_bookmark_status_description),
                value: _draft.ignoreBookmarkStatus,
                onChanged: enabled
                    ? (value) => setState(() {
                        _draft = _draft.withIgnoreBookmarkStatus(value);
                      })
                    : null,
              ),
              _fetchAction(
                key: const ValueKey('server-favorites-fetch-all'),
                label: t.save_fetch_all,
                onPressed: enabled && configured.isNotEmpty
                    ? () => _save(fetch: configured)
                    : null,
              ),
              if (running) ...[
                const LinearProgressIndicator(),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const ValueKey('server-favorites-cancel-all'),
                    onPressed: () => ref
                        .read(serverFavoriteFetchProvider.notifier)
                        .cancelAll(),
                    child: Text(t.cancel_all),
                  ),
                ),
              ],
              if (available.isNotEmpty) ...[
                const Divider(height: 24),
                _heading(context.t.navigation.profiles),
                for (final profile in available)
                  _profile(
                    profile,
                    enabled: enabled && library.hasValue,
                    progress: progress[profile.id],
                    // Independent jobs may use the saved assignments while
                    // editing remains locked until all jobs finish.
                    canFetch:
                        ready &&
                        library.hasValue &&
                        configured.contains(profile) &&
                        progress[profile.id]?.running != true &&
                        (!running || _draft == _baseline),
                  ),
              ],
              if (unavailable.isNotEmpty) ...[
                const Divider(height: 24),
                _heading(t.unavailable_profiles),
                for (final profile in unavailable)
                  _identity(
                    profile,
                    subtitle: serverFavoriteProblemText(
                      context,
                      availability[profile.id]!,
                    ),
                  ),
              ],
              if (problem != null) ...[
                const SizedBox(height: 8),
                Text(serverFavoriteProblemText(context, problem)),
                if (problem == ServerFavoriteProblem.targetChanged ||
                    problem == ServerFavoriteProblem.accountChanged)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(
                            () => _load(settings.requireValue, profiles),
                          ),
                    child: Text(t.reload_settings),
                  ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: 480,
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('server-favorites-close'),
                  style: _buttonStyle,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: _buttonLabel(
                    MaterialLocalizations.of(context).closeButtonLabel,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('server-favorites-save'),
                  style: _buttonStyle,
                  onPressed: enabled ? () => _save() : null,
                  child: _buttonLabel(context.t.generic.action.save),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _identity(BooruConfig profile, {String? subtitle}) => ListTile(
    key: ValueKey('server-favorites-profile-${profile.id}'),
    contentPadding: EdgeInsets.zero,
    leading: SizedBox(
      width: 32,
      height: 32,
      child: ConfigAwareWebsiteLogo.fromConfig(
        profile.auth,
        customIconUrl: profile.profileIcon?.url,
      ),
    ),
    title: Text(
      _name(profile),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: subtitle == null ? null : Text(subtitle),
  );

  Widget _profile(
    BooruConfig profile, {
    required bool enabled,
    required ServerFavoriteProgress? progress,
    required bool canFetch,
  }) {
    final t = context.t.bookmark.server_favorites;
    final target = _draft.targetFor(profile.id);
    final label = switch (target.mode) {
      ServerFavoriteTargetMode.inherit => t.inherited_group.replaceAll(
        '{group}',
        _groupLabel(_draft.globalGroupId),
      ),
      ServerFavoriteTargetMode.none => t.none,
      ServerFavoriteTargetMode.group => _groupLabel(target.groupId),
    };
    final missing =
        _draft.resolve(profile.id) != null &&
        !(ref
                .read(bookmarkLibraryProvider)
                .valueOrNull
                ?.groupsById
                .containsKey(_draft.resolve(profile.id)) ??
            false);
    final retry =
        progress?.status == ServerFavoriteFetchStatus.failed ||
        progress?.status == ServerFavoriteFetchStatus.cancelled;
    return Column(
      key: ValueKey('server-favorites-section-${profile.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _identity(profile),
        KurumiPopupMenuButton(
          key: ValueKey('server-favorites-target-${profile.id}'),
          enabled: enabled,
          maxWidth: 280,
          semanticLabel: '${_name(profile)}: ${t.bookmark_group}: $label',
          items: [
            Builder(
              builder: (context) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: _modeMenuHeight(context),
                ),
                child: SingleChildScrollView(
                  key: ValueKey('server-favorites-mode-options-${profile.id}'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (mode, text) in [
                        (ServerFavoriteTargetMode.inherit, t.use_global),
                        (ServerFavoriteTargetMode.none, t.none),
                        (ServerFavoriteTargetMode.group, t.different_group),
                      ])
                        KurumiPopupMenuItem(
                          key: ValueKey(
                            'server-favorites-mode-${profile.id}-${mode.name}',
                          ),
                          title: Text(text),
                          trailing: mode == target.mode
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            if (mode == ServerFavoriteTargetMode.group) {
                              unawaited(_choose(profileId: profile.id));
                            } else {
                              setState(() {
                                _draft = _draft.withProfile(
                                  profile.id,
                                  mode == ServerFavoriteTargetMode.inherit
                                      ? const ServerFavoriteTarget.inherit()
                                      : const ServerFavoriteTarget.none(),
                                );
                                _problem = null;
                              });
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          child: _targetField(
            label: t.bookmark_group,
            value: label,
            icon: Icons.arrow_drop_down,
          ),
        ),
        if (missing) Text(t.targetMissing),
        _fetchAction(
          key: ValueKey('server-favorites-fetch-${profile.id}'),
          label: retry ? t.retry : t.save_fetch,
          onPressed: canFetch ? () => _save(fetch: [profile]) : null,
          icon: retry ? Icons.refresh : Icons.download,
        ),
        if (progress != null) _progress(profile.id, progress),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _progress(String id, ServerFavoriteProgress progress) {
    final t = context.t.bookmark.server_favorites;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress.running) const LinearProgressIndicator(),
        Text(
          progress.phase == ServerFavoriteFetchPhase.downloading
              ? t.download_progress.replaceAll(
                  '{pages}',
                  '${progress.downloadedPages}',
                )
              : t.progress
                    .replaceAll('{pages}', '${progress.pages}')
                    .replaceAll('{added}', '${progress.added}'),
        ),
        if (progress.running)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: ValueKey('server-favorites-cancel-$id'),
              onPressed: () =>
                  ref.read(serverFavoriteFetchProvider.notifier).cancel(id),
              child: Text(context.t.generic.action.cancel),
            ),
          ),
        if (progress.problem case final problem?)
          Text(serverFavoriteProblemText(context, problem)),
        if (progress.status == ServerFavoriteFetchStatus.completed)
          Text(t.completed),
        if (progress.status == ServerFavoriteFetchStatus.cancelled)
          Text(t.cancelled),
      ],
    );
  }

  static const _buttonStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, 48)),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
  );

  double _modeMenuHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final bounds = AnchorData.of(context).geometry.childBounds;
    final top = media.padding.top + 12;
    final bottom =
        media.size.height -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        12;
    final above = bounds == null ? 0.0 : bounds.top - top;
    final below = bounds == null ? bottom - top : bottom - bounds.bottom;
    // Fit on one side of the field, allowing for the anchor gap and popup
    // padding. Whole-screen bounds can overflow next to a tall labeled field.
    return (math.max(above, below) - 4 - 16).clamp(0.0, 480.0);
  }

  Widget _targetField({
    Key? key,
    required String label,
    required String value,
    VoidCallback? onTap,
    IconData icon = Icons.chevron_right,
  }) => ListTile(
    key: key,
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: Theme.of(context).textTheme.labelMedium),
    subtitle: Text(
      value,
      style: Theme.of(context).textTheme.bodyLarge,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: Icon(icon),
    onTap: onTap,
  );

  Widget _fetchAction({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
    IconData icon = Icons.download,
  }) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton.icon(
      key: key,
      style: _buttonStyle,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );

  Widget _buttonLabel(String label) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(label, maxLines: 1, softWrap: false),
  );

  Widget _heading(String text) =>
      Text(text, style: Theme.of(context).textTheme.titleSmall);

  Future<void> _showInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(context.t.bookmark.server_favorites.about),
      content: Text(context.t.bookmark.server_favorites.help),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );

  Future<void> _choose({String? profileId}) async {
    final target = await showServerFavoriteTargetPicker(
      context,
      selected: profileId == null
          ? _draft.globalGroupId == null
                ? const ServerFavoriteTarget.none()
                : ServerFavoriteTarget.group(_draft.globalGroupId!)
          : _draft.targetFor(profileId),
    );
    if (target == null || !mounted) return;
    setState(() {
      _draft = profileId == null
          ? _draft.withGlobal(target.groupId)
          : _draft.withProfile(profileId, target);
      _problem = null;
    });
  }

  Future<void> _save({List<BooruConfig>? fetch}) async {
    final baseline = _baseline;
    if (baseline == null) return;
    final updated = _draft;
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      final newlyBound = updated.assignedGroupIds.difference(
        baseline.assignedGroupIds,
      );
      final snapshot = newlyBound.isNotEmpty || fetch != null
          ? await ref.read(bookmarkLibraryProvider.notifier).snapshotForExport()
          : null;
      final sessions = <ServerFavoriteSession>[];
      for (final profile in fetch ?? <BooruConfig>[]) {
        final groupId = updated.resolve(profile.id);
        if (groupId == null ||
            !(snapshot?.groupsById.containsKey(groupId) ?? false)) {
          throw const ServerFavoriteException(
            ServerFavoriteProblem.targetMissing,
          );
        }
        sessions.add(ServerFavoriteSession(profile, groupId));
      }
      final clears = snapshot == null
          ? <BookmarkGroup>[]
          : serverFavoriteGroupsToClear(baseline, updated, snapshot.groups);
      if (!mounted) return;
      if (clears.isNotEmpty) {
        final t = context.t.bookmark.server_favorites;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(t.clear_title),
            content: Text(
              t.clear_warning.replaceAll(
                '{groups}',
                clears.map((g) => _groupLabel(g.id)).join(', '),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.t.generic.action.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  fetch == null ? t.clear_confirm : t.clear_fetch_confirm,
                ),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      await ref
          .read(serverFavoriteSettingsProvider.notifier)
          .saveAll(
            profiles: _accounts,
            expected: baseline,
            updated: updated,
            confirmedClears: clears,
          );
      if (!mounted) return;
      if (fetch == null) {
        Navigator.of(context).pop();
        return;
      }
      // Further fetches and edits must compare against this successful save,
      // while the editor remains open to display progress and recovery actions.
      setState(() => _baseline = updated);
      if (sessions.isNotEmpty) {
        unawaited(
          ref.read(serverFavoriteFetchProvider.notifier).startAll(sessions),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _problem = error is ServerFavoriteException
              ? error.problem
              : ServerFavoriteProblem.localFailure,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Use the same fitting component and typography as toolbar titles, bounded to
/// one nominal line so this compact dialog does not gain a second title row.
class _ServerFavoritesTitle extends StatelessWidget {
  const _ServerFavoritesTitle({required this.title, required this.onInfo});
  final String title;
  final VoidCallback onInfo;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = DefaultTextStyle.of(context).style.merge(
      theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      maxLines: 1,
      textScaler: scaler,
      textDirection: Directionality.of(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return SizedBox(
      width: 480,
      height: height < 48 ? 48 : height,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: height,
              child: KurumiFittedText(
                Text(title, style: style),
                minimumWrappingFontSizeGain: 1.5,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('server-favorites-info'),
            tooltip: context.t.profile.tabs.info,
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }
}
