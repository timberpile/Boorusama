// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../core/configs/config/providers.dart';
import '../../../../core/posts/details/providers.dart';
import '../../../../core/posts/details/types.dart';
import '../../../../core/posts/details_pageview/widgets.dart';
import '../../../../core/posts/post/types.dart';
import '../../configs/providers.dart';
import '../../favorites/providers.dart';
import '../../moebooru.dart';
import '../../posts/types.dart';

class MoebooruFavoriteUsersLoader extends ConsumerStatefulWidget {
  const MoebooruFavoriteUsersLoader({
    required this.post,
    required this.child,
    super.key,
  });

  final Post post;
  final Widget child;

  @override
  ConsumerState<MoebooruFavoriteUsersLoader> createState() =>
      _MoebooruFavoriteUsersLoaderState();
}

class _MoebooruFavoriteUsersLoaderState
    extends ConsumerState<MoebooruFavoriteUsersLoader> {
  PostDetailsPageViewController? _controller;
  var _fetchSkipped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;

    _controller = PostDetailsPageViewScope.of(context);
    _controller!.slideshowController.state.addListener(_onSlideshowChanged);
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant MoebooruFavoriteUsersLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) _scheduleLoad();
  }

  bool get _slideshowActive =>
      _controller?.slideshowController.isRunning ?? false;

  void _scheduleLoad() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _loadFavoriteUsers();
  });

  void _onSlideshowChanged() {
    if (_slideshowActive) {
      _fetchSkipped = false;
    } else if (_fetchSkipped) {
      _fetchSkipped = false;
      _loadFavoriteUsers();
    }
  }

  Future<void> _loadFavoriteUsers() async {
    final config = ref.readConfigAuth;
    final loginDetails = ref.read(moebooruLoginDetailsProvider(config));
    final booru = ref.read(moebooruProvider);

    if (!booru.supportsFavorite(config.url) || !loginDetails.hasLogin()) return;
    if (_slideshowActive) {
      _fetchSkipped = true;
      return;
    }

    await ref
        .read(moebooruFavoritesProvider(widget.post.id).notifier)
        .loadFavoriteUsers();
  }

  @override
  void dispose() {
    _controller?.slideshowController.state.removeListener(_onSlideshowChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MoebooruFavoritesLoader extends ConsumerStatefulWidget {
  const MoebooruFavoritesLoader({
    required this.data,
    required this.controller,
    required this.child,
    super.key,
  });

  final PostDetailsData<Post> data;
  final PostDetailsPageViewController controller;
  final Widget child;

  @override
  ConsumerState<MoebooruFavoritesLoader> createState() =>
      _MoebooruFavoritesLoaderState();
}

class _MoebooruFavoritesLoaderState
    extends ConsumerState<MoebooruFavoritesLoader> {
  late PostDetailsData<Post> data = widget.data;
  late var _pageViewController = widget.controller;

  List<Post> get posts => data.posts;
  PostDetailsController<Post> get controller => data.controller;

  var _fetchFavSlideShowSkipped = false;

  bool get _slideshowActive =>
      _pageViewController.slideshowController.isRunning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavoriteUsers(posts[controller.initialPage].id);
    });

    data.controller.currentPage.addListener(_onPageChanged);
    _pageViewController.slideshowController.state.addListener(
      _onSlideShowChanged,
    );
  }

  @override
  void didUpdateWidget(covariant MoebooruFavoritesLoader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data) {
      controller.currentPage.removeListener(_onPageChanged);
      setState(() {
        data = widget.data;
        controller.currentPage.addListener(_onPageChanged);
      });
    }

    if (oldWidget.controller != widget.controller) {
      _cleanUpPageViewController();
      _pageViewController = widget.controller;
      _pageViewController.slideshowController.state.addListener(
        _onSlideShowChanged,
      );
    }
  }

  void _onSlideShowChanged() {
    if (!_slideshowActive) {
      if (_fetchFavSlideShowSkipped) {
        _fetchFavSlideShowSkipped = false;
        _loadFavoriteUsers(posts[controller.currentPage.value].id);
      }
    } else {
      _fetchFavSlideShowSkipped = false;
    }
  }

  void _onPageChanged() {
    _loadFavoriteUsers(posts[controller.currentPage.value].id);
  }

  Future<void> _loadFavoriteUsers(int postId) async {
    final config = ref.readConfigAuth;
    final loginDetails = ref.watch(moebooruLoginDetailsProvider(config));
    final booru = ref.read(moebooruProvider);

    if (booru.supportsFavorite(config.url) && loginDetails.hasLogin()) {
      // Prevent loading favorites if the slideshow is active
      if (_slideshowActive) {
        _fetchFavSlideShowSkipped = true;
        return;
      }

      return ref
          .read(moebooruFavoritesProvider(postId).notifier)
          .loadFavoriteUsers();
    }
  }

  void _cleanUpPageViewController() {
    _pageViewController.slideshowController.state.removeListener(
      _onSlideShowChanged,
    );
  }

  @override
  void dispose() {
    controller.currentPage.removeListener(_onPageChanged);
    _cleanUpPageViewController();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
