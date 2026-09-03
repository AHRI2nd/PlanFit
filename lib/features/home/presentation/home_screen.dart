import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../../design/glass/glass_surface.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/tokens/event_color_tag.dart';
import '../../../design/widgets/section_header.dart';
import '../../../design/widgets/time_gradient_background.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/calendar_dot.dart';
import '../../schedule/presentation/event_edit/event_editor_sheet.dart';
import '../../settings/application/settings_controller.dart';
import '../../todo/application/todo_providers.dart';
import '../../todo/domain/todo_overdue.dart';
import '../../todo/presentation/todo_detail_sheet.dart';
import '../../todo/presentation/todo_smart_list_screen.dart';

/// The home hero: the current moment as a large clock over the day's gradient,
/// what's coming up next, and today's to-do progress. The app's first
/// impression — everything else stays quiet so this reads clearly.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final now = ref.watch(nowTickerProvider).asData?.value ?? DateTime.now();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );

    return TimeGradientBackground(
      at: now,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            140,
          ),
          children: [
            SafeArea(
              bottom: false,
              child: _Hero(now: now, l10n: l10n, use24Hour: use24),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(l10n.homeToday),
            _TodayFeed(now: now, locale: locale, l10n: l10n, use24Hour: use24),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(l10n.homeWeekTitle),
            _WeeklyStats(now: now, locale: locale, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.now, required this.l10n, required this.use24Hour});

  final DateTime now;
  final AppL10n l10n;
  final bool use24Hour;

  String _greeting() {
    final h = now.hour;
    if (h < 5) return l10n.homeGreetingDawn;
    if (h < 11) return l10n.homeGreetingMorning;
    if (h < 17) return l10n.homeGreetingAfternoon;
    if (h < 21) return l10n.homeGreetingEvening;
    return l10n.homeGreetingNight;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Fmt.time(now, locale, use24Hour: use24Hour),
            style: AppTypography.clock.copyWith(color: palette.ink),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            Fmt.fullDate(now, locale),
            // inkSoft, not inkFaint — this is real, useful information
            // (today's actual date) right under the clock, not a tertiary
            // annotation like _WeekDayBar's own "3/5" count below, which is
            // what inkFaint is really meant for.
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// One chronologically-ordered feed of both what's coming up and what's due
/// today — items 2a/2b's merge of the old separate `_UpcomingList`
/// (events-only) and `_TodayTodos` (todos-only) cards, which read as two
/// disconnected lists even though "what do I need to deal with today"
/// is really one question spanning both.
sealed class _FeedEntry {
  const _FeedEntry();
  DateTime get sortKey;
}

class _FeedEventEntry extends _FeedEntry {
  const _FeedEventEntry(this.event);
  final EventRow event;
  @override
  DateTime get sortKey => event.startAt;
}

class _FeedTodoEntry extends _FeedEntry {
  const _FeedTodoEntry(this.todo);
  final TodoRow todo;
  @override
  DateTime get sortKey => todo.slotStart;
}

class _TodayFeed extends ConsumerWidget {
  const _TodayFeed({
    required this.now,
    required this.locale,
    required this.l10n,
    required this.use24Hour,
  });

  final DateTime now;
  final String locale;
  final AppL10n l10n;
  final bool use24Hour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());
    // Scoped to *today* specifically (eventsForDayProvider, same window
    // todosForDayProvider already uses below) — this card sits under a
    // "오늘"/Today section header, but used to watch upcomingEventsProvider
    // (the next N events from now, with no date ceiling at all). On a quiet
    // day that silently pulled in whatever was next regardless of how far
    // off it was — a holiday 24 days out ended up labeled "오늘" alongside
    // its own honest "24일 뒤" relative-time badge, a contradiction visible
    // right on the card. upcomingEventsProvider itself is untouched and
    // still correct for its other callers (the OS home-screen widget, the
    // schedule-tab badge) — those aren't making a "today" claim.
    final events =
        ref.watch(eventsForDayProvider(today)).asData?.value ??
        const <EventRow>[];
    final todos =
        ref.watch(todosForDayProvider(today)).asData?.value ??
        const <TodoRow>[];

    if (events.isEmpty && todos.isEmpty) {
      return _EmptyCard(
        icon: Icons.wb_sunny_outlined,
        message: l10n.homeTodayEmpty,
      );
    }

    final done = todos.where((t) => t.isDone).length;
    final overdue = todos.where((t) => isTodoOverdue(t, now)).length;
    final entries = <_FeedEntry>[
      for (final e in events) _FeedEventEntry(e),
      for (final t in todos) _FeedTodoEntry(t),
    ]..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    return GlassSurface(
      borderRadius: AppRadius.cardLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The per-row detail below already shows each to-do's own state,
          // but "how many of today's to-dos are done" is an aggregate the
          // rows alone don't convey — kept as a summary strip, same as the
          // old _TodayTodos card, rather than dropped in favor of the list.
          if (todos.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.homeTodosDone(done, todos.length),
                    // titleLarge, not titleMedium — the row tiles below
                    // (_UpcomingTile/_FeedTodoTile's own titles) already use
                    // titleMedium, so this card's own heading needs to read
                    // a size above them to actually look like a heading
                    // instead of one more flat row.
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l10n.homeTodosViewAll,
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const TodoSmartListScreen(),
                    ),
                  ),
                  icon: Icon(Icons.chevron_right, color: palette.inkFaint),
                ),
              ],
            ),
            if (overdue > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  l10n.homeTodosOverdue(overdue),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: switch (entry) {
                _FeedEventEntry(:final event) => _UpcomingTile(
                  event: event,
                  now: now,
                  locale: locale,
                  use24Hour: use24Hour,
                ),
                _FeedTodoEntry(:final todo) => _FeedTodoTile(
                  todo: todo,
                  locale: locale,
                  use24Hour: use24Hour,
                ),
              },
            ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({
    required this.event,
    required this.now,
    required this.locale,
    required this.use24Hour,
  });

  final EventRow event;
  final DateTime now;
  final String locale;
  final bool use24Hour;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = EventColorTag.resolve(event.colorTag, event.startAt);
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => showEventEditor(context, existing: event),
      child: GlassSurface(
        borderRadius: AppRadius.cardMd,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fmt.time(event.startAt, locale, use24Hour: use24Hour),
                  // A light preset (amber/sky/rose) or a time-gradient
                  // moment near those same hues measured well under WCAG
                  // AA's 4.5:1 text floor here — see legibleOn's own doc.
                  style: AppTypography.clockSmall.copyWith(
                    color: legibleOn(palette.surface, accent),
                  ),
                ),
                Text(
                  Fmt.relative(event.startAt, now, locale),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.inkFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Container(width: 1, height: 32, color: palette.hairline),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                event.title.isEmpty ? '—' : event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTodoTile extends ConsumerWidget {
  const _FeedTodoTile({
    required this.todo,
    required this.locale,
    required this.use24Hour,
  });

  final TodoRow todo;
  final String locale;
  final bool use24Hour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final isOverdue = isTodoOverdue(todo, DateTime.now());

    return GestureDetector(
      onTap: () => showTodoDetailSheet(context, todo),
      child: GlassSurface(
        borderRadius: AppRadius.cardMd,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Same tap-target/color language as HourlyTodoList's own
            // checkbox — accent when done, danger when overdue, faint
            // otherwise. Forced up to the 44x44 accessibility floor via
            // SizedBox, kept separate from the 22px icon's own visual size
            // — same pattern as _TitleChevron in schedule_screen.dart.
            Semantics(
              button: true,
              checked: todo.isDone,
              label: AppL10n.of(context).todoMarkDone,
              child: SizedBox(
                width: 44,
                height: 44,
                child: InkWell(
                  onTap: () => ref
                      .read(todoControllerProvider)
                      .toggle(todo.id, !todo.isDone),
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(
                      todo.isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 22,
                      color: todo.isDone
                          ? palette.accent
                          : (isOverdue ? palette.danger : palette.inkFaint),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                todo.title.isEmpty ? '—' : todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: todo.isDone ? palette.inkFaint : palette.ink,
                  decoration: todo.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (todo.hasTime) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                Fmt.time(todo.slotStart, locale, use24Hour: use24Hour),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isOverdue ? palette.danger : palette.inkFaint,
                  fontWeight: isOverdue ? FontWeight.w700 : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// This Mon–Sun's event count and to-do completion, plus a 7-day bar so a
/// week's shape is visible at a glance rather than just a single number.
class _WeeklyStats extends ConsumerWidget {
  const _WeeklyStats({
    required this.now,
    required this.locale,
    required this.l10n,
  });

  final DateTime now;
  final String locale;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // `now` ticks every 30s (nowTickerProvider) with full second/millisecond
    // precision; these providers only care which *week* that lands in, and
    // aren't .autoDispose. Keying them on `now` directly would mint a brand
    // new family instance — and a brand new open DB stream subscription —
    // on every tick, forever, since the old ones never get disposed. Keying
    // on the day instead (stable for 24h) reuses the same instance across
    // every tick within that day, matching how _TodayTodos already keys
    // todosForDayProvider on `dateOnly(DateTime.now())` rather than a raw
    // timestamp.
    final today = dateOnly(now);
    final events =
        ref.watch(eventsForWeekProvider(today)).asData?.value ??
        const <EventRow>[];
    final todos =
        ref.watch(todosForWeekProvider(today)).asData?.value ??
        const <TodoRow>[];

    if (events.isEmpty && todos.isEmpty) {
      return _EmptyCard(
        icon: Icons.insights_outlined,
        message: l10n.homeWeekEmpty,
      );
    }

    final weekStart = startOfWeek(
      today,
      startWeekday: ref.watch(weekStartWeekdayProvider),
    );
    final totalByDay = <DateTime, int>{};
    final doneByDay = <DateTime, int>{};
    for (final t in todos) {
      final d = dateOnly(t.slotStart);
      totalByDay[d] = (totalByDay[d] ?? 0) + 1;
      if (t.isDone) doneByDay[d] = (doneByDay[d] ?? 0) + 1;
    }
    final eventDays = {for (final e in events) dateOnly(e.startAt)};
    // Per calendar_dot.dart's shared rule.
    final overdueDays = {
      for (final t in todos)
        if (isTodoOverdue(t, now)) dateOnly(t.slotStart),
    };
    final todoDays = {
      for (final t in todos)
        if (!t.isDone) dateOnly(t.slotStart),
    }..removeAll(overdueDays);
    final doneTotal = todos.where((t) => t.isDone).length;

    return GlassSurface(
      borderRadius: AppRadius.cardLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeWeekSummary(events.length, doneTotal, todos.length),
            // Same titleLarge bump as _TodayFeed's own card heading, for
            // the same reason — it needs to outrank the day labels and
            // done/total counts inside its own card, not match them.
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = addCalendarDays(weekStart, i);
                      return _WeekDayBar(
                        day: day,
                        isToday: day == today,
                        done: doneByDay[day] ?? 0,
                        total: totalByDay[day] ?? 0,
                        hasEvent: eventDays.contains(day),
                        hasTodo: todoDays.contains(day),
                        hasOverdueTodo: overdueDays.contains(day),
                        locale: locale,
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDayBar extends StatelessWidget {
  const _WeekDayBar({
    required this.day,
    required this.isToday,
    required this.done,
    required this.total,
    required this.hasEvent,
    required this.hasTodo,
    required this.hasOverdueTodo,
    required this.locale,
  });

  final DateTime day;
  final bool isToday;
  final int done;
  final int total;
  final bool hasEvent;
  final bool hasTodo;
  final bool hasOverdueTodo;
  final String locale;

  static const double _barHeight = 48;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : done / total;
    final dotColor = calendarDotColor(
      palette: palette,
      hasEvent: hasEvent,
      hasTodo: hasTodo,
      hasOverdueTodo: hasOverdueTodo,
    );
    return Column(
      children: [
        SizedBox(
          height: 6,
          child: dotColor == null
              ? null
              : Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        SizedBox(
          height: _barHeight,
          width: 8,
          child: Align(
            alignment: Alignment.bottomCenter,
            // A fraction-based height needs a child with its own intrinsic
            // size — DecoratedBox alone collapses to zero under the loose
            // constraints FractionallySizedBox hands it, so compute the
            // pixel height directly instead.
            child: Container(
              height: _barHeight * (total == 0 ? 0.06 : (0.12 + ratio * 0.88)),
              decoration: BoxDecoration(
                color: total == 0
                    ? palette.hairline
                    : palette.accent.withValues(alpha: 0.35 + ratio * 0.65),
                borderRadius: AppRadius.allPill,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        // The bar's height/opacity alone is a subtle, purely-visual
        // encoding of the same done/total ratio — this spells it out as an
        // actual number for anyone who can't (or would rather not) read
        // that at a glance. Reserves its line even at total == 0 so the
        // weekday labels below stay aligned across all seven columns.
        SizedBox(
          height: 12,
          child: total == 0
              ? null
              : Text(
                  '$done/$total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: palette.inkFaint,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          Fmt.weekdayShort(day, locale),
          style: theme.textTheme.labelSmall?.copyWith(
            color: isToday ? palette.ink : palette.inkFaint,
            fontWeight: isToday ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassSurface(
      borderRadius: AppRadius.cardLg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icon, color: palette.inkFaint, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
