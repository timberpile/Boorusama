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
import '../types/topic_search_origin.dart';
import '../widgets/search_controller.dart';
import '../widgets/search_profile_session.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({this.initialConfig, super.key});

  final BooruConfig? initialConfig;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _origin = ValueNotifier<TopicSearchOrigin?>(null);
  var _originCaptured = false;

  @override
  void initState() {
    super.initState();
    _origin.addListener(_originChanged);
  }

  void _originChanged() {
    setState(() {
      // A chosen Topic owns its source locally even if a later multi-follow
      // clears the identity. Keep the displayed source and query in place.
      if (_origin.value case final origin?) {
        _localProfile = origin.profile;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_originCaptured) {
      _originCaptured = true;
      _origin.value = InheritedInitialSearchQuery.maybeOf(context)
          ?.params
          .topicOrigin;
    }
  }

  @override
  void dispose() {
    _origin.dispose();
    super.dispose();
  }

  var _followGlobalProfile = false;
  SearchProfileSnapshot? _snapshot;
  BooruConfig? _localProfile;

  void _switchProfile(BooruConfig profile, SearchPageController controller) {
    final local =
        DestinationScope.maybeOf(context) != null ||
        _localProfile != null ||
        InheritedInitialSearchQuery.maybeOf(context)
                ?.params
                .originatingTopicId !=
            null;
    final current = local
        ? (_localProfile ?? widget.initialConfig ?? ref.readConfig)
        : (_followGlobalProfile
              ? ref.read(currentBooruConfigProvider)
              : ref.readConfig);
    if (profile.id == current.id &&
        (local || profile.id == ref.read(currentBooruConfigProvider).id)) {
      return;
    }
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
    final local =
        DestinationScope.maybeOf(context) != null ||
        _localProfile != null ||
        InheritedInitialSearchQuery.maybeOf(context)
                ?.params
                .originatingTopicId !=
            null;
    final config = local
        ? (_localProfile ??= widget.initialConfig ?? ref.readConfig)
        : _followGlobalProfile
        ? ref.watch(currentBooruConfigProvider)
        : ref.watchConfig;
    final builder = ref
        .watch(booruBuilderProvider(config.auth))
        ?.searchPageBuilder;
    final params =
        (InheritedInitialSearchQuery.maybeOf(context)?.params ??
                const SearchParams())
            .withOriginatingTopic(
              _origin.value?.topic.id,
              topicOrigin: _origin.value,
            );

    final page = KeyedSubtree(
      key: ValueKey((config.id, config.auth)),
      child: Builder(
        builder: (context) => builder != null
            ? builder(
                context,
                _snapshot == null
                    ? params
                    : SearchParams(
                        originatingTopicId: params.originatingTopicId,
                        topicOrigin: params.topicOrigin,
                      ),
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
        child: TopicSearchOriginScope(origin: _origin, child: page),
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
