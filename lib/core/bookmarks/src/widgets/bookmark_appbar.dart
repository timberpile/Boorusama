// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

class BookmarkAppBar extends StatelessWidget {
  const BookmarkAppBar({this.title, this.textScaler, super.key});

  final String? title;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) => KurumiAppBar(
    title: Text(title ?? context.t.bookmark.title, textScaler: textScaler),
  );
}
