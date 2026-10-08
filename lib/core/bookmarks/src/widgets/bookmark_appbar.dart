// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

class BookmarkAppBar extends StatelessWidget {
  const BookmarkAppBar({this.title, super.key});

  final String? title;

  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title ?? context.t.bookmark.title),
  );
}
