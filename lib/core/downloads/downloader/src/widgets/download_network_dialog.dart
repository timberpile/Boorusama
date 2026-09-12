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
}) {
  return showDialog<DownloadNetworkPromptResult>(
    context: context,
    builder: (_) => DownloadNetworkDialog(
      wifiDownloadConstraintSupported: wifiDownloadConstraintSupported,
    ),
  );
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
