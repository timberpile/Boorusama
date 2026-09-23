// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/explores/types.dart';
import '../../../core/posts/explores/widgets.dart';
import '../../../core/posts/listing/widgets.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/widgets/widgets.dart';
import 'providers.dart';

class E621PopularPage extends ConsumerStatefulWidget {
  const E621PopularPage({
    super.key,
  });

  @override
  ConsumerState<E621PopularPage> createState() => _E621PopularPageState();
}

class _E621PopularPageState extends ConsumerState<E621PopularPage> {
  final selectedDateNotifier = ValueNotifier(DateTime.now());
  final selectedTimescale = ValueNotifier(TimeScale.day);

  DateTime get selectedDate => selectedDateNotifier.value;
  TimeScale get scale => selectedTimescale.value;

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final repo = ref.watch(e621PopularPostRepoProvider(config.auth));
    final origin = PostOrigin.fromSource(
      booruType: config.auth.booruType,
      booruId: config.booruId,
      source: config.url,
      profileIdHint: config.id,
    );

    return CustomContextMenuOverlay(
      child: Scaffold(
        body: SafeArea(
          child: PostScope(
            fetcher: (page) => page > 1
                ? TaskEither.of(<Post>[].toResult())
                : repo
                      .getPopularPosts(selectedDate, scale)
                      .map(
                        (result) =>
                            bindPostResultOrigin(result, origin: origin),
                      ),
            builder: (context, controller) => Column(
              children: [
                Container(
                  color: Kurumi.themeOf(
                    context,
                  ).bottomNavigationBarTheme.backgroundColor,
                  child: ValueListenableBuilder<DateTime>(
                    valueListenable: selectedDateNotifier,
                    builder: (context, d, _) => ValueListenableBuilder(
                      valueListenable: selectedTimescale,
                      builder: (_, scale, _) => DateTimeSelector(
                        onDateChanged: (date) {
                          selectedDateNotifier.value = date;
                          controller.refresh();
                        },
                        date: d,
                        scale: scale,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                TimeScaleToggleSwitch(
                  onToggle: (category) {
                    selectedTimescale.value = category;
                    controller.refresh();
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PostGrid(
                    controller: controller,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
