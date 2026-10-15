#!/usr/bin/env python3
"""Install identical viewer-only diagnostics on the known before/after revisions.

Run from the instrumented checkout, passing a clean isolated baseline worktree.
No Git operations, optimization changes, dependency resolution or builds are run.
"""
from pathlib import Path
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = 'a46521eced78ae2f31a5c2517a43fc2e4e4a6072'
FIXED = 'f3ce8bc4cc3900f577a2f2e6dd88004201ff594f'
FILES = ['packages/foundation/lib/performance.dart', 'packages/foundation/lib/src/performance/recorder.dart', 'packages/foundation/test/performance_recorder_test.dart', 'lib/foundation/performance/performance_diagnostics.dart', 'lib/foundation/performance/performance_navigation.dart', 'lib/core/settings/src/pages/performance_diagnostics_page.dart', 'test/settings/performance_diagnostics_page_test.dart', 'test/foundation/performance_navigation_test.dart', 'scripts/analyze_performance.py', 'scripts/compare_viewer_performance.py', 'scripts/tests/test_analyze_performance.py']
INSTRUMENTED = [
    'lib/core/router.dart',
    'lib/core/settings/src/pages/bookmark_maintenance_page.dart',
    'lib/core/posts/details/src/widgets/post_details_image_preloader.dart',
    'lib/core/posts/details/src/widgets/post_details_item.dart',
    'lib/core/posts/details/src/widgets/post_details_page_scaffold.dart',
    'lib/core/posts/media_preload/src/preload_manager.dart',
    'packages/i18n/translations/en-US.json', 'packages/i18n/translations/de-DE.json',
]


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f'Expected exactly one anchor: {old[:90]}')
    return text.replace(old, new, 1)


def wrap(text, signature, operation, before='', after='', returns=False):
    start = text.index(signature) + len(signature)
    end = text.index('\n  }', start)
    body = text[start:end]
    wrapped = ('\n    ' + before + '\n    ' + ('return ' if returns else '') +
               'performanceRecorder.measureSync(PerfOperation.' + operation + ', () {' +
               body + '\n    });\n    ' + after)
    return text[:start] + wrapped + text[end:]


def add_import(text, statement):
    group = '// Package imports:\n' if "'package:" in statement else '// Project imports:\n'
    if group in text:
        return text.replace(group, group + statement + '\n', 1)
    return statement + '\n\n' + text


def transform(name, text):
    if name.endswith('/router.dart'):
        text = add_import(text, "import '../foundation/performance/performance_navigation.dart';")
        text = add_import(text, "import '../foundation/info/package_info.dart';")
        return replace_once(text, '    observers: [', '    observers: [if (ref.watch(isDevEnvironmentProvider)) PerformanceNavigationObserver(),')
    if name.endswith('/bookmark_maintenance_page.dart'):
        text = add_import(text, "import 'performance_diagnostics_page.dart';")
        return replace_once(text, '    title: Text(context.t.bookmark.maintenance.advanced),\n    children: [', """    title: Text(context.t.bookmark.maintenance.advanced),
    children: [
      ListTile(
        title: Text(context.t.performance_diagnostics.title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const PerformanceDiagnosticsPage(),
        )),
      ),""")
    if name.endswith('.json'):
        # Preserve the original translation formatting and content.
        strings = json.loads((ROOT/name).read_text())['performance_diagnostics']
        if '"performance_diagnostics"' in text: raise ValueError('Already instrumented')
        if not text.startswith('{\n'): raise ValueError('Unexpected translation format')
        return '{\n  "performance_diagnostics": ' + json.dumps(strings, ensure_ascii=False, indent=2).replace('\n', '\n  ') + ',\n' + text[2:]
    text = add_import(text, "import 'package:foundation/performance.dart';")
    if name.endswith('/post_details_image_preloader.dart'):
        start = text.index('  void _preloadAdjacentPages(int currentPage) {')
        end = text.index('\n  }', start)
        body = text[start:end]
        if 'final post = widget.posts[index];' in body:
            body = replace_once(body, 'final post = widget.posts[index];', 'if (diagnosticRecording) diagnosticResolved++;\n        final post = widget.posts[index];')
        else:
            body = replace_once(body, 'if (_resolve(widget.posts[index])', 'if (diagnosticRecording) diagnosticResolved++;\n      if (_resolve(widget.posts[index])')
        text = text[:start] + body + text[end:]
        text = wrap(text, '  void _preloadAdjacentPages(int currentPage) {', 'mixedPreloadResolve',
                    before='final diagnosticRecording = performanceRecorder.enabled;\n    var diagnosticResolved = 0;',
                    after='performanceRecorder.count(PerfCounter.mixedCollectionSize, widget.posts.length);\n    performanceRecorder.count(PerfCounter.mixedResolvedPosts, diagnosticResolved);')
        return wrap(text, '  Future<void> _preloadAdjacentPages(int currentPage) async {', 'viewerPreloadDispatch')
    if name.endswith('/preload_manager.dart'):
        # The closure and counter exist only while recording; disabled calls retain
        # the original builder and avoid per-resolution diagnostics overhead.
        text = replace_once(text, '      mediaBuilder: mediaBuilder,', """      mediaBuilder: diagnosticRecording ? (index) {
        diagnosticBuilds++;
        return mediaBuilder(index);
      } : mediaBuilder,""")
        return instrument_manager(text)
    if name.endswith('/post_details_item.dart'):
        return replace_once(text, '  Widget build(BuildContext context) {', """  Widget build(BuildContext context) => performanceRecorder.measureSync(
    PerfOperation.viewerItemBuild, () => _buildItem(context),
  );

  Widget _buildItem(BuildContext context) {""")
    if name.endswith('/post_details_page_scaffold.dart'):
        text = add_import(text, "import '../../../../../foundation/performance/performance_navigation.dart';")
        text = wrap(text, '  void _onPrecisePageChanged() {', 'viewerPrecisePageCallback')
        text = wrap(text, '  void _onPageSettled(int page) {', 'viewerSettlement')
        text = text.replace('  Widget build(BuildContext context) {', """  Widget build(BuildContext context) => PerformanceScreenScope(
    screen: PerfScreen.postViewer,
    child: performanceRecorder.measureSync(PerfOperation.viewerScaffoldBuild, () => _buildViewer(context)),
  );

  Widget _buildViewer(BuildContext context) {""", 1)
        return text
    raise ValueError(f'Unhandled file: {name}')


def instrument_manager(text):
    start = text.index('  void preloadWithStrategy({')
    body = text.index('  }) {', start) + len('  }) {')
    end = text.index('\n  }', body)
    return (text[:body] + """
    final diagnosticRecording = performanceRecorder.enabled;
    var diagnosticBuilds = 0;
    performanceRecorder.measureSync(PerfOperation.viewerPreloadPlan, () {""" + text[body:end] + """
    });
    performanceRecorder.count(PerfCounter.preloadMediaBuilds, diagnosticBuilds);
    performanceRecorder.count(PerfCounter.preloadCompletedHistory, _completedUrls.length);""" + text[end:])


def apply(target):
    target = target.resolve()
    if target == ROOT: raise ValueError('Target must be a separate clean checkout')
    head = subprocess.check_output(['git', '-C', str(target), 'rev-parse', 'HEAD'], text=True).strip()
    if head not in (BASE, FIXED): raise ValueError('Target must be the documented baseline or corrected revision')
    if subprocess.check_output(['git', '-C', str(target), 'status', '--porcelain'], text=True).strip():
        raise ValueError('Target must be clean; existing work will not be overwritten')
    # Validate and prepare every transformation before the first write.
    prepared = {name: transform(name, (target/name).read_text()) for name in INSTRUMENTED}
    for name in FILES:
        if (target/name).exists(): raise ValueError(f'Destination already exists: {name}')
        prepared[name] = (ROOT/name).read_text()
    for name, contents in prepared.items():
        path = target/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)
    print(f'Installed viewerSwipeV1 on {head}; no optimizations copied. Resolve dependencies and run gen.sh next.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', type=Path)
    args = parser.parse_args()
    try: apply(args.target)
    except (ValueError, OSError, subprocess.CalledProcessError) as error: parser.exit(1, f'{error}\n')
