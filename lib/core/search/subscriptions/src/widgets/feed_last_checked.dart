import 'package:clock/clock.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../widgets/time_pulse.dart';

class FeedLastChecked extends StatelessWidget {
  const FeedLastChecked({required this.checkedAt, super.key});

  final DateTime? checkedAt;

  @override
  Widget build(BuildContext context) => switch (checkedAt) {
    null => Text(context.t.pinned_searches.never_checked),
    final timestamp => TimePulse(
      initial: timestamp,
      updateInterval: const Duration(minutes: 1),
      builder: (context, _) {
        final relative = timeago.format(
          timestamp.toLocal(),
          locale: context.locale.toLanguageTag(),
          clock: clock.now().toLocal(),
        );
        return Text(
          context.t.pinned_searches.last_checked.replaceAll('{date}', relative),
        );
      },
    ),
  };
}
