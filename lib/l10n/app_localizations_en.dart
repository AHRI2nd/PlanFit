// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'PlanFit';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingPage1Title => 'A day as a river of time';

  @override
  String get onboardingPage1Body =>
      'From dawn to night, your calendar\'s color flows with the day';

  @override
  String get onboardingPage2Title => 'Events and to-dos, together';

  @override
  String get onboardingPage2Body =>
      'See day, month, or year at a glance, with to-dos alongside your schedule';

  @override
  String get onboardingPage3Title => 'Never miss a moment';

  @override
  String get onboardingPage3Body =>
      'Get a reminder before each event starts, exactly when you want it';

  @override
  String get tabHome => 'Home';

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get tabSettings => 'Settings';

  @override
  String get homeGreetingDawn => 'A quiet dawn';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeGreetingNight => 'Late night';

  @override
  String get homeToday => 'Today';

  @override
  String get homeTodayEmpty => 'Nothing planned or due today';

  @override
  String get homeUpcoming => 'Up next';

  @override
  String get homeUpcomingEmpty => 'Nothing scheduled';

  @override
  String get homeTodayTodos => 'Today\'s to-dos';

  @override
  String homeTodosDone(int done, int total) {
    return '$done/$total done';
  }

  @override
  String get homeNoTodos => 'No to-dos for today';

  @override
  String homeTodosOverdue(int count) {
    return '$count overdue';
  }

  @override
  String get homeNowLabel => 'now';

  @override
  String get homeTodosViewAll => 'View all to-dos';

  @override
  String get homeWeekTitle => 'This week';

  @override
  String homeWeekSummary(int events, int done, int total) {
    return '$events events · $done/$total to-dos done';
  }

  @override
  String get homeWeekEmpty => 'Quiet week so far';

  @override
  String get scheduleTitle => 'Schedule';

  @override
  String get viewDay => 'Day';

  @override
  String get viewWeek => 'Week';

  @override
  String get viewMonth => 'Month';

  @override
  String get viewYear => 'Year';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String get dayLayoutSwitchToClock => 'Clock view';

  @override
  String get dayLayoutSwitchToTimeline => 'Timeline view';

  @override
  String get calendarLegendTooltip => 'What the calendar dots mean';

  @override
  String get calendarLegendTitle => 'What do the dot colors mean?';

  @override
  String get calendarLegendOverdueTodo => 'There\'s an overdue to-do';

  @override
  String get calendarLegendTodo => 'There\'s an unfinished to-do';

  @override
  String get calendarLegendEvent => 'There\'s an event';

  @override
  String get calendarLegendMultiDayBarNote =>
      'A multi-day event\'s color bar is different — it\'s just the color you picked for that event.';

  @override
  String get monthSplitHandleLabel => 'Adjust calendar size';

  @override
  String get dayEmpty => 'This day is still empty';

  @override
  String get dayAddHint => 'Tap + or long-press an empty time to add something';

  @override
  String get agendaEmpty => 'No events coming up';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String get todosSectionTitle => 'To-dos';

  @override
  String get searchTooltip => 'Search';

  @override
  String get quickAddEventTitle => 'Quick add';

  @override
  String get quickAddEventHint => 'Understands dates and times automatically';

  @override
  String get quickAddEventExample => 'Meeting tomorrow 3pm';

  @override
  String quickAddEventCreated(String title, String day, String time) {
    return 'Added \"$title\" · $day $time';
  }

  @override
  String get searchHint => 'Search by title or notes';

  @override
  String get searchEmpty => 'No results';

  @override
  String get searchPrompt => 'Type a title or note to search';

  @override
  String get searchSectionEvents => 'Events';

  @override
  String get searchSectionTodos => 'To-dos';

  @override
  String get searchFilterAll => 'All';

  @override
  String get searchFilterTagLabel => 'Tag';

  @override
  String get searchFilterDateRangePick => 'Pick date range';

  @override
  String get searchFilterDateRangeClear => 'Clear date range filter';

  @override
  String get socialTitle => 'Social';

  @override
  String get socialComingSoonTitle => 'Coming soon';

  @override
  String get socialComingSoonBody =>
      'Adding friends and sharing schedules is on the way. For now, focus on your own time.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationSound => 'Notification sound';

  @override
  String get settingsNotificationSoundDesc =>
      'Play a sound when an event starts';

  @override
  String get settingsExactAlarm => 'Exact-time alerts';

  @override
  String get settingsExactAlarmDesc =>
      'Needs permission to alert right on time';

  @override
  String get settingsCalendar => 'Calendar';

  @override
  String get settingsCalendarSync => 'Sync with device calendar';

  @override
  String get settingsCalendarSyncDesc =>
      'Keep PlanFit events in your device calendar too';

  @override
  String get settingsCalendarAutoImport => 'Auto-import from device calendar';

  @override
  String get settingsCalendarAutoImportDesc =>
      'Also bring in events added directly in the calendar app';

  @override
  String get settingsSyncLog => 'Sync activity';

  @override
  String get settingsLastSync => 'Last synced';

  @override
  String get settingsLastSyncNever => 'Not synced yet';

  @override
  String get settingsCalendarTarget => 'Sync calendar';

  @override
  String get settingsCalendarTargetAuto => 'Auto';

  @override
  String get settingsCalendarTargetDisabledHint => 'Turn on sync to choose';

  @override
  String get settingsCalendarTargetEmpty =>
      'No calendars available to choose from';

  @override
  String get settingsCalendarImport => 'Import from another calendar';

  @override
  String get settingsCalendarImportDesc =>
      'Import from or subscribe to an existing calendar';

  @override
  String get settingsHolidayCalendar => 'Show holidays';

  @override
  String get settingsHolidayCalendarDesc =>
      'Automatically loads a holiday calendar for your chosen country';

  @override
  String settingsHolidaySourceCurrent(String source) {
    return 'Current: $source';
  }

  @override
  String get settingsHolidaySourceCustomLabel => 'Custom calendar';

  @override
  String get settingsHolidaySourceEmpty => 'None selected';

  @override
  String settingsHolidaySourceMore(String first, int count) {
    return '$first and $count more';
  }

  @override
  String get holidayCountryKR => 'South Korea';

  @override
  String get holidayCountryUS => 'United States';

  @override
  String get holidayCountryJP => 'Japan';

  @override
  String get holidayCountryGB => 'United Kingdom';

  @override
  String get holidayCountryDE => 'Germany';

  @override
  String get holidayCountryFR => 'France';

  @override
  String get holidayCountryCA => 'Canada';

  @override
  String get holidayCountryAU => 'Australia';

  @override
  String get holidayCalendarSourceTitle => 'Choose holiday calendar';

  @override
  String get holidayCalendarSourceSectionCountries => 'Choose a country';

  @override
  String get holidayCalendarSourceCustomEntry => 'Add from a URL';

  @override
  String get holidayCalendarSourceRemoveCustomUrl => 'Remove';

  @override
  String get holidayCalendarSourceCustomDialogTitle => 'Enter calendar URL';

  @override
  String get holidayCalendarSourceCustomDialogHint =>
      'https://example.com/calendar.ics';

  @override
  String get holidayCalendarSourceCustomInvalidUrl =>
      'Enter a valid http/https link';

  @override
  String get holidayCalendarSourceSyncFailed =>
      'Couldn\'t load that calendar — check the link';

  @override
  String get holidayCalendarSourceSyncFailedGeneric =>
      'Couldn\'t load the holiday calendar';

  @override
  String get holidayCalendarSourceColorTooltip => 'Change display color';

  @override
  String get holidayCalendarSourceColorTitle => 'Choose calendar color';

  @override
  String get holidayCalendarSourceColorDefault => 'Default';

  @override
  String get calendarImportTitle => 'Import or subscribe';

  @override
  String get calendarImportEmpty => 'No calendars available to import from';

  @override
  String calendarImportConfirmTitle(String calendarName) {
    return 'Import from $calendarName?';
  }

  @override
  String get calendarImportConfirmBody =>
      'Copies events from the last 30 days through a year ahead into PlanFit. They come in with notifications off, and importing again later updates anything that overlaps.';

  @override
  String get calendarImportConfirmAction => 'Import';

  @override
  String get calendarImportInProgress => 'Importing…';

  @override
  String calendarImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count events',
      one: 'Imported 1 event',
    );
    return '$_temp0';
  }

  @override
  String get calendarImportFailed => 'Import failed';

  @override
  String get calendarImportSubscribedHint =>
      'Subscribed — kept up to date automatically';

  @override
  String get calendarImportMirroredReadOnlyNote =>
      'This event came from a calendar you subscribed to, so it\'s read-only in PlanFit. Edit it in the original calendar app instead.';

  @override
  String get holidayEventBadge => 'Holiday';

  @override
  String get holidayEventReadOnlyNote =>
      'This is a holiday loaded automatically from a trusted calendar, so it\'s read-only in PlanFit.';

  @override
  String get settingsPermissionGranted => 'Granted';

  @override
  String get settingsPermissionDenied => 'Not granted';

  @override
  String get settingsPermissionDeniedMessage =>
      'Permission is denied — allow it in your device settings.';

  @override
  String get settingsOpenAppSettings => 'Open Settings';

  @override
  String get settingsGrant => 'Grant';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsWeekStart => 'Week starts on';

  @override
  String get settingsWeekStartMonday => 'Monday';

  @override
  String get settingsWeekStartSunday => 'Sunday';

  @override
  String get settingsThemeSystem => 'Follow system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsTimeFormatDisplay => 'Event/to-do time display';

  @override
  String get settingsTimeFormatDial => 'Time-picker dial';

  @override
  String get settingsTimeFormatSystem => 'Follow system';

  @override
  String get settingsTimeFormatH12 => '12-hour';

  @override
  String get settingsTimeFormatH24 => '24-hour';

  @override
  String get settingsTodo => 'To-dos';

  @override
  String get settingsReminderSync => 'Sync with device reminders';

  @override
  String get settingsReminderSyncDesc =>
      'Keep PlanFit to-dos in your device\'s Reminders app too';

  @override
  String get settingsTodoRetention => 'Auto-clean completed to-dos';

  @override
  String get settingsTodoRetentionDesc =>
      'Automatically delete to-dos a while after they\'re completed';

  @override
  String get settingsTodoRetentionOff => 'Off';

  @override
  String settingsTodoRetentionDays(int days) {
    return 'After ${days}d';
  }

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsDataBackupSection => 'Backup';

  @override
  String get settingsDataIcsSection => 'Calendar file (.ics)';

  @override
  String get settingsExport => 'Export full backup';

  @override
  String get settingsExportDesc => 'Save every event and to-do into one file';

  @override
  String get settingsImport => 'Import full backup';

  @override
  String get settingsImportDesc =>
      'Restore events and to-dos from an exported file';

  @override
  String get settingsExportIcs => 'Export as calendar file';

  @override
  String get settingsExportIcsDesc =>
      'A standard file (.ics) other calendar apps can open';

  @override
  String get settingsImportIcs => 'Import calendar file';

  @override
  String get settingsImportIcsDesc =>
      'Add events from a .ics file exported by another calendar app';

  @override
  String icsImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count events',
      one: 'Imported 1 event',
    );
    return '$_temp0';
  }

  @override
  String icsImportSkipped(int count) {
    return 'Skipped $count with an unrecognized format';
  }

  @override
  String get icsImportFailed => 'Import failed';

  @override
  String get settingsAutoBackup => 'Automatic backups';

  @override
  String get autoBackupTitle => 'Automatic backups';

  @override
  String get autoBackupEmpty => 'No automatic backups yet';

  @override
  String get autoBackupDesc =>
      'Backs up automatically every 24 hours, keeping the last 7';

  @override
  String get autoBackupRestore => 'Restore this backup';

  @override
  String get autoBackupRestoreConfirmTitle => 'Restore this backup?';

  @override
  String get autoBackupRestoreConfirmBody =>
      'This backup\'s contents will be merged into what you have now. Matching items get overwritten with the backup\'s version.';

  @override
  String get backupExportFailed => 'Export failed';

  @override
  String backupImportSuccess(int events, int todos) {
    return 'Imported $events events and $todos to-dos';
  }

  @override
  String get backupImportFailed => 'Import failed — check the file format';

  @override
  String get eventNew => 'New event';

  @override
  String get eventEdit => 'Edit event';

  @override
  String get eventSectionBasic => 'Basic';

  @override
  String get eventSectionSchedule => 'Date & time';

  @override
  String get eventSectionNotify => 'Notification';

  @override
  String get eventSectionDisplay => 'Display';

  @override
  String get eventDuplicate => 'Duplicate event';

  @override
  String get eventShare => 'Share event';

  @override
  String get eventShareFailed => 'Share failed';

  @override
  String get eventTemplates => 'Templates';

  @override
  String get templatesTitle => 'Frequently used';

  @override
  String get templatesEmpty => 'No saved templates yet';

  @override
  String get templatesSaveCurrent => 'Save current as template';

  @override
  String get templatesNameHint => 'Template name (e.g. Gym)';

  @override
  String get templatesNameRequired => 'Please enter a template name';

  @override
  String get templatesSaved => 'Template saved';

  @override
  String get templatesDeleted => 'Template deleted';

  @override
  String get eventTitle => 'Title';

  @override
  String get eventTitleHint => 'What\'s happening?';

  @override
  String get eventMemo => 'Notes';

  @override
  String get eventMemoHint => 'Add a note';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventLocationHint => 'Add a location';

  @override
  String get eventOpenInMaps => 'Open in Maps';

  @override
  String get eventOpenInMapsFailed => 'Couldn\'t open Maps';

  @override
  String get eventAllDay => 'All-day';

  @override
  String get eventStart => 'Starts';

  @override
  String get eventEnd => 'Ends';

  @override
  String get eventNotify => 'Notify at start';

  @override
  String get eventReminderLead => 'Remind me';

  @override
  String get eventReminderAtStart => 'At start';

  @override
  String eventReminderMinutesBefore(int minutes) {
    return '${minutes}m before';
  }

  @override
  String eventReminderHoursBefore(int hours) {
    return '${hours}h before';
  }

  @override
  String get eventReminderDayBefore => '1 day before';

  @override
  String get eventReminderAdditional => 'Additional reminders (pick any)';

  @override
  String get eventRepeat => 'Repeat';

  @override
  String get eventRepeatNone => 'Never';

  @override
  String get eventRepeatDaily => 'Daily';

  @override
  String get eventRepeatWeekly => 'Weekly';

  @override
  String get eventRepeatMonthly => 'Monthly';

  @override
  String get eventRepeatYearly => 'Yearly';

  @override
  String get eventRepeatUntil => 'Ends';

  @override
  String get eventRepeatWeekdays => 'Repeat on';

  @override
  String get eventRepeatEndLabel => 'Ends';

  @override
  String get eventRepeatEndByDate => 'On date';

  @override
  String get eventRepeatEndByCount => 'After N times';

  @override
  String eventRepeatCountTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: '1 time',
    );
    return '$_temp0';
  }

  @override
  String get eventRepeatCountDecrease => 'Decrease repeat count';

  @override
  String get eventRepeatCountIncrease => 'Increase repeat count';

  @override
  String get eventDeleteSeriesTitle => 'Delete recurring event';

  @override
  String get eventDeleteSeriesBody =>
      'This event is part of a series. How should it be deleted?';

  @override
  String get eventDeleteThisOnly => 'This event only';

  @override
  String get eventDeleteThisAndFuture => 'This and future events';

  @override
  String get eventSaveSeriesTitle => 'Save repeating event';

  @override
  String get eventSaveSeriesBody =>
      'This event is part of a repeating series. How should the changes apply?';

  @override
  String get eventSaveThisOnly => 'Just this event';

  @override
  String get eventSaveThisAndFuture => 'This and future events';

  @override
  String get eventColor => 'Color';

  @override
  String get eventColorAuto => 'Auto';

  @override
  String get eventColorCustom => 'Custom';

  @override
  String get eventColorPickerTitle => 'Pick a color';

  @override
  String get eventSave => 'Save';

  @override
  String get eventDelete => 'Delete';

  @override
  String get eventDeleted => 'Event deleted';

  @override
  String get eventUndo => 'Undo';

  @override
  String eventSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get eventSelectionDelete => 'Delete';

  @override
  String eventSelectionDeleted(int count) {
    return 'Deleted $count';
  }

  @override
  String get eventTitleRequired => 'Please enter a title';

  @override
  String get eventRecurrenceTruncated =>
      'Repeat only generated the first 200 occurrences';

  @override
  String get todoAdd => 'Add to-do';

  @override
  String get todoHint => 'Enter a to-do';

  @override
  String get todoRepeat => 'Repeat';

  @override
  String get todoNoTime => 'No time';

  @override
  String get todoMoreOptions => 'More options (priority, repeat, no time)';

  @override
  String get todoFewerOptions => 'Fewer options';

  @override
  String get todoRepeatIndicator => 'Recurring to-do';

  @override
  String get todoDragHandle => 'Reorder';

  @override
  String get todoDeleteSeriesTitle => 'Delete recurring to-do';

  @override
  String get todoDeleteSeriesBody =>
      'This item is part of a recurring to-do. How should it be deleted?';

  @override
  String get todoDeleteThisOnly => 'This item only';

  @override
  String get todoDeleteThisAndFuture => 'This and future items';

  @override
  String get todoDeleted => 'To-do deleted';

  @override
  String todoQuickAddAddedToOtherDay(String day) {
    return 'Added to $day';
  }

  @override
  String todoSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get todoSelectionComplete => 'Mark done';

  @override
  String get todoMarkDone => 'Done';

  @override
  String get todoSelectItem => 'Select';

  @override
  String get todoSelectionDelete => 'Delete';

  @override
  String todoSelectionDeleted(int count) {
    return 'Deleted $count';
  }

  @override
  String get todoEditTitle => 'Edit to-do';

  @override
  String get todoTitleLabel => 'Title';

  @override
  String get todoReminderAdditional => 'Additional reminders (pick any number)';

  @override
  String get todoPriorityLabel => 'Priority';

  @override
  String get todoPriorityNone => 'None';

  @override
  String get todoPriorityLow => 'Low';

  @override
  String get todoPriorityMedium => 'Medium';

  @override
  String get todoPriorityHigh => 'High';

  @override
  String get todoTagsLabel => 'Tags';

  @override
  String get todoTagsHint => 'Comma-separated (e.g. work,urgent)';

  @override
  String get todoSubtasksLabel => 'Subtasks';

  @override
  String get todoSubtaskHint => 'Add a subtask';

  @override
  String get todoSubtaskDelete => 'Delete subtask';

  @override
  String get todoNotify => 'Notify at due time';

  @override
  String get todoNotifyNoTimeHint => 'Set a time to turn on notifications';

  @override
  String get todoPin => 'Pin';

  @override
  String get todoUnpin => 'Unpin';

  @override
  String get todoPinned => 'Pinned';

  @override
  String get smartListTitle => 'All to-dos';

  @override
  String get smartListToday => 'Today';

  @override
  String get smartListOverdue => 'Overdue';

  @override
  String get smartListHighPriority => 'High priority';

  @override
  String get smartListPinned => 'Pinned';

  @override
  String get smartListByTag => 'By tag';

  @override
  String get smartListEmptyToday => 'No to-dos today';

  @override
  String get smartListEmptyOverdue => 'Nothing overdue';

  @override
  String get smartListEmptyHighPriority => 'No high-priority to-dos';

  @override
  String get smartListEmptyPinned => 'No pinned to-dos';

  @override
  String get smartListEmptyByTag => 'No to-dos with this tag';

  @override
  String get smartListNoTags => 'No tags yet';

  @override
  String get smartListPickTag => 'Pick a tag';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDone => 'Done';

  @override
  String get commonToday => 'Today';

  @override
  String get errorWidgetFallback => 'Something went wrong';

  @override
  String get notificationChannelName => 'Event reminders';

  @override
  String get notificationChannelDescription =>
      'Alerts you when an event starts';

  @override
  String get notificationSnoozeLabel => 'Remind me in 5 min';

  @override
  String get notificationEventFallbackTitle => 'Event';

  @override
  String get notificationTodoFallbackTitle => 'To-do';

  @override
  String lunarDateLabel(int month, int day) {
    return 'Lunar $month/$day';
  }

  @override
  String lunarDateLabelLeap(int month, int day) {
    return 'Lunar $month/$day (leap)';
  }

  @override
  String get settingsShowLunarDates => 'Show lunar dates';

  @override
  String get settingsShowLunarDatesDesc =>
      'Shows the lunar-calendar date alongside the day/week/month views';
}
