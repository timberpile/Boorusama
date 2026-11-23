// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../url_launcher.dart';
import '../android_github_apk_installer.dart';
import '../github_apk_artifact.dart';
import '../providers.dart';
import '../types/update_status.dart';

class AppUpdateDialog extends ConsumerStatefulWidget {
  const AppUpdateDialog({
    required this.status,
    super.key,
  });

  final UpdateAvailable status;

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

enum _UpdateFailure { download, unsupported, install }

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog>
    with WidgetsBindingObserver {
  final _installer = const AndroidGitHubApkInstaller();
  CancelToken? _cancelToken;
  File? _apk;
  GitHubApkArtifact? _selectedArtifact;
  double? _progress;
  var _downloading = false;
  var _installing = false;
  var _permissionNeeded = false;
  var _awaitingPermissionReturn = false;
  var _resumeInstallation = false;
  var _requestPermissionOnResume = false;
  AppLifecycleState? _lifecycleState;
  _UpdateFailure? _failure;

  @override
  void initState() {
    super.initState();
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelToken?.cancel('Update dialog closed');
    super.dispose();
  }

  bool get _isCurrent => mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  bool get _isForeground =>
      _lifecycleState == null || _lifecycleState == AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state != AppLifecycleState.resumed) return;
    if (_awaitingPermissionReturn) {
      _awaitingPermissionReturn = false;
      _resumeInstallation = true;
      // Returning without permission must not reopen Settings in a loop.
      _requestPermissionOnResume = false;
    }
    _resumeIfIdle();
  }

  void _resumeIfIdle() {
    if (!_isCurrent ||
        !_isForeground ||
        _downloading ||
        _installing ||
        !_resumeInstallation) {
      return;
    }
    final requestPermission = _requestPermissionOnResume;
    _resumeInstallation = false;
    unawaited(_install(requestPermission: requestPermission));
  }

  bool get _canDownload =>
      ref.read(githubAndroidInstallationSupportedProvider) &&
      widget.status.githubBuildNumber != null &&
      widget.status.githubApks.isNotEmpty;

  Future<void> _downloadAndInstall() async {
    if (_downloading || _installing) return;
    if (_apk == null) await _download();
    if (!_isCurrent || _apk == null) return;
    // Keep the verified APK if the download finishes while backgrounded.
    // Opening Android UI waits until this dialog is current and resumed.
    _resumeInstallation = true;
    _requestPermissionOnResume = true;
    _resumeIfIdle();
  }

  Future<void> _download() async {
    if (_downloading) return;

    setState(() {
      _downloading = true;
      _failure = null;
      _progress = null;
      _apk = null;
      _selectedArtifact = null;
      _permissionNeeded = false;
    });

    final token = CancelToken();
    _cancelToken = token;
    try {
      final abis = await _installer.supportedAbis();
      if (!_isCurrent || token.isCancelled) return;

      final artifact = GitHubApkArtifact.selectForAbis(
        widget.status.githubApks,
        abis,
      );
      if (artifact == null) {
        setState(() => _failure = _UpdateFailure.unsupported);
        return;
      }

      setState(() => _selectedArtifact = artifact);
      final apk = await ref
          .read(githubApkDownloaderProvider)
          .download(
            artifact,
            cancelToken: token,
            onProgress: (received, total) {
              if (!mounted || token.isCancelled) return;
              setState(() {
                _progress = (received / artifact.size).clamp(0.0, 1.0);
              });
            },
          );
      if (_isCurrent && !token.isCancelled) setState(() => _apk = apk);
    } on Object {
      if (mounted && !token.isCancelled) {
        setState(() => _failure = _UpdateFailure.download);
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _cancelToken = null;
        });
      }
    }
  }

  Future<void> _install({bool requestPermission = true}) async {
    final apk = _apk;
    final build = widget.status.githubBuildNumber;
    final artifact = _selectedArtifact;
    if (!_isCurrent ||
        !_isForeground ||
        apk == null ||
        build == null ||
        artifact == null ||
        _installing) {
      return;
    }
    _awaitingPermissionReturn = false;
    setState(() {
      _installing = true;
      _failure = null;
    });
    try {
      final allowed = await _installer.canInstall();
      if (!_isCurrent) return;
      if (!_isForeground) {
        // Permission lookup can complete after the app loses foreground.
        // Recheck permission on resume rather than using a stale result.
        _resumeInstallation = true;
        _requestPermissionOnResume = requestPermission;
        return;
      }
      setState(() => _permissionNeeded = !allowed);
      if (!allowed) {
        if (requestPermission) {
          _awaitingPermissionReturn = true;
          await _installer.openInstallSettings();
        }
        return;
      }
      await _installer.install(
        apk,
        buildNumber: artifact.androidVersionCode(build),
        version: widget.status.storeVersion,
      );
      if (mounted && _isCurrent) Navigator.of(context).pop();
    } on Object {
      _awaitingPermissionReturn = false;
      _resumeInstallation = false;
      if (mounted) setState(() => _failure = _UpdateFailure.install);
    } finally {
      if (mounted) {
        setState(() => _installing = false);
        // Settings can report resumed before its channel future completes,
        // and the app may have lost foreground again in the meantime.
        _resumeIfIdle();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final textTheme = Kurumi.themeOf(context).textTheme;
    final canDownload = _canDownload;

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.t.app_update.update_available,
                  style: textTheme.titleLarge,
                ),
              ),
              _VersionChangeVisualizedText(status: status),
              const Divider(thickness: 1.5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.t.app_update.whats_new,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: MarkdownBody(data: status.releaseNotes),
              ),
              if (_downloading) ...[
                const SizedBox(height: 8),
                if (_progress case final value?)
                  LinearProgressIndicator(value: value)
                else
                  const LinearProgressIndicator(),
                const SizedBox(height: 4),
                Text(
                  '${context.t.app_update.downloading} '
                  '${_selectedArtifact == null ? '' : '(${(_selectedArtifact!.size / 1048576).toStringAsFixed(1)} MiB)'}',
                  style: textTheme.bodySmall,
                ),
              ],
              if (_apk != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.t.app_update.verified),
                ),
              if (_permissionNeeded)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.t.app_update.allow_installs_detail),
                ),
              if (_failure case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    switch (error) {
                      _UpdateFailure.download =>
                        context.t.app_update.download_failed,
                      _UpdateFailure.unsupported =>
                        context.t.app_update.unsupported_apk,
                      _UpdateFailure.install =>
                        context.t.app_update.install_failed,
                    },
                    style: TextStyle(
                      color: Kurumi.themeOf(context).colorScheme.error,
                    ),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.t.app_update.later),
                  ),
                  if (Uri.tryParse(status.storeUrl)?.host == 'github.com')
                    TextButton(
                      onPressed: () => launchExternalUrlString(
                        status.storeUrl,
                        launcher: ref.read(externalUrlLauncherProvider),
                      ),
                      child: Text(context.t.app_update.open_github),
                    ),
                  if (_downloading)
                    TextButton(
                      onPressed: () => _cancelToken?.cancel('User cancelled'),
                      child: Text(context.t.generic.action.cancel),
                    )
                  else if (!canDownload)
                    FilledButton(
                      onPressed: () {
                        launchExternalUrlString(
                          status.storeUrl,
                          launcher: ref.read(externalUrlLauncherProvider),
                        );
                        Navigator.of(context).pop();
                      },
                      child: Text(context.t.app_update.update),
                    )
                  else
                    FilledButton(
                      key: const ValueKey('github-update-primary'),
                      onPressed: _installing ? null : _downloadAndInstall,
                      child: Text(
                        _apk == null
                            ? context.t.app_update.download_and_install
                            : context.t.app_update.install_update,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionChangeVisualizedText extends StatelessWidget {
  const _VersionChangeVisualizedText({
    required this.status,
  });

  final UpdateAvailable status;

  @override
  Widget build(BuildContext context) {
    final theme = Kurumi.themeOf(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: status.currentVersion,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.outline,
            ),
          ),
          const TextSpan(text: '  ➞  '),
          TextSpan(
            text: status.storeVersion,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
