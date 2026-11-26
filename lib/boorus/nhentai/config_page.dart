import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../core/configs/auth/widgets.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/providers.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/http/client/providers.dart';
import 'favorites/account.dart';

class NhentaiConfigPage extends StatelessWidget {
  const NhentaiConfigPage({this.backgroundColor, this.initialTab, super.key});

  final Color? backgroundColor;
  final String? initialTab;

  @override
  Widget build(BuildContext context) => CreateBooruConfigScaffold(
    backgroundColor: backgroundColor,
    initialTab: initialTab,
    authTab: const _NhentaiAuthView(),
    canSubmit: (_) => true,
  );
}

class _NhentaiAuthView extends ConsumerStatefulWidget {
  const _NhentaiAuthView();

  @override
  ConsumerState<_NhentaiAuthView> createState() => _NhentaiAuthViewState();
}

class _NhentaiAuthViewState extends ConsumerState<_NhentaiAuthView> {
  late final _id = ref.read(editBooruConfigIdProvider);
  late final _draft = editBooruConfigProvider(_id);
  late final _key = TextEditingController(text: ref.read(_draft).apiKey);
  CancelToken? _checking;
  String? _username;
  var _failed = false;

  @override
  void dispose() {
    _checking?.cancel();
    _key.dispose();
    super.dispose();
  }

  Future<void> _verify(String key) async {
    if (_checking != null || !isNhentaiApiKey(key)) return;
    final draft = ref.read(_draft);
    final token = CancelToken();
    setState(() {
      _checking = token;
      _failed = false;
      _username = null;
    });
    final connection = newNhentaiAccountConnection(
      apiKey: key,
      userAgent: ref.read(defaultUserAgentProvider),
      coordinator: ref.read(apiRequestCoordinatorProvider),
      current: () => mounted && !token.isCancelled,
      proxy: draft.proxySettingsTyped,
    );
    try {
      final account = await connection.client.getAccount(cancelToken: token);
      if (!mounted ||
          token.isCancelled ||
          _key.text.trim() != key ||
          ref.read(_draft).apiKey != draft.apiKey) {
        return;
      }
      ref.read(_draft.notifier).updateApiKey(key);
      setState(() => _username = account.username);
    } catch (_) {
      if (mounted && !token.isCancelled) setState(() => _failed = true);
    } finally {
      connection.dio.close(force: true);
      if (mounted && identical(_checking, token)) {
        setState(() => _checking = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(_draft.select((draft) => draft.apiKey));
    final strings = context.t.nhentai;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(strings.api_key_hint),
        const SizedBox(height: 12),
        CreateBooruApiKeyField(
          controller: _key,
          labelText: context.t.booru.password_api_key_label,
          onChanged: (_) => setState(() {
            _checking?.cancel();
            _checking = null;
            _failed = false;
            _username = null;
          }),
        ),
        const SizedBox(height: 8),
        if (_checking != null) const LinearProgressIndicator(),
        if (_failed) Text(strings.key_verification_failed),
        if (_username case final user?) Text(strings.connected_as(user: user)),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _checking == null && isNhentaiApiKey(_key.text.trim())
                  ? () => _verify(_key.text.trim())
                  : null,
              child: Text(context.t.generic.action.verify),
            ),
            if (stored.isNotEmpty)
              TextButton(
                onPressed: _checking == null
                    ? () {
                        _key.clear();
                        ref.read(_draft.notifier).updateApiKey('');
                        setState(() {
                          _failed = false;
                          _username = null;
                        });
                      }
                    : null,
                child: Text(context.t.auth.clear_credentials),
              ),
          ],
        ),
      ],
    );
  }
}
