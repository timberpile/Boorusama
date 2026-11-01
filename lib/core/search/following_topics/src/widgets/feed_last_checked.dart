import 'package:clock/clock.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../widgets/time_pulse.dart';
import '../../../../widgets/date_tooltip.dart';

class FeedLastChecked extends StatelessWidget {
  const FeedLastChecked({
    required this.checkedAt,
    this.compact = false,
    super.key,
  });

  final DateTime? checkedAt;
  final bool compact;

  @override
  Widget build(BuildContext context) => switch (checkedAt) {
    null => Text(context.t.following_topics.never_checked),
    final timestamp => TimePulse(
      initial: timestamp,
      updateInterval: const Duration(minutes: 1),
      builder: (context, _) {
        final relative = timeago.format(
          timestamp.toLocal(),
          locale: context.locale.toLanguageTag(),
          clock: clock.now().toLocal(),
        );
        if (compact) {
          return DateTooltip(
            date: timestamp.toLocal(),
            child: Semantics(
              label: context.t.following_topics.last_checked.replaceAll(
                '{date}',
                relative,
              ),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _compactAge(context, timestamp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Text(
          context.t.following_topics.last_checked.replaceAll(
            '{date}',
            relative,
          ),
        );
      },
    ),
  };
}

class FeedLastRefresh extends StatelessWidget {
  const FeedLastRefresh({required this.refreshedAt, super.key});

  final DateTime? refreshedAt;

  @override
  Widget build(BuildContext context) {
    Widget text() {
      final strings = context.t.following_topics;
      final timestamp = refreshedAt;
      final value = timestamp == null
          ? strings.never_checked
          : timeago.format(
              timestamp.toLocal(),
              locale: context.locale.toLanguageTag(),
              clock: clock.now().toLocal(),
            );
      return Text(
        strings.last_refresh.replaceAll('{date}', value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return refreshedAt == null
        ? text()
        : TimePulse(
            initial: refreshedAt!,
            updateInterval: const Duration(minutes: 1),
            builder: (_, _) => text(),
          );
  }
}

String _compactAge(BuildContext context, DateTime timestamp) {
  final age = clock.now().difference(timestamp);
  final seconds = age.inSeconds.clamp(0, 1 << 62);
  final units = context.t.time.compact_age;
  return switch (seconds) {
    >= 365 * 86400 => units.years(n: seconds ~/ (365 * 86400)),
    >= 30 * 86400 => units.months(n: seconds ~/ (30 * 86400)),
    >= 7 * 86400 => units.weeks(n: seconds ~/ (7 * 86400)),
    >= 86400 => units.days(n: seconds ~/ 86400),
    >= 3600 => units.hours(n: seconds ~/ 3600),
    >= 60 => units.minutes(n: seconds ~/ 60),
    _ => units.seconds(n: seconds),
  };
}
