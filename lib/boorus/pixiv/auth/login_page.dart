// Dart imports:
import 'dart:async';

// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Project imports:
import '../../../foundation/platform.dart';
import 'auth_interceptor.dart';
import 'pkce.dart';

/// The only redirect this flow accepts: `pixiv://account/login?code=...`.
const _kRedirectScheme = 'pixiv';
const _kRedirectHost = 'account';
const _kRedirectPath = '/login';

/// Hosts whose cookies are cleared once the login webview is done with.
///
/// Android's WebView cookie jar is process-global, so a leftover pixiv.net
/// session would stay visible to every other webview in the app (including
/// the DDoS solver) and would survive deleting the profile. Clearing it also
/// makes "log in as a different account" actually work.
const _kPixivCookieUrls = [
  'https://pixiv.net/',
  'https://www.pixiv.net/',
  'https://accounts.pixiv.net/',
  'https://app-api.pixiv.net/',
  'https://oauth.secure.pixiv.net/',
];

/// Extracts the authorization code from a navigation target, or returns null
/// if that target is not exactly Pixiv's redirect.
///
/// The match is pinned on the parsed [Uri]'s scheme, host and path. A
/// `startsWith` / `contains` / regex test on the raw string would accept
/// `https://evil/?x=pixiv://account/login?code=1` (an attacker page whose
/// query merely mentions the redirect) and `pixiv://account/login@evil/`
/// (where the interesting part is in the path, not the authority) — both of
/// which hand the code to somebody else.
String? pixivAuthCodeFromRedirect(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  if (uri.scheme != _kRedirectScheme) return null;
  if (uri.host != _kRedirectHost) return null;
  if (uri.path != _kRedirectPath) return null;
  // Nothing legitimate puts credentials in a custom-scheme redirect, and
  // `pixiv://account@evil/login` style targets have no business here.
  if (uri.userInfo.isNotEmpty) return null;

  final code = uri.queryParameters['code'];
  if (code == null || code.isEmpty) return null;

  return code;
}

/// The hosted login page. Pixiv verifies the challenge against the verifier
/// we send later at the token endpoint.
Uri pixivLoginUri(String codeChallenge) =>
    Uri.parse(kPixivLoginUrlBase).replace(
      queryParameters: {
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'client': 'pixiv-android',
      },
    );

/// Whether the in-app login webview can run here. `webview_flutter` ships
/// Android and iOS implementations only; desktop and web users authenticate
/// by pasting a refresh token instead.
bool get isPixivWebViewLoginSupported => isAndroid() || isIOS();

/// Hosts Pixiv's own login page in a webview and exchanges the code it
/// redirects with for a token pair.
///
/// The page never inspects, injects into or reads back anything from the
/// login document: no `runJavaScript`, no `JavaScriptChannel`, no autofill
/// injection, no page-source reads. The user's Pixiv password is theirs
/// alone; the only thing this flow ever takes from the webview is the
/// authorization code in the redirect.
class PixivLoginPage extends StatefulWidget {
  const PixivLoginPage({
    required this.onSuccess,
    super.key,
  });

  final void Function(PixivTokens tokens) onSuccess;

  @override
  State<PixivLoginPage> createState() => _PixivLoginPageState();
}

class _PixivLoginPageState extends State<PixivLoginPage> {
  /// Single-use, page-local, never persisted and never held in a provider
  /// that outlives this State — it is the only thing binding the code Pixiv
  /// returns to the request we made.
  late PixivPkcePair _pkce;

  WebViewController? _controller;
  var _exchanging = false;
  var _cleared = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    // Covers the cancel paths (system back, swipe, app bar close) — the
    // success path clears before handing the tokens back.
    unawaited(_clearWebViewState());
    super.dispose();
  }

  void _start() {
    _pkce = PixivPkcePair.generate();
    _errorMessage = null;
    _exchanging = false;
    _cleared = false;

    if (!isPixivWebViewLoginSupported) return;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(pixivLoginUri(_pkce.codeChallenge));
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final code = pixivAuthCodeFromRedirect(request.url);

    if (code == null) return NavigationDecision.navigate;

    // Handled in-process and never handed to the platform: `pixiv://` is
    // not exclusively claimable, so letting this navigation proceed would
    // deliver the authorization code to whatever app registered the scheme.
    unawaited(_exchange(code));

    return NavigationDecision.prevent;
  }

  Future<void> _exchange(String code) async {
    if (_exchanging) return;
    setState(() {
      _exchanging = true;
      _errorMessage = null;
    });

    try {
      final tokens = await createPixivAuthClient().exchangeCode(
        code: code,
        codeVerifier: _pkce.codeVerifier,
      );

      await _clearWebViewState();

      if (!mounted) return;

      widget.onSuccess(tokens);
      Navigator.of(context).pop();
    } on PixivException catch (e) {
      if (!mounted) return;
      setState(() {
        _exchanging = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exchanging = false;
        _errorMessage = context.t.pixiv.auth.login_failed;
      });
    }
  }

  Future<void> _clearWebViewState() async {
    if (_cleared) return;
    _cleared = true;

    for (final url in _kPixivCookieUrls) {
      try {
        await WebviewCookieManager().removeCookie(url);
      } catch (_) {
        // Best effort: a platform without a cookie manager has no jar to
        // leak from either.
      }
    }

    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.clearCache();
    } catch (_) {
      // Ignored deliberately — see above.
    }

    try {
      await controller.clearLocalStorage();
    } catch (_) {
      // Ignored deliberately — see above.
    }
  }

  void _retry() {
    setState(_start);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.pixiv.auth.login_title),
      ),
      body: SafeArea(
        child: switch ((isPixivWebViewLoginSupported, _errorMessage)) {
          (false, _) => _buildMessage(
            context.t.pixiv.auth.webview_unsupported,
            canRetry: false,
          ),
          (_, final String message) => _buildMessage(message, canRetry: true),
          _ => Column(
            children: [
              if (_exchanging) const LinearProgressIndicator(),
              if (controller != null)
                Expanded(
                  child: WebViewWidget(controller: controller),
                ),
            ],
          ),
        },
      ),
    );
  }

  Widget _buildMessage(String message, {required bool canRetry}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(
              color: Kurumi.themeOf(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          if (canRetry)
            FilledButton(
              onPressed: _retry,
              child: Text(context.t.pixiv.auth.try_again),
            ),
        ],
      ),
    );
  }
}
