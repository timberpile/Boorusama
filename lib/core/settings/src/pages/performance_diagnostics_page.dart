import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../../../../foundation/performance/performance_diagnostics.dart';
import '../../../../foundation/performance/performance_navigation.dart';
import '../widgets/settings_page_scaffold.dart';

class PerformanceDiagnosticsPage extends ConsumerStatefulWidget {
  const PerformanceDiagnosticsPage({super.key});
  @override
  ConsumerState<PerformanceDiagnosticsPage> createState() => _PerformanceDiagnosticsPageState();
}

class _PerformanceDiagnosticsPageState extends ConsumerState<PerformanceDiagnosticsPage> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final diagnostics = ref.watch(performanceDiagnosticsProvider);
    final strings = context.t.performance_diagnostics;
    return PerformanceScreenScope(
      screen: PerfScreen.diagnostics,
      child: ListenableBuilder(
        listenable: diagnostics,
        builder: (context, _) {
          final recorder = diagnostics.recorder;
          final busy = diagnostics.draining || _exporting;
          return SettingsPageScaffold(
            title: Text(strings.title),
            children: [
              ListTile(
                title: Text(recorder.recording ? strings.recording : strings.stopped),
                subtitle: Text(kIsWeb ? strings.native_only : strings.description),
              ),
              if (diagnostics.draining)
                ListTile(title: Text(strings.finishing)),
              ListTile(
                title: Text(strings.summary
                    .replaceAll('{frames}', '${recorder.frameCount}')
                    .replaceAll('{slow}', '${recorder.overBudgetFrames}')
                    .replaceAll('{delays}', '${recorder.uiDelayCount}')),
                subtitle: Text(strings.privacy),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: busy || kIsWeb ? null : () {
                        if (recorder.recording) {
                          diagnostics.stop();
                        } else {
                          diagnostics.start();
                        }
                      },
                      icon: Icon(recorder.recording ? Icons.stop : Icons.play_arrow),
                      label: Text(recorder.recording ? strings.stop : strings.start),
                    ),
                    OutlinedButton.icon(
                      onPressed: recorder.enabled && !busy ? diagnostics.mark : null,
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(strings.mark),
                    ),
                    if (defaultTargetPlatform != TargetPlatform.linux)
                      Builder(builder: (buttonContext) => OutlinedButton.icon(
                        onPressed: recorder.hasSession && !busy
                            ? () => _export(buttonContext, copy: false) : null,
                        icon: const Icon(Icons.share),
                        label: Text(strings.export),
                      )),
                    OutlinedButton.icon(
                      onPressed: recorder.hasSession && !busy
                          ? () => _export(context, copy: true) : null,
                      icon: const Icon(Icons.copy),
                      label: Text(strings.copy),
                    ),
                    TextButton(
                      onPressed: recorder.hasSession && !recorder.recording && !busy
                          ? diagnostics.clear : null,
                      child: Text(strings.clear),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _export(BuildContext buttonContext, {required bool copy}) async {
    if (_exporting) return;
    final diagnostics = ref.read(performanceDiagnosticsProvider);
    final strings = context.t.performance_diagnostics;
    final renderObject = buttonContext.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size : null;
    setState(() => _exporting = true);
    try {
      // Stop before snapshot/JSON/file/share work so export cannot create its
      // own lag samples. Drain the delayed release-mode frame callback first.
      await diagnostics.stop();
      if (!mounted) return;
      final json = await compute(_encodeReport, diagnostics.report());
      if (!mounted) return;
      if (copy) {
        await Clipboard.setData(ClipboardData(text: json));
      } else {
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(utf8.encode(json), mimeType: 'application/json')],
          fileNameOverrides: const ['boorusama-performance.json'],
          sharePositionOrigin: origin,
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.export_failed)),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

String _encodeReport(Map<String, Object?> report) => jsonEncode(report);
