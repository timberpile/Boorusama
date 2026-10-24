// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/router.dart';
import '../../../../../../foundation/display.dart';
import '../pages/edit_saved_search_sheet.dart';
import '../types/saved_search.dart';

void goToSavedSearchCreatePage(
  BuildContext context, {
  String? initialValue,
}) {
  if (kPreferredLayout.isMobile) {
    Kurumi.showAppModalBottomSheet(
      context: context,
      resizeToAvoidBottomInset: true,
      routeSettings: const RouteSettings(
        name: RouterPageConstant.savedSearchCreate,
      ),
      builder: (_) => CreateSavedSearchSheet(
        initialValue: initialValue,
      ),
    );
  } else {
    showGeneralDialog(
      context: context,
      routeSettings: const RouteSettings(
        name: RouterPageConstant.savedSearchCreate,
      ),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      pageBuilder: (context, _, _) {
        return Dialog(
          child: Container(
            width: MediaQuery.widthOf(context) * 0.8,
            height: MediaQuery.heightOf(context) * 0.8,
            margin: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(8),
              ),
            ),
            child: CreateSavedSearchSheet(
              initialValue: initialValue,
            ),
          ),
        );
      },
    );
  }
}

void goToSavedSearchPatchPage(
  BuildContext context,
  SavedSearch savedSearch,
) {
  Kurumi.showAppModalBottomSheet(
    context: context,
    resizeToAvoidBottomInset: true,
    routeSettings: const RouteSettings(
      name: RouterPageConstant.savedSearchPatch,
    ),
    builder: (_) => EditSavedSearchSheet(
      savedSearch: savedSearch,
    ),
  );
}

void goToSavedSearchEditPage(WidgetRef ref) {
  ref.pushRoute(
    Uri(
      pathSegments: [
        '',
        'danbooru',
        'saved_searches',
      ],
    ).toString(),
  );
}
