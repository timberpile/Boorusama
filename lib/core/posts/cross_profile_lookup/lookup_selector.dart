import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../configs/config/types.dart';
import '../../configs/config/providers.dart';
import 'lookup_preferences.dart';
import 'types.dart';

String lookupMethodLabel(BuildContext context, PostLookupMatchKind method) {
  final t = context.t.post.cross_profile;
  return switch (method) {
    PostLookupMatchKind.exactFile => t.exact_method,
    PostLookupMatchKind.pixivSource => t.pixiv_method,
    PostLookupMatchKind.sourceUrl => t.source_method,
    PostLookupMatchKind.similarImage => t.iqdb_method,
  };
}

Future<List<LookupTarget>?> selectLookupTargets(
  BuildContext context,
  ProviderContainer container, {
  required Set<PostLookupMatchKind> Function(BooruConfig) available,
  String? excludedProfileId,
  bool settings = false,
  bool enriching = false,
  bool useSourceDefaults = false,
  PostLookupMatchKind? preferredMethod,
  bool rememberChoices = true,
}) async {
  final profiles = container.read(orderedProfileConfigsProvider);
  final preferences = container.read(lookupPreferencesProvider);
  final choices = <String, LookupProfileChoice>{
    ...?preferences.profiles,
  };
  if (preferences.profiles == null) {
    for (final profile in profiles) {
      if (!configuredLookupMethods(profile)
          .contains(PostLookupMatchKind.exactFile)) {
        continue;
      }
      choices[profile.id] = (
        endpoint: lookupEndpoint(profile),
        methods: const {PostLookupMatchKind.exactFile},
      );
    }
  }

  final methodsByProfile = {
    for (final profile in profiles)
      if (profile.id != excludedProfileId)
        if (available(profile) case final methods when methods.isNotEmpty)
          profile: methods,
  };
  if (methodsByProfile.isEmpty && !settings) {
    Kurumi.showErrorToast(
      context,
      context.t.post.cross_profile.no_matching_profiles,
    );
    return null;
  }

  final requiresCredentials = {
    for (final entry in methodsByProfile.entries)
      if (entry.value.contains(PostLookupMatchKind.similarImage) &&
          !supportsIqdbLookup(entry.key))
        entry.key,
  };
  final selectableMethods = {
    for (final entry in methodsByProfile.entries)
      entry.key: !settings && requiresCredentials.contains(entry.key)
          ? entry.value.difference({PostLookupMatchKind.similarImage})
          : entry.value,
  };
  Set<PostLookupMatchKind> methodsFor(BooruConfig profile) {
    final saved = choices[profile.id];
    return saved?.endpoint == lookupEndpoint(profile)
        ? saved!.methods
        : const {};
  }

  Set<PostLookupMatchKind> defaultsFor(Set<PostLookupMatchKind> available) {
    if (preferredMethod != null && available.contains(preferredMethod)) {
      return {preferredMethod};
    }
    if (available.contains(PostLookupMatchKind.exactFile)) {
      return {PostLookupMatchKind.exactFile};
    }
    return available.difference({PostLookupMatchKind.similarImage});
  }

  if (preferences.profiles == null) {
    for (final entry in methodsByProfile.entries) {
      if (preferredMethod != null) {
        choices[entry.key.id] = (
          endpoint: lookupEndpoint(entry.key),
          methods: defaultsFor(entry.value),
        );
        continue;
      }
      if (!useSourceDefaults && !supportsPixivArtworkTarget(entry.key)) {
        continue;
      }
      final defaults = entry.value.difference({
        PostLookupMatchKind.exactFile,
        PostLookupMatchKind.similarImage,
      });
      if (defaults.isEmpty) continue;
      choices[entry.key.id] = (
        endpoint: lookupEndpoint(entry.key),
        methods: {...methodsFor(entry.key), ...defaults},
      );
    }
  }

  void setMethods(BooruConfig profile, Set<PostLookupMatchKind> methods) {
    choices[profile.id] = (
      endpoint: lookupEndpoint(profile),
      methods: Set.unmodifiable(methods),
    );
  }

  List<LookupTarget> selectedTargets() => [
    for (final entry in selectableMethods.entries)
      if (methodsFor(entry.key).intersection(entry.value) case final methods
          when methods.isNotEmpty)
        (profile: entry.key, methods: Set.unmodifiable(methods)),
  ];

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final t = context.t.post.cross_profile;
        final targets = selectedTargets();
        final hasUnselectedMethods = selectableMethods.entries.any(
          (entry) => !methodsFor(entry.key).containsAll(entry.value),
        );
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.matching_profiles,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(t.matching_profiles_description),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: hasUnselectedMethods
                          ? () => setState(() {
                              for (final entry in selectableMethods.entries) {
                                final current = methodsFor(entry.key);
                                if (current.containsAll(entry.value)) continue;
                                setMethods(entry.key, {
                                  ...current,
                                  ...entry.value,
                                });
                              }
                            })
                          : null,
                      child: Text(t.select_all_profiles),
                    ),
                    TextButton(
                      onPressed: targets.isEmpty
                          ? null
                          : () => setState(() {
                              for (final target in targets) {
                                setMethods(
                                  target.profile,
                                  methodsFor(target.profile)
                                      .difference(target.methods),
                                );
                              }
                            }),
                      child: Text(t.clear_profiles),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: [
                      if (methodsByProfile.isEmpty)
                        Text(t.no_matching_profiles),
                      for (final entry in methodsByProfile.entries)
                        ListTile(
                          title: Text(entry.key.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                children: [
                                  for (final method in entry.value)
                                    FilterChip(
                                      label: Text(
                                        lookupMethodLabel(context, method),
                                      ),
                                      selected: methodsFor(entry.key)
                                          .contains(method),
                                      onSelected:
                                          !selectableMethods[entry.key]!
                                              .contains(method)
                                          ? null
                                          : (selected) => setState(() {
                                              final next = {
                                                ...methodsFor(entry.key),
                                              };
                                              if (selected) {
                                                next.add(method);
                                              } else {
                                                next.remove(method);
                                              }
                                              setMethods(entry.key, next);
                                            }),
                                    ),
                                ],
                              ),
                              if (requiresCredentials.contains(entry.key))
                                Text(t.iqdb_credentials_required),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: FilledButton(
                    onPressed: !settings && targets.isEmpty
                        ? null
                        : () async {
                            final enableIqdb =
                                targets.any(
                                  (target) => target.methods.contains(
                                    PostLookupMatchKind.similarImage,
                                  ),
                                ) &&
                                !container
                                    .read(lookupPreferencesProvider)
                                    .allowIqdb;
                            if (enableIqdb && !await _confirmIqdb(context)) {
                              return;
                            }
                            if (context.mounted) {
                              Navigator.pop(context, enableIqdb);
                            }
                          },
                    child: Text(
                      settings
                          ? context.t.generic.action.save
                          : enriching
                          ? t.enrich_selected
                          : t.search_selected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (confirmed == null || !context.mounted) return null;
  if (!rememberChoices) return selectedTargets();
  try {
    await container
        .read(lookupPreferencesProvider.notifier)
        .saveProfiles(choices, enableIqdb: confirmed);
  } catch (_) {
    if (context.mounted) {
      Kurumi.showErrorToast(context, context.t.local_media.operation_failed);
    }
    return null;
  }
  return selectedTargets();
}

Future<bool> _confirmIqdb(BuildContext context) async {
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => KurumiDialog(
      width: 460,
      screenInset: 16,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t.post.cross_profile.iqdb_consent_title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(context.t.post.cross_profile.iqdb_consent_description),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.t.generic.action.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      context.t.post.cross_profile.iqdb_consent_enable,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return approved ?? false;
}
