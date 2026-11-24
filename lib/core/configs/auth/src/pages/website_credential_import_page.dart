// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../foundation/browser/providers.dart';
import '../../../../../foundation/browser/types.dart';
import '../../../../proxy/types.dart';
import '../../../../widgets/embedded_browser_host.dart';
import '../website_credentials.dart';

class WebsiteCredentialImportPage extends ConsumerStatefulWidget {
  const WebsiteCredentialImportPage({
    required this.site,
    required this.proxy,
    super.key,
  });

  final WebsiteCredentialSite site;
  final ProxySettings? proxy;

  @override
  ConsumerState<WebsiteCredentialImportPage> createState() =>
      _WebsiteCredentialImportPageState();
}

enum _Failure { browser, session, credentials, verification }

class _WebsiteCredentialImportPageState
    extends ConsumerState<WebsiteCredentialImportPage> {
  EmbeddedBrowserSession? _browser;
  CancelToken? _validation;
  Uri? _observedUri;
  var _revision = 0;
  int? _checkingRevision;
  var _openedOptions = false;
  var _previewOpen = false;
  _Failure? _failure;

  WebsiteCredentialSite get _site => widget.site;
  bool get _checking => _checkingRevision == _revision;

  void _invalidate() {
    _revision++;
    _validation?.cancel();
    _validation = null;
  }

  bool _isCurrent(EmbeddedBrowserSession browser, int revision) =>
      mounted && identical(_browser, browser) && _revision == revision;

  void _onEvent(BrowserEvent event) {
    if (!mounted) return;
    switch (event.kind) {
      case BrowserEventKind.navigationStarted:
        _observedUri = event.uri;
        setState(_invalidate);
      case BrowserEventKind.urlChanged:
        if (event.uri == _observedUri) return;
        _observedUri = event.uri;
        setState(_invalidate);
      case BrowserEventKind.navigationCompleted:
        _observedUri = event.uri;
        unawaited(_inspectPage());
      case BrowserEventKind.loadError:
        if (event.isForMainFrame == false) return;
        setState(() {
          _invalidate();
          _failure = _Failure.browser;
        });
    }
  }

  Future<void> _inspectPage() async {
    final browser = _browser;
    if (browser == null || _checking || _previewOpen) return;
    final revision = _revision;
    setState(() {
      _checkingRevision = revision;
      _failure = null;
    });

    var failure = _Failure.browser;
    try {
      final uri = await browser.currentUri().timeout(websiteCredentialTimeout);
      if (!_isCurrent(browser, revision) || uri == null) return;
      if (!_site.matchesOrigin(uri)) return;

      if (!_site.isOptions(uri)) {
        if (_openedOptions) return;
        final destination = await _site
            .destination(browser)
            .timeout(websiteCredentialTimeout);
        if (!_isCurrent(browser, revision) || destination == null) return;
        _openedOptions = true;
        await browser.load(destination).timeout(websiteCredentialTimeout);
        return;
      }

      final candidates = await _readCandidates(browser)
          .timeout(websiteCredentialTimeout);
      if (!_isCurrent(browser, revision)) return;
      if (candidates == null) {
        setState(() => _failure = _Failure.session);
        return;
      }
      if (candidates.isEmpty) {
        setState(
          () => _failure = _site.importsKey
              ? _Failure.credentials
              : _Failure.verification,
        );
        return;
      }
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      final credentials = candidates.length == 1
          ? candidates.single
          : await _chooseCredential(candidates);
      if (!_isCurrent(browser, revision) || credentials == null) return;

      if (_site.importsKey) {
        failure = _Failure.verification;
        final cancel = _validation = CancelToken();
        final validated = await ref.read(websiteCredentialValidatorProvider)(
          _site,
          credentials,
          widget.proxy,
          cancel,
        );
        if (!_isCurrent(browser, revision)) return;
        _validation = null;
        if (!validated) {
          setState(() => _failure = failure);
          return;
        }
      }
      if (!await _matchesSession(browser, revision, credentials)) {
        if (_isCurrent(browser, revision)) {
          setState(() => _failure = _Failure.session);
        }
        return;
      }
      if (!mounted ||
          !_isCurrent(browser, revision) ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }

      failure = _Failure.session;
      setState(() => _previewOpen = true);
      final accepted = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (_) => _CredentialPreview(
          site: _site,
          login: credentials.login,
        ),
      );
      _previewOpen = false;
      if (!mounted || accepted != true) return;

      final sessionStillMatches = await _matchesSession(
        browser,
        revision,
        credentials,
      );
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        if (sessionStillMatches && _isCurrent(browser, revision)) {
          Navigator.of(context).pop(credentials);
        } else {
          setState(() => _failure = _Failure.session);
        }
      }
    } catch (_) {
      // Browser and HTTP exceptions can contain URLs or response bodies.
      if (_isCurrent(browser, revision)) {
        setState(() => _failure = failure);
      }
    } finally {
      if (_isCurrent(browser, revision)) {
        setState(() {
          _validation = null;
          _checkingRevision = null;
        });
      }
    }
  }

  Future<WebsiteCredentials?> _chooseCredential(
    List<WebsiteCredentials> candidates,
  ) async {
    setState(() => _previewOpen = true);
    try {
      return await showDialog<WebsiteCredentials>(
        context: context,
        useRootNavigator: false,
        builder: (context) {
          final text = context.t.booru.authentication.website_import;
          return Padding(
            padding: MediaQuery.viewInsetsOf(context),
            child: KurumiDialog(
              screenInset: 16,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text.choose_key,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    for (final (index, candidate) in candidates.indexed)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(candidate),
                        child: Text(
                          _safeName(candidate.name, candidates) ??
                              text.numbered_key(number: index + 1),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.t.generic.action.cancel),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _previewOpen = false);
    }
  }

  Future<List<WebsiteCredentials>?> _readCandidates(
    EmbeddedBrowserSession browser,
  ) async {
    final session = _site.importsSession
        ? await _site.readSession(browser, forImport: true)
        : null;
    if (_site.importsSession && session == null) return null;
    final raw = await browser.evaluateJavaScript(_site.extractorScript);
    return _site.candidates(raw, session: session);
  }

  Future<bool> _matchesSession(
    EmbeddedBrowserSession browser,
    int revision,
    WebsiteCredentials credentials,
  ) async {
    if (!_isCurrent(browser, revision)) return false;
    final uri = await browser.currentUri().timeout(websiteCredentialTimeout);
    if (!_isCurrent(browser, revision) ||
        uri == null ||
        !_site.isOptions(uri)) {
      return false;
    }
    final candidates = await _readCandidates(browser)
        .timeout(websiteCredentialTimeout);
    return _isCurrent(browser, revision) &&
        (candidates?.any(credentials.matches) ?? false);
  }

  void _retry() {
    _openedOptions = false;
    unawaited(_inspectPage());
  }

  void _closeBrowserSession() {
    _invalidate();
    _browser = null;
    _openedOptions = false;
    _observedUri = null;
  }

  @override
  void dispose() {
    _closeBrowserSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.t.booru.authentication.website_import;

    return Scaffold(
      appBar: KurumiAppBar(title: Text(text.login)),
      body: SafeArea(
        child: Column(
          children: [
            if (_checking && !_previewOpen) const LinearProgressIndicator(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  switch (_failure) {
                    _Failure.browser => text.browser_failed,
                    _Failure.session => text.session_failed,
                    _Failure.credentials => text.credentials_failed,
                    _Failure.verification =>
                      _site.importsKey
                          ? text.verification_failed
                          : text.website_sign_in_unconfirmed,
                    null => _checking ? text.checking : text.sign_in,
                  },
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (_browser != null)
              TextButton(
                onPressed: _checking ? null : _retry,
                child: Text(
                  _failure == null ? text.extract_credentials : text.retry,
                ),
              ),
            Expanded(
              flex: 4,
              child: EmbeddedBrowserHost(
                factory: ref.watch(embeddedBrowserFactoryProvider),
                initialUri: _site.loginUri,
                onReady: (browser) async {
                  _browser = browser;
                  if (mounted) setState(() => _failure = null);
                },
                onSessionClosing: _closeBrowserSession,
                onEvent: _onEvent,
                onFailure: (_) {
                  if (mounted) setState(() => _failure = _Failure.browser);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialPreview extends StatelessWidget {
  const _CredentialPreview({required this.site, required this.login});

  final WebsiteCredentialSite site;
  final String login;

  @override
  Widget build(BuildContext context) {
    final text = context.t.booru.authentication.website_import;
    return Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: KurumiDialog(
        screenInset: 16,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text.preview, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(site.host),
              if (site.importsLogin)
                Text(
                  site.importsSession
                      ? text.user_id(id: login)
                      : text.username(name: login),
                ),
              if (site.importsKey) Text(text.masked_key),
              if (site.importsSession) Text(text.session_available),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.t.generic.action.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(text.apply),
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

String? _safeName(String? name, List<WebsiteCredentials> candidates) {
  if (name == null || name.length > 128) return null;
  return candidates.any((candidate) => name.contains(candidate.apiKey))
      ? null
      : name;
}
