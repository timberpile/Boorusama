import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../foundation/clipboard.dart';
import '../posts/details_parts/types.dart';
import '../posts/details_parts/widgets.dart';
import 'local_media_actions.dart';
import 'local_media_models.dart';
import 'local_media_providers.dart';
import 'local_media_reference.dart';
import 'local_media_tags.dart';

const localMediaDetailsParts = {
  DetailsPart.toolbar,
  DetailsPart.tags,
  DetailsPart.fileDetails,
};

PostDetailsUIBuilder localMediaDetailsUi(LocalMediaReference reference) {
  Widget Function(BuildContext) itemSection(
    Widget Function(BuildContext, LocalMediaItem) build,
  ) =>
      (_) => SliverToBoxAdapter(
        child: Consumer(
          builder: (context, ref, _) {
            final item = ref
                .watch(localMediaPresentationProvider(reference))
                .valueOrNull
                ?.item;
            return item == null
                ? const SizedBox.shrink()
                : build(context, item);
          },
        ),
      );

  Widget toolbar(BuildContext context) => SliverToBoxAdapter(
    child: LocalMediaActions(reference, key: ValueKey(reference)),
  );
  return PostDetailsUIBuilder(
    preview: {DetailsPart.toolbar: toolbar},
    full: {
      DetailsPart.toolbar: toolbar,
      DetailsPart.tags: itemSection(
        (context, item) => item.tags.isEmpty
            ? const SizedBox.shrink()
            : LocalMediaTagsTile(tags: item.tags),
      ),
      DetailsPart.fileDetails: itemSection((context, item) {
        final t = context.t.local_media;
        final sha256 = item.reference.sha256;
        return FileDetailsSection(
          post: item.toPost(),
          rating: item.rating,
          dateLabel: item.createdAt == null ? t.import_date : t.creation_date,
          customDetails: [
            if (item.createdAt != null)
              FileDetailTile(
                title: t.import_date,
                valueLabel: item.importedAt.fuzzify(
                  locale: Localizations.localeOf(context),
                ),
              ),
            FileDetailTile(
              title: t.sha256,
              valueLabel: sha256,
              valueMaxLines: 1,
              valueTrailing: Tooltip(
                message: t.copy_sha256,
                child: Icon(
                  Icons.copy,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onValueTap: () => AppClipboard.copyWithDefaultToast(
                context,
                sha256,
              ),
            ),
          ],
        );
      }),
    },
  );
}
