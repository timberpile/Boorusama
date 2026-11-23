import 'package:clock/clock.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/date_tooltip.dart';
import '../../widgets/time_pulse.dart';

class MiteMiteRelativeDate extends StatelessWidget {
  const MiteMiteRelativeDate({required this.date, this.builder, super.key});

  final DateTime? date;
  final Widget Function(BuildContext context, String relative)? builder;

  @override
  Widget build(BuildContext context) => switch (date) {
    null => Text(context.t.mitemite.never),
    final timestamp => TimePulse(
      initial: timestamp,
      updateInterval: const Duration(minutes: 1),
      builder: (context, _) {
        final relative = timeago.format(
          timestamp.toLocal(),
          locale: context.locale.toLanguageTag(),
          clock: clock.now().toLocal(),
          allowFromNow: true,
        );
        return DateTooltip(
          date: timestamp.toLocal(),
          child: builder?.call(context, relative) ?? Text(relative),
        );
      },
    ),
  };
}
