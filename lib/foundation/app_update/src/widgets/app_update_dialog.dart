// Dart imports:
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

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  final _installer = const AndroidGitHubApkInstaller();
  CancelToken? _cancelToken;
  File? _apk;
  GitHubApkArtifact? _selectedArtifact;
  double? _progress;
  var _downloading = false;
  var _installing = false;
  var _permissionNeeded = false;
  _UpdateFailure? _failure;

  @override
  void dispose() {
    _cancelToken?.cancel('Update dialog closed');
    super.dispose();
  }

  bool get _canDownload =>
      ref.read(githubAndroidInstallationSupportedProvider) &&
      widget.status.githubBuildNumber != null &&
      widget.status.githubApks.isNotEmpty;

  Future<void> _download() async {
    if (_downloading) return;

    setState(() {
      _downloading = true;
      _failure = null;
      _progress = null;
      _apk = null;
      _selectedArtifact = null;
    });

    final token = CancelToken();
    _cancelToken = token;
    try {
      final abis = await _installer.supportedAbis();
      if (token.isCancelled) return;

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
      if (mounted && !token.isCancelled) setState(() => _apk = apk);
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

  Future<void> _install() async {
    final apk = _apk;
    final build = widget.status.githubBuildNumber;
    if (apk == null || build == null || _installing) return;
    setState(() {
      _installing = true;
      _failure = null;
    });
    try {
      final allowed = await _installer.canInstall();
      if (!mounted) return;
      if (!allowed) {
        setState(() => _permissionNeeded = true);
        return;
      }
      await _installer.install(
        apk,
        buildNumber: build,
        version: widget.status.storeVersion,
      );
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) setState(() => _failure = _UpdateFailure.install);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _openPermissionSettings() async {
    try {
      await _installer.openInstallSettings();
      if (mounted) setState(() => _permissionNeeded = false);
    } on Object {
      if (mounted) setState(() => _failure = _UpdateFailure.install);
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
                      onPressed: () => launchExternalUrlString(status.storeUrl),
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
                        launchExternalUrlString(status.storeUrl);
                        Navigator.of(context).pop();
                      },
                      child: Text(context.t.app_update.update),
                    )
                  else if (_apk == null)
                    FilledButton(
                      onPressed: _download,
                      child: Text(context.t.app_update.download_update),
                    )
                  else
                    FilledButton(
                      onPressed: _installing
                          ? null
                          : _permissionNeeded
                          ? _openPermissionSettings
                          : _install,
                      child: Text(
                        _permissionNeeded
                            ? context.t.app_update.allow_installs
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
