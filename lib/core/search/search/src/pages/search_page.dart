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
import '../../../../navigation/destination_profile_scope.dart';
import '../../../suggestions/providers.dart';
import '../routes/params.dart';
import '../widgets/search_controller.dart';
import '../widgets/search_profile_session.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({this.initialConfig, super.key});

  final BooruConfig? initialConfig;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  var _followGlobalProfile = false;
  SearchProfileSnapshot? _snapshot;
  BooruConfig? _localProfile;

  void _switchProfile(BooruConfig profile, SearchPageController controller) {
    final local = DestinationScope.maybeOf(context) != null;
    final current = local
        ? (_localProfile ?? widget.initialConfig ?? ref.readConfig)
        : (_followGlobalProfile
              ? ref.read(currentBooruConfigProvider)
              : ref.readConfig);
    if (profile.id == current.id &&
        (local || profile.id == ref.read(currentBooruConfigProvider).id))
      return;
    if (local) {
      setState(() {
        _snapshot = SearchProfileSnapshot.capture(controller);
        _localProfile = profile;
      });
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
    final local = DestinationScope.maybeOf(context) != null;
    final config = local
        ? (_localProfile ??= widget.initialConfig ?? ref.readConfig)
        : _followGlobalProfile
        ? ref.watch(currentBooruConfigProvider)
        : ref.watchConfig;
    final builder = ref
        .watch(booruBuilderProvider(config.auth))
        ?.searchPageBuilder;
    final params =
        InheritedInitialSearchQuery.maybeOf(context)?.params ??
        const SearchParams();

    final page = KeyedSubtree(
      key: ValueKey((config.id, config.auth)),
      child: Builder(
        builder: (context) => builder != null
            ? builder(
                context,
                _snapshot == null ? params : const SearchParams(),
              )
            : const UnimplementedPage(),
      ),
    );
    return CurrentBooruConfigScope(
      config: config,
      child: SearchProfileSession(
        local: local,
        snapshot: _snapshot,
        onSwitch: _switchProfile,
        child: page,
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
