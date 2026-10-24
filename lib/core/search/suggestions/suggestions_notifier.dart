import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../../configs/config/providers.dart';
import '../../configs/config/types.dart';
import '../../tags/autocompletes/providers.dart';
import '../../tags/autocompletes/types.dart';
import '../../tags/configs/providers.dart';
import '../../tags/local/providers.dart';
import '../queries/types.dart';

class SuggestionsNotifier
    extends FamilyNotifier<SuggestionsState, BooruConfigAuth> {
  Timer? _timer;
  var _generation = 0;
  var _disposed = false;
  String? _pendingQuery;

  @override
  SuggestionsState build(BooruConfigAuth arg) {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _cancelPending();
    });
    return SuggestionsState.initial();
  }

  void _cancelPending() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _pendingQuery = null;
  }

  void clear() {
    _cancelPending();
    state = state.clear();
  }

  void setCategory(String? category) {
    if (state.category == category) return;
    _cancelPending();
    state = state.copyWith(
      category: () => category,
      suggestions: <String, IList<AutocompleteData>>{}.lock,
    );
  }

  void getSuggestions(String query) {
    final sanitized = sanitizeQuery(query);
    if (_pendingQuery == sanitized) return;
    _cancelPending();
    if (sanitized.isEmpty || state.hasSuggestions(sanitized)) return;

    final generation = _generation;
    final category = state.category;
    final autocompleteRepo = ref.read(autocompleteRepoProvider(arg));
    final tagInfo = ref.read(tagInfoProvider);
    final loginDetails = ref.read(booruLoginDetailsProvider(arg));
    _pendingQuery = sanitized;

    bool current() => !_disposed && generation == _generation;
    _timer = Timer(const Duration(milliseconds: 200), () async {
      try {
        final data = await autocompleteRepo.getAutocomplete(
          AutocompleteQuery(text: sanitized, category: category),
        );
        if (!current()) return;
        var filtered = filterNsfw(
          data,
          tagInfo.r18Tags,
          shouldFilter: loginDetails.hasSoftSFW,
        );

        state = state.addSuggestions(sanitized, filtered);
        // Publish the server response before waiting for optional cache I/O.
        // A cache enrichment failure must not discard usable API suggestions.
        if (filtered.isNotEmpty) {
          try {
            final cache = await ref.read(tagCacheRepositoryProvider.future);
            if (!current()) return;
            final resolved = await cache.resolveTags(
              arg.url,
              filtered.map((tag) => tag.value).toList(),
            );
            if (!current()) return;
            final found = {for (final tag in resolved.found) tag.tagName: tag};
            filtered = filtered
                .map((tag) {
                  final cached = found[tag.value];
                  return cached != null ? tag.resolveCached(cached) : tag;
                })
                .toList()
                .lock;
          } catch (_) {
            if (!current()) return;
          }
        }
        if (current()) state = state.addSuggestions(sanitized, filtered);
      } catch (_) {
        // No global/stale fallback. Failed requests remain retryable rather
        // than becoming a cached successful empty response.
      } finally {
        if (current()) _pendingQuery = null;
      }
    });
  }
}

class SuggestionsState extends Equatable {
  const SuggestionsState({required this.suggestions, this.category});

  SuggestionsState.initial()
    : suggestions = <String, IList<AutocompleteData>>{}.lock,
      category = null;

  final IMap<String, IList<AutocompleteData>> suggestions;
  final String? category;

  SuggestionsState copyWith({
    IMap<String, IList<AutocompleteData>>? suggestions,
    String? Function()? category,
  }) => SuggestionsState(
    suggestions: suggestions ?? this.suggestions,
    category: category != null ? category() : this.category,
  );

  SuggestionsState clear() => SuggestionsState.initial();
  bool hasSuggestions(String query) => suggestions.containsKey(query);
  IList<AutocompleteData>? getSuggestionsFor(String query) =>
      suggestions[query];
  SuggestionsState addSuggestions(String query, IList<AutocompleteData> data) =>
      copyWith(suggestions: suggestions.add(query, data));

  @override
  List<Object?> get props => [suggestions, category];
}

final suggestionsNotifierProvider =
    NotifierProvider.family<
      SuggestionsNotifier,
      SuggestionsState,
      BooruConfigAuth
    >(SuggestionsNotifier.new);

// Kept for source compatibility with existing consumers. Search suggestions no
// longer read or populate this cross-profile fallback.
final fallbackSuggestionsProvider =
    StateProvider.autoDispose<IList<AutocompleteData>>(
      (ref) => <AutocompleteData>[].lock,
    );

final suggestionProvider = Provider.autoDispose
    .family<IList<AutocompleteData>, (BooruConfigAuth, String)>(
      (ref, params) {
        final (config, tag) = params;
        final state = ref.watch(suggestionsNotifierProvider(config));
        return state.getSuggestionsFor(sanitizeQuery(tag)) ??
            <AutocompleteData>[].lock;
      },
      dependencies: [suggestionsNotifierProvider],
    );
