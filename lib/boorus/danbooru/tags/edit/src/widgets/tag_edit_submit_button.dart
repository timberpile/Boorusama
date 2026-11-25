// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/posts/rating/types.dart';
import '../../../_shared/tag_list_notifier.dart';
import '../providers/providers.dart';
import '../providers/tag_edit_notifier.dart';

class TagEditSubmitButton extends ConsumerWidget {
  const TagEditSubmitButton({super.key, this.onSubmit, this.enabled = true});

  final void Function(BuildContext, Set<String>, Rating?)? onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = TagEditParamsProvider.of(context);
    final initialRating = params.initialRating;
    final postId = params.postId;
    final addedTags = ref.watch(
      tagEditProvider(params).select((value) => value.toBeAdded),
    );
    final removedTags = ref.watch(
      tagEditProvider(params).select((value) => value.toBeRemoved),
    );
    final rating = ref.watch(selectedTagEditRatingProvider(initialRating));

    final save =
        enabled &&
            (addedTags.isNotEmpty ||
                removedTags.isNotEmpty ||
                rating != initialRating)
        ? () {
            if (onSubmit case final submit?) {
              submit(
                context,
                ref.read(tagEditProvider(params)).tags,
                rating,
              );
              return;
            }
            ref
                .read(danbooruTagListProvider(ref.readConfigAuth).notifier)
                .setTags(
                  postId,
                  addedTags: addedTags.toList(),
                  removedTags: removedTags.toList(),
                  rating: rating != initialRating ? rating : null,
                );
            Navigator.of(context).pop();
          }
        : null;
    return onSubmit != null
        ? IconButton(
            onPressed: save,
            tooltip: context.t.generic.action.save,
            icon: const Icon(Icons.save_outlined),
          )
        : TextButton(onPressed: save, child: Text('Submit'.hc));
  }
}
