import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/di.dart';
import '../../../../core/format.dart';
import '../../../../core/time_format.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../../design/widgets/multi_chip_row.dart';
import '../../../../design/widgets/snackbar_x.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/schedule_providers.dart';
import '../../domain/event_input.dart';
import '../../domain/recurrence.dart';
import 'mirrored_event_detail_screen.dart';

/// Opens the create/edit screen. When [existing] is null it's a new event
/// anchored at [initialDay]; otherwise it edits that row. [duplicateFrom]
/// pre-fills a new (unsaved) event's fields from another row — used by the
/// "duplicate" action, which always creates a fresh event rather than
/// editing the source in place.
///
/// An [existing] event mirrored in from a subscribed calendar (see
/// CalendarImportService's doc comment) opens the read-only
/// [MirroredEventDetailScreen] instead — never the editable form, since a
/// save there would try to push the edit back out to a calendar that may
/// not even be writable.
///
/// Pushed as a full-screen route (not `showModalBottomSheet`) so its content
/// always gets the whole screen height up front — a modal sheet that resizes
/// itself as fields like recurrence or reminder chips show/hide could grow
/// taller than its viewport without Flutter ever making the extra content
/// reachable by scrolling, cutting it off (confirmed via
/// `debugDumpRenderTree`: the layout was correct, only the scroll/paint
/// never caught up). A full page sidesteps that class of bug entirely.
Future<void> showEventEditor(
  BuildContext context, {
  EventRow? existing,
  DateTime? initialDay,
  EventRow? duplicateFrom,
  DateTime? initialStart,
  DateTime? initialEnd,
}) {
  if (existing != null && existing.importSourceCalendarId != null) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MirroredEventDetailScreen(event: existing),
      ),
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EventEditorSheet(
        existing: existing,
        initialDay: initialDay,
        duplicateFrom: duplicateFrom,
        initialStart: initialStart,
        initialEnd: initialEnd,
      ),
    ),
  );
}

class EventEditorSheet extends ConsumerStatefulWidget {
  const EventEditorSheet({
    super.key,
    this.existing,
    this.initialDay,
    this.duplicateFrom,
    this.initialStart,
    this.initialEnd,
  });

  final EventRow? existing;
  final DateTime? initialDay;
  final EventRow? duplicateFrom;

  /// Pre-fills a brand-new event's start/end (e.g. from a drag-to-create
  /// gesture on the day/week timeline) — ignored when [existing] or
  /// [duplicateFrom] supplies its own times.
  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  ConsumerState<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends ConsumerState<EventEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _memo;
  late final TextEditingController _location;
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late bool _notify;
  late int _reminderMinutesBefore;

  /// Extra reminder offsets on top of [_reminderMinutesBefore] — see
  /// `EventAlertX.reminderOffsets` for how the two combine.
  late Set<int> _additionalReminders;
  late EventColorTag? _colorTag;

  /// Set when the user picked a color from the full palette rather than a
  /// preset — mutually exclusive with [_colorTag].
  late Color? _customColor;
  late RecurrenceFrequency _recurrence;
  late DateTime _recurrenceUntil;

  /// Extra weekdays a weekly repeat also lands on, on top of [_start]'s own
  /// — see `EventInput.recurrenceByWeekdays`. Empty means "just the start
  /// date's weekday", the original single-weekday behavior.
  final Set<int> _recurrenceWeekdays = {};

  /// `false` = ends on [_recurrenceUntil] (the original, only behavior);
  /// `true` = ends after [_recurrenceCount] occurrences instead — see
  /// `EventInput.recurrenceCount`. Exactly one of the two is ever sent to
  /// [EventInput], matching its own exactly-one-of assert.
  bool _recurrenceEndByCount = false;
  int _recurrenceCount = 10;
  bool _titleError = false;

  static const List<int> _leadTimeOptions = [0, 5, 10, 30, 60, 1440];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    // A duplicate only ever pre-fills a brand-new event's fields — [e] (the
    // row actually being edited in place) always wins when both are set,
    // though callers never pass both.
    final source = e ?? widget.duplicateFrom;
    _title = TextEditingController(text: source?.title ?? '');
    _memo = TextEditingController(text: source?.memo ?? '');
    _location = TextEditingController(text: source?.location ?? '');
    final anchor = widget.initialDay ?? DateTime.now();
    final base =
        source?.startAt ??
        widget.initialStart ??
        DateTime(anchor.year, anchor.month, anchor.day, _nextHour());
    _start = base;
    _end =
        source?.endAt ??
        (source == null ? widget.initialEnd : null) ??
        base.add(const Duration(hours: 1));
    _allDay = source?.isAllDay ?? false;
    _notify = source?.notify ?? true;
    _reminderMinutesBefore = source?.reminderMinutesBefore ?? 0;
    _additionalReminders = (source?.additionalReminderMinutes ?? '')
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
    _colorTag = EventColorTag.tryParse(source?.colorTag);
    _customColor = EventColorTag.parseHex(source?.colorTag);
    // Recurrence is create-only (see EventRepository.save); defaults are
    // never surfaced when editing since the picker stays hidden then.
    _recurrence = RecurrenceFrequency.none;
    _recurrenceUntil = _start.add(const Duration(days: 365));
  }

  String _recurrenceLabel(AppL10n l10n, RecurrenceFrequency f) => switch (f) {
    RecurrenceFrequency.none => l10n.eventRepeatNone,
    RecurrenceFrequency.daily => l10n.eventRepeatDaily,
    RecurrenceFrequency.weekly => l10n.eventRepeatWeekly,
    RecurrenceFrequency.monthly => l10n.eventRepeatMonthly,
    RecurrenceFrequency.yearly => l10n.eventRepeatYearly,
  };

  /// 2024-01-01 was a Monday, so `DateTime(2024, 1, weekday)` for
  /// weekday in 1..7 lands exactly on that week's Mon..Sun — a cheap way to
  /// get a locale-correct short weekday name out of [Fmt.weekdayShort]
  /// without a dedicated weekday-name table.
  static const List<int> _weekdayOptions = [1, 2, 3, 4, 5, 6, 7];

  String _weekdayLabel(int weekday, String locale) =>
      Fmt.weekdayShort(DateTime(2024, 1, weekday), locale);

  String _leadTimeLabel(AppL10n l10n, int minutes) {
    if (minutes == 0) return l10n.eventReminderAtStart;
    if (minutes == 1440) return l10n.eventReminderDayBefore;
    if (minutes % 60 == 0) return l10n.eventReminderHoursBefore(minutes ~/ 60);
    return l10n.eventReminderMinutesBefore(minutes);
  }

  int _nextHour() {
    final h = DateTime.now().hour + 1;
    return h > 23 ? 23 : h;
  }

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isStart) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    var picked = DateTime(
      date.year,
      date.month,
      date.day,
      initial.hour,
      initial.minute,
    );
    if (!_allDay) {
      final time = await showAppTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        dialFormat: ref.read(
          settingsControllerProvider.select((s) => s.dialTimeFormatPreference),
        ),
      );
      if (time == null || !mounted) return;
      picked = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }
    setState(() {
      if (isStart) {
        final delta = _end.difference(_start);
        // Preserve the recurrence window's length in days so pushing the
        // start date out doesn't leave a stale "until" behind it — an
        // "until" on/before the new start collapses the whole series to a
        // single occurrence (see RecurrenceExpansion.occurrences' doc), so
        // when that would happen, carry the until forward by the same shift
        // instead of silently truncating the recurrence.
        final span = dateOnly(_recurrenceUntil).difference(dateOnly(_start));
        _start = picked;
        if (_end.isBefore(_start)) _end = _start.add(delta.abs());
        if (_recurrence != RecurrenceFrequency.none &&
            !dateOnly(_recurrenceUntil).isAfter(dateOnly(_start))) {
          _recurrenceUntil = dateOnly(_start).add(span);
        }
      } else {
        _end = picked.isBefore(_start)
            ? _start.add(const Duration(hours: 1))
            : picked;
      }
    });
  }

  Future<void> _pickUntil() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recurrenceUntil.isBefore(_start)
          ? _start
          : _recurrenceUntil,
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    // Compared by date only in RecurrenceExpansion, so no need to match this
    // to the event's time-of-day.
    setState(
      () => _recurrenceUntil = DateTime(date.year, date.month, date.day),
    );
  }

  Future<void> _pickCustomColor() async {
    final l10n = AppL10n.of(context);
    var working =
        _customColor ??
        _colorTag?.color ??
        AppColors.timeGradient(_start).first;

    final picked = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.eventColorPickerTitle),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: working,
            onColorChanged: (c) => working = c,
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(working),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customColor = picked;
      _colorTag = null;
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    final isNewRecurring =
        widget.existing == null && _recurrence != RecurrenceFrequency.none;
    final truncated =
        isNewRecurring &&
        RecurrenceExpansion.isTruncated(
          start: _start,
          frequency: _recurrence,
          until: _recurrenceEndByCount ? null : _recurrenceUntil,
          count: _recurrenceEndByCount ? _recurrenceCount : null,
          byWeekdays: _recurrenceWeekdays,
        );
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // An all-day event's start/end can still carry a leftover time-of-day
    // from before the toggle was flipped on (the time picker is simply
    // skipped while _allDay is true, not reset) — normalize to day
    // boundaries here rather than pushing e.g. "9:00 AM, all-day" to the OS
    // calendar, which EventKit/CalendarProvider would silently re-normalize
    // on their own, surfacing as a spurious mismatch on the very next
    // reconcile. endAt lands on the day *after* its own date, matching the
    // half-open-interval convention EventDao's queries already use (and how
    // EventKit itself represents an all-day event's end).
    final startAt = _allDay ? dateOnly(_start) : _start;
    final endAt = _allDay ? dateOnly(_end).add(const Duration(days: 1)) : _end;

    final input = EventInput(
      id: widget.existing?.id,
      title: _title.text.trim(),
      memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      startAt: startAt,
      endAt: endAt,
      isAllDay: _allDay,
      notify: _notify,
      reminderMinutesBefore: _reminderMinutesBefore,
      additionalReminderMinutes: _additionalReminders.toList(),
      colorTag: _customColor != null
          ? EventColorTag.toHex(_customColor!)
          : _colorTag?.name,
      recurrenceFrequency: _recurrence,
      recurrenceUntil:
          _recurrence == RecurrenceFrequency.none || _recurrenceEndByCount
          ? null
          : _recurrenceUntil,
      recurrenceCount:
          _recurrence == RecurrenceFrequency.none || !_recurrenceEndByCount
          ? null
          : _recurrenceCount,
      recurrenceByWeekdays: _recurrence == RecurrenceFrequency.weekly
          ? _recurrenceWeekdays
          : null,
    );
    final repo = ref.read(eventRepositoryProvider);

    // Editing an existing occurrence of a recurring series defaults to
    // touching just that one row (see EventRepository.save's doc) — offer
    // "apply to this and future" as an explicit opt-in, mirroring _delete()'s
    // "this only / this and future" choice below.
    final existing = widget.existing;
    if (existing != null && existing.recurrenceGroupId != null) {
      final applyToFuture = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.eventSaveSeriesTitle),
          content: Text(l10n.eventSaveSeriesBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.eventSaveThisOnly),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.eventSaveThisAndFuture),
            ),
          ],
        ),
      );
      if (applyToFuture == null || !mounted) return;
      if (applyToFuture) {
        await repo.saveSeriesFrom(existing.id, input);
      } else {
        await repo.save(input);
      }
    } else {
      await repo.save(input);
    }
    if (!mounted) return;
    navigator.pop();
    if (truncated) {
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.eventRecurrenceTruncated)),
      );
    }
  }

  void _duplicate() {
    final existing = widget.existing;
    if (existing == null) return;
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    navigator.pop();
    showEventEditor(rootContext, duplicateFrom: existing);
  }

  /// Exports just this one event as a `.ics` file and hands it to the
  /// share sheet — for sending a single appointment to someone, unlike
  /// settings' whole-calendar export.
  Future<void> _share() async {
    final existing = widget.existing;
    if (existing == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    try {
      final file = await ref
          .read(icsExportServiceProvider)
          .exportEventToFile(existing);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: existing.title.isEmpty ? null : existing.title,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.eventShareFailed)),
      );
    }
  }

  Future<void> _openTemplates() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (sheetContext) => _TemplatePickerSheet(
        onApply: (t) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _title.text = t.title;
            _memo.text = t.memo ?? '';
            _end = _start.add(Duration(minutes: t.durationMinutes));
            _allDay = t.isAllDay;
            _notify = t.notify;
            _reminderMinutesBefore = t.reminderMinutesBefore;
            // Templates don't carry additional reminders — applying one
            // resets to just its single lead time rather than leaving
            // whatever was picked before around.
            _additionalReminders = {};
            _colorTag = EventColorTag.tryParse(t.colorTag);
            _customColor = EventColorTag.parseHex(t.colorTag);
          });
        },
        currentSnapshot: () => _TemplateSnapshot(
          title: _title.text.trim(),
          memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
          durationMinutes: _end
              .difference(_start)
              .inMinutes
              .clamp(1, 60 * 24 * 365),
          isAllDay: _allDay,
          colorTag: _customColor != null
              ? EventColorTag.toHex(_customColor!)
              : _colorTag?.name,
          notify: _notify,
          reminderMinutesBefore: _reminderMinutesBefore,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final id = existing.id;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(eventRepositoryProvider);

    var deleteSeries = false;
    if (existing.recurrenceGroupId != null) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.eventDeleteSeriesTitle),
          content: Text(l10n.eventDeleteSeriesBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.eventDeleteThisOnly),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: context.palette.danger,
              ),
              child: Text(l10n.eventDeleteThisAndFuture),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      deleteSeries = choice;
    }

    if (deleteSeries) {
      await repo.deleteSeriesFrom(id);
    } else {
      await repo.delete(id);
    }
    if (!mounted) return;
    navigator.pop();
    messenger.showAutoDismissSnackBar(SnackBar(content: Text(l10n.eventDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final accent = AppColors.timeGradient(_start).first;
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );

    // A full-screen route, not a modal bottom sheet — see the doc comment on
    // showEventEditor() for why. Scaffold handles the keyboard inset and
    // safe areas on its own, so none of that needs hand-rolling here.
    return GestureDetector(
      // Tapping any empty space (dividers, background, chip gaps) dismisses
      // the keyboard instead of leaving it stuck open — fields and buttons
      // still claim their own taps first.
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: palette.surface,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              // Generous blank bottom padding, not just AppSpacing.md — see
              // PROGRESS.md's "잔여 엣지 케이스" note. Impeller (iOS
              // simulator) has a rendering glitch right at a scroll view's
              // maxScrollExtent boundary; keeping the last real field well
              // clear of that boundary means the boundary itself only ever
              // lands on empty padding, never on content that could glitch.
              AppSpacing.xxl * 2,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.commonCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.existing == null ? l10n.eventNew : l10n.eventEdit,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (widget.existing != null) ...[
                    IconButton(
                      icon: const Icon(Icons.ios_share),
                      tooltip: l10n.eventShare,
                      onPressed: _share,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_all_rounded),
                      tooltip: l10n.eventDuplicate,
                      onPressed: _duplicate,
                    ),
                  ] else
                    IconButton(
                      icon: const Icon(Icons.bookmark_border_rounded),
                      tooltip: l10n.eventTemplates,
                      onPressed: _openTemplates,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _title,
                autofocus: widget.existing == null,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: l10n.eventTitleHint,
                  errorText: _titleError ? l10n.eventTitleRequired : null,
                ),
                onChanged: (_) {
                  if (_titleError) {
                    setState(() => _titleError = false);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _memo,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(hintText: l10n.eventMemoHint),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _location,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: l10n.eventLocationHint,
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ToggleRow(
                label: l10n.eventAllDay,
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
              const Divider(height: AppSpacing.lg),
              _DateRow(
                label: l10n.eventStart,
                value: _allDay
                    ? Fmt.monthDay(_start, locale)
                    : '${Fmt.monthDay(_start, locale)}  ${Fmt.time(_start, locale, use24Hour: use24)}',
                onTap: () => _pick(true),
                accent: accent,
              ),
              const SizedBox(height: AppSpacing.sm),
              _DateRow(
                label: l10n.eventEnd,
                value: _allDay
                    ? Fmt.monthDay(_end, locale)
                    : '${Fmt.monthDay(_end, locale)}  ${Fmt.time(_end, locale, use24Hour: use24)}',
                onTap: () => _pick(false),
                accent: accent,
              ),
              if (widget.existing == null) ...[
                const Divider(height: AppSpacing.lg),
                _ChipRow<RecurrenceFrequency>(
                  label: l10n.eventRepeat,
                  options: RecurrenceFrequency.values,
                  selected: _recurrence,
                  labelFor: (f) => _recurrenceLabel(l10n, f),
                  accent: accent,
                  onChanged: (v) => setState(() => _recurrence = v),
                ),
                if (_recurrence == RecurrenceFrequency.weekly) ...[
                  const SizedBox(height: AppSpacing.sm),
                  MultiChipRow(
                    label: l10n.eventRepeatWeekdays,
                    options: _weekdayOptions,
                    // The start date's own weekday is always implicitly
                    // included (see EventInput.recurrenceByWeekdays), so it's
                    // shown selected here even before the user touches
                    // anything — reflecting what will actually be saved.
                    selected: {..._recurrenceWeekdays, _start.weekday},
                    labelFor: (w) => _weekdayLabel(w, locale),
                    accent: accent,
                    onChanged: (v) => setState(() {
                      if (_recurrenceWeekdays.contains(v)) {
                        // The start date's own weekday can't be removed —
                        // it's always implicitly included (see
                        // EventInput.recurrenceByWeekdays), so leaving it
                        // selectable-but-inert here would be misleading.
                        if (v == _start.weekday) return;
                        _recurrenceWeekdays.remove(v);
                      } else {
                        _recurrenceWeekdays.add(v);
                      }
                    }),
                  ),
                ],
                if (_recurrence != RecurrenceFrequency.none) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ChipRow<bool>(
                    label: l10n.eventRepeatEndLabel,
                    options: const [false, true],
                    selected: _recurrenceEndByCount,
                    labelFor: (byCount) => byCount
                        ? l10n.eventRepeatEndByCount
                        : l10n.eventRepeatEndByDate,
                    accent: accent,
                    onChanged: (v) => setState(() => _recurrenceEndByCount = v),
                    trailing: _recurrenceEndByCount
                        ? _CountStepper(
                            count: _recurrenceCount,
                            max: RecurrenceExpansion.maxOccurrences,
                            accent: accent,
                            labelFor: (n) => l10n.eventRepeatCountTimes(n),
                            onChanged: (v) =>
                                setState(() => _recurrenceCount = v),
                          )
                        : TextButton(
                            onPressed: _pickUntil,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              Fmt.monthDay(_recurrenceUntil, locale),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: accent,
                              ),
                            ),
                          ),
                  ),
                ],
              ],
              const Divider(key: ValueKey('div-notify'), height: AppSpacing.lg),
              _ToggleRow(
                key: const ValueKey('row-notify'),
                label: l10n.eventNotify,
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
              if (_notify) ...[
                const SizedBox(
                  key: ValueKey('gap-reminder'),
                  height: AppSpacing.sm,
                ),
                _ChipRow<int>(
                  key: const ValueKey('chips-reminder'),
                  label: l10n.eventReminderLead,
                  options: _leadTimeOptions,
                  selected: _reminderMinutesBefore,
                  labelFor: (m) => _leadTimeLabel(l10n, m),
                  accent: accent,
                  onChanged: (v) => setState(() {
                    _reminderMinutesBefore = v;
                    // Keep the primary and additional pickers
                    // disjoint so the same offset never shows
                    // selected in both.
                    _additionalReminders.remove(v);
                  }),
                ),
                const SizedBox(
                  key: ValueKey('gap-reminder-extra'),
                  height: AppSpacing.sm,
                ),
                MultiChipRow(
                  key: const ValueKey('chips-reminder-extra'),
                  label: l10n.eventReminderAdditional,
                  options: _leadTimeOptions
                      .where((m) => m != _reminderMinutesBefore)
                      .toList(),
                  selected: _additionalReminders,
                  labelFor: (m) => _leadTimeLabel(l10n, m),
                  accent: accent,
                  onChanged: (v) => setState(() {
                    if (_additionalReminders.contains(v)) {
                      _additionalReminders.remove(v);
                    } else {
                      _additionalReminders.add(v);
                    }
                  }),
                ),
              ],
              const Divider(key: ValueKey('div-color'), height: AppSpacing.lg),
              _ColorTagRow(
                key: const ValueKey('row-color'),
                label: l10n.eventColor,
                autoLabel: l10n.eventColorAuto,
                customLabel: l10n.eventColorCustom,
                autoColor: accent,
                selected: _colorTag,
                customColor: _customColor,
                onChanged: (v) => setState(() {
                  _colorTag = v;
                  _customColor = null;
                }),
                onCustomColorTap: _pickCustomColor,
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                if (widget.existing != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.danger,
                        side: BorderSide(color: palette.danger),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.cardMd,
                        ),
                      ),
                      child: Text(l10n.eventDelete),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.cardMd,
                      ),
                    ),
                    child: Text(l10n.eventSave),
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

/// A snapshot of the fields a template captures, read live from the editor's
/// current state at the moment the user chooses to save it.
class _TemplateSnapshot {
  const _TemplateSnapshot({
    required this.title,
    required this.memo,
    required this.durationMinutes,
    required this.isAllDay,
    required this.colorTag,
    required this.notify,
    required this.reminderMinutesBefore,
  });

  final String title;
  final String? memo;
  final int durationMinutes;
  final bool isAllDay;
  final String? colorTag;
  final bool notify;
  final int reminderMinutesBefore;
}

/// Lists saved templates for quick reuse and offers saving the editor's
/// current fields as a new one. Selecting a row hands the row back to the
/// caller via [onApply]; this sheet never touches [EventRepository] itself.
class _TemplatePickerSheet extends ConsumerWidget {
  const _TemplatePickerSheet({
    required this.onApply,
    required this.currentSnapshot,
  });

  final ValueChanged<EventTemplateRow> onApply;
  final _TemplateSnapshot Function() currentSnapshot;

  Future<void> _saveCurrent(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.templatesSaveCurrent),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.templatesNameHint),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showAutoDismissSnackBar(SnackBar(content: Text(l10n.templatesNameRequired)));
      return;
    }
    final snap = currentSnapshot();
    await ref
        .read(eventTemplateDaoProvider)
        .upsert(
          EventTemplatesCompanion.insert(
            id: const Uuid().v4(),
            name: name,
            title: Value(snap.title),
            memo: Value(snap.memo),
            durationMinutes: Value(snap.durationMinutes),
            isAllDay: Value(snap.isAllDay),
            colorTag: Value(snap.colorTag),
            notify: Value(snap.notify),
            reminderMinutesBefore: Value(snap.reminderMinutesBefore),
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showAutoDismissSnackBar(SnackBar(content: Text(l10n.templatesSaved)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final templatesAsync = ref.watch(eventTemplatesProvider);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.xs,
              ),
              child: Text(
                l10n.templatesTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: templatesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('$e'),
                ),
                data: (templates) => templates.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter,
                          vertical: AppSpacing.lg,
                        ),
                        child: Text(
                          l10n.templatesEmpty,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.inkFaint),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter,
                        ),
                        itemCount: templates.length,
                        itemBuilder: (context, i) {
                          final t = templates[i];
                          return Dismissible(
                            key: ValueKey(t.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                color: palette.danger,
                              ),
                            ),
                            onDismissed: (_) {
                              ref
                                  .read(eventTemplateDaoProvider)
                                  .deleteById(t.id);
                              ScaffoldMessenger.of(
                                context,
                              ).showAutoDismissSnackBar(
                                SnackBar(content: Text(l10n.templatesDeleted)),
                              );
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(t.name),
                              subtitle: t.title.isEmpty ? null : Text(t.title),
                              onTap: () => onApply(t),
                            ),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xs,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              child: OutlinedButton.icon(
                onPressed: () => _saveCurrent(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.templatesSaveCurrent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// A labeled row of single-select choice chips. Used for both the
/// notification lead-time picker (`int` minutes) and the repeat-frequency
/// picker (`RecurrenceFrequency`).
/// A compact -/+ stepper for [_recurrenceCount] — sits in a [_ChipRow]'s
/// [_ChipRow.trailing] slot (see its doc comment for why nothing here ever
/// adds a row of its own), clamped to [1, max].
class _CountStepper extends StatelessWidget {
  const _CountStepper({
    required this.count,
    required this.max,
    required this.accent,
    required this.labelFor,
    required this.onChanged,
  });

  final int count;
  final int max;
  final Color accent;
  final String Function(int count) labelFor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: count > 1 ? () => onChanged(count - 1) : null,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(Icons.remove_circle_outline, size: 20, color: accent),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            labelFor(count),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: palette.inkSoft),
          ),
        ),
        IconButton(
          onPressed: count < max ? () => onChanged(count + 1) : null,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(Icons.add_circle_outline, size: 20, color: accent),
        ),
      ],
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.accent,
    required this.onChanged,
    this.trailing,
  });

  final String label;
  final List<T> options;
  final T selected;
  final String Function(T value) labelFor;
  final Color accent;
  final ValueChanged<T> onChanged;

  /// An optional control shown on the same line as [label] instead of on a
  /// row of its own — used by the repeat-until date so selecting it never
  /// adds height to the form. Adding *any* extra row here (even an empty,
  /// zero-content one past a few pixels tall) reliably corrupts every row
  /// below it once the form's total content exceeds one screen — text
  /// renders visibly garbled and stays that way regardless of the
  /// surrounding scroll container. See docs/PROGRESS.md §3.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: palette.inkSoft,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in options)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text(labelFor(value)),
                    selected: selected == value,
                    onSelected: (_) => onChanged(value),
                    showCheckmark: false,
                    backgroundColor: palette.surface,
                    selectedColor: accent,
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: selected == value ? Colors.white : palette.inkSoft,
                    ),
                    side: BorderSide(
                      color: selected == value ? accent : palette.hairline,
                    ),
                    shape: const StadiumBorder(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorTagRow extends StatelessWidget {
  const _ColorTagRow({
    super.key,
    required this.label,
    required this.autoLabel,
    required this.customLabel,
    required this.autoColor,
    required this.selected,
    required this.customColor,
    required this.onChanged,
    required this.onCustomColorTap,
  });

  final String label;
  final String autoLabel;
  final String customLabel;

  /// Swatch shown for the "automatic" option — the current time-gradient
  /// accent, so it previews what the card will actually look like.
  final Color autoColor;
  final EventColorTag? selected;

  /// A color picked from the full palette, if that's the active choice —
  /// mutually exclusive with [selected].
  final Color? customColor;
  final ValueChanged<EventColorTag?> onChanged;

  /// Opens the full-palette picker (see [EventEditorSheet._pickCustomColor]).
  final VoidCallback onCustomColorTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Swatch(
                color: autoColor,
                selected: selected == null && customColor == null,
                semanticLabel: autoLabel,
                onTap: () => onChanged(null),
                auto: true,
              ),
              for (final tag in EventColorTag.values)
                _Swatch(
                  color: tag.color,
                  selected: selected == tag,
                  semanticLabel: tag.name,
                  onTap: () => onChanged(tag),
                ),
              _PaletteSwatch(
                color: customColor,
                semanticLabel: customLabel,
                onTap: onCustomColorTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    this.auto = false,
  });

  final Color color;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: selected ? palette.ink : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.surface, width: 1.5),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: auto ? palette.ink : Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The rightmost swatch in [_ColorTagRow]: opens the full color picker.
/// Shows the last custom color once one's been picked, otherwise a neutral
/// palette icon inviting the tap.
class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.color,
    required this.semanticLabel,
    required this.onTap,
  });

  final Color? color;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = color != null;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? palette.surface,
              border: Border.all(
                color: selected ? palette.ink : palette.hairline,
                width: selected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              selected ? Icons.check : Icons.palette_outlined,
              size: 15,
              color: selected ? Colors.white : palette.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: palette.inkSoft,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
