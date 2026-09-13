// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// Project imports:
import '../../../widgets/widgets.dart';
import '../widgets/bookmark_scroll_view.dart';
import '../types/bookmark_view.dart';

class BookmarkPage extends ConsumerStatefulWidget {
  const BookmarkPage({
    this.view = const BookmarkView.all(),
    this.title,
    super.key,
  });

  final BookmarkView view;
  final String? title;

  @override
  ConsumerState<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends ConsumerState<BookmarkPage> {
  final _searchController = TextEditingController();
  final _scrollController = AutoScrollController();

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
          view: widget.view,
          title: widget.title,
        ),
      ),
    );
  }
}
