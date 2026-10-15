// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../router.dart';
import '../../../suggestions/providers.dart';
import '../routes/params.dart';
import '../widgets/search_controller.dart';
import '../widgets/search_profile_session.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  var _followGlobalProfile = false;
  SearchProfileSnapshot? _snapshot;

  void _switchProfile(BooruConfig profile, SearchPageController controller) {
    if (profile.id ==
            (_followGlobalProfile
                ? ref.read(currentBooruConfigProvider).id
                : ref.readConfig.id) &&
        profile.id == ref.read(currentBooruConfigProvider).id) {
      return;
    }
    ref.invalidate(fallbackSuggestionsProvider);
    setState(() {
      _snapshot = SearchProfileSnapshot.capture(controller);
      _followGlobalProfile = true;
    });
    ref.read(currentBooruConfigProvider.notifier).update(profile);
  }

  @override
  Widget build(BuildContext context) {
    final config = _followGlobalProfile
        ? ref.watch(currentBooruConfigProvider)
        : ref.watchConfig;
    final builder = ref
        .watch(booruBuilderProvider(config.auth))
        ?.searchPageBuilder;
    final params =
        InheritedInitialSearchQuery.maybeOf(context)?.params ??
        const SearchParams();

    return CurrentBooruConfigScope(
      config: config,
      child: SearchProfileSession(
        snapshot: _snapshot,
        onSwitch: _switchProfile,
        // Recreate engine widgets, parsers and result controllers together.
        child: KeyedSubtree(
          key: ValueKey((config.id, config.auth)),
          child: Builder(
            builder: (context) => builder != null
                ? builder(
                    context,
                    _snapshot == null ? params : const SearchParams(),
                  )
                : const UnimplementedPage(),
          ),
        ),
      ),
    );
  }
}

class InheritedInitialSearchQuery extends InheritedWidget {
  const InheritedInitialSearchQuery({
    required this.params,
    required super.child,
    super.key,
  });

  final SearchParams params;

  static InheritedInitialSearchQuery? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InheritedInitialSearchQuery>();
  }

  static InheritedInitialSearchQuery? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InheritedInitialSearchQuery>();
  }

  @override
  bool updateShouldNotify(InheritedInitialSearchQuery oldWidget) {
    return params != oldWidget.params;
  }
}
