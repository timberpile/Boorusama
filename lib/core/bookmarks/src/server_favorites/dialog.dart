import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../config_widgets/website_logo.dart';
import '../../../configs/config/types.dart';
import '../../../navigation/navigation_catalog_provider.dart';
import '../providers/bookmark_provider.dart';
import '../widgets/bookmark_group_label.dart';
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
      barrierDismissible: false,
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
  String? _expandedProfile;
  var _showUnavailable = false;
  var _saving = false;
  var _confirmingClose = false;
  ServerFavoriteProblem? _problem;

  bool get _dirty => _baseline != null && _draft != _baseline;

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
    if (library == null || !library.localGroupIds.contains(id)) {
      return t.group_unavailable;
    }
    final group = library.groupsById[id]!;
    return [
      ...library.groupTree
          .ancestors(group.id)
          .map((ancestor) => ancestor.displayName(context)),
      group.displayName(context),
    ].join(' / ');
  }

  String _destination(String id) {
    final t = context.t.bookmark.server_favorites;
    final target = _draft.targetFor(id);
    return switch (target.mode) {
      ServerFavoriteTargetMode.inherit => t.inherited_group,
      ServerFavoriteTargetMode.none => t.disabled,
      ServerFavoriteTargetMode.group => _groupLabel(target.groupId),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.bookmark.server_favorites;
    final settings = ref.watch(serverFavoriteSettingsProvider);
    final library = ref.watch(bookmarkLibraryProvider);
    final profiles = ref.watch(navigationProfilesProvider);
    final progress = ref.watch(serverFavoriteFetchProvider);
    final batchProgress = ref
        .read(serverFavoriteFetchProvider.notifier)
        .batchProgress;
    if (settings.valueOrNull case final value? when _baseline == null) {
      _load(value, profiles);
    }
    final baseline = _baseline;
    final current = settings.valueOrNull;
    final accountsChanged =
        baseline != null && !serverFavoriteAccountsMatch(_accounts, profiles);
    final assignmentsChanged =
        baseline != null &&
        current != null &&
        !_saving &&
        !baseline.hasSameAssignments(current);
    final ready =
        !_saving &&
        !accountsChanged &&
        !assignmentsChanged &&
        settings.hasValue;
    final running = progress.values.any((p) => p.running);
    final canEdit = ready && !running && library.hasValue;
    final available = <BooruConfig>[];
    final unavailable = <(BooruConfig, ServerFavoriteProblem)>[];
    for (final profile in profiles) {
      final problem = ref.watch(
        serverFavoriteAvailabilityProvider(profile.auth),
      );
      if (problem == null) {
        available.add(profile);
      } else {
        unavailable.add((profile, problem));
      }
    }

    final sessions = <String, ServerFavoriteSession>{};
    if (_baseline case final saved? when ready && !_dirty) {
      for (final profile in available) {
        final groupId = saved.resolve(profile.id);
        if (groupId != null &&
            (library.valueOrNull?.localGroupIds.contains(groupId) ?? false)) {
          sessions[profile.id] = ServerFavoriteSession(profile, groupId);
        }
      }
    }
    final problem = switch ((accountsChanged, assignmentsChanged)) {
      (true, _) => ServerFavoriteProblem.accountChanged,
      (_, true) => ServerFavoriteProblem.targetChanged,
      _ => _problem,
    };
    final closeLabel = MaterialLocalizations.of(context).closeButtonLabel;
    final style = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: KurumiDismissible(
        onDismiss: () => unawaited(_close()),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: KurumiDialog(
            width: 480,
            screenInset: 12,
            dismissible: false,
            semanticLabel: t.title,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ServerFavoritesTitle(
                    title: t.title,
                    onInfo: () => unawaited(
                      _showMessage(title: t.about, message: t.help),
                    ),
                    onClose: _saving ? null : _close,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      key: const ValueKey('server-favorites-content'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_baseline != null)
                            ListTile(
                              key: const ValueKey('server-favorites-global'),
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.bookmark_outline),
                              title: Text(
                                t.default_group,
                                style: style.labelLarge,
                              ),
                              subtitle: Text(
                                _groupLabel(_draft.globalGroupId),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.navigate_next),
                              onTap: canEdit ? () => _choose() : null,
                            ),
                          if (settings.isLoading || library.isLoading)
                            const LinearProgressIndicator(),
                          if (settings.hasError || library.hasError) ...[
                            Text(t.localFailure),
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      if (settings.hasError) {
                                        ref.invalidate(
                                          serverFavoriteSettingsProvider,
                                        );
                                      }
                                      if (library.hasError) {
                                        ref.invalidate(bookmarkLibraryProvider);
                                      }
                                    },
                              child: Text(context.t.generic.action.retry),
                            ),
                          ],
                          if (_baseline != null) ...[
                            const Divider(height: 16),
                            Text(
                              context.t.navigation.profiles,
                              style: style.titleSmall,
                            ),
                            for (final profile in available)
                              _profile(
                                profile,
                                canEdit: canEdit,
                                session: sessions[profile.id],
                                progress: progress[profile.id],
                              ),
                            if (unavailable.isNotEmpty) ...[
                              const Divider(height: 16),
                              Semantics(
                                expanded: _showUnavailable,
                                child: ListTile(
                                  key: const ValueKey(
                                    'server-favorites-unavailable',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    t.unavailable_profiles(
                                      count: unavailable.length,
                                    ),
                                  ),
                                  trailing: Icon(
                                    _showUnavailable
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  onTap: () => setState(
                                    () => _showUnavailable = !_showUnavailable,
                                  ),
                                ),
                              ),
                              if (_showUnavailable)
                                for (final (profile, reason)
                                    in unavailable) ...[
                                  _identity(
                                    profile,
                                    detail: _destination(profile.id),
                                    reason: serverFavoriteProblemText(
                                      context,
                                      reason,
                                    ),
                                  ),
                                  if (progress[profile.id] case final value?)
                                    _progress(profile.id, value),
                                ],
                            ],
                            const Divider(height: 16),
                            OutlinedButton.icon(
                              key: const ValueKey('server-favorites-fetch-all'),
                              onPressed: !running && sessions.isNotEmpty
                                  ? () => _fetchAll(sessions.values)
                                  : null,
                              icon: const Icon(Icons.download),
                              label: Text(t.fetch_all),
                            ),
                            if (batchProgress.any((p) => p.running))
                              _bulkProgress(batchProgress),
                            if (problem != null) ...[
                              const SizedBox(height: 8),
                              Text(serverFavoriteProblemText(context, problem)),
                              if (problem ==
                                      ServerFavoriteProblem.targetChanged ||
                                  problem ==
                                      ServerFavoriteProblem.accountChanged)
                                TextButton(
                                  onPressed: _saving || !settings.hasValue
                                      ? null
                                      : () => setState(
                                          () => _load(
                                            settings.requireValue,
                                            profiles,
                                          ),
                                        ),
                                  child: Text(t.reload_settings),
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('server-favorites-close'),
                          style: _footerStyle,
                          onPressed: _saving ? null : _close,
                          child: Text(closeLabel, textAlign: TextAlign.center),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('server-favorites-save'),
                          style: _footerStyle,
                          onPressed: ready && !running && _dirty ? _save : null,
                          child: Text(
                            context.t.generic.action.save,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _footerStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, 48)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
  );

  Widget _identity(
    BooruConfig profile, {
    required String detail,
    String? reason,
    Widget? trailing,
    VoidCallback? onTap,
  }) => ListTile(
    key: ValueKey('server-favorites-profile-${profile.id}'),
    contentPadding: EdgeInsets.zero,
    leading: SizedBox.square(
      dimension: 28,
      child: ConfigAwareWebsiteLogo.fromConfig(
        profile.auth,
        customIconUrl: profile.profileIcon?.url,
      ),
    ),
    title: Text(_name(profile), maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: reason == null
        ? Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis)
        : Text('$detail\n$reason'),
    trailing: trailing,
    onTap: onTap,
  );

  Widget _profile(
    BooruConfig profile, {
    required bool canEdit,
    required ServerFavoriteSession? session,
    required ServerFavoriteProgress? progress,
  }) {
    final t = context.t.bookmark.server_favorites;
    final id = profile.id;
    final expanded = _expandedProfile == id;
    final retry =
        progress?.status == ServerFavoriteFetchStatus.failed ||
        progress?.status == ServerFavoriteFetchStatus.cancelled;
    final name = _name(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: ValueKey('server-favorites-target-$id'),
          expanded: expanded,
          child: _identity(
            profile,
            detail: _destination(id),
            onTap: () =>
                setState(() => _expandedProfile = expanded ? null : id),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('server-favorites-fetch-$id'),
                  tooltip: retry
                      ? t.retry_profile(profile: name)
                      : t.fetch_profile(profile: name),
                  onPressed: session != null && progress?.running != true
                      ? () => _fetch(session)
                      : null,
                  icon: Icon(retry ? Icons.refresh : Icons.download),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (progress != null) _progress(id, progress),
        if (expanded)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: Column(
              key: ValueKey('server-favorites-mode-options-$id'),
              children: [
                for (final (mode, label) in [
                  (ServerFavoriteTargetMode.inherit, t.use_global),
                  (ServerFavoriteTargetMode.none, t.disabled),
                  (ServerFavoriteTargetMode.group, t.different_group),
                ])
                  ListTile(
                    key: ValueKey('server-favorites-mode-$id-${mode.name}'),
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: 4,
                      end: 4,
                    ),
                    title: Text(label),
                    leading: Icon(
                      mode == _draft.targetFor(id).mode
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    trailing: mode == ServerFavoriteTargetMode.group
                        ? const Icon(Icons.navigate_next)
                        : null,
                    selected: mode == _draft.targetFor(id).mode,
                    enabled: canEdit,
                    onTap: canEdit ? () => _setMode(id, mode) : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _progress(String id, ServerFavoriteProgress progress) {
    final t = context.t.bookmark.server_favorites;
    final counts = t.progress(pages: progress.pages, added: progress.added);
    final label = switch (progress.status) {
      ServerFavoriteFetchStatus.running =>
        progress.phase == ServerFavoriteFetchPhase.downloading
            ? t.download_progress(pages: progress.downloadedPages)
            : t.saving_progress(progress: counts),
      ServerFavoriteFetchStatus.completed => t.completed,
      ServerFavoriteFetchStatus.cancelled => t.cancelled,
      ServerFavoriteFetchStatus.failed => serverFavoriteProblemText(
        context,
        progress.problem ?? ServerFavoriteProblem.localFailure,
      ),
      ServerFavoriteFetchStatus.idle => counts,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress.running) const LinearProgressIndicator(),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (!progress.running && progress.pages > 0)
            Text(counts, style: Theme.of(context).textTheme.bodySmall),
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
        ],
      ),
    );
  }

  Widget _bulkProgress(Iterable<ServerFavoriteProgress> batch) {
    final t = context.t.bookmark.server_favorites;
    var finished = 0;
    var downloaded = 0;
    var saved = 0;
    var added = 0;
    for (final progress in batch) {
      if (!progress.running) finished++;
      downloaded += progress.downloadedPages;
      saved += progress.pages;
      added += progress.added;
    }
    return Column(
      key: const ValueKey('server-favorites-batch-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: finished / batch.length),
        Text(t.batch_progress(finished: finished, total: batch.length)),
        Text(
          t.batch_counts(downloaded: downloaded, saved: saved, added: added),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            key: const ValueKey('server-favorites-cancel-all'),
            onPressed: () =>
                ref.read(serverFavoriteFetchProvider.notifier).cancelAll(),
            child: Text(t.cancel_all),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showMessage({
    required String title,
    required String message,
    String? confirm,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => KurumiDialog(
      screenInset: 12,
      semanticLabel: title,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                confirm == null
                    ? MaterialLocalizations.of(context).closeButtonLabel
                    : context.t.generic.action.cancel,
              ),
            ),
            if (confirm != null)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirm),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _close() async {
    if (_saving || _confirmingClose) return;
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final t = context.t;
    _confirmingClose = true;
    final discard = await _showMessage(
      title: t.booru.unsaved_changes,
      message: t.bookmark.server_favorites.discard_question,
      confirm: t.booru.unsaved_changes_discard,
    );
    _confirmingClose = false;
    if (mounted && (discard ?? false)) Navigator.pop(context);
  }

  void _setMode(String id, ServerFavoriteTargetMode mode) {
    switch (mode) {
      case ServerFavoriteTargetMode.inherit:
        _setProfile(id, const ServerFavoriteTarget.inherit());
      case ServerFavoriteTargetMode.none:
        _setProfile(id, const ServerFavoriteTarget.none());
      case ServerFavoriteTargetMode.group:
        unawaited(_choose(profileId: id));
    }
  }

  void _setProfile(String id, ServerFavoriteTarget target) => setState(() {
    _draft = _draft.withProfile(id, target);
    _problem = null;
  });

  Future<void> _choose({String? profileId}) async {
    final globalId = _draft.globalGroupId;
    final target = await showServerFavoriteTargetPicker(
      context,
      allowNone: profileId == null,
      selected: profileId != null
          ? _draft.targetFor(profileId)
          : globalId == null
          ? const ServerFavoriteTarget.none()
          : ServerFavoriteTarget.group(globalId),
    );
    if (target == null || !mounted) return;
    if (profileId != null) {
      _setProfile(profileId, target);
    } else {
      setState(() {
        _draft = _draft.withGlobal(target.groupId);
        _problem = null;
      });
    }
  }

  Future<void> _save() async {
    final baseline = _baseline;
    if (baseline == null ||
        !_dirty ||
        _saving ||
        ref.read(serverFavoriteFetchProvider).values.any((p) => p.running)) {
      return;
    }
    final updated = _draft;
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      await ref
          .read(serverFavoriteSettingsProvider.notifier)
          .saveAll(
            profiles: _accounts,
            expected: baseline,
            updated: updated,
          );
      if (mounted) setState(() => _baseline = updated);
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

  void _fetch(ServerFavoriteSession session) {
    if (_dirty || _saving) return;
    unawaited(
      ref
          .read(serverFavoriteFetchProvider.notifier)
          .start(
            session.config.id,
            expectedSession: session,
          ),
    );
  }

  void _fetchAll(Iterable<ServerFavoriteSession> sessions) {
    if (_dirty ||
        _saving ||
        ref.read(serverFavoriteFetchProvider).values.any((p) => p.running)) {
      return;
    }
    unawaited(
      ref.read(serverFavoriteFetchProvider.notifier).startAll(sessions),
    );
  }
}

class _ServerFavoritesTitle extends StatelessWidget {
  const _ServerFavoritesTitle({
    required this.title,
    required this.onInfo,
    required this.onClose,
  });

  final String title;
  final VoidCallback onInfo;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: height,
            child: KurumiFittedText(Text(title, style: style)),
          ),
        ),
        IconButton(
          key: const ValueKey('server-favorites-info'),
          tooltip: context.t.profile.tabs.info,
          onPressed: onInfo,
          icon: const Icon(Icons.info_outline),
        ),
        IconButton(
          key: const ValueKey('server-favorites-header-close'),
          tooltip: MaterialLocalizations.of(context).closeButtonLabel,
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
