// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/posts/rating/types.dart';
import '../../../../configs/providers.dart';
import 'tag_how_to_rate_button.dart';

class TagEditRatingSelectorSection extends ConsumerWidget {
  const TagEditRatingSelectorSection({
    required this.rating,
    required this.onChanged,
    this.allowUnrated = false,
    super.key,
  });

  final Rating? rating;
  final bool allowUnrated;
  final void Function(Rating rating) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final loginDetails = ref.watch(danbooruLoginDetailsProvider(config));

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 360;
        final selector = KurumiSegmentedButton(
          segments: {
            if (allowUnrated)
              Rating.unknown: context.t.search_options.values.unrated,
            for (final rating in Rating.values.where(
              (rating) => rating != Rating.unknown,
            ))
              rating: compact
                  ? rating.name.sentenceCase.getFirstCharacter().toUpperCase()
                  : rating.name.sentenceCase,
          },
          initialValue: rating,
          onChanged: onChanged,
          fixedWidth: !allowUnrated && constraints.maxWidth < 360 ? 36 : null,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text(
                    'Rating',
                    style: Kurumi.themeOf(context).textTheme.titleLarge,
                  ),
                  if (!allowUnrated && !loginDetails.hasStrictSFW)
                    const TagHowToRateButton(),
                ],
              ),
            ),
            Center(
              child: allowUnrated
                  ? FittedBox(fit: BoxFit.scaleDown, child: selector)
                  : selector,
            ),
          ],
        );
      },
    );
  }
}
