// Package imports:
import 'package:kurumi/cupertino.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import '../../../foundation/display.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/widgets.dart';
import 'widgets/comment_side_sheet_container.dart';

Future<T?> showCommentPage<T>(
  BuildContext context, {
  required BooruConfig config,
  required Widget Function(BuildContext context, bool useAppBar) builder,
  RouteSettings? settings,
}) {
  Widget scopedBuilder(BuildContext context, bool useAppBar) =>
      CurrentBooruConfigScope(
        config: config,
        child: Builder(
          builder: (context) => builder(context, useAppBar),
        ),
      );

  return Screen.of(context).size == ScreenSize.small
      ? Navigator.of(context).push(
          CupertinoPageRoute(
            settings: settings,
            builder: (context) => scopedBuilder(context, true),
          ),
        )
      : Kurumi.showSideSheetFromRight(
          settings: settings,
          width: MediaQuery.widthOf(context) * 0.41,
          body: CommentSideSheetContainer(
            builder: scopedBuilder,
          ),
          context: context,
        );
}
