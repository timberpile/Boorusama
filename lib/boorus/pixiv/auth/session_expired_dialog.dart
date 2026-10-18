// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

var _isDialogVisible = false;

/// Shown when Pixiv rejects the stored refresh token outright, which only
/// re-logging in can fix. Deliberately Pixiv-local so its visibility latch
/// is not shared with another engine's dialog.
void showPixivSessionExpiredDialog({
  required BuildContext? context,
  required VoidCallback onReLogin,
}) {
  if (_isDialogVisible) return;

  if (context == null || !context.mounted) return;

  _isDialogVisible = true;

  showDialog<void>(
    context: context,
    routeSettings: const RouteSettings(name: 'pixiv_session_expired'),
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.t.auth.login_expires),
      content: Text(dialogContext.t.auth.session_expired),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            MaterialLocalizations.of(dialogContext).cancelButtonLabel,
          ),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onReLogin();
          },
          child: Text(dialogContext.t.auth.relogin),
        ),
      ],
    ),
  ).whenComplete(() => _isDialogVisible = false);
}
