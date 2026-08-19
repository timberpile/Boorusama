// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// Project imports:
import '../../../widgets/widgets.dart';
import '../providers/bookmark_group_providers.dart';
import '../widgets/bookmark_scroll_view.dart';
import 'bookmark_group_browser_page.dart';

class BookmarkPage extends StatelessWidget {
  const BookmarkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const BookmarkGroupBrowserPage();
  }
}

class BookmarkContentPage extends ConsumerStatefulWidget {
  const BookmarkContentPage({required this.selectedGroupId, super.key});

  final int? selectedGroupId;

  @override
  ConsumerState<BookmarkContentPage> createState() =>
      _BookmarkContentPageState();
}

class _BookmarkContentPageState extends ConsumerState<BookmarkContentPage> {
  final _searchController = TextEditingController();
  final _scrollController = AutoScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(selectedBookmarkGroupIdProvider.notifier).state =
            widget.selectedGroupId;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomContextMenuOverlay(
      child: Scaffold(
        body: BookmarkScrollView(
          scrollController: _scrollController,
          searchController: _searchController,
        ),
      ),
    );
  }
}
