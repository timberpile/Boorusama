// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:readmore/readmore.dart';

// Project imports:
import '../../../../foundation/clipboard.dart';
import '../../../../foundation/filesystem.dart';
import '../../../../foundation/loggers.dart';
import '../../../settings/providers.dart';
import '../../../widgets/widgets.dart';
import '../data/log_export.dart';
import '../providers/providers.dart';
import '../types/log_data.dart';
import '../types/write_log_status.dart';
import '../widgets/log_text_highlighting.dart';

class DebugLogsPage extends ConsumerStatefulWidget {
  const DebugLogsPage({
    super.key,
  });

  @override
  ConsumerState<DebugLogsPage> createState() => _DebugLogsPageState();
}

class _DebugLogsPageState extends ConsumerState<DebugLogsPage> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(debugLogsProvider);
    final redactSensitiveDetails = ref.watch(redactSensitiveLogsProvider);
    final selectedCategory = ref.watch(selectedDebugLogCategoryProvider);

    void copyLogsToClipboard() {
      // Copy/export retain chronological capture order for report readers.
      final data = ref.read(appLoggerProvider).dump();
      AppClipboard.copyAndToast(
        context,
        data,
        message: context.t.settings.debug_logs.logs_copied,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.settings.debug_logs.debug_logs),
        actions: [
          IconButton(
            icon: const Icon(Symbols.content_copy),
            onPressed: copyLogsToClipboard,
          ),
          IconButton(
            icon: const Icon(Symbols.download),
            onPressed: () async {
              final fs = ref.read(appFileSystemProvider);
              await writeLogsToFile(
                fs,
                context,
                ref.read(appLoggerProvider).logs,
                reportContext: ref.read(appLoggerProvider).reportContext,
              );
            },
          ),
          KurumiPopupMenuButton(
            semanticLabel: 'Log options'.hc,
            items: [
              KurumiPopupMenuItem(
                title: Text(
                  redactSensitiveDetails
                      ? 'Include sensitive details'.hc
                      : 'Redact sensitive details'.hc,
                ),
                onTap: () async {
                  try {
                    await ref
                        .read(logOptionsProvider.notifier)
                        .setRedactSensitiveDetails(!redactSensitiveDetails);
                  } catch (_) {
                    if (context.mounted) {
                      Kurumi.showErrorToast(
                        context,
                        'Could not save log redaction preference'.hc,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: KurumiScrollToTop(
        scrollController: scrollController,
        child: KurumiScrollToTopButton(
          onPressed: () {
            scrollController.animateToWithAccessibility(
              scrollController.position.minScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              reduceAnimations: ref.read(settingsProvider).reduceAnimations,
            );
          },
        ),
      ),
      body: Column(
        children: [
          const _DebugCategorySelector(),
          Expanded(
            child: _LogsList(
              logs: logs,
              selectedCategory: selectedCategory,
              scrollController: scrollController,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> writeLogsToFile(
  AppFileSystem fs,
  BuildContext context,
  List<LogData> logs, {
  Map<String, String> reportContext = const {},
}) async {
  final result = await writeLogs(fs, logs, context: reportContext);

  switch (result) {
    case WriteLogFailure(:final message):
      if (context.mounted) {
        Kurumi.showErrorToast(
          context,
          message,
        );
      }
    case WriteLogSuccess(:final filePath):
      if (context.mounted) {
        Kurumi.showSuccessToast(
          context,
          'Logs written to $filePath',
          duration: KurumiDurations.longToast,
        );
      }
  }
}

class _DebugCategorySelector extends ConsumerWidget {
  const _DebugCategorySelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(debugLogsProvider);
    final categories = logs.map((e) => e.serviceName).toSet().toList();
    final selectedCategory = ref.watch(selectedDebugLogCategoryProvider);

    return ChoiceOptionSelectorList(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      options: categories,
      selectedOption: selectedCategory,
      searchable: false,
      optionLabelBuilder: (option) => option ?? 'All',
      onSelected: (value) {
        ref.read(selectedDebugLogCategoryProvider.notifier).state = value;
      },
    );
  }
}

class _LogsList extends StatefulWidget {
  const _LogsList({
    required this.logs,
    required this.selectedCategory,
    required this.scrollController,
  });

  final List<LogData> logs;
  final String? selectedCategory;
  final ScrollController scrollController;

  @override
  State<_LogsList> createState() => _LogsListState();
}

class _LogsListState extends State<_LogsList> {
  final _center = GlobalKey();
  Object? _anchor;

  List<LogData> get _visibleLogs => [
    for (final log in widget.logs.reversed)
      if (widget.selectedCategory == null ||
          log.serviceName == widget.selectedCategory)
        log,
  ];

  @override
  void didUpdateWidget(_LogsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final position = widget.scrollController.positions.firstOrNull;
    if (oldWidget.selectedCategory != widget.selectedCategory ||
        position == null ||
        !position.hasContentDimensions ||
        position.pixels <= position.minScrollExtent + .5) {
      _anchor = null;
      if (position != null && position.pixels != 0) {
        // Following latest chooses the new top. Readers farther down retain
        // their center sliver and offset when rows arrive above it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.scrollController.positions.length == 1) {
            widget.scrollController.jumpTo(0);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final colors = LogTextColors.forBrightness(colorScheme.brightness);
    final annotations = logTextAnnotations(colors);

    final logs = _visibleLogs;
    var anchorIndex = _anchor == null
        ? 0
        : logs.indexWhere((log) => identical(log.identity, _anchor));
    if (anchorIndex < 0) anchorIndex = 0;
    _anchor = logs.isEmpty ? null : logs[anchorIndex].identity;
    final indices = {
      for (var i = 0; i < logs.length; i++) logs[i].identity: i,
    };
    Widget row(BuildContext context, int index) {
      final log = logs[index];
      return SelectionArea(
        key: ObjectKey(log.identity),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                log.dateTime.toString(),
                style: TextStyle(
                  color: colors.muted,
                ),
              ),
              Wrap(
                children: [
                  Text(
                    '[${log.serviceName}]: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  ReadMoreText(
                    log.message,
                    annotations: annotations,
                    trimCollapsedText: context.t.misc.trailing_more,
                    trimExpandedText: context.t.misc.trailing_less,
                    trimMode: TrimMode.Line,
                    trimLines: 3,
                    style: TextStyle(
                      fontSize: 13,
                      color: switch (log.level) {
                        LogLevel.warning => colors.warning,
                        LogLevel.error => colors.error,
                        _ => colors.text,
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      key: const ValueKey('debug-logs-list'),
      controller: widget.scrollController,
      center: _center,
      slivers: [
        // Rows inserted while reading older content grow above the persistent
        // center. No guessed row height or forced scroll correction is needed.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => row(context, anchorIndex - index - 1),
              childCount: anchorIndex,
              findChildIndexCallback: (key) {
                if (key is! ObjectKey) return null;
                final index = indices[key.value];
                return index != null && index < anchorIndex
                    ? anchorIndex - index - 1
                    : null;
              },
            ),
          ),
        ),
        SliverPadding(
          key: _center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => row(context, anchorIndex + index),
              childCount: logs.length - anchorIndex,
              findChildIndexCallback: (key) {
                if (key is! ObjectKey) return null;
                final index = indices[key.value];
                return index != null && index >= anchorIndex
                    ? index - anchorIndex
                    : null;
              },
            ),
          ),
        ),
      ],
    );
  }
}
