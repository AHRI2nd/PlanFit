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
import '../../../design/widgets/adaptive_bottom_sheet.dart'
    show kFloatingNavBarClearance;
import '../../../design/widgets/section_header.dart';
import '../../../design/widgets/time_gradient_background.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/calendar_dot.dart';
import '../../schedule/domain/event_span.dart';
import '../../schedule/presentation/event_edit/event_editor_sheet.dart';
import '../../schedule/presentation/event_edit/event_preview_sheet.dart';
import '../../settings/application/settings_controller.dart';
import '../../todo/application/todo_providers.dart';
import '../../todo/domain/todo_delete_flow.dart';
import '../../todo/domain/todo_overdue.dart';
import '../../todo/domain/todo_priority.dart';
import '../../todo/presentation/quick_add_todo_sheet.dart';
import '../../todo/presentation/todo_detail_sheet.dart';
import '../../todo/presentation/todo_smart_list_screen.dart';

/// How much of the screen the pull-up bar covers once dragged (or tapped)
/// open — short of the very top, so a sliver of the hero peeks through as a
/// hint there's more screen above it.
const double _kExpandedSheetSize = 0.92;

/// The home hero: the current moment as a large clock over the day's gradient,
/// what's coming up next, and today's to-do progress. The app's first
/// impression — everything else stays quiet so this reads clearly.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _peekKey = GlobalKey();

  /// A permanently-offstage twin of the pull-up bar's collapsed content,
  /// with its details panel forced open from the start — exists solely so
  /// [_expandedExtraHeight] below can be measured without ever showing this
  /// copy to anyone. Never swapped into the live tree the way [_peekKey]'s
  /// widget is.
  final _expandedProbeKey = GlobalKey();

  final _sheetController = DraggableScrollableController();

  static const _optionsAnimationDuration = Duration(milliseconds: 180);

  /// The pull-up bar's own collapsed content (drag handle + "할 일 추가"
  /// header + field) measured once, real pixels, rather than guessed —
  /// [DraggableScrollableSheet] takes its `minChildSize` as a fraction
  /// decided *before* layout, with no way to ask "how tall does my content
  /// actually want to be", and a guess here that undershoots doesn't just
  /// clip: the sheet ends up short enough that 할 일's own header/first row
  /// peeks into the same collapsed view, landing right behind (and, in
  /// gaps around it, visibly poking out past) the app's floating tab bar.
  /// Null until the post-frame measurement below runs once, at which point
  /// it never changes again for the rest of this State's lifetime.
  double? _peekHeight;

  /// How much taller the field's own details panel (tags field + repeat/
  /// priority/no-time buttons) makes the pull-up bar once expanded — measured
  /// once, the same way as [_peekHeight], via [_expandedProbeKey]'s twin.
  /// Drives [_onOptionsExpandedChanged] below: tapping the field's own
  /// "tune" button grows/shrinks the *sheet itself* by exactly this many
  /// pixels, in step with the field's own [AnimatedSize], rather than the
  /// panel just growing inside a sheet that stays a fixed size.
  double? _expandedExtraHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheetController.dispose();
    super.dispose();
  }

  /// Rotation, window resize, or a system text-scale change can all change
  /// how tall the pull-up bar's own content is — re-measure from scratch
  /// rather than keep stale [_peekHeight]/[_expandedExtraHeight] values.
  @override
  void didChangeMetrics() => _remeasure();

  @override
  void didChangeTextScaleFactor() => _remeasure();

  void _remeasure() {
    if (!mounted) return;
    setState(() {
      _peekHeight = null;
      _expandedExtraHeight = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final collapsed = _peekKey.currentContext?.size?.height;
    final expanded = _expandedProbeKey.currentContext?.size?.height;
    if (collapsed == null || collapsed <= 0) return;
    setState(() {
      _peekHeight = collapsed;
      if (expanded != null && expanded > collapsed) {
        _expandedExtraHeight = expanded - collapsed;
      }
    });
  }

  /// Fired by the live field's own "tune" button — animates the sheet up
  /// (or back down) by [_expandedExtraHeight], in the same duration/curve as
  /// the field's own details-panel [AnimatedSize], so the two grow together
  /// instead of the panel appearing to fight a sheet that doesn't move.
  ///
  /// Skipped when the user has already dragged the bar all the way up to
  /// browse 할 일 — there's already plenty of room there for the panel to
  /// grow into, so forcing the whole sheet back down just because they
  /// touched a toggle inside it would fight their own drag instead of
  /// helping it.
  void _onOptionsExpandedChanged(bool expanded) {
    final peekHeight = _peekHeight;
    final extra = _expandedExtraHeight;
    if (peekHeight == null || extra == null || !_sheetController.isAttached) {
      return;
    }
    if ((_kExpandedSheetSize - _sheetController.size).abs() < 0.02) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final collapsedSheetSize =
        ((peekHeight + kFloatingNavBarClearance) / screenHeight).clamp(
          0.12,
          0.6,
        );
    final target =
        ((peekHeight + (expanded ? extra : 0) + kFloatingNavBarClearance) /
                screenHeight)
            .clamp(collapsedSheetSize, _kExpandedSheetSize);
    _sheetController.animateTo(
      target,
      duration: _optionsAnimationDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final now = ref.watch(nowTickerProvider).asData?.value ?? DateTime.now();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    final screenHeight = MediaQuery.sizeOf(context).height;
    final peekHeight = _peekHeight;
    final peekContent = _TodoAddPeek(
      key: _peekKey,
      l10n: l10n,
      onOptionsExpandedChanged: _onOptionsExpandedChanged,
    );

    return TimeGradientBackground(
      at: now,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                // The pull-up bar below is a Stack overlay, not part of
                // this list — its own collapsed height (once known; a
                // generous placeholder before that) is padded in here so
                // 이번 주's card never renders underneath it.
                (peekHeight ?? 220) + kFloatingNavBarClearance + AppSpacing.md,
              ),
              children: [
                SafeArea(
                  bottom: false,
                  child: _Hero(now: now, l10n: l10n, use24Hour: use24),
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(l10n.homeToday),
                _TodayFeed(
                  now: now,
                  locale: locale,
                  l10n: l10n,
                  use24Hour: use24,
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(l10n.homeWeekTitle),
                _WeeklyStats(now: now, locale: locale, l10n: l10n),
              ],
            ),
            // Never shown, never removed — see [_expandedExtraHeight]'s own
            // doc for why this twin exists purely to be measured.
            Offstage(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: _TodoAddPeek(
                  key: _expandedProbeKey,
                  l10n: l10n,
                  forceOptionsExpanded: true,
                ),
              ),
            ),
            if (peekHeight == null)
              // Laid out (so its real height can be measured) but never
              // painted or hit-tested — swapped for the real pull-up bar
              // the moment _measure's setState lands, which for a human
              // eye is well within one imperceptible frame.
              Offstage(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child: peekContent,
                ),
              )
            else
              // The add field lives collapsed here, at the bottom, always
              // reachable — drag (or fling) it up and it turns into a
              // scrollable popup showing 할 일, the same list that used to
              // sit fixed further down the page. snap:true means a
              // partial drag always settles fully open or fully collapsed
              // instead of stopping halfway.
              //
              // Positioned.fill, not a bare Stack child: without it, the
              // sheet's own layout box silently claims the *entire* Stack
              // area for hit-testing (matching Flutter's own canonical
              // usage) even though it only *paints* its current fraction —
              // an invisible pane over whatever "오늘"/"이번 주" render
              // underneath, swallowing every tap there before it can ever
              // reach them.
              Positioned.fill(
                child: Builder(
                  builder: (context) {
                    final collapsedSheetSize =
                        ((peekHeight + kFloatingNavBarClearance) / screenHeight)
                            .clamp(0.12, 0.6);
                    return DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: collapsedSheetSize,
                      minChildSize: collapsedSheetSize,
                      maxChildSize: _kExpandedSheetSize,
                      snap: true,
                      snapSizes: [collapsedSheetSize, _kExpandedSheetSize],
                      builder: (context, scrollController) {
                        final palette = context.palette;
                        return DecoratedBox(
                          key: const ValueKey('homeTodoSheetSurface'),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: const BorderRadius.vertical(
                              top: AppRadius.lg,
                            ),
                          ),
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.gutter,
                              0,
                              AppSpacing.gutter,
                              kFloatingNavBarClearance,
                            ),
                            children: [
                              peekContent,
                              const SizedBox(height: AppSpacing.xl),
                              SectionHeader(l10n.homeTodoListTitle),
                              _HomeTodoList(
                                locale: locale,
                                l10n: l10n,
                                use24Hour: use24,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The pull-up bar's collapsed content: a drag handle, then the "할 일
/// 추가" section exactly as it always rendered — see [_HomeScreenState]'s
/// own doc for why this exists as its own widget (it's measured once,
/// standalone, before the real sheet that reuses it ever mounts).
///
/// The "+" in the field's own icon was mistaken for a moment for the FAB
/// schedule_screen.dart's own "+" opens (that one's for events) — this is
/// the day/week views' own convention instead: an always-visible inline
/// add field, not a FAB hiding the affordance behind a modal sheet. Home
/// has no single day of its own to scope the field's date/time defaults to
/// (unlike HourlyTodoList's), so it falls back to today, no time, same as
/// QuickAddTodoSheet's own field does for the smart-list screen.
class _TodoAddPeek extends StatelessWidget {
  const _TodoAddPeek({
    super.key,
    required this.l10n,
    this.forceOptionsExpanded = false,
    this.onOptionsExpandedChanged,
  });

  final AppL10n l10n;
  final bool forceOptionsExpanded;
  final ValueChanged<bool>? onOptionsExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SectionHeader(l10n.todoAdd),
          QuickAddTodoField(
            forceOptionsExpanded: forceOptionsExpanded,
            onOptionsExpandedChanged: onOptionsExpandedChanged,
          ),
        ],
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
      onTap: () => showEventPreview(context, event: event),
      onLongPress: () => showEventEditor(context, existing: event),
      // RepaintBoundary isolates this tile's own BackdropFilter blur layer
      // — same fix as day_view.dart's event cards — so scrolling the
      // "오늘" feed (or the minute-by-minute nowTickerProvider tick this
      // card's ancestor watches) doesn't force every tile's blur to
      // recomposite, just because its position on screen moved.
      child: RepaintBoundary(
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
                    Fmt.relative(event.startAt, now, locale, end: event.endAt),
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
      ),
    );
  }
}

class _FeedTodoTile extends ConsumerWidget {
  const _FeedTodoTile({
    required this.todo,
    required this.locale,
    required this.use24Hour,
    this.showDate = false,
  });

  final TodoRow todo;
  final String locale;
  final bool use24Hour;

  /// `_TodayFeed` (every to-do it shows is already today's) leaves this
  /// off — just the time is enough there. `_HomeTodoList` turns it on:
  /// unlike `_TodayFeed`, its to-dos can be from any day (overdue from
  /// however long ago, or up to 30 days into the future), so a bare time
  /// with no date would be genuinely ambiguous. Same "date, plus time if
  /// timed" shape `todo_smart_list_screen.dart`'s own cross-day tile
  /// already uses, for the same reason.
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final isOverdue = isTodoOverdue(todo, DateTime.now());
    final priority = TodoPriority.fromValue(todo.priority);
    final tags = (todo.tags ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final trailing = !showDate
        ? (todo.hasTime
              ? Fmt.time(todo.slotStart, locale, use24Hour: use24Hour)
              : null)
        : (todo.hasTime
              ? '${Fmt.monthDay(todo.slotStart, locale)} '
                    '${Fmt.time(todo.slotStart, locale, use24Hour: use24Hour)}'
              : Fmt.monthDay(todo.slotStart, locale));

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: Icon(Icons.delete_outline, color: palette.danger),
      ),
      confirmDismiss: (_) => confirmAndDeleteTodo(context, ref, todo),
      child: GestureDetector(
        onTap: () => showTodoDetailSheet(context, todo),
        // See _UpcomingTile's own comment — isolates this tile's blur layer
        // from the rest of the scrolling feed.
        child: RepaintBoundary(
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
                // Same priority-dot treatment as _SmartTodoTile's own —
                // this tile used to drop priority entirely, so setting one
                // never showed up anywhere on the home screen.
                if (priority.color(palette) != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: priority.color(palette),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title.isEmpty ? '—' : todo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: todo.isDone ? palette.inkFaint : palette.ink,
                          decoration: todo.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (tags.isNotEmpty)
                        Text(
                          tags.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.inkFaint,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    trailing,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isOverdue ? palette.danger : palette.inkFaint,
                      fontWeight: isOverdue ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "할 일" list under the add-a-to-do field: every not-done to-do that's
/// overdue, oldest due date first (see [overdueTodosProvider] — reversed
/// here, since that provider's own most-recently-overdue-first order suits
/// the smart list's "기한 지남" tab, its other caller, not this one), followed
/// by the nearest [upcomingNotOverdueTodosProvider] (capped at 30, soonest
/// first). Unlike [_TodayFeed] just above it on this same screen, this
/// isn't scoped to today at all — a to-do overdue from last month, or one
/// due three weeks out, both belong here; [_TodayFeed] and this list will
/// naturally show the same to-do when it happens to be due today.
///
/// Two separate DB queries concatenated in order, not one query re-sorted
/// client-side: a to-do with no time at all is never "overdue" (see
/// [isTodoOverdue]'s own doc) regardless of how long ago its day was, so a
/// single sort by [TodoRow.slotStart] would wrongly interleave a stale
/// no-time to-do among genuinely overdue timed ones just because its
/// midnight-normalized slot happens to be an earlier instant.
class _HomeTodoList extends ConsumerWidget {
  const _HomeTodoList({
    required this.locale,
    required this.l10n,
    required this.use24Hour,
  });

  final String locale;
  final AppL10n l10n;
  final bool use24Hour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue =
        ref.watch(overdueTodosProvider).asData?.value ?? const <TodoRow>[];
    final upcoming =
        ref.watch(upcomingNotOverdueTodosProvider).asData?.value ??
        const <TodoRow>[];

    if (overdue.isEmpty && upcoming.isEmpty) {
      return _EmptyCard(
        icon: Icons.checklist_rounded,
        message: l10n.homeTodoListEmpty,
      );
    }

    // overdueTodosProvider orders most-recently-overdue first (descending
    // by slotStart) for its smart-list use — reversed to oldest-first here.
    final oldestOverdueFirst = overdue.reversed.toList();
    // The query itself stays uncapped (its count feeds the badge above and
    // _WeeklyStats' own overdue dots), but rendering every single one of a
    // large backlog inline here — this Column has no lazy-building
    // ListView.builder under it — would still get slow well before that
    // count is remotely realistic; cap what actually renders and point the
    // rest at the smart list's own scrollable overdue tab instead.
    const overdueRenderCap = 50;
    final shownOverdue = oldestOverdueFirst.length > overdueRenderCap
        ? oldestOverdueFirst.sublist(0, overdueRenderCap)
        : oldestOverdueFirst;
    final hiddenOverdueCount = oldestOverdueFirst.length - shownOverdue.length;

    return GlassSurface(
      borderRadius: AppRadius.cardLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final todo in shownOverdue)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _FeedTodoTile(
                todo: todo,
                locale: locale,
                use24Hour: use24Hour,
                showDate: true,
              ),
            ),
          if (hiddenOverdueCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: InkWell(
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const TodoSmartListScreen(
                      initialTab: SmartListInitialTab.overdue,
                    ),
                  ),
                ),
                child: Text(
                  l10n.homeOverdueListMore(hiddenOverdueCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          for (final todo in upcoming)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _FeedTodoTile(
                todo: todo,
                locale: locale,
                use24Hour: use24Hour,
                showDate: true,
              ),
            ),
        ],
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
    // `now` ticks every minute (nowTickerProvider) with full second/
    // millisecond precision; these providers only care which *week* that
    // lands in. Keying them on `now` directly would mint a brand new family
    // instance — and a brand new open DB stream subscription — on every
    // tick; even with these providers' own autoDispose-plus-grace-period
    // (see riverpod_x.dart's keepAliveFor), that's still a fresh instance
    // (and a fresh query) every single minute instead of reusing one.
    // Keying on the day instead (stable for 24h) reuses the same instance
    // across every tick within that day, matching how _TodayTodos already
    // keys todosForDayProvider on `dateOnly(DateTime.now())` rather than a
    // raw timestamp.
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
    // Every day a multi-day event spans (via eventDaysInRange), not only its
    // start day — see week_view.dart's matching fix for why.
    final weekEnd = addCalendarDays(weekStart, 7);
    final eventDays = {
      for (final e in events) ...eventDaysInRange(e, weekStart, weekEnd),
    };
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
        //
        // 12px fits this text's own natural line height (9 * labelSmall's
        // 1.2 line-height multiplier = 10.8px) at the default 1.0x text
        // scale, but app.dart clamps the system accessibility text scale up
        // to 1.3x app-wide — at that ceiling the same text needs ~14px, 2px
        // taller than this fixed box. The box being a plain SizedBox (not a
        // Flex) means that never threw a catchable overflow error; it just
        // silently let the label's true layout paint outside its box and
        // overlap the weekday abbreviation directly below — confirmed via a
        // widget test pinning MediaQuery's textScaler to 1.3x and comparing
        // this box's measured size against an unclamped TextPainter layout
        // of the same style/scaler. Scaling by the same effective factor
        // keeps this box exactly 12px at the default scale (this app's
        // vast majority of users, and every existing test, which run at
        // 1.0x) while giving larger accessibility text the room it needs.
        SizedBox(
          height: 12 * MediaQuery.textScalerOf(context).scale(1.0),
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
