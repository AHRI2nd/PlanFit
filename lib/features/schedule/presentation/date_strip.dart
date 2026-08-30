import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';
import '../../../core/format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../todo/application/todo_providers.dart';
import '../application/schedule_providers.dart';
import '../domain/calendar_dot.dart';

/// Always-visible horizontal date picker in the schedule tab's header — a
/// calendar-app-style strip, so jumping to a nearby date no longer requires
/// switching to the Month tab's grid just to tap a day. That grid (see
/// MonthView) stays exactly as it was, for month-at-a-glance browsing; this
/// is purely the fast, always-present "jump a few days either way" path,
/// present across all five schedule sub-views (Day/Week/Month/Year/Agenda).
class DateStrip extends ConsumerStatefulWidget {
  const DateStrip({super.key});

  @override
  ConsumerState<DateStrip> createState() => _DateStripState();
}

class _DateStripState extends ConsumerState<DateStrip> {
  static const _cellWidth = 52.0;
  static const _dotSize = 4.0;

  // A finite but generously wide range (~20 years total) rather than a
  // literal infinite scroll — plenty for a personal scheduling app, and
  // avoids the complexity of a true unbounded ListView. Fixed at first
  // build so index math stays stable across rebuilds.
  static const _daysBefore = 3650;
  static const _daysAfter = 3650;
  late final DateTime _epoch = dateOnly(DateTime.now());

  final _controller = ScrollController();
  bool _didInitialScroll = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexOf(DateTime day) =>
      dateOnly(day).difference(_epoch).inDays + _daysBefore;

  DateTime _dateOf(int index) => addCalendarDays(_epoch, index - _daysBefore);

  void _centerOn(DateTime date, {required bool animate}) {
    if (!_controller.hasClients) return;
    final target =
        _indexOf(date) * _cellWidth -
        (_controller.position.viewportDimension - _cellWidth) / 2;
    final clamped = target.clamp(0.0, _controller.position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final selected = ref.watch(selectedDateProvider);

    // A selection change from elsewhere (the Month tab's grid, the "Today"
    // button, search) re-centers the strip on it too, so all of them stay
    // visibly in sync with each other.
    ref.listen(selectedDateProvider, (previous, next) {
      if (previous != next) _centerOn(next, animate: true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_didInitialScroll || !mounted) return;
      _didInitialScroll = true;
      _centerOn(selected, animate: false);
    });

    final events =
        ref.watch(eventsForDateStripProvider(selected)).asData?.value ??
        const <EventRow>[];
    final eventDays = {for (final e in events) dateOnly(e.startAt)};
    final overdueTodos =
        ref.watch(overdueTodosProvider).asData?.value ?? const <TodoRow>[];
    final overdueDays = {for (final t in overdueTodos) dateOnly(t.slotStart)};

    return SizedBox(
      height: 64,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: _daysBefore + _daysAfter,
        itemBuilder: (context, index) {
          final date = _dateOf(index);
          final isSelected = date == dateOnly(selected);
          final dotColor = calendarDotColor(
            palette: palette,
            hasEvent: eventDays.contains(date),
            hasOverdueTodo: overdueDays.contains(date),
          );
          return SizedBox(
            key: ValueKey(date),
            width: _cellWidth,
            child: InkWell(
              onTap: () => ref.read(selectedDateProvider.notifier).select(date),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    Fmt.weekdayShort(date, locale),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? palette.accent : palette.inkFaint,
                      fontWeight: isSelected ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? palette.accent : null,
                    ),
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected ? Colors.white : palette.ink,
                        fontWeight: isSelected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _dotSize + 2,
                    child: dotColor == null
                        ? null
                        : Center(
                            child: Container(
                              key: ValueKey('dot-$date'),
                              width: _dotSize,
                              height: _dotSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.white : dotColor,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
