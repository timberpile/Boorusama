// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../routes/route_utils.dart';
import '../../../../content/types.dart';
import '../../../details_parts/types.dart';

class AddCustomDetailsButton extends ConsumerWidget {
  const AddCustomDetailsButton({
    this.galleryAccess,
    this.galleryBuilder,
    super.key,
  });

  final ContentAccessContext? galleryAccess;
  final PostDetailsUIBuilder? galleryBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: KurumiDottedBorderButton(
        borderColor: Kurumi.themeOf(context).colorScheme.hintColor,
        onTap: () {
          final access = galleryAccess;
          if (access != null) {
            goToGalleryDetailsLayoutManager(
              ref,
              access: access,
              uiBuilder: galleryBuilder!,
            );
          } else {
            goToDetailsLayoutManagerForFullWidgets(ref);
          }
        },
        title: context.t.settings.appearance.customize,
      ),
    );
  }
}
