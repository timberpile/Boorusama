// Package imports:
import 'package:booru_clients/core.dart' as c;
import 'package:booru_clients/gelbooru.dart';
import 'package:coreutils/coreutils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/auth/widgets.dart';
import '../../../core/configs/create/providers.dart';
import '../../../core/configs/create/widgets.dart';
import '../../../core/configs/gesture/types.dart';
import '../../../core/configs/gesture/widgets.dart';
import '../../../core/configs/search/widgets.dart';
import '../../../core/configs/viewer/widgets.dart';
import '../../gelbooru/configs/_internal_widgets.dart';
import 'internal_widgets.dart';

const _kGelbooruV2SpecificGestureActions = {
  kToggleFavoriteAction,
};

const _kGelbooruV2PreviewGestureActions = {
  ...kDefaultGestureActions,
  ..._kGelbooruV2SpecificGestureActions,
};

const _kGelbooruV2FullviewGestureActions = {
  ...kDefaultFullviewActions,
  ..._kGelbooruV2SpecificGestureActions,
};

final _rule34CookieRequestUris = [
  Rule34WebsiteSession.addFavoriteUri,
  Rule34WebsiteSession.indexUri,
];

class CreateGelbooruV2ConfigPage extends StatelessWidget {
  const CreateGelbooruV2ConfigPage({
    required this.url,
    super.key,
    this.backgroundColor,
    this.initialTab,
  });

  final Color? backgroundColor;
  final String? initialTab;
  final String url;

  @override
  Widget build(BuildContext context) {
    return CreateBooruConfigScaffold(
      initialTab: initialTab,
      backgroundColor: backgroundColor,
      authTab: GelbooruV2AuthView(
        authConfig: c.GelbooruV2Config.siteCapabilities(url).auth,
        requireMatchingWebsiteSession: GelbooruV2Client.isRule34Website(url),
      ),
      gestureTab: BooruConfigGesturesView(
        previewGestureActions: _kGelbooruV2PreviewGestureActions,
        fullviewGestureActions: _kGelbooruV2FullviewGestureActions,
        describePostDetailsAction: (action) => switch (action) {
          kToggleFavoriteAction => context.t.post.action.toggle_favorite,
          _ => describeDefaultGestureAction(action, context),
        },
      ),
      searchTab: const DefaultBooruConfigSearchView(
        hasRatingFilter: true,
      ),
      imageViewerTab: const BooruConfigViewerView(
        autoLoadNotes: DefaultAutoFetchNotesSwitch(),
      ),
    );
  }
}

class GelbooruV2AuthView extends ConsumerStatefulWidget {
  const GelbooruV2AuthView({
    this.authConfig,
    this.requireMatchingWebsiteSession = false,
    super.key,
  });

  final c.AuthConfig? authConfig;
  final bool requireMatchingWebsiteSession;

  @override
  ConsumerState<GelbooruV2AuthView> createState() => _GelbooruV2AuthViewState();
}

class _GelbooruV2AuthViewState extends ConsumerState<GelbooruV2AuthView> {
  late final loginController = TextEditingController(
    text: ref.read(
      editBooruConfigProvider(
        ref.read(editBooruConfigIdProvider),
      ).select((value) => value.login),
    ),
  );
  late final apiKeyController = TextEditingController(
    text: ref.read(
      editBooruConfigProvider(
        ref.read(editBooruConfigIdProvider),
      ).select((value) => value.apiKey),
    ),
  );

  @override
  void dispose() {
    super.dispose();
    loginController.dispose();
    apiKeyController.dispose();
  }

  String? _importWebsiteSession(List<Cookie> cookies) {
    final userIds = _cookieValues(cookies, Rule34WebsiteSession.userIdCookie);
    final tokens = _cookieValues(cookies, Rule34WebsiteSession.sessionCookie);
    final messages = context.t.favorites.update;
    if (userIds.length != 1 || tokens.length != 1) {
      return messages.website_session_missing;
    }
    final session = Rule34WebsiteSession.fromCookies(
      signedUserId: userIds.single,
      token: tokens.single,
    );
    if (session == null) return messages.website_session_missing;
    final apiUserId = loginController.text.trim();
    if (apiUserId.isNotEmpty && apiUserId != session.userId) {
      return messages.website_session_import_failed;
    }

    ref.editNotifier.updateLogin(session.userId);
    ref.editNotifier.updatePassHash(session.toStoredValue());
    loginController.text = session.userId;
    return null;
  }

  Set<String> _cookieValues(List<Cookie> cookies, String name) => {
    for (final cookie in cookies)
      if (cookie.name == name && cookie.value.trim().isNotEmpty) cookie.value,
  };

  @override
  Widget build(BuildContext context) {
    final authConfig = widget.authConfig;
    final instructionsText = switch (authConfig?.instructionsKey) {
      final String key when key.isNotEmpty => context.t[key],
      _ => context.t.booru.api_key_instructions.variants_2,
    };
    final (userId, passHash) = ref.watch(
      editBooruConfigProvider(
        ref.watch(editBooruConfigIdProvider),
      ).select((value) => (value.login, value.passHash)),
    );
    final websiteSessionPresent = widget.requireMatchingWebsiteSession
        ? Rule34WebsiteSession.fromStoredValue(passHash, userId: userId) != null
        : null;
    final authRequired = authConfig?.required ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BasicAuthSection(
            titleText: authRequired
                ? context.t.booru.authentication.gelbooru.basic_auth
                : null,
            descriptionText: null,
            loginController: loginController,
            apiKeyController: apiKeyController,
            loginField: GelbooruV2LoginField(
              controller: loginController,
            ),
            apiKeyField: GelbooruV2ApiKeyField(
              controller: apiKeyController,
            ),
            instructionsText: instructionsText,
            apiKeyUrl: switch (authConfig?.apiKeyUrl) {
              final String apiKeyUrl when apiKeyUrl.isNotEmpty => apiKeyUrl,
              _ => null,
            },
            pasteButton: authRequired
                ? GelbooruConfigPasteFromClipboardButton(
                    login: loginController,
                    apiKey: apiKeyController,
                  )
                : null,
          ),
          if (authConfig?.loginUrl case final loginUrl?)
            AdvancedAuthSection(
              loginController: loginController,
              getLoginUrl: () => loginUrl,
              importCookies: widget.requireMatchingWebsiteSession
                  ? _importWebsiteSession
                  : null,
              cookieRequestUris: widget.requireMatchingWebsiteSession
                  ? _rule34CookieRequestUris
                  : null,
              websiteSessionPresent: websiteSessionPresent,
              showWarningContainer: websiteSessionPresent ?? passHash != null,
              warningTitle: context
                  .t
                  .booru
                  .authentication
                  .gelbooru
                  .fav_button_tooltip_title,
              warningDescription: context
                  .t
                  .booru
                  .authentication
                  .gelbooru
                  .fav_button_tooltip_description,
            ),
        ],
      ),
    );
  }
}
