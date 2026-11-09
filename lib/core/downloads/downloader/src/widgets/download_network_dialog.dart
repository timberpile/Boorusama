// Package imports:
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../types/download_network_policy.dart';

Future<DownloadNetworkPromptResult?> showDownloadNetworkDialog(
  BuildContext context, {
  required bool wifiDownloadConstraintSupported,
}) async {
  final promptOwner = Object();
  PopupRoute<dynamic>? promptRoute;
  final result = await showDialog<DownloadNetworkPromptResult>(
    context: context,
    routeSettings: RouteSettings(
      name: 'download-network-prompt',
      arguments: promptOwner,
    ),
    builder: (context) {
      final route = ModalRoute.of(context);
      // Native window presenters may expose an unrelated inner page route.
      if (route is PopupRoute &&
          identical(route.settings.arguments, promptOwner)) {
        promptRoute = route;
      }
      return DownloadNetworkDialog(
        wifiDownloadConstraintSupported: wifiDownloadConstraintSupported,
      );
    },
  );
  // A pop result precedes popup disposal and the deferred activity rebuild.
  // Resume the caller only after the surface handoff; it still checks its actor.
  if (promptRoute case final route?) await route.completed;
  await WidgetsBinding.instance.endOfFrame;
  if (promptRoute == null) {
    // Native windows have no owned PopupRoute animation to advance that rebuild.
    await WidgetsBinding.instance.endOfFrame;
  }
  return result;
}

class DownloadNetworkDialog extends StatefulWidget {
  const DownloadNetworkDialog({
    required this.wifiDownloadConstraintSupported,
    super.key,
  });

  final bool wifiDownloadConstraintSupported;

  @override
  State<DownloadNetworkDialog> createState() => _DownloadNetworkDialogState();
}

class _DownloadNetworkDialogState extends State<DownloadNetworkDialog> {
  var _rememberForSession = false;

  void _complete(DownloadNetworkConstraint constraint) {
    Navigator.of(context).pop(
      DownloadNetworkPromptResult(
        constraint: constraint,
        rememberForSession: _rememberForSession,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KurumiDialog(
      semanticLabel: context.t.download.network_prompt.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t.download.network_prompt.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(context.t.download.network_prompt.description),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              context.t.download.network_prompt.remember_for_session,
            ),
            value: _rememberForSession,
            onChanged: (value) {
              setState(() => _rememberForSession = value ?? false);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.t.generic.action.cancel),
              ),
              ElevatedButton(
                onPressed: widget.wifiDownloadConstraintSupported
                    ? () => _complete(
                        DownloadNetworkConstraint.wifiRequired,
                      )
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t.download.network_prompt.wait_for_wifi,
                    ),
                    if (!widget.wifiDownloadConstraintSupported)
                      Text(
                        context.t.generic.requirement.android.version_or_later(
                          version: AndroidVersions.android9.release,
                        ),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => _complete(
                  DownloadNetworkConstraint.unrestricted,
                ),
                child: Text(
                  context.t.download.network_prompt.use_mobile_data,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
