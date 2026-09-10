import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/quick_add/quick_add_parser.dart';
import '../../../core/time_format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_motion.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/application/schedule_providers.dart' show dateOnly;
import '../../schedule/domain/recurrence.dart';
import '../../settings/application/settings_controller.dart';
import '../application/todo_providers.dart';
import '../domain/todo_priority.dart';

/// The single-line "type a to-do, optionally with a date/time/priority/tag
/// phrase" sheet — the smart-list screen's own "add a to-do" affordance,
/// for the one screen with no single day to anchor an inline add row to
/// (`HourlyTodoList`'s own field, used inside a specific day, covers that
/// case instead — see [QuickAddTodoField]'s own doc).
Future<void> showQuickAddTodoSheet(BuildContext context) =>
    showAdaptiveBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddTodoSheet(),
    );

/// A new to-do here defaults to 9am today, reusing the same [parseQuickAdd]
/// phrase-parsing (and the same time/priority/repeat controls) the day
/// view's own quick-add field runs. Just a title plus [QuickAddTodoField]
/// in sheet chrome — see that widget's own doc for the actual field +
/// submit logic.
class QuickAddTodoSheet extends StatelessWidget {
  const QuickAddTodoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.gutter,
          right: AppSpacing.gutter,
          top: AppSpacing.sm,
          bottom: AppSpacing.gutter + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.todoAdd, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            QuickAddTodoField(
              autofocus: true,
              onAdded: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The inline "add a to-do" row: an add icon, a text field, a time chip, and
/// — behind a "tune" toggle so the collapsed row still reads as *quick* — a
/// priority menu, a repeat menu, and a no-time toggle. Submitting runs
/// [parseQuickAdd], so typing "내일 오후 3시 병원" fills in the date/time from
/// the phrase (overriding the chips) and adds just "병원" as the title.
///
/// Shared by three places so they stay literally identical rather than
/// drifting: the day view's [day]-scoped list (`HourlyTodoList`), the home
/// screen's always-visible bottom section, and the smart-list screen's
/// quick-add sheet ([QuickAddTodoSheet]). [day] anchors a new item's date
/// and the "added to another day" SnackBar's comparison; when null (home /
/// the sheet, neither of which frames a single day) it falls back to today.
class QuickAddTodoField extends ConsumerStatefulWidget {
  const QuickAddTodoField({
    super.key,
    this.day,
    this.autofocus = false,
    this.focusNode,
    this.onAdded,
  });

  /// The day a new item lands on (and the reference the "added to another
  /// day" SnackBar compares a parsed date against). Null → today.
  final DateTime? day;

  final bool autofocus;

  /// Lets a caller drive focus into this field from outside — see
  /// `DayView`'s to-dos-header "+" button for the pattern. Owned and
  /// disposed by whoever passes it in; when absent this widget creates and
  /// owns its own instead, so the field still works standalone.
  final FocusNode? focusNode;

  /// Called after a to-do is successfully created. [QuickAddTodoSheet] uses
  /// this to pop itself closed; a caller that shows this field inline (day
  /// view, home) leaves it null — the field just clears itself and stays,
  /// ready for the next one.
  final VoidCallback? onAdded;

  @override
  ConsumerState<QuickAddTodoField> createState() => _QuickAddTodoFieldState();
}

class _QuickAddTodoFieldState extends ConsumerState<QuickAddTodoField> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();

  TimeOfDay _addTime = const TimeOfDay(hour: 9, minute: 0);
  bool _addHasTime = true;
  RecurrenceFrequency _addRecurrence = RecurrenceFrequency.none;
  TodoPriority _addPriority = TodoPriority.none;

  /// Whether the priority/repeat/no-time controls are expanded below the
  /// main row — collapsed by default so the "quick" add row actually reads
  /// as quick (add icon + text field + time chip), not a five-control wall.
  /// A display preference, not per-day data, so it's deliberately not reset
  /// on a [day] change — it stays as the user left it while paging days.
  bool _addOptionsExpanded = false;

  late DateTime _lastAnchorDay = _anchorDay;

  DateTime get _anchorDay => dateOnly(widget.day ?? DateTime.now());

  @override
  void didUpdateWidget(covariant QuickAddTodoField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `HourlyTodoList` reuses one instance of this widget (no key at its
    // call site) as the selected day changes — reset the per-day add
    // defaults when that happens, the same way the old inline field did.
    if (_anchorDay != _lastAnchorDay) {
      _lastAnchorDay = _anchorDay;
      _addTime = const TimeOfDay(hour: 9, minute: 0);
      _addHasTime = true;
      _addRecurrence = RecurrenceFrequency.none;
      _addPriority = TodoPriority.none;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAddTime() async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: _addTime,
      dialFormat: ref.read(
        settingsControllerProvider.select((s) => s.dialTimeFormatPreference),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _addTime = picked;
      _addHasTime = true;
    });
  }

  String _recurrenceLabel(AppL10n l10n, RecurrenceFrequency f) => switch (f) {
    RecurrenceFrequency.none => l10n.eventRepeatNone,
    RecurrenceFrequency.daily => l10n.eventRepeatDaily,
    RecurrenceFrequency.weekly => l10n.eventRepeatWeekly,
    RecurrenceFrequency.monthly => l10n.eventRepeatMonthly,
    RecurrenceFrequency.yearly => l10n.eventRepeatYearly,
    // To-dos have no lunar-date input mode (that's an event-editor-only
    // feature — see event_editor_sheet.dart's own doc), so this value
    // never actually reaches this switch; only here for exhaustiveness.
    RecurrenceFrequency.yearlyLunar => l10n.eventRepeatYearlyLunar,
  };

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final anchor = _anchorDay;

    final parsed = parseQuickAdd(text, now: DateTime.now());
    final base = parsed.date ?? anchor;
    final time = parsed.time ?? _addTime;
    final title = parsed.title.isEmpty ? text : parsed.title;

    await ref
        .read(todoControllerProvider)
        .add(
          title: title,
          slotStart: DateTime(
            base.year,
            base.month,
            base.day,
            time.hour,
            time.minute,
          ),
          hasTime: parsed.time != null || _addHasTime,
          frequency: _addRecurrence,
          // A parsed !priority/#tag overrides the chip/picker, the same
          // "explicit phrase wins over the UI default" rule the date/time
          // fields already follow.
          priority: parsed.priority ?? _addPriority.value,
          tags: parsed.tags.isEmpty ? null : parsed.tags.join(','),
        );

    if (!mounted) return;
    _controller.clear();
    setState(() {
      _addRecurrence = RecurrenceFrequency.none;
      _addPriority = TodoPriority.none;
    });
    widget.onAdded?.call();

    if (parsed.date != null && !dateOnly(base).isAtSameMomentAs(anchor)) {
      messenger.showAutoDismissSnackBar(
        SnackBar(
          content: Text(
            l10n.todoQuickAddAddedToOtherDay(Fmt.monthDay(base, locale)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final repeating = _addRecurrence != RecurrenceFrequency.none;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardMd,
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.add, size: 20, color: palette.inkFaint),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: l10n.todoHint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: _pickAddTime,
                borderRadius: BorderRadius.all(AppRadius.xs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Text(
                    _addHasTime ? _addTime.format(context) : l10n.todoNoTime,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _addHasTime ? palette.inkSoft : palette.accent,
                    ),
                  ),
                ),
              ),
              // Priority/repeat/no-time all sit behind this toggle by
              // default — tinted accent whenever one of them is set to
              // something non-default, so a collapsed panel never silently
              // hides an active choice from view.
              IconButton(
                tooltip: _addOptionsExpanded
                    ? l10n.todoFewerOptions
                    : l10n.todoMoreOptions,
                onPressed: () =>
                    setState(() => _addOptionsExpanded = !_addOptionsExpanded),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _addOptionsExpanded ? Icons.expand_less : Icons.tune,
                  size: 18,
                  color: (repeating || _addPriority != TodoPriority.none)
                      ? palette.accent
                      : palette.inkFaint,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: context.motionDuration(const Duration(milliseconds: 180)),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !_addOptionsExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        PopupMenuButton<TodoPriority>(
                          tooltip: l10n.todoPriorityLabel,
                          initialValue: _addPriority,
                          onSelected: (v) => setState(() => _addPriority = v),
                          itemBuilder: (context) => TodoPriority.values
                              .map(
                                (p) => PopupMenuItem(
                                  value: p,
                                  child: Text(p.label(l10n)),
                                ),
                              )
                              .toList(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxs,
                              vertical: AppSpacing.xxs,
                            ),
                            child: Icon(
                              _addPriority == TodoPriority.none
                                  ? Icons.flag_outlined
                                  : Icons.flag,
                              size: 18,
                              color:
                                  _addPriority.color(palette) ??
                                  palette.inkFaint,
                            ),
                          ),
                        ),
                        PopupMenuButton<RecurrenceFrequency>(
                          tooltip: l10n.todoRepeat,
                          initialValue: _addRecurrence,
                          onSelected: (v) => setState(() => _addRecurrence = v),
                          itemBuilder: (context) => RecurrenceFrequency.values
                              // To-dos have no lunar-date input mode
                              // (event-editor-only), so yearlyLunar is
                              // excluded here rather than assumed unreachable.
                              .where(
                                (f) => f != RecurrenceFrequency.yearlyLunar,
                              )
                              .map(
                                (f) => PopupMenuItem(
                                  value: f,
                                  child: Text(_recurrenceLabel(l10n, f)),
                                ),
                              )
                              .toList(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxs,
                              vertical: AppSpacing.xxs,
                            ),
                            child: Icon(
                              Icons.repeat_rounded,
                              size: 18,
                              color: repeating
                                  ? palette.accent
                                  : palette.inkFaint,
                            ),
                          ),
                        ),
                        // Toggles between a picked time and no-time-at-all —
                        // tapping the chip in the row above always sets a
                        // concrete time (that's what showTimePicker does),
                        // so clearing it needs its own control.
                        IconButton(
                          tooltip: l10n.todoNoTime,
                          onPressed: () =>
                              setState(() => _addHasTime = !_addHasTime),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            _addHasTime
                                ? Icons.timer_off_outlined
                                : Icons.access_time_outlined,
                            size: 16,
                            color: palette.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
