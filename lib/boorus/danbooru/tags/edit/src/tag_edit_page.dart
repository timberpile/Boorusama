// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/posts/rating/types.dart';
import '../../../../../core/posts/listing/providers.dart';
import '../../../posts/details/providers.dart';
import '../../../posts/post/types.dart';
import '../../_shared/tag_list_notifier.dart';
import 'providers/providers.dart';
import 'providers/tag_edit_notifier.dart';
import 'tag_edit_content.dart';
import 'tag_edit_page_scaffold.dart';
import 'widgets/tag_edit_rating_selector_section.dart';
import 'widgets/tag_edit_submit_button.dart';

class DanbooruTagEditPage extends ConsumerWidget {
  const DanbooruTagEditPage({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final viewer = ref.watchConfigViewer;
    final tags = ref.watch(danbooruTagListProvider(config));
    final initialRating = tags.containsKey(post.id)
        ? tags[post.id]!.rating
        : post.rating;
    final effectiveTags = tags.containsKey(post.id)
        ? tags[post.id]!.allTags
        : post.tags.toSet();
    final mediaResolver = ref.watch(danbooruMediaUrlResolverProvider(config));
    final gridThumbnailSettings = ref.watch(
      gridThumbnailSettingsProvider(config),
    );
    final gridThumbnailUrlGenerator = ref.watch(
      gridThumbnailUrlGeneratorProvider(config),
    );
    final placeholderMedia = gridThumbnailUrlGenerator.resolve(
      post,
      settings: gridThumbnailSettings,
    );

    return PostTagEditEditor(
      params: TagEditParams(
        initialTags: effectiveTags,
        postId: post.id,
        imageAspectRatio: post.aspectRatio ?? 1,
        imageUrl: mediaResolver.resolveMediaUrl(post, viewer),
        placeholderMedia: placeholderMedia,
        initialRating: initialRating,
        post: post,
      ),
    );
  }
}

class PostTagEditEditor extends ConsumerStatefulWidget {
  const PostTagEditEditor({
    required this.params,
    super.key,
    this.preview,
    this.searchConfig,
    this.onSubmit,
    this.allowUnrated = false,
  });

  final TagEditParams params;
  final Widget? preview;
  final bool allowUnrated;
  final BooruConfigAuth? searchConfig;
  final Future<void> Function(BuildContext, Set<String>, Rating?)? onSubmit;

  @override
  ConsumerState<PostTagEditEditor> createState() => _PostTagEditEditorState();
}

class _PostTagEditEditorState extends ConsumerState<PostTagEditEditor> {
  final _scrollController = ScrollController();
  var _saving = false;

  Future<void> _submit(
    BuildContext context,
    Set<String> tags,
    Rating? rating,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit!(context, tags, rating);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialRating = widget.params.initialRating;
    return TagEditParamsProvider(
      params: widget.params,
      child: TagEditPageScaffold(
        scrollController: _scrollController,
        preview: widget.preview,
        searchConfig: widget.searchConfig,
        content: TagEditContent(
          ratingSelector: TagEditRatingSelectorSection(
            rating: initialRating,
            allowUnrated: widget.allowUnrated,
            onChanged: (value) {
              ref
                      .read(
                        selectedTagEditRatingProvider(initialRating).notifier,
                      )
                      .state =
                  value;
            },
          ),
          scrollController: _scrollController,
        ),
        submitButton: TagEditSubmitButton(
          enabled: !_saving,
          onSubmit: widget.onSubmit == null ? null : _submit,
        ),
      ),
    );
  }
}
