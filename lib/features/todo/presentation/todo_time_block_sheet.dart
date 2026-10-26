import '../../schedule/application/schedule_providers.dart' show dateOnly;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/clock.dart';
import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';
import '../../../core/di.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../design/widgets/app_dialog.dart';
import '../../../design/widgets/minutes_picker_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/application/settings_controller.dart';
import '../application/todo_providers.dart';
import '../domain/planning_preferences.dart';
import '../domain/todo_time_block.dart';

Future<TodoRow?> showTodoTimeBlockSheet(BuildContext context, TodoRow todo) =>
    showAdaptiveBottomSheet<TodoRow>(
      context: context,
      builder: (_) => _TimeBlockSheet(todo: todo),
    );

class _TimeBlockSheet extends ConsumerStatefulWidget {
  const _TimeBlockSheet({required this.todo});
  final TodoRow todo;
  @override
  ConsumerState<_TimeBlockSheet> createState() => _TimeBlockSheetState();
}

class _TimeBlockSheetState extends ConsumerState<_TimeBlockSheet> {
  late DateTime _start;
  late int _minutes;
  late PlanningPreferences _prefs;
  late Future<List<TimeBlockConflict>> _busyRanges;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _prefs = PlanningPreferences.load(ref.read(sharedPreferencesProvider));
    final row = widget.todo;
    _start = row.hasTime
        ? row.slotStart
        : DateTime(
            row.slotStart.year,
            row.slotStart.month,
            row.slotStart.day,
            _prefs.startMinute ~/ 60,
            _prefs.startMinute % 60,
          );
    _minutes = TodoTimeBlock.of(row)?.duration.inMinutes ?? 30;
    _refresh();
  }

  DateTime _at(int minute) => DateTime(
    _start.year,
    _start.month,
    _start.day,
    minute ~/ 60,
    minute % 60,
  );
  void _refresh() {
    _busyRanges = findTimeBlockConflicts(
      ref.read(todoDaoProvider),
      widget.todo.id,
      TodoTimeBlock(dateOnly(_start), addCalendarDays(dateOnly(_start), 1)),
      blockAllDay: _prefs.blockAllDay,
    );
  }

  String _range(TodoTimeBlock block, String locale, bool use24) =>
      '${Fmt.monthDay(block.start, locale)} ${Fmt.time(block.start, locale, use24Hour: use24)} – ${Fmt.monthDay(block.end, locale)} ${Fmt.time(block.end, locale, use24Hour: use24)}';
  Future<TimeOfDay?> _pickTime(int minute) => showAppTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: (minute ~/ 60) % 24, minute: minute % 60),
    dialFormat: ref.read(settingsControllerProvider).dialTimeFormatPreference,
  );
  Future<void> _pickWork(bool isBreak, bool end) async {
    final value = isBreak
        ? (end ? _prefs.breakEnd : _prefs.breakStart)
        : (end ? _prefs.endMinute : _prefs.startMinute);
    final picked = await _pickTime(value);
    if (picked == null || !mounted) return;
    final minute = picked.hour * 60 + picked.minute;
    final ws = !isBreak && !end ? minute : _prefs.startMinute;
    final we = !isBreak && end ? minute : _prefs.endMinute;
    final bs = isBreak && !end ? minute : _prefs.breakStart;
    final be = isBreak && end ? minute : _prefs.breakEnd;
    if (we <= ws || be <= bs) {
      setState(() => _error = AppL10n.of(context).durationInvalid);
      return;
    }
    _changePrefs(
      PlanningPreferences(
        startMinute: ws,
        endMinute: we,
        breakStart: bs,
        breakEnd: be,
        hasBreak: _prefs.hasBreak,
        weekdays: _prefs.weekdays,
        blockAllDay: _prefs.blockAllDay,
      ),
    );
  }

  void _changePrefs(PlanningPreferences value) {
    setState(() {
      _prefs = value;
      _error = null;
      _refresh();
    });
  }

  Future<void> _apply({bool clear = false}) async {
    if (_saving) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _prefs.save(ref.read(sharedPreferencesProvider));
      final controller = ref.read(todoControllerProvider);
      if (clear) {
        await controller.clearTime(widget.todo.id);
      } else {
        final acknowledged = <String>{};
        final block = TodoTimeBlock(
          _start,
          _start.add(Duration(minutes: _minutes)),
        );
        while (true) {
          final result = await controller.setTimeBlock(
            widget.todo.id,
            block,
            acknowledgedConflicts: acknowledged,
            blockAllDay: _prefs.blockAllDay,
          );
          if (!mounted) return;
          if (result.saved) {
            if (result.deferred) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.blockDeferred)));
            }
            break;
          }
          final locale = Localizations.localeOf(context).toLanguageTag();
          final use24 = resolveUse24Hour(
            ref.read(settingsControllerProvider).displayTimeFormatPreference,
            context,
          );
          final accepted = await showAppDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.blockConflict),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.blockConflictHelp),
                    for (final conflict in result.conflicts)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${conflict.title}\n${_range(TodoTimeBlock(conflict.start, conflict.end), locale, use24)}',
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.blockConfirmOverlap),
                ),
              ],
            ),
          );
          if (accepted != true || !mounted) return;
          acknowledged.addAll(result.conflicts.map((c) => c.token));
        }
      }
      final row = await ref.read(todoDaoProvider).findById(widget.todo.id);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context, row);
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.todoUpdateFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24 = resolveUse24Hour(
      ref.watch(settingsControllerProvider).displayTimeFormatPreference,
      context,
    );
    final now = ref.watch(nowTickerProvider).value ?? DateTime.now();
    final block = TodoTimeBlock(
      _start,
      _start.add(Duration(minutes: _minutes)),
    );
    String clock(int minute) => Fmt.time(_at(minute), locale, use24Hour: use24);
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: AbsorbPointer(
            absorbing: _saving,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.blockTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(widget.todo.title),
                Text(_range(block, locale, use24)),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: Text(Fmt.monthDay(_start, locale)),
                      onPressed: () async {
                        final day = await showAppDatePicker(
                          context: context,
                          initialDate: _start,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2200),
                        );
                        if (mounted && day != null) {
                          setState(() {
                            _start = DateTime(
                              day.year,
                              day.month,
                              day.day,
                              _start.hour,
                              _start.minute,
                            );
                            _refresh();
                          });
                        }
                      },
                    ),
                    ActionChip(
                      label: Text(Fmt.time(_start, locale, use24Hour: use24)),
                      onPressed: () async {
                        final time = await _pickTime(
                          _start.hour * 60 + _start.minute,
                        );
                        if (mounted && time != null) {
                          setState(
                            () => _start = _at(time.hour * 60 + time.minute),
                          );
                        }
                      },
                    ),
                    ActionChip(
                      label: Text(l10n.durationMinutes(_minutes)),
                      onPressed: () async {
                        final minutes = await showMinutesPicker(
                          context,
                          initialMinutes: _minutes,
                        );
                        if (mounted && minutes != null) {
                          setState(() => _minutes = minutes);
                        }
                      },
                    ),
                  ],
                ),
                ExpansionTile(
                  title: Text(l10n.blockAvailability),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _pickWork(false, false),
                          child: Text(
                            '${l10n.blockWorkStart} ${clock(_prefs.startMinute)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () => _pickWork(false, true),
                          child: Text(
                            '${l10n.blockWorkEnd} ${clock(_prefs.endMinute)}',
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          FilterChip(
                            label: Text(
                              Fmt.weekdayShort(DateTime(2024, 1, d), locale),
                            ),
                            selected: _prefs.weekdays.contains(d),
                            onSelected: (value) {
                              final days = {..._prefs.weekdays};
                              if (value) {
                                days.add(d);
                              } else {
                                days.remove(d);
                              }
                              _changePrefs(
                                PlanningPreferences(
                                  startMinute: _prefs.startMinute,
                                  endMinute: _prefs.endMinute,
                                  breakStart: _prefs.breakStart,
                                  breakEnd: _prefs.breakEnd,
                                  hasBreak: _prefs.hasBreak,
                                  weekdays: days,
                                  blockAllDay: _prefs.blockAllDay,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    SwitchListTile(
                      title: Text(l10n.blockBreak),
                      value: _prefs.hasBreak,
                      onChanged: (value) => _changePrefs(
                        PlanningPreferences(
                          startMinute: _prefs.startMinute,
                          endMinute: _prefs.endMinute,
                          breakStart: _prefs.breakStart,
                          breakEnd: _prefs.breakEnd,
                          hasBreak: value,
                          weekdays: _prefs.weekdays,
                          blockAllDay: _prefs.blockAllDay,
                        ),
                      ),
                    ),
                    if (_prefs.hasBreak)
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: () => _pickWork(true, false),
                            child: Text(clock(_prefs.breakStart)),
                          ),
                          TextButton(
                            onPressed: () => _pickWork(true, true),
                            child: Text(clock(_prefs.breakEnd)),
                          ),
                        ],
                      ),
                    SwitchListTile(
                      title: Text(l10n.blockAllDay),
                      value: _prefs.blockAllDay,
                      onChanged: (value) => _changePrefs(
                        PlanningPreferences(
                          startMinute: _prefs.startMinute,
                          endMinute: _prefs.endMinute,
                          breakStart: _prefs.breakStart,
                          breakEnd: _prefs.breakEnd,
                          hasBreak: _prefs.hasBreak,
                          weekdays: _prefs.weekdays,
                          blockAllDay: value,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  l10n.blockSuggestions,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l10n.blockSuggestionHelp),
                FutureBuilder<List<TimeBlockConflict>>(
                  future: _busyRanges,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return TextButton(
                        onPressed: () => setState(_refresh),
                        child: Text(l10n.commonRetry),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final slots = _prefs.weekdays.contains(_start.weekday)
                        ? availableTimeBlocks(
                            work: TodoTimeBlock(
                              _at(_prefs.startMinute),
                              _at(_prefs.endMinute),
                            ),
                            duration: Duration(minutes: _minutes),
                            notBefore: now,
                            busy: [
                              for (final c in snapshot.data!)
                                TodoTimeBlock(c.start, c.end),
                              if (_prefs.hasBreak)
                                TodoTimeBlock(
                                  _at(_prefs.breakStart),
                                  _at(_prefs.breakEnd),
                                ),
                            ],
                          )
                        : <TodoTimeBlock>[];
                    if (slots.isEmpty) return Text(l10n.blockNoSuggestions);
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final slot in slots)
                              ActionChip(
                                label: Text(
                                  '${clock(slot.start.hour * 60 + slot.start.minute)} – ${clock(slot.end.hour * 60 + slot.end.minute)}',
                                ),
                                onPressed: () =>
                                    setState(() => _start = slot.start),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_saving) const LinearProgressIndicator(),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      onPressed: () => _apply(),
                      child: Text(l10n.eventSave),
                    ),
                    if (widget.todo.hasTime)
                      TextButton(
                        onPressed: () => _apply(clear: true),
                        child: Text(l10n.blockClear),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.commonCancel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
