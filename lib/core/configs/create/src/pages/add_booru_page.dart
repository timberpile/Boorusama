// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../../foundation/clipboard.dart';
import '../../../../analytics/providers.dart';
import '../../../../boorus/booru/providers.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../config_widgets/website_logo.dart';
import '../../../config/types.dart';
import '../types/edit_booru_config_id.dart';
import '../types/quick_profile_site.dart';
import '../types/validator/booru_url_error.dart';
import '../types/validator/booru_url_validator.dart';
import 'add_unknown_booru_page.dart';
import 'create_booru_config_scaffold.dart';

class AddBooruPage extends ConsumerStatefulWidget {
  const AddBooruPage({
    required this.setCurrentBooruOnSubmit,
    super.key,
    this.backgroundColor,
    this.initialConfigId,
  });

  final bool setCurrentBooruOnSubmit;
  final Color? backgroundColor;
  final EditBooruConfigId? initialConfigId;

  @override
  ConsumerState<AddBooruPage> createState() => _AddBooruPageState();
}

class _AddBooruPageState extends ConsumerState<AddBooruPage> {
  late EditBooruConfigId? configId = widget.initialConfigId;

  @override
  Widget build(BuildContext context) {
    final booruDb = ref.watch(booruDbProvider);

    return switch (configId) {
      null => AnalyticsInitStateHook(
        screenName: 'config/url_input',
        child: AddBooruPageInternal(
          backgroundColor: widget.backgroundColor,
          setCurrentBooruOnSubmit: widget.setCurrentBooruOnSubmit,
          quickSetupSites: QuickProfileSiteCatalog.fromBoorus(
            booruDb.getAllBoorus(),
          ),
          onQuickBooruSubmit: (site) => setState(() {
            configId = site.toEditId();
          }),
          onBooruSubmit: (url) => setState(() {
            configId = EditBooruConfigId.newId(
              booruType: BooruType.fromLegacyId(
                booruDb.getBooruFromUrl(url)?.id,
              ),
              url: url,
            );
          }),
        ),
      ),
      EditBooruConfigId(booruType: BooruType.unknown) && final id =>
        CreateBooruConfigScope(
          id: id,
          config: BooruConfig.defaultConfig(
            booruType: id.booruType,
            url: id.url,
            customDownloadFileNameFormat: null,
          ),
          child: AnalyticsInitStateHook(
            screenName: 'config/create_unknown_booru',
            child: AddUnknownBooruPage(
              setCurrentBooruOnSubmit: widget.setCurrentBooruOnSubmit,
              backgroundColor: widget.backgroundColor,
            ),
          ),
        ),
      final id => _buildNewKnownBooru(id),
    };
  }

  Widget _buildNewKnownBooru(EditBooruConfigId configId) {
    final defaultConfig = BooruConfig.defaultConfig(
      booruType: configId.booruType,
      url: configId.url,
      customDownloadFileNameFormat: null,
    );
    final booruBuilder = ref
        .watch(booruBuilderProvider(defaultConfig.auth))
        ?.createConfigPageBuilder;

    return booruBuilder != null
        ? AddKnownBooru(
            child: booruBuilder(
              context,
              configId,
              backgroundColor: widget.backgroundColor,
            ),
          )
        : Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('Not implemented'),
            ),
          );
  }
}

class AnalyticsInitStateHook extends ConsumerStatefulWidget {
  const AnalyticsInitStateHook({
    required this.screenName,
    required this.child,
    super.key,
  });

  final String screenName;
  final Widget child;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _AnalyticsInitStateHookState();
}

class _AnalyticsInitStateHookState
    extends ConsumerState<AnalyticsInitStateHook> {
  @override
  void initState() {
    super.initState();

    ref
        .read(analyticsProvider)
        .whenData(
          (analytics) => analytics?.logScreenView(widget.screenName),
        );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Need to be stateful to keep the state for analytics
class AddKnownBooru extends ConsumerStatefulWidget {
  const AddKnownBooru({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<AddKnownBooru> createState() => _AddKnownBooruState();
}

class _AddKnownBooruState extends ConsumerState<AddKnownBooru> {
  @override
  Widget build(BuildContext context) {
    return AnalyticsInitStateHook(
      screenName: 'config/create_known_booru',
      child: widget.child,
    );
  }
}

class AddBooruPageInternal extends ConsumerStatefulWidget {
  const AddBooruPageInternal({
    required this.setCurrentBooruOnSubmit,
    super.key,
    this.backgroundColor,
    this.onBooruSubmit,
    this.onQuickBooruSubmit,
    this.quickSetupSites = const [],
  });

  final bool setCurrentBooruOnSubmit;
  final Color? backgroundColor;
  final void Function(String url)? onBooruSubmit;
  final ValueChanged<QuickProfileSite>? onQuickBooruSubmit;
  final List<QuickProfileSite> quickSetupSites;

  @override
  ConsumerState<AddBooruPageInternal> createState() =>
      _AddBooruPageInternalState();
}

class _AddBooruPageInternalState extends ConsumerState<AddBooruPageInternal> {
  final urlController = TextEditingController();
  final booruUrlError = ValueNotifier(left(BooruUrlError.emptyUrl));
  final inputText = ValueNotifier('');
  var showCustomSetup = false;

  @override
  void dispose() {
    urlController.dispose();
    booruUrlError.dispose();
    inputText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor,
      child: showCustomSetup
          ? _buildCustomSetup()
          : QuickProfileSetupPicker(
              sites: widget.quickSetupSites,
              onSelected: (site) => widget.onQuickBooruSubmit?.call(site),
              onCustomSite: () => setState(() => showCustomSetup = true),
              onClose: Navigator.of(context).pop,
            ),
    );
  }

  Widget _buildCustomSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: MediaQuery.viewPaddingOf(context).top,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => showCustomSetup = false),
                icon: const Icon(Symbols.arrow_back),
              ),
              Expanded(
                child: Text(
                  context.t.booru.add_a_booru_site,
                  style: Kurumi.themeOf(context).textTheme.headlineSmall!
                      .copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              IconButton(
                onPressed: Navigator.of(context).pop,
                icon: const Icon(Symbols.close),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(
          thickness: 2,
          endIndent: 16,
          indent: 16,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: ValueListenableBuilder(
            valueListenable: booruUrlError,
            builder: (_, error, _) => AutofillGroup(
              child: KurumiTextFormField(
                validator: (p0) => null,
                autocorrect: false,
                autofillHints: const [
                  AutofillHints.url,
                ],
                keyboardType: TextInputType.url,
                autofocus: true,
                onChanged: (value) {
                  inputText.value = value;
                  booruUrlError.value = createBooruUri(value);
                },
                onFieldSubmitted: error.fold(
                  (l) => null,
                  (r) =>
                      (_) => _onNext(r.toString()),
                ),
                onTapOutside: (event) {
                  FocusScope.of(context).unfocus();
                },
                controller: urlController,
                decoration: InputDecoration(
                  labelText: context.t.booru.site_url,
                  suffixIcon: IconButton(
                    iconSize: 20,
                    onPressed: () {
                      AppClipboard.paste('text/plain').then((value) {
                        if (value != null) {
                          urlController.text = value;
                          inputText.value = value;
                          booruUrlError.value = createBooruUri(value);
                        }
                      });
                    },
                    icon: const Icon(Icons.paste),
                  ),
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: booruUrlError,
          builder: (_, error, _) => error.fold(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: ValueListenableBuilder(
                valueListenable: inputText,
                builder: (_, input, _) => Text(
                  e.message(context, input),
                  style: Kurumi.themeOf(context).textTheme.bodyLarge!.copyWith(
                    color: Kurumi.themeOf(context).colorScheme.error,
                  ),
                ),
              ),
            ),
            (uri) => const SizedBox.shrink(),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: booruUrlError,
          builder: (_, error, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: error.fold(
              (e) => FilledButton(
                onPressed: null,
                child: Text(context.t.booru.next_step),
              ),
              (uri) => FilledButton(
                onPressed: () => _onNext(uri.toString()),
                child: Text(context.t.booru.next_step),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onNext(String url) {
    widget.onBooruSubmit?.call(url);
  }
}

class QuickProfileSetupPicker extends StatelessWidget {
  const QuickProfileSetupPicker({
    required this.sites,
    required this.onSelected,
    required this.onCustomSite,
    super.key,
    this.onClose,
  });

  final List<QuickProfileSite> sites;
  final ValueChanged<QuickProfileSite> onSelected;
  final VoidCallback onCustomSite;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Kurumi.themeOf(context);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t.booru.quick_setup.popular_sites,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onClose case final onClose?)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Symbols.close),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
            child: Text(context.t.booru.quick_setup.description),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
            child: OutlinedButton.icon(
              onPressed: onCustomSite,
              icon: const Icon(Symbols.add_link),
              label: Text(context.t.booru.quick_setup.custom_site),
            ),
          ),
          const Divider(height: 1, thickness: 2, indent: 16, endIndent: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sites.isEmpty ? 1 : sites.length,
              itemBuilder: (context, index) {
                if (sites.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.t.booru.quick_setup.no_sites),
                  );
                }

                final site = sites[index];
                return _QuickProfileSiteTile(
                  key: ValueKey('quick-profile-${site.url}'),
                  site: site,
                  onTap: () => onSelected(site),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickProfileSiteTile extends StatelessWidget {
  const _QuickProfileSiteTile({
    required this.site,
    required this.onTap,
    super.key,
  });

  final QuickProfileSite site;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Kurumi.themeOf(context);

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: Center(
                  child: ConfigAwareWebsiteLogo.fromBooruType(
                    site.booruType,
                    site.url,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        site.profileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (site.authentication ==
                        QuickProfileAuthentication.required) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Container(
                          key: ValueKey(
                            'quick-profile-auth-required-${site.url}',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.t.booru.quick_setup.account_required,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textScaler: MediaQuery.textScalerOf(context).clamp(
                              maxScaleFactor: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Symbols.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

extension BooruUrlErrorX on BooruUrlError {
  String message(BuildContext context, String url) => switch (this) {
    BooruUrlError.nullUrl => 'URL is null',
    BooruUrlError.emptyUrl => context.t.booru.validation_empty_url,
    BooruUrlError.invalidUrlFormat =>
      context.t.booru.validation_invalid_url.replaceAll('{0}', url),
    BooruUrlError.notAnHttpOrHttpsUrl =>
      context.t.booru.validation_invalid_http_url.replaceAll('{0}', url),
    BooruUrlError.redundantWww =>
      context.t.booru.validation_redundant_www.replaceAll('{0}', url),
    BooruUrlError.stringHasInbetweenSpaces =>
      context.t.booru.validation_contains_spaces.replaceAll('{0}', url),
  };
}
