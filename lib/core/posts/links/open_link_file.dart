import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../foundation/filesystem.dart';
import '../../../foundation/picker.dart';
import '../../router.dart';
import 'boorusama_link_file.dart';
import 'link_file_labels.dart';

/// A navigation action and fallback when messengers lose file associations.
/// Content validation, not the filename suffix, grants access.
class OpenLinkFileTile extends ConsumerStatefulWidget {
  const OpenLinkFileTile({this.enabled = true, this.onOpened, super.key});

  final bool enabled;
  final VoidCallback? onOpened;

  @override
  ConsumerState<OpenLinkFileTile> createState() => _OpenLinkFileTileState();
}

class _OpenLinkFileTileState extends ConsumerState<OpenLinkFileTile> {
  var _busy = false;

  Future<void> _pick() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    try {
      // Some messengers expose a generic MIME type or rename the attachment.
      final path = await ref.read(appFilePickerProvider).pickFile();
      if (path != null && mounted) {
        widget.onOpened?.call();
        await openBoorusamaLinkFile(ref, path);
      }
    } on Exception {
      if (mounted) await showInvalidLinkFile(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.file_open_outlined),
    title: Text(context.openLinkFileLabel),
    enabled: widget.enabled && !_busy,
    onTap: widget.enabled && !_busy ? _pick : null,
  );
}

/// Returns after validating and starting navigation, not after the post closes.
/// This lets another incoming file be handled while the app is already open.
Future<void> openBoorusamaLinkFile(
  WidgetRef ref,
  String path, {
  bool invalidDelivery = false,
}) async {
  try {
    if (invalidDelivery) throw const FormatException('Invalid link delivery');
    final document = await BoorusamaLinkFile.read(
      path,
      ref.read(appFileSystemProvider),
    );
    if (!ref.context.mounted) return;
    // The envelope only permits the existing, strict post/search parsers.
    final feedbackContext = ref
        .read(appNavigationProvider)
        .navigatorKey
        .currentContext;
    unawaited(
      ref.read(routerProvider).push<void>(document.uri.toString()).catchError(
        (Object _, StackTrace __) async {
          if (feedbackContext != null && feedbackContext.mounted) {
            await showInvalidLinkFile(feedbackContext);
          }
        },
      ),
    );
  } on Exception {
    if (ref.context.mounted) {
      // External listeners live above MaterialApp, so use its navigator context.
      final feedbackContext = ref
          .read(appNavigationProvider)
          .navigatorKey
          .currentContext;
      if (feedbackContext != null && feedbackContext.mounted) {
        await showInvalidLinkFile(feedbackContext);
      }
    }
  }
}

Future<void> showInvalidLinkFile(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.openLinkFileLabel),
    content: Text(context.t.post.app_link.invalid),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.t.generic.action.ok),
      ),
    ],
  ),
);
