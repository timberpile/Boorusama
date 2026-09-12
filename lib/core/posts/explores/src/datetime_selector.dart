// Package imports:
import 'package:intl/intl.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import 'types.dart';
import 'utils.dart';

/// The default lower bound of [DateTimeSelector]'s date picker and step
/// arrows, used whenever a caller doesn't override [DateTimeSelector.firstDate].
final kDateTimeSelectorDefaultFirstDate = DateTime(2005);

/// The default upper bound of [DateTimeSelector]'s date picker and step
/// arrows, used whenever a caller doesn't override [DateTimeSelector.lastDate].
///
/// Computed fresh on each read (rather than once at load time) so it stays
/// "tomorrow" relative to whenever the widget actually builds.
DateTime kDateTimeSelectorDefaultLastDate() =>
    DateTime.now().add(const Duration(days: 1));

/// Whether stepping [date] by [scale] in [forward] direction stays within
/// `[firstDate, lastDate]`, comparing calendar dates only (time-of-day is
/// ignored on all three arguments).
///
/// Used to disable a [DateTimeSelector] step arrow at either boundary
/// instead of letting it fire a callback that a caller silently clamps —
/// see `clampPixivRankingDate` for why pixiv's ranking needs that clamp in
/// the first place.
bool canStepDateTime({
  required DateTime date,
  required TimeScale scale,
  required bool forward,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final stepped = forward
      ? date.addTimeScale(scale)
      : date.subtractTimeScale(scale);

  final steppedDay = DateTime(stepped.year, stepped.month, stepped.day);
  final firstDay = DateTime(firstDate.year, firstDate.month, firstDate.day);
  final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);

  return !steppedDay.isBefore(firstDay) && !steppedDay.isAfter(lastDay);
}

class DateTimeSelector extends StatelessWidget {
  const DateTimeSelector({
    required this.onDateChanged,
    required this.date,
    super.key,
    this.scale = TimeScale.day,
    this.backgroundColor,
    this.firstDate,
    this.lastDate,
  });

  final void Function(DateTime date) onDateChanged;
  final DateTime date;
  final TimeScale scale;
  final Color? backgroundColor;

  /// Earliest selectable date, for both the date picker and the back
  /// arrow. Defaults to [kDateTimeSelectorDefaultFirstDate] so existing
  /// callers are unaffected.
  final DateTime? firstDate;

  /// Latest selectable date, for both the date picker and the forward
  /// arrow. Defaults to [kDateTimeSelectorDefaultLastDate] so existing
  /// callers are unaffected.
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final effectiveFirstDate = firstDate ?? kDateTimeSelectorDefaultFirstDate;
    final effectiveLastDate = lastDate ?? kDateTimeSelectorDefaultLastDate();

    final canStepBack = canStepDateTime(
      date: date,
      scale: scale,
      forward: false,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
    );
    final canStepForward = canStepDateTime(
      date: date,
      scale: scale,
      forward: true,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Symbols.keyboard_arrow_left),
              onPressed: canStepBack
                  ? () => onDateChanged(date.subtractTimeScale(scale))
                  : null,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Kurumi.themeOf(
                context,
              ).textTheme.titleLarge?.color,
              backgroundColor:
                  backgroundColor ??
                  Kurumi.themeOf(context).colorScheme.surfaceContainerHighest,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: effectiveFirstDate,
                lastDate: effectiveLastDate,
              );
              if (picked != null) {
                onDateChanged(picked);
              }
            },
            child: Row(
              children: [
                Text(DateFormat('MMM d, yyyy').format(date)),
                const Icon(Symbols.arrow_drop_down),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Symbols.keyboard_arrow_right),
              onPressed: canStepForward
                  ? () => onDateChanged(date.addTimeScale(scale))
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
