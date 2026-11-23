// Dart imports:
import 'dart:async';

// Package imports:
import 'package:booru_clients/gelbooru.dart';
import 'package:coreutils/coreutils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../foundation/browser/cookie_conversion.dart';
import '../../../../../foundation/browser/providers.dart';
import '../../../../../foundation/browser/types.dart';
import '../../../../../foundation/loggers.dart';
import '../../../../widgets/embedded_browser_host.dart';

class CookieAccessWebViewPage extends ConsumerStatefulWidget {
  const CookieAccessWebViewPage({
    required this.url,
    required this.onGet,
    this.cookieRequestUris,
    super.key,
  });

  final String url;
  final List<Uri>? cookieRequestUris;
  final String? Function(List<Cookie> cookies) onGet;

  @override
  ConsumerState<CookieAccessWebViewPage> createState() =>
      _CookieAccessWebViewPageState();
}

class _CookieAccessWebViewPageState
    extends ConsumerState<CookieAccessWebViewPage> {
  late final Logger _logger;
  EmbeddedBrowserSession? _session;
  var _generation = 0;
  var _exporting = false;
  String? _error;

  void _log(String message) => _logger.info(
    'Login',
    'login=${identityHashCode(this)} $message',
  );

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
    _log('opened host=${Uri.parse(widget.url).host}');
  }

  Future<void> _exportCookies() async {
    final session = _session;
    final generation = _generation;
    if (session == null || _exporting) return;
    setState(() {
      _exporting = true;
      _error = null;
    });
    _log('cookie access requested');
    try {
      final uris = widget.cookieRequestUris ?? [Uri.parse(widget.url)];
      final cookiesByUri = await Future.wait([
        for (final uri in uris)
          session
              .getCookies(uri)
              .then(
                (cookies) => browserCookiesForRequest(
                  uri: uri,
                  cookies: cookies,
                  now: DateTime.now(),
                ),
              ),
      ]);
      if (!mounted ||
          generation != _generation ||
          !identical(_session, session)) {
        return;
      }
      // A credential reused across endpoints must be eligible for all of them.
      final cookies = cookiesByUri.first
          .where(
            (cookie) => cookiesByUri
                .skip(1)
                .every(
                  (others) => others.any(
                    (other) =>
                        other.name == cookie.name &&
                        other.value == cookie.value,
                  ),
                ),
          )
          .toList();
      _log(
        'cookie access count=${cookies.length} '
        'passHashPresent=${cookies.any((c) => c.name == 'pass_hash')} '
        'userIdPresent=${cookies.any((c) => c.name == 'user_id')} '
        'rule34SessionPresent=${cookies.any((c) => c.name == Rule34WebsiteSession.sessionCookie)} '
        'rule34UserIdPresent=${cookies.any((c) => c.name == Rule34WebsiteSession.userIdCookie)}',
      );
      final error = widget.onGet(cookies);
      if (error != null && mounted) setState(() => _error = error);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Cookie access failed. Please retry.');
      }
      _log('cookie access failed type=${error.runtimeType}');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _session = null;
    _log('closed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(widget.url);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text('Login'.hc)),
      body: Column(
        children: [
          _buildBanner('Press the button below after you logged in.'.hc),
          FilledButton(
            onPressed: _session == null || _exporting ? null : _exportCookies,
            child: Text('Access Cookie'.hc),
          ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(error, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: uri == null
                ? const Center(child: Text('Invalid login URL'))
                : EmbeddedBrowserHost(
                    factory: ref.watch(embeddedBrowserFactoryProvider),
                    initialUri: uri,
                    onSessionClosing: () {
                      if (mounted) setState(() => _session = null);
                      _generation++;
                    },
                    onReady: (session) async {
                      if (mounted) {
                        setState(() => _session = session);
                      }
                    },
                    onEvent: (event) {
                      if (event.kind == BrowserEventKind.loadError) {
                        _log('resource error type=${event.errorType}');
                      }
                    },
                    onFailure: (error) {
                      _log('browser setup failed code=${error.code}');
                      if (mounted) {
                        setState(
                          () => _error = 'Browser setup failed. Please retry.',
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: Border.all(color: Colors.white),
      ),
      width: MediaQuery.widthOf(context),
      padding: const EdgeInsets.all(8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
