// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EventsTable extends Events with TableInfo<$EventsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAllDayMeta = const VerificationMeta(
    'isAllDay',
  );
  @override
  late final GeneratedColumn<bool> isAllDay = GeneratedColumn<bool>(
    'is_all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorTagMeta = const VerificationMeta(
    'colorTag',
  );
  @override
  late final GeneratedColumn<String> colorTag = GeneratedColumn<String>(
    'color_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notifyMeta = const VerificationMeta('notify');
  @override
  late final GeneratedColumn<bool> notify = GeneratedColumn<bool>(
    'notify',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _reminderMinutesBeforeMeta =
      const VerificationMeta('reminderMinutesBefore');
  @override
  late final GeneratedColumn<int> reminderMinutesBefore = GeneratedColumn<int>(
    'reminder_minutes_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _additionalReminderMinutesMeta =
      const VerificationMeta('additionalReminderMinutes');
  @override
  late final GeneratedColumn<String> additionalReminderMinutes =
      GeneratedColumn<String>(
        'additional_reminder_minutes',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recurrenceRuleMeta = const VerificationMeta(
    'recurrenceRule',
  );
  @override
  late final GeneratedColumn<String> recurrenceRule = GeneratedColumn<String>(
    'recurrence_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceGroupIdMeta = const VerificationMeta(
    'recurrenceGroupId',
  );
  @override
  late final GeneratedColumn<String> recurrenceGroupId =
      GeneratedColumn<String>(
        'recurrence_group_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _osCalendarIdMeta = const VerificationMeta(
    'osCalendarId',
  );
  @override
  late final GeneratedColumn<String> osCalendarId = GeneratedColumn<String>(
    'os_calendar_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _osEventIdMeta = const VerificationMeta(
    'osEventId',
  );
  @override
  late final GeneratedColumn<String> osEventId = GeneratedColumn<String>(
    'os_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _osLastKnownModifiedMeta =
      const VerificationMeta('osLastKnownModified');
  @override
  late final GeneratedColumn<DateTime> osLastKnownModified =
      GeneratedColumn<DateTime>(
        'os_last_known_modified',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<SyncStatus, String> syncStatus =
      GeneratedColumn<String>(
        'sync_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(SyncStatus.pendingPush.name),
      ).withConverter<SyncStatus>($EventsTable.$convertersyncStatus);
  static const VerificationMeta _importSourceCalendarIdMeta =
      const VerificationMeta('importSourceCalendarId');
  @override
  late final GeneratedColumn<String> importSourceCalendarId =
      GeneratedColumn<String>(
        'import_source_calendar_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _importSourceEventIdMeta =
      const VerificationMeta('importSourceEventId');
  @override
  late final GeneratedColumn<String> importSourceEventId =
      GeneratedColumn<String>(
        'import_source_event_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    memo,
    location,
    startAt,
    endAt,
    isAllDay,
    colorTag,
    notify,
    reminderMinutesBefore,
    additionalReminderMinutes,
    recurrenceRule,
    recurrenceGroupId,
    osCalendarId,
    osEventId,
    osLastKnownModified,
    syncStatus,
    importSourceCalendarId,
    importSourceEventId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('is_all_day')) {
      context.handle(
        _isAllDayMeta,
        isAllDay.isAcceptableOrUnknown(data['is_all_day']!, _isAllDayMeta),
      );
    }
    if (data.containsKey('color_tag')) {
      context.handle(
        _colorTagMeta,
        colorTag.isAcceptableOrUnknown(data['color_tag']!, _colorTagMeta),
      );
    }
    if (data.containsKey('notify')) {
      context.handle(
        _notifyMeta,
        notify.isAcceptableOrUnknown(data['notify']!, _notifyMeta),
      );
    }
    if (data.containsKey('reminder_minutes_before')) {
      context.handle(
        _reminderMinutesBeforeMeta,
        reminderMinutesBefore.isAcceptableOrUnknown(
          data['reminder_minutes_before']!,
          _reminderMinutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('additional_reminder_minutes')) {
      context.handle(
        _additionalReminderMinutesMeta,
        additionalReminderMinutes.isAcceptableOrUnknown(
          data['additional_reminder_minutes']!,
          _additionalReminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_rule')) {
      context.handle(
        _recurrenceRuleMeta,
        recurrenceRule.isAcceptableOrUnknown(
          data['recurrence_rule']!,
          _recurrenceRuleMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_group_id')) {
      context.handle(
        _recurrenceGroupIdMeta,
        recurrenceGroupId.isAcceptableOrUnknown(
          data['recurrence_group_id']!,
          _recurrenceGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('os_calendar_id')) {
      context.handle(
        _osCalendarIdMeta,
        osCalendarId.isAcceptableOrUnknown(
          data['os_calendar_id']!,
          _osCalendarIdMeta,
        ),
      );
    }
    if (data.containsKey('os_event_id')) {
      context.handle(
        _osEventIdMeta,
        osEventId.isAcceptableOrUnknown(data['os_event_id']!, _osEventIdMeta),
      );
    }
    if (data.containsKey('os_last_known_modified')) {
      context.handle(
        _osLastKnownModifiedMeta,
        osLastKnownModified.isAcceptableOrUnknown(
          data['os_last_known_modified']!,
          _osLastKnownModifiedMeta,
        ),
      );
    }
    if (data.containsKey('import_source_calendar_id')) {
      context.handle(
        _importSourceCalendarIdMeta,
        importSourceCalendarId.isAcceptableOrUnknown(
          data['import_source_calendar_id']!,
          _importSourceCalendarIdMeta,
        ),
      );
    }
    if (data.containsKey('import_source_event_id')) {
      context.handle(
        _importSourceEventIdMeta,
        importSourceEventId.isAcceptableOrUnknown(
          data['import_source_event_id']!,
          _importSourceEventIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      )!,
      isAllDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_all_day'],
      )!,
      colorTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_tag'],
      ),
      notify: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify'],
      )!,
      reminderMinutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes_before'],
      )!,
      additionalReminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}additional_reminder_minutes'],
      ),
      recurrenceRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_rule'],
      ),
      recurrenceGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_group_id'],
      ),
      osCalendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}os_calendar_id'],
      ),
      osEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}os_event_id'],
      ),
      osLastKnownModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}os_last_known_modified'],
      ),
      syncStatus: $EventsTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      importSourceCalendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_source_calendar_id'],
      ),
      importSourceEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_source_event_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncStatus, String, String> $convertersyncStatus =
      const EnumNameConverter<SyncStatus>(SyncStatus.values);
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final String id;
  final String title;
  final String? memo;
  final String? location;
  final DateTime startAt;
  final DateTime endAt;
  final bool isAllDay;
  final String? colorTag;

  /// Whether a local notification fires for this event.
  final bool notify;

  /// Minutes before [startAt] the primary notification fires. 0 = at start
  /// time.
  final int reminderMinutesBefore;

  /// Extra reminder offsets (minutes before [startAt]) on top of
  /// [reminderMinutesBefore], comma-separated (e.g. "60,1440" for "1 hour
  /// before" + "1 day before" in addition to the primary one). Null/empty
  /// when there are none. See `EventAlertX.reminderOffsets`.
  final String? additionalReminderMinutes;

  /// RFC 5545-style RRULE string (e.g. `FREQ=WEEKLY;UNTIL=...`), informational
  /// — recurrence is materialized as individual rows (see
  /// [recurrenceGroupId]), not expanded from this at query time.
  final String? recurrenceRule;

  /// Shared id linking every materialized occurrence of one recurring series,
  /// so "delete this and future" can bulk-target them. Null for one-off
  /// events.
  final String? recurrenceGroupId;
  final String? osCalendarId;
  final String? osEventId;
  final DateTime? osLastKnownModified;
  final SyncStatus syncStatus;
  final String? importSourceCalendarId;
  final String? importSourceEventId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const EventRow({
    required this.id,
    required this.title,
    this.memo,
    this.location,
    required this.startAt,
    required this.endAt,
    required this.isAllDay,
    this.colorTag,
    required this.notify,
    required this.reminderMinutesBefore,
    this.additionalReminderMinutes,
    this.recurrenceRule,
    this.recurrenceGroupId,
    this.osCalendarId,
    this.osEventId,
    this.osLastKnownModified,
    required this.syncStatus,
    this.importSourceCalendarId,
    this.importSourceEventId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['start_at'] = Variable<DateTime>(startAt);
    map['end_at'] = Variable<DateTime>(endAt);
    map['is_all_day'] = Variable<bool>(isAllDay);
    if (!nullToAbsent || colorTag != null) {
      map['color_tag'] = Variable<String>(colorTag);
    }
    map['notify'] = Variable<bool>(notify);
    map['reminder_minutes_before'] = Variable<int>(reminderMinutesBefore);
    if (!nullToAbsent || additionalReminderMinutes != null) {
      map['additional_reminder_minutes'] = Variable<String>(
        additionalReminderMinutes,
      );
    }
    if (!nullToAbsent || recurrenceRule != null) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule);
    }
    if (!nullToAbsent || recurrenceGroupId != null) {
      map['recurrence_group_id'] = Variable<String>(recurrenceGroupId);
    }
    if (!nullToAbsent || osCalendarId != null) {
      map['os_calendar_id'] = Variable<String>(osCalendarId);
    }
    if (!nullToAbsent || osEventId != null) {
      map['os_event_id'] = Variable<String>(osEventId);
    }
    if (!nullToAbsent || osLastKnownModified != null) {
      map['os_last_known_modified'] = Variable<DateTime>(osLastKnownModified);
    }
    {
      map['sync_status'] = Variable<String>(
        $EventsTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    if (!nullToAbsent || importSourceCalendarId != null) {
      map['import_source_calendar_id'] = Variable<String>(
        importSourceCalendarId,
      );
    }
    if (!nullToAbsent || importSourceEventId != null) {
      map['import_source_event_id'] = Variable<String>(importSourceEventId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      title: Value(title),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      startAt: Value(startAt),
      endAt: Value(endAt),
      isAllDay: Value(isAllDay),
      colorTag: colorTag == null && nullToAbsent
          ? const Value.absent()
          : Value(colorTag),
      notify: Value(notify),
      reminderMinutesBefore: Value(reminderMinutesBefore),
      additionalReminderMinutes:
          additionalReminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(additionalReminderMinutes),
      recurrenceRule: recurrenceRule == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceRule),
      recurrenceGroupId: recurrenceGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceGroupId),
      osCalendarId: osCalendarId == null && nullToAbsent
          ? const Value.absent()
          : Value(osCalendarId),
      osEventId: osEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(osEventId),
      osLastKnownModified: osLastKnownModified == null && nullToAbsent
          ? const Value.absent()
          : Value(osLastKnownModified),
      syncStatus: Value(syncStatus),
      importSourceCalendarId: importSourceCalendarId == null && nullToAbsent
          ? const Value.absent()
          : Value(importSourceCalendarId),
      importSourceEventId: importSourceEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(importSourceEventId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory EventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      memo: serializer.fromJson<String?>(json['memo']),
      location: serializer.fromJson<String?>(json['location']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime>(json['endAt']),
      isAllDay: serializer.fromJson<bool>(json['isAllDay']),
      colorTag: serializer.fromJson<String?>(json['colorTag']),
      notify: serializer.fromJson<bool>(json['notify']),
      reminderMinutesBefore: serializer.fromJson<int>(
        json['reminderMinutesBefore'],
      ),
      additionalReminderMinutes: serializer.fromJson<String?>(
        json['additionalReminderMinutes'],
      ),
      recurrenceRule: serializer.fromJson<String?>(json['recurrenceRule']),
      recurrenceGroupId: serializer.fromJson<String?>(
        json['recurrenceGroupId'],
      ),
      osCalendarId: serializer.fromJson<String?>(json['osCalendarId']),
      osEventId: serializer.fromJson<String?>(json['osEventId']),
      osLastKnownModified: serializer.fromJson<DateTime?>(
        json['osLastKnownModified'],
      ),
      syncStatus: $EventsTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      importSourceCalendarId: serializer.fromJson<String?>(
        json['importSourceCalendarId'],
      ),
      importSourceEventId: serializer.fromJson<String?>(
        json['importSourceEventId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'memo': serializer.toJson<String?>(memo),
      'location': serializer.toJson<String?>(location),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime>(endAt),
      'isAllDay': serializer.toJson<bool>(isAllDay),
      'colorTag': serializer.toJson<String?>(colorTag),
      'notify': serializer.toJson<bool>(notify),
      'reminderMinutesBefore': serializer.toJson<int>(reminderMinutesBefore),
      'additionalReminderMinutes': serializer.toJson<String?>(
        additionalReminderMinutes,
      ),
      'recurrenceRule': serializer.toJson<String?>(recurrenceRule),
      'recurrenceGroupId': serializer.toJson<String?>(recurrenceGroupId),
      'osCalendarId': serializer.toJson<String?>(osCalendarId),
      'osEventId': serializer.toJson<String?>(osEventId),
      'osLastKnownModified': serializer.toJson<DateTime?>(osLastKnownModified),
      'syncStatus': serializer.toJson<String>(
        $EventsTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'importSourceCalendarId': serializer.toJson<String?>(
        importSourceCalendarId,
      ),
      'importSourceEventId': serializer.toJson<String?>(importSourceEventId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EventRow copyWith({
    String? id,
    String? title,
    Value<String?> memo = const Value.absent(),
    Value<String?> location = const Value.absent(),
    DateTime? startAt,
    DateTime? endAt,
    bool? isAllDay,
    Value<String?> colorTag = const Value.absent(),
    bool? notify,
    int? reminderMinutesBefore,
    Value<String?> additionalReminderMinutes = const Value.absent(),
    Value<String?> recurrenceRule = const Value.absent(),
    Value<String?> recurrenceGroupId = const Value.absent(),
    Value<String?> osCalendarId = const Value.absent(),
    Value<String?> osEventId = const Value.absent(),
    Value<DateTime?> osLastKnownModified = const Value.absent(),
    SyncStatus? syncStatus,
    Value<String?> importSourceCalendarId = const Value.absent(),
    Value<String?> importSourceEventId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EventRow(
    id: id ?? this.id,
    title: title ?? this.title,
    memo: memo.present ? memo.value : this.memo,
    location: location.present ? location.value : this.location,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    isAllDay: isAllDay ?? this.isAllDay,
    colorTag: colorTag.present ? colorTag.value : this.colorTag,
    notify: notify ?? this.notify,
    reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    additionalReminderMinutes: additionalReminderMinutes.present
        ? additionalReminderMinutes.value
        : this.additionalReminderMinutes,
    recurrenceRule: recurrenceRule.present
        ? recurrenceRule.value
        : this.recurrenceRule,
    recurrenceGroupId: recurrenceGroupId.present
        ? recurrenceGroupId.value
        : this.recurrenceGroupId,
    osCalendarId: osCalendarId.present ? osCalendarId.value : this.osCalendarId,
    osEventId: osEventId.present ? osEventId.value : this.osEventId,
    osLastKnownModified: osLastKnownModified.present
        ? osLastKnownModified.value
        : this.osLastKnownModified,
    syncStatus: syncStatus ?? this.syncStatus,
    importSourceCalendarId: importSourceCalendarId.present
        ? importSourceCalendarId.value
        : this.importSourceCalendarId,
    importSourceEventId: importSourceEventId.present
        ? importSourceEventId.value
        : this.importSourceEventId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      memo: data.memo.present ? data.memo.value : this.memo,
      location: data.location.present ? data.location.value : this.location,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      isAllDay: data.isAllDay.present ? data.isAllDay.value : this.isAllDay,
      colorTag: data.colorTag.present ? data.colorTag.value : this.colorTag,
      notify: data.notify.present ? data.notify.value : this.notify,
      reminderMinutesBefore: data.reminderMinutesBefore.present
          ? data.reminderMinutesBefore.value
          : this.reminderMinutesBefore,
      additionalReminderMinutes: data.additionalReminderMinutes.present
          ? data.additionalReminderMinutes.value
          : this.additionalReminderMinutes,
      recurrenceRule: data.recurrenceRule.present
          ? data.recurrenceRule.value
          : this.recurrenceRule,
      recurrenceGroupId: data.recurrenceGroupId.present
          ? data.recurrenceGroupId.value
          : this.recurrenceGroupId,
      osCalendarId: data.osCalendarId.present
          ? data.osCalendarId.value
          : this.osCalendarId,
      osEventId: data.osEventId.present ? data.osEventId.value : this.osEventId,
      osLastKnownModified: data.osLastKnownModified.present
          ? data.osLastKnownModified.value
          : this.osLastKnownModified,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      importSourceCalendarId: data.importSourceCalendarId.present
          ? data.importSourceCalendarId.value
          : this.importSourceCalendarId,
      importSourceEventId: data.importSourceEventId.present
          ? data.importSourceEventId.value
          : this.importSourceEventId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('location: $location, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('colorTag: $colorTag, ')
          ..write('notify: $notify, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('additionalReminderMinutes: $additionalReminderMinutes, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceGroupId: $recurrenceGroupId, ')
          ..write('osCalendarId: $osCalendarId, ')
          ..write('osEventId: $osEventId, ')
          ..write('osLastKnownModified: $osLastKnownModified, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('importSourceCalendarId: $importSourceCalendarId, ')
          ..write('importSourceEventId: $importSourceEventId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    memo,
    location,
    startAt,
    endAt,
    isAllDay,
    colorTag,
    notify,
    reminderMinutesBefore,
    additionalReminderMinutes,
    recurrenceRule,
    recurrenceGroupId,
    osCalendarId,
    osEventId,
    osLastKnownModified,
    syncStatus,
    importSourceCalendarId,
    importSourceEventId,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.memo == this.memo &&
          other.location == this.location &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.isAllDay == this.isAllDay &&
          other.colorTag == this.colorTag &&
          other.notify == this.notify &&
          other.reminderMinutesBefore == this.reminderMinutesBefore &&
          other.additionalReminderMinutes == this.additionalReminderMinutes &&
          other.recurrenceRule == this.recurrenceRule &&
          other.recurrenceGroupId == this.recurrenceGroupId &&
          other.osCalendarId == this.osCalendarId &&
          other.osEventId == this.osEventId &&
          other.osLastKnownModified == this.osLastKnownModified &&
          other.syncStatus == this.syncStatus &&
          other.importSourceCalendarId == this.importSourceCalendarId &&
          other.importSourceEventId == this.importSourceEventId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> memo;
  final Value<String?> location;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<bool> isAllDay;
  final Value<String?> colorTag;
  final Value<bool> notify;
  final Value<int> reminderMinutesBefore;
  final Value<String?> additionalReminderMinutes;
  final Value<String?> recurrenceRule;
  final Value<String?> recurrenceGroupId;
  final Value<String?> osCalendarId;
  final Value<String?> osEventId;
  final Value<DateTime?> osLastKnownModified;
  final Value<SyncStatus> syncStatus;
  final Value<String?> importSourceCalendarId;
  final Value<String?> importSourceEventId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.memo = const Value.absent(),
    this.location = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.colorTag = const Value.absent(),
    this.notify = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.additionalReminderMinutes = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceGroupId = const Value.absent(),
    this.osCalendarId = const Value.absent(),
    this.osEventId = const Value.absent(),
    this.osLastKnownModified = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.importSourceCalendarId = const Value.absent(),
    this.importSourceEventId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.memo = const Value.absent(),
    this.location = const Value.absent(),
    required DateTime startAt,
    required DateTime endAt,
    this.isAllDay = const Value.absent(),
    this.colorTag = const Value.absent(),
    this.notify = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.additionalReminderMinutes = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceGroupId = const Value.absent(),
    this.osCalendarId = const Value.absent(),
    this.osEventId = const Value.absent(),
    this.osLastKnownModified = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.importSourceCalendarId = const Value.absent(),
    this.importSourceEventId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startAt = Value(startAt),
       endAt = Value(endAt);
  static Insertable<EventRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? memo,
    Expression<String>? location,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<bool>? isAllDay,
    Expression<String>? colorTag,
    Expression<bool>? notify,
    Expression<int>? reminderMinutesBefore,
    Expression<String>? additionalReminderMinutes,
    Expression<String>? recurrenceRule,
    Expression<String>? recurrenceGroupId,
    Expression<String>? osCalendarId,
    Expression<String>? osEventId,
    Expression<DateTime>? osLastKnownModified,
    Expression<String>? syncStatus,
    Expression<String>? importSourceCalendarId,
    Expression<String>? importSourceEventId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (memo != null) 'memo': memo,
      if (location != null) 'location': location,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (isAllDay != null) 'is_all_day': isAllDay,
      if (colorTag != null) 'color_tag': colorTag,
      if (notify != null) 'notify': notify,
      if (reminderMinutesBefore != null)
        'reminder_minutes_before': reminderMinutesBefore,
      if (additionalReminderMinutes != null)
        'additional_reminder_minutes': additionalReminderMinutes,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (recurrenceGroupId != null) 'recurrence_group_id': recurrenceGroupId,
      if (osCalendarId != null) 'os_calendar_id': osCalendarId,
      if (osEventId != null) 'os_event_id': osEventId,
      if (osLastKnownModified != null)
        'os_last_known_modified': osLastKnownModified,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (importSourceCalendarId != null)
        'import_source_calendar_id': importSourceCalendarId,
      if (importSourceEventId != null)
        'import_source_event_id': importSourceEventId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? memo,
    Value<String?>? location,
    Value<DateTime>? startAt,
    Value<DateTime>? endAt,
    Value<bool>? isAllDay,
    Value<String?>? colorTag,
    Value<bool>? notify,
    Value<int>? reminderMinutesBefore,
    Value<String?>? additionalReminderMinutes,
    Value<String?>? recurrenceRule,
    Value<String?>? recurrenceGroupId,
    Value<String?>? osCalendarId,
    Value<String?>? osEventId,
    Value<DateTime?>? osLastKnownModified,
    Value<SyncStatus>? syncStatus,
    Value<String?>? importSourceCalendarId,
    Value<String?>? importSourceEventId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      location: location ?? this.location,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isAllDay: isAllDay ?? this.isAllDay,
      colorTag: colorTag ?? this.colorTag,
      notify: notify ?? this.notify,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      additionalReminderMinutes:
          additionalReminderMinutes ?? this.additionalReminderMinutes,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceGroupId: recurrenceGroupId ?? this.recurrenceGroupId,
      osCalendarId: osCalendarId ?? this.osCalendarId,
      osEventId: osEventId ?? this.osEventId,
      osLastKnownModified: osLastKnownModified ?? this.osLastKnownModified,
      syncStatus: syncStatus ?? this.syncStatus,
      importSourceCalendarId:
          importSourceCalendarId ?? this.importSourceCalendarId,
      importSourceEventId: importSourceEventId ?? this.importSourceEventId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (isAllDay.present) {
      map['is_all_day'] = Variable<bool>(isAllDay.value);
    }
    if (colorTag.present) {
      map['color_tag'] = Variable<String>(colorTag.value);
    }
    if (notify.present) {
      map['notify'] = Variable<bool>(notify.value);
    }
    if (reminderMinutesBefore.present) {
      map['reminder_minutes_before'] = Variable<int>(
        reminderMinutesBefore.value,
      );
    }
    if (additionalReminderMinutes.present) {
      map['additional_reminder_minutes'] = Variable<String>(
        additionalReminderMinutes.value,
      );
    }
    if (recurrenceRule.present) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule.value);
    }
    if (recurrenceGroupId.present) {
      map['recurrence_group_id'] = Variable<String>(recurrenceGroupId.value);
    }
    if (osCalendarId.present) {
      map['os_calendar_id'] = Variable<String>(osCalendarId.value);
    }
    if (osEventId.present) {
      map['os_event_id'] = Variable<String>(osEventId.value);
    }
    if (osLastKnownModified.present) {
      map['os_last_known_modified'] = Variable<DateTime>(
        osLastKnownModified.value,
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $EventsTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (importSourceCalendarId.present) {
      map['import_source_calendar_id'] = Variable<String>(
        importSourceCalendarId.value,
      );
    }
    if (importSourceEventId.present) {
      map['import_source_event_id'] = Variable<String>(
        importSourceEventId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('location: $location, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('colorTag: $colorTag, ')
          ..write('notify: $notify, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('additionalReminderMinutes: $additionalReminderMinutes, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceGroupId: $recurrenceGroupId, ')
          ..write('osCalendarId: $osCalendarId, ')
          ..write('osEventId: $osEventId, ')
          ..write('osLastKnownModified: $osLastKnownModified, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('importSourceCalendarId: $importSourceCalendarId, ')
          ..write('importSourceEventId: $importSourceEventId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoItemsTable extends TodoItems
    with TableInfo<$TodoItemsTable, TodoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES events (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _slotStartMeta = const VerificationMeta(
    'slotStart',
  );
  @override
  late final GeneratedColumn<DateTime> slotStart = GeneratedColumn<DateTime>(
    'slot_start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotEndMeta = const VerificationMeta(
    'slotEnd',
  );
  @override
  late final GeneratedColumn<DateTime> slotEnd = GeneratedColumn<DateTime>(
    'slot_end',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasTimeMeta = const VerificationMeta(
    'hasTime',
  );
  @override
  late final GeneratedColumn<bool> hasTime = GeneratedColumn<bool>(
    'has_time',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_time" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDoneMeta = const VerificationMeta('isDone');
  @override
  late final GeneratedColumn<bool> isDone = GeneratedColumn<bool>(
    'is_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notifyMeta = const VerificationMeta('notify');
  @override
  late final GeneratedColumn<bool> notify = GeneratedColumn<bool>(
    'notify',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _additionalReminderMinutesMeta =
      const VerificationMeta('additionalReminderMinutes');
  @override
  late final GeneratedColumn<String> additionalReminderMinutes =
      GeneratedColumn<String>(
        'additional_reminder_minutes',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recurrenceRuleMeta = const VerificationMeta(
    'recurrenceRule',
  );
  @override
  late final GeneratedColumn<String> recurrenceRule = GeneratedColumn<String>(
    'recurrence_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceGroupIdMeta = const VerificationMeta(
    'recurrenceGroupId',
  );
  @override
  late final GeneratedColumn<String> recurrenceGroupId =
      GeneratedColumn<String>(
        'recurrence_group_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _osReminderIdMeta = const VerificationMeta(
    'osReminderId',
  );
  @override
  late final GeneratedColumn<String> osReminderId = GeneratedColumn<String>(
    'os_reminder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _osReminderListIdMeta = const VerificationMeta(
    'osReminderListId',
  );
  @override
  late final GeneratedColumn<String> osReminderListId = GeneratedColumn<String>(
    'os_reminder_list_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _osReminderLastKnownModifiedMeta =
      const VerificationMeta('osReminderLastKnownModified');
  @override
  late final GeneratedColumn<DateTime> osReminderLastKnownModified =
      GeneratedColumn<DateTime>(
        'os_reminder_last_known_modified',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<SyncStatus, String>
  reminderSyncStatus = GeneratedColumn<String>(
    'reminder_sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(SyncStatus.pendingPush.name),
  ).withConverter<SyncStatus>($TodoItemsTable.$converterreminderSyncStatus);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    title,
    slotStart,
    slotEnd,
    hasTime,
    isDone,
    completedAt,
    sortOrder,
    priority,
    tags,
    notify,
    additionalReminderMinutes,
    recurrenceRule,
    recurrenceGroupId,
    isPinned,
    osReminderId,
    osReminderListId,
    osReminderLastKnownModified,
    reminderSyncStatus,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('slot_start')) {
      context.handle(
        _slotStartMeta,
        slotStart.isAcceptableOrUnknown(data['slot_start']!, _slotStartMeta),
      );
    } else if (isInserting) {
      context.missing(_slotStartMeta);
    }
    if (data.containsKey('slot_end')) {
      context.handle(
        _slotEndMeta,
        slotEnd.isAcceptableOrUnknown(data['slot_end']!, _slotEndMeta),
      );
    }
    if (data.containsKey('has_time')) {
      context.handle(
        _hasTimeMeta,
        hasTime.isAcceptableOrUnknown(data['has_time']!, _hasTimeMeta),
      );
    }
    if (data.containsKey('is_done')) {
      context.handle(
        _isDoneMeta,
        isDone.isAcceptableOrUnknown(data['is_done']!, _isDoneMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('notify')) {
      context.handle(
        _notifyMeta,
        notify.isAcceptableOrUnknown(data['notify']!, _notifyMeta),
      );
    }
    if (data.containsKey('additional_reminder_minutes')) {
      context.handle(
        _additionalReminderMinutesMeta,
        additionalReminderMinutes.isAcceptableOrUnknown(
          data['additional_reminder_minutes']!,
          _additionalReminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_rule')) {
      context.handle(
        _recurrenceRuleMeta,
        recurrenceRule.isAcceptableOrUnknown(
          data['recurrence_rule']!,
          _recurrenceRuleMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_group_id')) {
      context.handle(
        _recurrenceGroupIdMeta,
        recurrenceGroupId.isAcceptableOrUnknown(
          data['recurrence_group_id']!,
          _recurrenceGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('os_reminder_id')) {
      context.handle(
        _osReminderIdMeta,
        osReminderId.isAcceptableOrUnknown(
          data['os_reminder_id']!,
          _osReminderIdMeta,
        ),
      );
    }
    if (data.containsKey('os_reminder_list_id')) {
      context.handle(
        _osReminderListIdMeta,
        osReminderListId.isAcceptableOrUnknown(
          data['os_reminder_list_id']!,
          _osReminderListIdMeta,
        ),
      );
    }
    if (data.containsKey('os_reminder_last_known_modified')) {
      context.handle(
        _osReminderLastKnownModifiedMeta,
        osReminderLastKnownModified.isAcceptableOrUnknown(
          data['os_reminder_last_known_modified']!,
          _osReminderLastKnownModifiedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      slotStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}slot_start'],
      )!,
      slotEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}slot_end'],
      ),
      hasTime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_time'],
      )!,
      isDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_done'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      notify: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify'],
      )!,
      additionalReminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}additional_reminder_minutes'],
      ),
      recurrenceRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_rule'],
      ),
      recurrenceGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_group_id'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      osReminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}os_reminder_id'],
      ),
      osReminderListId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}os_reminder_list_id'],
      ),
      osReminderLastKnownModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}os_reminder_last_known_modified'],
      ),
      reminderSyncStatus: $TodoItemsTable.$converterreminderSyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reminder_sync_status'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoItemsTable createAlias(String alias) {
    return $TodoItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncStatus, String, String>
  $converterreminderSyncStatus = const EnumNameConverter<SyncStatus>(
    SyncStatus.values,
  );
}

class TodoRow extends DataClass implements Insertable<TodoRow> {
  final String id;
  final String? eventId;
  final String title;
  final DateTime slotStart;
  final DateTime? slotEnd;

  /// Whether [slotStart] represents an actual time the user picked, or just
  /// a day this to-do belongs to with no specific hour ("today, sometime").
  /// [slotStart] is never null either way (a to-do always belongs to some
  /// day) — this flag alone decides whether the UI shows/sorts by its
  /// time-of-day or groups it into that day's "no time" bucket instead.
  final bool hasTime;
  final bool isDone;

  /// When [isDone] last flipped true — null while not done, and cleared
  /// back to null if un-checked. Distinct from [slotStart] (when it was
  /// *due*): the settings > "완료된 할 일 자동 정리" auto-prune
  /// (`TodoController.pruneCompleted`) measures staleness from completion,
  /// not from the due slot, since a to-do finished late shouldn't vanish
  /// immediately just because its slot was days ago.
  final DateTime? completedAt;
  final int sortOrder;

  /// 0 = none, 1 = low, 2 = medium, 3 = high — see `TodoPriority` for the
  /// enum this maps to in the UI/domain layer.
  final int priority;

  /// Comma-separated free-form tags (e.g. "업무,급함") — same
  /// deliberately-simple storage as [Events.additionalReminderMinutes]
  /// rather than a join table, since tags here are just labels with no
  /// identity of their own to look up by.
  final String? tags;

  /// Whether a local notification fires at [slotStart] — meaningless (and
  /// never actually scheduled, see `TodoController.add`) when [hasTime] is
  /// false, since there's no specific moment to fire at. Unlike
  /// [Events.reminderMinutesBefore], a to-do has no separate "primary" lead
  /// time of its own — the due-time alert (offset 0) is always implicitly
  /// included whenever this is on, with [additionalReminderMinutes] only
  /// ever adding extra earlier ones on top of it.
  final bool notify;

  /// Extra reminder offsets (minutes before [slotStart]) on top of the
  /// implicit "at due time" (offset 0) alert, comma-separated — same storage
  /// shape as [Events.additionalReminderMinutes]. Null/empty when there are
  /// none. See `TodoAlertX.reminderOffsets`.
  final String? additionalReminderMinutes;

  /// RFC 5545-style RRULE string, informational only — see
  /// [Events.recurrenceRule] for why recurrence is materialized as separate
  /// rows instead of expanded from this at query time.
  final String? recurrenceRule;

  /// Shared id linking every materialized occurrence of one recurring
  /// series, so "delete this and future" can bulk-target them. Null for a
  /// one-off to-do.
  final String? recurrenceGroupId;

  /// Pinned to-dos surface first on the smart list's "고정됨" tab and carry
  /// a small badge wherever else they're shown — purely a visibility aid,
  /// never a sort override in the day view's own timeline (that view's
  /// whole point is chronological order; forcing a pinned 3pm item ahead of
  /// a 9am one there would fight that, unlike the no-time bucket's
  /// `sortOrder` drag reorder, which has no chronological meaning to
  /// protect).
  final bool isPinned;
  final String? osReminderId;
  final String? osReminderListId;
  final DateTime? osReminderLastKnownModified;
  final SyncStatus reminderSyncStatus;
  final DateTime createdAt;
  const TodoRow({
    required this.id,
    this.eventId,
    required this.title,
    required this.slotStart,
    this.slotEnd,
    required this.hasTime,
    required this.isDone,
    this.completedAt,
    required this.sortOrder,
    required this.priority,
    this.tags,
    required this.notify,
    this.additionalReminderMinutes,
    this.recurrenceRule,
    this.recurrenceGroupId,
    required this.isPinned,
    this.osReminderId,
    this.osReminderListId,
    this.osReminderLastKnownModified,
    required this.reminderSyncStatus,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['title'] = Variable<String>(title);
    map['slot_start'] = Variable<DateTime>(slotStart);
    if (!nullToAbsent || slotEnd != null) {
      map['slot_end'] = Variable<DateTime>(slotEnd);
    }
    map['has_time'] = Variable<bool>(hasTime);
    map['is_done'] = Variable<bool>(isDone);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['notify'] = Variable<bool>(notify);
    if (!nullToAbsent || additionalReminderMinutes != null) {
      map['additional_reminder_minutes'] = Variable<String>(
        additionalReminderMinutes,
      );
    }
    if (!nullToAbsent || recurrenceRule != null) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule);
    }
    if (!nullToAbsent || recurrenceGroupId != null) {
      map['recurrence_group_id'] = Variable<String>(recurrenceGroupId);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || osReminderId != null) {
      map['os_reminder_id'] = Variable<String>(osReminderId);
    }
    if (!nullToAbsent || osReminderListId != null) {
      map['os_reminder_list_id'] = Variable<String>(osReminderListId);
    }
    if (!nullToAbsent || osReminderLastKnownModified != null) {
      map['os_reminder_last_known_modified'] = Variable<DateTime>(
        osReminderLastKnownModified,
      );
    }
    {
      map['reminder_sync_status'] = Variable<String>(
        $TodoItemsTable.$converterreminderSyncStatus.toSql(reminderSyncStatus),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoItemsCompanion toCompanion(bool nullToAbsent) {
    return TodoItemsCompanion(
      id: Value(id),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      title: Value(title),
      slotStart: Value(slotStart),
      slotEnd: slotEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(slotEnd),
      hasTime: Value(hasTime),
      isDone: Value(isDone),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      sortOrder: Value(sortOrder),
      priority: Value(priority),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      notify: Value(notify),
      additionalReminderMinutes:
          additionalReminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(additionalReminderMinutes),
      recurrenceRule: recurrenceRule == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceRule),
      recurrenceGroupId: recurrenceGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceGroupId),
      isPinned: Value(isPinned),
      osReminderId: osReminderId == null && nullToAbsent
          ? const Value.absent()
          : Value(osReminderId),
      osReminderListId: osReminderListId == null && nullToAbsent
          ? const Value.absent()
          : Value(osReminderListId),
      osReminderLastKnownModified:
          osReminderLastKnownModified == null && nullToAbsent
          ? const Value.absent()
          : Value(osReminderLastKnownModified),
      reminderSyncStatus: Value(reminderSyncStatus),
      createdAt: Value(createdAt),
    );
  }

  factory TodoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoRow(
      id: serializer.fromJson<String>(json['id']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      title: serializer.fromJson<String>(json['title']),
      slotStart: serializer.fromJson<DateTime>(json['slotStart']),
      slotEnd: serializer.fromJson<DateTime?>(json['slotEnd']),
      hasTime: serializer.fromJson<bool>(json['hasTime']),
      isDone: serializer.fromJson<bool>(json['isDone']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      priority: serializer.fromJson<int>(json['priority']),
      tags: serializer.fromJson<String?>(json['tags']),
      notify: serializer.fromJson<bool>(json['notify']),
      additionalReminderMinutes: serializer.fromJson<String?>(
        json['additionalReminderMinutes'],
      ),
      recurrenceRule: serializer.fromJson<String?>(json['recurrenceRule']),
      recurrenceGroupId: serializer.fromJson<String?>(
        json['recurrenceGroupId'],
      ),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      osReminderId: serializer.fromJson<String?>(json['osReminderId']),
      osReminderListId: serializer.fromJson<String?>(json['osReminderListId']),
      osReminderLastKnownModified: serializer.fromJson<DateTime?>(
        json['osReminderLastKnownModified'],
      ),
      reminderSyncStatus: $TodoItemsTable.$converterreminderSyncStatus.fromJson(
        serializer.fromJson<String>(json['reminderSyncStatus']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventId': serializer.toJson<String?>(eventId),
      'title': serializer.toJson<String>(title),
      'slotStart': serializer.toJson<DateTime>(slotStart),
      'slotEnd': serializer.toJson<DateTime?>(slotEnd),
      'hasTime': serializer.toJson<bool>(hasTime),
      'isDone': serializer.toJson<bool>(isDone),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'priority': serializer.toJson<int>(priority),
      'tags': serializer.toJson<String?>(tags),
      'notify': serializer.toJson<bool>(notify),
      'additionalReminderMinutes': serializer.toJson<String?>(
        additionalReminderMinutes,
      ),
      'recurrenceRule': serializer.toJson<String?>(recurrenceRule),
      'recurrenceGroupId': serializer.toJson<String?>(recurrenceGroupId),
      'isPinned': serializer.toJson<bool>(isPinned),
      'osReminderId': serializer.toJson<String?>(osReminderId),
      'osReminderListId': serializer.toJson<String?>(osReminderListId),
      'osReminderLastKnownModified': serializer.toJson<DateTime?>(
        osReminderLastKnownModified,
      ),
      'reminderSyncStatus': serializer.toJson<String>(
        $TodoItemsTable.$converterreminderSyncStatus.toJson(reminderSyncStatus),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoRow copyWith({
    String? id,
    Value<String?> eventId = const Value.absent(),
    String? title,
    DateTime? slotStart,
    Value<DateTime?> slotEnd = const Value.absent(),
    bool? hasTime,
    bool? isDone,
    Value<DateTime?> completedAt = const Value.absent(),
    int? sortOrder,
    int? priority,
    Value<String?> tags = const Value.absent(),
    bool? notify,
    Value<String?> additionalReminderMinutes = const Value.absent(),
    Value<String?> recurrenceRule = const Value.absent(),
    Value<String?> recurrenceGroupId = const Value.absent(),
    bool? isPinned,
    Value<String?> osReminderId = const Value.absent(),
    Value<String?> osReminderListId = const Value.absent(),
    Value<DateTime?> osReminderLastKnownModified = const Value.absent(),
    SyncStatus? reminderSyncStatus,
    DateTime? createdAt,
  }) => TodoRow(
    id: id ?? this.id,
    eventId: eventId.present ? eventId.value : this.eventId,
    title: title ?? this.title,
    slotStart: slotStart ?? this.slotStart,
    slotEnd: slotEnd.present ? slotEnd.value : this.slotEnd,
    hasTime: hasTime ?? this.hasTime,
    isDone: isDone ?? this.isDone,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    sortOrder: sortOrder ?? this.sortOrder,
    priority: priority ?? this.priority,
    tags: tags.present ? tags.value : this.tags,
    notify: notify ?? this.notify,
    additionalReminderMinutes: additionalReminderMinutes.present
        ? additionalReminderMinutes.value
        : this.additionalReminderMinutes,
    recurrenceRule: recurrenceRule.present
        ? recurrenceRule.value
        : this.recurrenceRule,
    recurrenceGroupId: recurrenceGroupId.present
        ? recurrenceGroupId.value
        : this.recurrenceGroupId,
    isPinned: isPinned ?? this.isPinned,
    osReminderId: osReminderId.present ? osReminderId.value : this.osReminderId,
    osReminderListId: osReminderListId.present
        ? osReminderListId.value
        : this.osReminderListId,
    osReminderLastKnownModified: osReminderLastKnownModified.present
        ? osReminderLastKnownModified.value
        : this.osReminderLastKnownModified,
    reminderSyncStatus: reminderSyncStatus ?? this.reminderSyncStatus,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoRow copyWithCompanion(TodoItemsCompanion data) {
    return TodoRow(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      title: data.title.present ? data.title.value : this.title,
      slotStart: data.slotStart.present ? data.slotStart.value : this.slotStart,
      slotEnd: data.slotEnd.present ? data.slotEnd.value : this.slotEnd,
      hasTime: data.hasTime.present ? data.hasTime.value : this.hasTime,
      isDone: data.isDone.present ? data.isDone.value : this.isDone,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      priority: data.priority.present ? data.priority.value : this.priority,
      tags: data.tags.present ? data.tags.value : this.tags,
      notify: data.notify.present ? data.notify.value : this.notify,
      additionalReminderMinutes: data.additionalReminderMinutes.present
          ? data.additionalReminderMinutes.value
          : this.additionalReminderMinutes,
      recurrenceRule: data.recurrenceRule.present
          ? data.recurrenceRule.value
          : this.recurrenceRule,
      recurrenceGroupId: data.recurrenceGroupId.present
          ? data.recurrenceGroupId.value
          : this.recurrenceGroupId,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      osReminderId: data.osReminderId.present
          ? data.osReminderId.value
          : this.osReminderId,
      osReminderListId: data.osReminderListId.present
          ? data.osReminderListId.value
          : this.osReminderListId,
      osReminderLastKnownModified: data.osReminderLastKnownModified.present
          ? data.osReminderLastKnownModified.value
          : this.osReminderLastKnownModified,
      reminderSyncStatus: data.reminderSyncStatus.present
          ? data.reminderSyncStatus.value
          : this.reminderSyncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoRow(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('title: $title, ')
          ..write('slotStart: $slotStart, ')
          ..write('slotEnd: $slotEnd, ')
          ..write('hasTime: $hasTime, ')
          ..write('isDone: $isDone, ')
          ..write('completedAt: $completedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('priority: $priority, ')
          ..write('tags: $tags, ')
          ..write('notify: $notify, ')
          ..write('additionalReminderMinutes: $additionalReminderMinutes, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceGroupId: $recurrenceGroupId, ')
          ..write('isPinned: $isPinned, ')
          ..write('osReminderId: $osReminderId, ')
          ..write('osReminderListId: $osReminderListId, ')
          ..write('osReminderLastKnownModified: $osReminderLastKnownModified, ')
          ..write('reminderSyncStatus: $reminderSyncStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    eventId,
    title,
    slotStart,
    slotEnd,
    hasTime,
    isDone,
    completedAt,
    sortOrder,
    priority,
    tags,
    notify,
    additionalReminderMinutes,
    recurrenceRule,
    recurrenceGroupId,
    isPinned,
    osReminderId,
    osReminderListId,
    osReminderLastKnownModified,
    reminderSyncStatus,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoRow &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.title == this.title &&
          other.slotStart == this.slotStart &&
          other.slotEnd == this.slotEnd &&
          other.hasTime == this.hasTime &&
          other.isDone == this.isDone &&
          other.completedAt == this.completedAt &&
          other.sortOrder == this.sortOrder &&
          other.priority == this.priority &&
          other.tags == this.tags &&
          other.notify == this.notify &&
          other.additionalReminderMinutes == this.additionalReminderMinutes &&
          other.recurrenceRule == this.recurrenceRule &&
          other.recurrenceGroupId == this.recurrenceGroupId &&
          other.isPinned == this.isPinned &&
          other.osReminderId == this.osReminderId &&
          other.osReminderListId == this.osReminderListId &&
          other.osReminderLastKnownModified ==
              this.osReminderLastKnownModified &&
          other.reminderSyncStatus == this.reminderSyncStatus &&
          other.createdAt == this.createdAt);
}

class TodoItemsCompanion extends UpdateCompanion<TodoRow> {
  final Value<String> id;
  final Value<String?> eventId;
  final Value<String> title;
  final Value<DateTime> slotStart;
  final Value<DateTime?> slotEnd;
  final Value<bool> hasTime;
  final Value<bool> isDone;
  final Value<DateTime?> completedAt;
  final Value<int> sortOrder;
  final Value<int> priority;
  final Value<String?> tags;
  final Value<bool> notify;
  final Value<String?> additionalReminderMinutes;
  final Value<String?> recurrenceRule;
  final Value<String?> recurrenceGroupId;
  final Value<bool> isPinned;
  final Value<String?> osReminderId;
  final Value<String?> osReminderListId;
  final Value<DateTime?> osReminderLastKnownModified;
  final Value<SyncStatus> reminderSyncStatus;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoItemsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.title = const Value.absent(),
    this.slotStart = const Value.absent(),
    this.slotEnd = const Value.absent(),
    this.hasTime = const Value.absent(),
    this.isDone = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.priority = const Value.absent(),
    this.tags = const Value.absent(),
    this.notify = const Value.absent(),
    this.additionalReminderMinutes = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceGroupId = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.osReminderId = const Value.absent(),
    this.osReminderListId = const Value.absent(),
    this.osReminderLastKnownModified = const Value.absent(),
    this.reminderSyncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoItemsCompanion.insert({
    required String id,
    this.eventId = const Value.absent(),
    this.title = const Value.absent(),
    required DateTime slotStart,
    this.slotEnd = const Value.absent(),
    this.hasTime = const Value.absent(),
    this.isDone = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.priority = const Value.absent(),
    this.tags = const Value.absent(),
    this.notify = const Value.absent(),
    this.additionalReminderMinutes = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceGroupId = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.osReminderId = const Value.absent(),
    this.osReminderListId = const Value.absent(),
    this.osReminderLastKnownModified = const Value.absent(),
    this.reminderSyncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       slotStart = Value(slotStart);
  static Insertable<TodoRow> custom({
    Expression<String>? id,
    Expression<String>? eventId,
    Expression<String>? title,
    Expression<DateTime>? slotStart,
    Expression<DateTime>? slotEnd,
    Expression<bool>? hasTime,
    Expression<bool>? isDone,
    Expression<DateTime>? completedAt,
    Expression<int>? sortOrder,
    Expression<int>? priority,
    Expression<String>? tags,
    Expression<bool>? notify,
    Expression<String>? additionalReminderMinutes,
    Expression<String>? recurrenceRule,
    Expression<String>? recurrenceGroupId,
    Expression<bool>? isPinned,
    Expression<String>? osReminderId,
    Expression<String>? osReminderListId,
    Expression<DateTime>? osReminderLastKnownModified,
    Expression<String>? reminderSyncStatus,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (title != null) 'title': title,
      if (slotStart != null) 'slot_start': slotStart,
      if (slotEnd != null) 'slot_end': slotEnd,
      if (hasTime != null) 'has_time': hasTime,
      if (isDone != null) 'is_done': isDone,
      if (completedAt != null) 'completed_at': completedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (priority != null) 'priority': priority,
      if (tags != null) 'tags': tags,
      if (notify != null) 'notify': notify,
      if (additionalReminderMinutes != null)
        'additional_reminder_minutes': additionalReminderMinutes,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (recurrenceGroupId != null) 'recurrence_group_id': recurrenceGroupId,
      if (isPinned != null) 'is_pinned': isPinned,
      if (osReminderId != null) 'os_reminder_id': osReminderId,
      if (osReminderListId != null) 'os_reminder_list_id': osReminderListId,
      if (osReminderLastKnownModified != null)
        'os_reminder_last_known_modified': osReminderLastKnownModified,
      if (reminderSyncStatus != null)
        'reminder_sync_status': reminderSyncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoItemsCompanion copyWith({
    Value<String>? id,
    Value<String?>? eventId,
    Value<String>? title,
    Value<DateTime>? slotStart,
    Value<DateTime?>? slotEnd,
    Value<bool>? hasTime,
    Value<bool>? isDone,
    Value<DateTime?>? completedAt,
    Value<int>? sortOrder,
    Value<int>? priority,
    Value<String?>? tags,
    Value<bool>? notify,
    Value<String?>? additionalReminderMinutes,
    Value<String?>? recurrenceRule,
    Value<String?>? recurrenceGroupId,
    Value<bool>? isPinned,
    Value<String?>? osReminderId,
    Value<String?>? osReminderListId,
    Value<DateTime?>? osReminderLastKnownModified,
    Value<SyncStatus>? reminderSyncStatus,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoItemsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      slotStart: slotStart ?? this.slotStart,
      slotEnd: slotEnd ?? this.slotEnd,
      hasTime: hasTime ?? this.hasTime,
      isDone: isDone ?? this.isDone,
      completedAt: completedAt ?? this.completedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      notify: notify ?? this.notify,
      additionalReminderMinutes:
          additionalReminderMinutes ?? this.additionalReminderMinutes,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceGroupId: recurrenceGroupId ?? this.recurrenceGroupId,
      isPinned: isPinned ?? this.isPinned,
      osReminderId: osReminderId ?? this.osReminderId,
      osReminderListId: osReminderListId ?? this.osReminderListId,
      osReminderLastKnownModified:
          osReminderLastKnownModified ?? this.osReminderLastKnownModified,
      reminderSyncStatus: reminderSyncStatus ?? this.reminderSyncStatus,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (slotStart.present) {
      map['slot_start'] = Variable<DateTime>(slotStart.value);
    }
    if (slotEnd.present) {
      map['slot_end'] = Variable<DateTime>(slotEnd.value);
    }
    if (hasTime.present) {
      map['has_time'] = Variable<bool>(hasTime.value);
    }
    if (isDone.present) {
      map['is_done'] = Variable<bool>(isDone.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (notify.present) {
      map['notify'] = Variable<bool>(notify.value);
    }
    if (additionalReminderMinutes.present) {
      map['additional_reminder_minutes'] = Variable<String>(
        additionalReminderMinutes.value,
      );
    }
    if (recurrenceRule.present) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule.value);
    }
    if (recurrenceGroupId.present) {
      map['recurrence_group_id'] = Variable<String>(recurrenceGroupId.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (osReminderId.present) {
      map['os_reminder_id'] = Variable<String>(osReminderId.value);
    }
    if (osReminderListId.present) {
      map['os_reminder_list_id'] = Variable<String>(osReminderListId.value);
    }
    if (osReminderLastKnownModified.present) {
      map['os_reminder_last_known_modified'] = Variable<DateTime>(
        osReminderLastKnownModified.value,
      );
    }
    if (reminderSyncStatus.present) {
      map['reminder_sync_status'] = Variable<String>(
        $TodoItemsTable.$converterreminderSyncStatus.toSql(
          reminderSyncStatus.value,
        ),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoItemsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('title: $title, ')
          ..write('slotStart: $slotStart, ')
          ..write('slotEnd: $slotEnd, ')
          ..write('hasTime: $hasTime, ')
          ..write('isDone: $isDone, ')
          ..write('completedAt: $completedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('priority: $priority, ')
          ..write('tags: $tags, ')
          ..write('notify: $notify, ')
          ..write('additionalReminderMinutes: $additionalReminderMinutes, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceGroupId: $recurrenceGroupId, ')
          ..write('isPinned: $isPinned, ')
          ..write('osReminderId: $osReminderId, ')
          ..write('osReminderListId: $osReminderListId, ')
          ..write('osReminderLastKnownModified: $osReminderLastKnownModified, ')
          ..write('reminderSyncStatus: $reminderSyncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoSubtasksTable extends TodoSubtasks
    with TableInfo<$TodoSubtasksTable, TodoSubtaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoSubtasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _todoIdMeta = const VerificationMeta('todoId');
  @override
  late final GeneratedColumn<String> todoId = GeneratedColumn<String>(
    'todo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES todo_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isDoneMeta = const VerificationMeta('isDone');
  @override
  late final GeneratedColumn<bool> isDone = GeneratedColumn<bool>(
    'is_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    todoId,
    title,
    isDone,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_subtasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoSubtaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('todo_id')) {
      context.handle(
        _todoIdMeta,
        todoId.isAcceptableOrUnknown(data['todo_id']!, _todoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_todoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('is_done')) {
      context.handle(
        _isDoneMeta,
        isDone.isAcceptableOrUnknown(data['is_done']!, _isDoneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoSubtaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoSubtaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      todoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}todo_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoSubtasksTable createAlias(String alias) {
    return $TodoSubtasksTable(attachedDatabase, alias);
  }
}

class TodoSubtaskRow extends DataClass implements Insertable<TodoSubtaskRow> {
  final String id;
  final String todoId;
  final String title;
  final bool isDone;
  final int sortOrder;
  final DateTime createdAt;
  const TodoSubtaskRow({
    required this.id,
    required this.todoId,
    required this.title,
    required this.isDone,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['todo_id'] = Variable<String>(todoId);
    map['title'] = Variable<String>(title);
    map['is_done'] = Variable<bool>(isDone);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoSubtasksCompanion toCompanion(bool nullToAbsent) {
    return TodoSubtasksCompanion(
      id: Value(id),
      todoId: Value(todoId),
      title: Value(title),
      isDone: Value(isDone),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory TodoSubtaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoSubtaskRow(
      id: serializer.fromJson<String>(json['id']),
      todoId: serializer.fromJson<String>(json['todoId']),
      title: serializer.fromJson<String>(json['title']),
      isDone: serializer.fromJson<bool>(json['isDone']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'todoId': serializer.toJson<String>(todoId),
      'title': serializer.toJson<String>(title),
      'isDone': serializer.toJson<bool>(isDone),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoSubtaskRow copyWith({
    String? id,
    String? todoId,
    String? title,
    bool? isDone,
    int? sortOrder,
    DateTime? createdAt,
  }) => TodoSubtaskRow(
    id: id ?? this.id,
    todoId: todoId ?? this.todoId,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoSubtaskRow copyWithCompanion(TodoSubtasksCompanion data) {
    return TodoSubtaskRow(
      id: data.id.present ? data.id.value : this.id,
      todoId: data.todoId.present ? data.todoId.value : this.todoId,
      title: data.title.present ? data.title.value : this.title,
      isDone: data.isDone.present ? data.isDone.value : this.isDone,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoSubtaskRow(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, todoId, title, isDone, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoSubtaskRow &&
          other.id == this.id &&
          other.todoId == this.todoId &&
          other.title == this.title &&
          other.isDone == this.isDone &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class TodoSubtasksCompanion extends UpdateCompanion<TodoSubtaskRow> {
  final Value<String> id;
  final Value<String> todoId;
  final Value<String> title;
  final Value<bool> isDone;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoSubtasksCompanion({
    this.id = const Value.absent(),
    this.todoId = const Value.absent(),
    this.title = const Value.absent(),
    this.isDone = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoSubtasksCompanion.insert({
    required String id,
    required String todoId,
    this.title = const Value.absent(),
    this.isDone = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       todoId = Value(todoId);
  static Insertable<TodoSubtaskRow> custom({
    Expression<String>? id,
    Expression<String>? todoId,
    Expression<String>? title,
    Expression<bool>? isDone,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (todoId != null) 'todo_id': todoId,
      if (title != null) 'title': title,
      if (isDone != null) 'is_done': isDone,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoSubtasksCompanion copyWith({
    Value<String>? id,
    Value<String>? todoId,
    Value<String>? title,
    Value<bool>? isDone,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoSubtasksCompanion(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (todoId.present) {
      map['todo_id'] = Variable<String>(todoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isDone.present) {
      map['is_done'] = Variable<bool>(isDone.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoSubtasksCompanion(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncLogsTable extends SyncLogs
    with TableInfo<$SyncLogsTable, SyncLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _eventTitleMeta = const VerificationMeta(
    'eventTitle',
  );
  @override
  late final GeneratedColumn<String> eventTitle = GeneratedColumn<String>(
    'event_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncResolution, String>
  resolution = GeneratedColumn<String>(
    'resolution',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<SyncResolution>($SyncLogsTable.$converterresolution);
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    eventTitle,
    resolution,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    }
    if (data.containsKey('event_title')) {
      context.handle(
        _eventTitleMeta,
        eventTitle.isAcceptableOrUnknown(data['event_title']!, _eventTitleMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      eventTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_title'],
      ),
      resolution: $SyncLogsTable.$converterresolution.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}resolution'],
        )!,
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
    );
  }

  @override
  $SyncLogsTable createAlias(String alias) {
    return $SyncLogsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncResolution, String, String>
  $converterresolution = const EnumNameConverter<SyncResolution>(
    SyncResolution.values,
  );
}

class SyncLogRow extends DataClass implements Insertable<SyncLogRow> {
  final int id;
  final DateTime at;
  final String? eventTitle;
  final SyncResolution resolution;
  final String? detail;
  const SyncLogRow({
    required this.id,
    required this.at,
    this.eventTitle,
    required this.resolution,
    this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['at'] = Variable<DateTime>(at);
    if (!nullToAbsent || eventTitle != null) {
      map['event_title'] = Variable<String>(eventTitle);
    }
    {
      map['resolution'] = Variable<String>(
        $SyncLogsTable.$converterresolution.toSql(resolution),
      );
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    return map;
  }

  SyncLogsCompanion toCompanion(bool nullToAbsent) {
    return SyncLogsCompanion(
      id: Value(id),
      at: Value(at),
      eventTitle: eventTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(eventTitle),
      resolution: Value(resolution),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
    );
  }

  factory SyncLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLogRow(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      eventTitle: serializer.fromJson<String?>(json['eventTitle']),
      resolution: $SyncLogsTable.$converterresolution.fromJson(
        serializer.fromJson<String>(json['resolution']),
      ),
      detail: serializer.fromJson<String?>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<DateTime>(at),
      'eventTitle': serializer.toJson<String?>(eventTitle),
      'resolution': serializer.toJson<String>(
        $SyncLogsTable.$converterresolution.toJson(resolution),
      ),
      'detail': serializer.toJson<String?>(detail),
    };
  }

  SyncLogRow copyWith({
    int? id,
    DateTime? at,
    Value<String?> eventTitle = const Value.absent(),
    SyncResolution? resolution,
    Value<String?> detail = const Value.absent(),
  }) => SyncLogRow(
    id: id ?? this.id,
    at: at ?? this.at,
    eventTitle: eventTitle.present ? eventTitle.value : this.eventTitle,
    resolution: resolution ?? this.resolution,
    detail: detail.present ? detail.value : this.detail,
  );
  SyncLogRow copyWithCompanion(SyncLogsCompanion data) {
    return SyncLogRow(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      eventTitle: data.eventTitle.present
          ? data.eventTitle.value
          : this.eventTitle,
      resolution: data.resolution.present
          ? data.resolution.value
          : this.resolution,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogRow(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('eventTitle: $eventTitle, ')
          ..write('resolution: $resolution, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, at, eventTitle, resolution, detail);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLogRow &&
          other.id == this.id &&
          other.at == this.at &&
          other.eventTitle == this.eventTitle &&
          other.resolution == this.resolution &&
          other.detail == this.detail);
}

class SyncLogsCompanion extends UpdateCompanion<SyncLogRow> {
  final Value<int> id;
  final Value<DateTime> at;
  final Value<String?> eventTitle;
  final Value<SyncResolution> resolution;
  final Value<String?> detail;
  const SyncLogsCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.eventTitle = const Value.absent(),
    this.resolution = const Value.absent(),
    this.detail = const Value.absent(),
  });
  SyncLogsCompanion.insert({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.eventTitle = const Value.absent(),
    required SyncResolution resolution,
    this.detail = const Value.absent(),
  }) : resolution = Value(resolution);
  static Insertable<SyncLogRow> custom({
    Expression<int>? id,
    Expression<DateTime>? at,
    Expression<String>? eventTitle,
    Expression<String>? resolution,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (eventTitle != null) 'event_title': eventTitle,
      if (resolution != null) 'resolution': resolution,
      if (detail != null) 'detail': detail,
    });
  }

  SyncLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? at,
    Value<String?>? eventTitle,
    Value<SyncResolution>? resolution,
    Value<String?>? detail,
  }) {
    return SyncLogsCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      eventTitle: eventTitle ?? this.eventTitle,
      resolution: resolution ?? this.resolution,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (eventTitle.present) {
      map['event_title'] = Variable<String>(eventTitle.value);
    }
    if (resolution.present) {
      map['resolution'] = Variable<String>(
        $SyncLogsTable.$converterresolution.toSql(resolution.value),
      );
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogsCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('eventTitle: $eventTitle, ')
          ..write('resolution: $resolution, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $EventTemplatesTable extends EventTemplates
    with TableInfo<$EventTemplatesTable, EventTemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _isAllDayMeta = const VerificationMeta(
    'isAllDay',
  );
  @override
  late final GeneratedColumn<bool> isAllDay = GeneratedColumn<bool>(
    'is_all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorTagMeta = const VerificationMeta(
    'colorTag',
  );
  @override
  late final GeneratedColumn<String> colorTag = GeneratedColumn<String>(
    'color_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notifyMeta = const VerificationMeta('notify');
  @override
  late final GeneratedColumn<bool> notify = GeneratedColumn<bool>(
    'notify',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _reminderMinutesBeforeMeta =
      const VerificationMeta('reminderMinutesBefore');
  @override
  late final GeneratedColumn<int> reminderMinutesBefore = GeneratedColumn<int>(
    'reminder_minutes_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    title,
    memo,
    durationMinutes,
    isAllDay,
    colorTag,
    notify,
    reminderMinutesBefore,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventTemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('is_all_day')) {
      context.handle(
        _isAllDayMeta,
        isAllDay.isAcceptableOrUnknown(data['is_all_day']!, _isAllDayMeta),
      );
    }
    if (data.containsKey('color_tag')) {
      context.handle(
        _colorTagMeta,
        colorTag.isAcceptableOrUnknown(data['color_tag']!, _colorTagMeta),
      );
    }
    if (data.containsKey('notify')) {
      context.handle(
        _notifyMeta,
        notify.isAcceptableOrUnknown(data['notify']!, _notifyMeta),
      );
    }
    if (data.containsKey('reminder_minutes_before')) {
      context.handle(
        _reminderMinutesBeforeMeta,
        reminderMinutesBefore.isAcceptableOrUnknown(
          data['reminder_minutes_before']!,
          _reminderMinutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventTemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventTemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      isAllDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_all_day'],
      )!,
      colorTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_tag'],
      ),
      notify: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify'],
      )!,
      reminderMinutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes_before'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EventTemplatesTable createAlias(String alias) {
    return $EventTemplatesTable(attachedDatabase, alias);
  }
}

class EventTemplateRow extends DataClass
    implements Insertable<EventTemplateRow> {
  final String id;
  final String name;
  final String title;
  final String? memo;
  final int durationMinutes;
  final bool isAllDay;
  final String? colorTag;
  final bool notify;
  final int reminderMinutesBefore;
  final DateTime createdAt;
  const EventTemplateRow({
    required this.id,
    required this.name,
    required this.title,
    this.memo,
    required this.durationMinutes,
    required this.isAllDay,
    this.colorTag,
    required this.notify,
    required this.reminderMinutesBefore,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['is_all_day'] = Variable<bool>(isAllDay);
    if (!nullToAbsent || colorTag != null) {
      map['color_tag'] = Variable<String>(colorTag);
    }
    map['notify'] = Variable<bool>(notify);
    map['reminder_minutes_before'] = Variable<int>(reminderMinutesBefore);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EventTemplatesCompanion toCompanion(bool nullToAbsent) {
    return EventTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      title: Value(title),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      durationMinutes: Value(durationMinutes),
      isAllDay: Value(isAllDay),
      colorTag: colorTag == null && nullToAbsent
          ? const Value.absent()
          : Value(colorTag),
      notify: Value(notify),
      reminderMinutesBefore: Value(reminderMinutesBefore),
      createdAt: Value(createdAt),
    );
  }

  factory EventTemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventTemplateRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      title: serializer.fromJson<String>(json['title']),
      memo: serializer.fromJson<String?>(json['memo']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      isAllDay: serializer.fromJson<bool>(json['isAllDay']),
      colorTag: serializer.fromJson<String?>(json['colorTag']),
      notify: serializer.fromJson<bool>(json['notify']),
      reminderMinutesBefore: serializer.fromJson<int>(
        json['reminderMinutesBefore'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'title': serializer.toJson<String>(title),
      'memo': serializer.toJson<String?>(memo),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'isAllDay': serializer.toJson<bool>(isAllDay),
      'colorTag': serializer.toJson<String?>(colorTag),
      'notify': serializer.toJson<bool>(notify),
      'reminderMinutesBefore': serializer.toJson<int>(reminderMinutesBefore),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EventTemplateRow copyWith({
    String? id,
    String? name,
    String? title,
    Value<String?> memo = const Value.absent(),
    int? durationMinutes,
    bool? isAllDay,
    Value<String?> colorTag = const Value.absent(),
    bool? notify,
    int? reminderMinutesBefore,
    DateTime? createdAt,
  }) => EventTemplateRow(
    id: id ?? this.id,
    name: name ?? this.name,
    title: title ?? this.title,
    memo: memo.present ? memo.value : this.memo,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    isAllDay: isAllDay ?? this.isAllDay,
    colorTag: colorTag.present ? colorTag.value : this.colorTag,
    notify: notify ?? this.notify,
    reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    createdAt: createdAt ?? this.createdAt,
  );
  EventTemplateRow copyWithCompanion(EventTemplatesCompanion data) {
    return EventTemplateRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      title: data.title.present ? data.title.value : this.title,
      memo: data.memo.present ? data.memo.value : this.memo,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      isAllDay: data.isAllDay.present ? data.isAllDay.value : this.isAllDay,
      colorTag: data.colorTag.present ? data.colorTag.value : this.colorTag,
      notify: data.notify.present ? data.notify.value : this.notify,
      reminderMinutesBefore: data.reminderMinutesBefore.present
          ? data.reminderMinutesBefore.value
          : this.reminderMinutesBefore,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventTemplateRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('colorTag: $colorTag, ')
          ..write('notify: $notify, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    title,
    memo,
    durationMinutes,
    isAllDay,
    colorTag,
    notify,
    reminderMinutesBefore,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTemplateRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.title == this.title &&
          other.memo == this.memo &&
          other.durationMinutes == this.durationMinutes &&
          other.isAllDay == this.isAllDay &&
          other.colorTag == this.colorTag &&
          other.notify == this.notify &&
          other.reminderMinutesBefore == this.reminderMinutesBefore &&
          other.createdAt == this.createdAt);
}

class EventTemplatesCompanion extends UpdateCompanion<EventTemplateRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> title;
  final Value<String?> memo;
  final Value<int> durationMinutes;
  final Value<bool> isAllDay;
  final Value<String?> colorTag;
  final Value<bool> notify;
  final Value<int> reminderMinutesBefore;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const EventTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.title = const Value.absent(),
    this.memo = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.colorTag = const Value.absent(),
    this.notify = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventTemplatesCompanion.insert({
    required String id,
    required String name,
    this.title = const Value.absent(),
    this.memo = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.colorTag = const Value.absent(),
    this.notify = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<EventTemplateRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? title,
    Expression<String>? memo,
    Expression<int>? durationMinutes,
    Expression<bool>? isAllDay,
    Expression<String>? colorTag,
    Expression<bool>? notify,
    Expression<int>? reminderMinutesBefore,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (title != null) 'title': title,
      if (memo != null) 'memo': memo,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (isAllDay != null) 'is_all_day': isAllDay,
      if (colorTag != null) 'color_tag': colorTag,
      if (notify != null) 'notify': notify,
      if (reminderMinutesBefore != null)
        'reminder_minutes_before': reminderMinutesBefore,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? title,
    Value<String?>? memo,
    Value<int>? durationMinutes,
    Value<bool>? isAllDay,
    Value<String?>? colorTag,
    Value<bool>? notify,
    Value<int>? reminderMinutesBefore,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return EventTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isAllDay: isAllDay ?? this.isAllDay,
      colorTag: colorTag ?? this.colorTag,
      notify: notify ?? this.notify,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (isAllDay.present) {
      map['is_all_day'] = Variable<bool>(isAllDay.value);
    }
    if (colorTag.present) {
      map['color_tag'] = Variable<String>(colorTag.value);
    }
    if (notify.present) {
      map['notify'] = Variable<bool>(notify.value);
    }
    if (reminderMinutesBefore.present) {
      map['reminder_minutes_before'] = Variable<int>(
        reminderMinutesBefore.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('colorTag: $colorTag, ')
          ..write('notify: $notify, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventsTable events = $EventsTable(this);
  late final $TodoItemsTable todoItems = $TodoItemsTable(this);
  late final $TodoSubtasksTable todoSubtasks = $TodoSubtasksTable(this);
  late final $SyncLogsTable syncLogs = $SyncLogsTable(this);
  late final $EventTemplatesTable eventTemplates = $EventTemplatesTable(this);
  late final EventDao eventDao = EventDao(this as AppDatabase);
  late final TodoDao todoDao = TodoDao(this as AppDatabase);
  late final SyncLogDao syncLogDao = SyncLogDao(this as AppDatabase);
  late final EventTemplateDao eventTemplateDao = EventTemplateDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    events,
    todoItems,
    todoSubtasks,
    syncLogs,
    eventTemplates,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('todo_items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'todo_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('todo_subtasks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      required String id,
      Value<String> title,
      Value<String?> memo,
      Value<String?> location,
      required DateTime startAt,
      required DateTime endAt,
      Value<bool> isAllDay,
      Value<String?> colorTag,
      Value<bool> notify,
      Value<int> reminderMinutesBefore,
      Value<String?> additionalReminderMinutes,
      Value<String?> recurrenceRule,
      Value<String?> recurrenceGroupId,
      Value<String?> osCalendarId,
      Value<String?> osEventId,
      Value<DateTime?> osLastKnownModified,
      Value<SyncStatus> syncStatus,
      Value<String?> importSourceCalendarId,
      Value<String?> importSourceEventId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> memo,
      Value<String?> location,
      Value<DateTime> startAt,
      Value<DateTime> endAt,
      Value<bool> isAllDay,
      Value<String?> colorTag,
      Value<bool> notify,
      Value<int> reminderMinutesBefore,
      Value<String?> additionalReminderMinutes,
      Value<String?> recurrenceRule,
      Value<String?> recurrenceGroupId,
      Value<String?> osCalendarId,
      Value<String?> osEventId,
      Value<DateTime?> osLastKnownModified,
      Value<SyncStatus> syncStatus,
      Value<String?> importSourceCalendarId,
      Value<String?> importSourceEventId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$EventsTableReferences
    extends BaseReferences<_$AppDatabase, $EventsTable, EventRow> {
  $$EventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TodoItemsTable, List<TodoRow>>
  _todoItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.todoItems,
    aliasName: 'events__id__todo_items__event_id',
  );

  $$TodoItemsTableProcessedTableManager get todoItemsRefs {
    final manager = $$TodoItemsTableTableManager(
      $_db,
      $_db.todoItems,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todoItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorTag => $composableBuilder(
    column: $table.colorTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get additionalReminderMinutes => $composableBuilder(
    column: $table.additionalReminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceGroupId => $composableBuilder(
    column: $table.recurrenceGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get osCalendarId => $composableBuilder(
    column: $table.osCalendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get osEventId => $composableBuilder(
    column: $table.osEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get osLastKnownModified => $composableBuilder(
    column: $table.osLastKnownModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncStatus, SyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get importSourceCalendarId => $composableBuilder(
    column: $table.importSourceCalendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importSourceEventId => $composableBuilder(
    column: $table.importSourceEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> todoItemsRefs(
    Expression<bool> Function($$TodoItemsTableFilterComposer f) f,
  ) {
    final $$TodoItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoItems,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemsTableFilterComposer(
            $db: $db,
            $table: $db.todoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorTag => $composableBuilder(
    column: $table.colorTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get additionalReminderMinutes => $composableBuilder(
    column: $table.additionalReminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceGroupId => $composableBuilder(
    column: $table.recurrenceGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get osCalendarId => $composableBuilder(
    column: $table.osCalendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get osEventId => $composableBuilder(
    column: $table.osEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get osLastKnownModified => $composableBuilder(
    column: $table.osLastKnownModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importSourceCalendarId => $composableBuilder(
    column: $table.importSourceCalendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importSourceEventId => $composableBuilder(
    column: $table.importSourceEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<bool> get isAllDay =>
      $composableBuilder(column: $table.isAllDay, builder: (column) => column);

  GeneratedColumn<String> get colorTag =>
      $composableBuilder(column: $table.colorTag, builder: (column) => column);

  GeneratedColumn<bool> get notify =>
      $composableBuilder(column: $table.notify, builder: (column) => column);

  GeneratedColumn<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get additionalReminderMinutes => $composableBuilder(
    column: $table.additionalReminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceGroupId => $composableBuilder(
    column: $table.recurrenceGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get osCalendarId => $composableBuilder(
    column: $table.osCalendarId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get osEventId =>
      $composableBuilder(column: $table.osEventId, builder: (column) => column);

  GeneratedColumn<DateTime> get osLastKnownModified => $composableBuilder(
    column: $table.osLastKnownModified,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SyncStatus, String> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get importSourceCalendarId => $composableBuilder(
    column: $table.importSourceCalendarId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importSourceEventId => $composableBuilder(
    column: $table.importSourceEventId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> todoItemsRefs<T extends Object>(
    Expression<T> Function($$TodoItemsTableAnnotationComposer a) f,
  ) {
    final $$TodoItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoItems,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          EventRow,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (EventRow, $$EventsTableReferences),
          EventRow,
          PrefetchHooks Function({bool todoItemsRefs})
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> endAt = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> colorTag = const Value.absent(),
                Value<bool> notify = const Value.absent(),
                Value<int> reminderMinutesBefore = const Value.absent(),
                Value<String?> additionalReminderMinutes = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceGroupId = const Value.absent(),
                Value<String?> osCalendarId = const Value.absent(),
                Value<String?> osEventId = const Value.absent(),
                Value<DateTime?> osLastKnownModified = const Value.absent(),
                Value<SyncStatus> syncStatus = const Value.absent(),
                Value<String?> importSourceCalendarId = const Value.absent(),
                Value<String?> importSourceEventId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                title: title,
                memo: memo,
                location: location,
                startAt: startAt,
                endAt: endAt,
                isAllDay: isAllDay,
                colorTag: colorTag,
                notify: notify,
                reminderMinutesBefore: reminderMinutesBefore,
                additionalReminderMinutes: additionalReminderMinutes,
                recurrenceRule: recurrenceRule,
                recurrenceGroupId: recurrenceGroupId,
                osCalendarId: osCalendarId,
                osEventId: osEventId,
                osLastKnownModified: osLastKnownModified,
                syncStatus: syncStatus,
                importSourceCalendarId: importSourceCalendarId,
                importSourceEventId: importSourceEventId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<String?> location = const Value.absent(),
                required DateTime startAt,
                required DateTime endAt,
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> colorTag = const Value.absent(),
                Value<bool> notify = const Value.absent(),
                Value<int> reminderMinutesBefore = const Value.absent(),
                Value<String?> additionalReminderMinutes = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceGroupId = const Value.absent(),
                Value<String?> osCalendarId = const Value.absent(),
                Value<String?> osEventId = const Value.absent(),
                Value<DateTime?> osLastKnownModified = const Value.absent(),
                Value<SyncStatus> syncStatus = const Value.absent(),
                Value<String?> importSourceCalendarId = const Value.absent(),
                Value<String?> importSourceEventId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion.insert(
                id: id,
                title: title,
                memo: memo,
                location: location,
                startAt: startAt,
                endAt: endAt,
                isAllDay: isAllDay,
                colorTag: colorTag,
                notify: notify,
                reminderMinutesBefore: reminderMinutesBefore,
                additionalReminderMinutes: additionalReminderMinutes,
                recurrenceRule: recurrenceRule,
                recurrenceGroupId: recurrenceGroupId,
                osCalendarId: osCalendarId,
                osEventId: osEventId,
                osLastKnownModified: osLastKnownModified,
                syncStatus: syncStatus,
                importSourceCalendarId: importSourceCalendarId,
                importSourceEventId: importSourceEventId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$EventsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({todoItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (todoItemsRefs) db.todoItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (todoItemsRefs)
                    await $_getPrefetchedData<EventRow, $EventsTable, TodoRow>(
                      currentTable: table,
                      referencedTable: $$EventsTableReferences
                          ._todoItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EventsTableReferences(db, table, p0).todoItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.eventId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      EventRow,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (EventRow, $$EventsTableReferences),
      EventRow,
      PrefetchHooks Function({bool todoItemsRefs})
    >;
typedef $$TodoItemsTableCreateCompanionBuilder =
    TodoItemsCompanion Function({
      required String id,
      Value<String?> eventId,
      Value<String> title,
      required DateTime slotStart,
      Value<DateTime?> slotEnd,
      Value<bool> hasTime,
      Value<bool> isDone,
      Value<DateTime?> completedAt,
      Value<int> sortOrder,
      Value<int> priority,
      Value<String?> tags,
      Value<bool> notify,
      Value<String?> additionalReminderMinutes,
      Value<String?> recurrenceRule,
      Value<String?> recurrenceGroupId,
      Value<bool> isPinned,
      Value<String?> osReminderId,
      Value<String?> osReminderListId,
      Value<DateTime?> osReminderLastKnownModified,
      Value<SyncStatus> reminderSyncStatus,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$TodoItemsTableUpdateCompanionBuilder =
    TodoItemsCompanion Function({
      Value<String> id,
      Value<String?> eventId,
      Value<String> title,
      Value<DateTime> slotStart,
      Value<DateTime?> slotEnd,
      Value<bool> hasTime,
      Value<bool> isDone,
      Value<DateTime?> completedAt,
      Value<int> sortOrder,
      Value<int> priority,
      Value<String?> tags,
      Value<bool> notify,
      Value<String?> additionalReminderMinutes,
      Value<String?> recurrenceRule,
      Value<String?> recurrenceGroupId,
      Value<bool> isPinned,
      Value<String?> osReminderId,
      Value<String?> osReminderListId,
      Value<DateTime?> osReminderLastKnownModified,
      Value<SyncStatus> reminderSyncStatus,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$TodoItemsTableReferences
    extends BaseReferences<_$AppDatabase, $TodoItemsTable, TodoRow> {
  $$TodoItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EventsTable _eventIdTable(_$AppDatabase db) =>
      db.events.createAlias('todo_items__event_id__events__id');

  $$EventsTableProcessedTableManager? get eventId {
    final $_column = $_itemColumn<String>('event_id');
    if ($_column == null) return null;
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TodoSubtasksTable, List<TodoSubtaskRow>>
  _todoSubtasksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.todoSubtasks,
    aliasName: 'todo_items__id__todo_subtasks__todo_id',
  );

  $$TodoSubtasksTableProcessedTableManager get todoSubtasksRefs {
    final manager = $$TodoSubtasksTableTableManager(
      $_db,
      $_db.todoSubtasks,
    ).filter((f) => f.todoId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todoSubtasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TodoItemsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoItemsTable> {
  $$TodoItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get slotStart => $composableBuilder(
    column: $table.slotStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get slotEnd => $composableBuilder(
    column: $table.slotEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasTime => $composableBuilder(
    column: $table.hasTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get additionalReminderMinutes => $composableBuilder(
    column: $table.additionalReminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceGroupId => $composableBuilder(
    column: $table.recurrenceGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get osReminderId => $composableBuilder(
    column: $table.osReminderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get osReminderListId => $composableBuilder(
    column: $table.osReminderListId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get osReminderLastKnownModified => $composableBuilder(
    column: $table.osReminderLastKnownModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncStatus, SyncStatus, String>
  get reminderSyncStatus => $composableBuilder(
    column: $table.reminderSyncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EventsTableFilterComposer get eventId {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> todoSubtasksRefs(
    Expression<bool> Function($$TodoSubtasksTableFilterComposer f) f,
  ) {
    final $$TodoSubtasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoSubtasks,
      getReferencedColumn: (t) => t.todoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoSubtasksTableFilterComposer(
            $db: $db,
            $table: $db.todoSubtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoItemsTable> {
  $$TodoItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get slotStart => $composableBuilder(
    column: $table.slotStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get slotEnd => $composableBuilder(
    column: $table.slotEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasTime => $composableBuilder(
    column: $table.hasTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get additionalReminderMinutes => $composableBuilder(
    column: $table.additionalReminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceGroupId => $composableBuilder(
    column: $table.recurrenceGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get osReminderId => $composableBuilder(
    column: $table.osReminderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get osReminderListId => $composableBuilder(
    column: $table.osReminderListId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get osReminderLastKnownModified =>
      $composableBuilder(
        column: $table.osReminderLastKnownModified,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get reminderSyncStatus => $composableBuilder(
    column: $table.reminderSyncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EventsTableOrderingComposer get eventId {
    final $$EventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableOrderingComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoItemsTable> {
  $$TodoItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get slotStart =>
      $composableBuilder(column: $table.slotStart, builder: (column) => column);

  GeneratedColumn<DateTime> get slotEnd =>
      $composableBuilder(column: $table.slotEnd, builder: (column) => column);

  GeneratedColumn<bool> get hasTime =>
      $composableBuilder(column: $table.hasTime, builder: (column) => column);

  GeneratedColumn<bool> get isDone =>
      $composableBuilder(column: $table.isDone, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get notify =>
      $composableBuilder(column: $table.notify, builder: (column) => column);

  GeneratedColumn<String> get additionalReminderMinutes => $composableBuilder(
    column: $table.additionalReminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceGroupId => $composableBuilder(
    column: $table.recurrenceGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<String> get osReminderId => $composableBuilder(
    column: $table.osReminderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get osReminderListId => $composableBuilder(
    column: $table.osReminderListId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get osReminderLastKnownModified =>
      $composableBuilder(
        column: $table.osReminderLastKnownModified,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<SyncStatus, String> get reminderSyncStatus =>
      $composableBuilder(
        column: $table.reminderSyncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$EventsTableAnnotationComposer get eventId {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> todoSubtasksRefs<T extends Object>(
    Expression<T> Function($$TodoSubtasksTableAnnotationComposer a) f,
  ) {
    final $$TodoSubtasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoSubtasks,
      getReferencedColumn: (t) => t.todoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoSubtasksTableAnnotationComposer(
            $db: $db,
            $table: $db.todoSubtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoItemsTable,
          TodoRow,
          $$TodoItemsTableFilterComposer,
          $$TodoItemsTableOrderingComposer,
          $$TodoItemsTableAnnotationComposer,
          $$TodoItemsTableCreateCompanionBuilder,
          $$TodoItemsTableUpdateCompanionBuilder,
          (TodoRow, $$TodoItemsTableReferences),
          TodoRow,
          PrefetchHooks Function({bool eventId, bool todoSubtasksRefs})
        > {
  $$TodoItemsTableTableManager(_$AppDatabase db, $TodoItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> slotStart = const Value.absent(),
                Value<DateTime?> slotEnd = const Value.absent(),
                Value<bool> hasTime = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<bool> notify = const Value.absent(),
                Value<String?> additionalReminderMinutes = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceGroupId = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<String?> osReminderId = const Value.absent(),
                Value<String?> osReminderListId = const Value.absent(),
                Value<DateTime?> osReminderLastKnownModified =
                    const Value.absent(),
                Value<SyncStatus> reminderSyncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoItemsCompanion(
                id: id,
                eventId: eventId,
                title: title,
                slotStart: slotStart,
                slotEnd: slotEnd,
                hasTime: hasTime,
                isDone: isDone,
                completedAt: completedAt,
                sortOrder: sortOrder,
                priority: priority,
                tags: tags,
                notify: notify,
                additionalReminderMinutes: additionalReminderMinutes,
                recurrenceRule: recurrenceRule,
                recurrenceGroupId: recurrenceGroupId,
                isPinned: isPinned,
                osReminderId: osReminderId,
                osReminderListId: osReminderListId,
                osReminderLastKnownModified: osReminderLastKnownModified,
                reminderSyncStatus: reminderSyncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> eventId = const Value.absent(),
                Value<String> title = const Value.absent(),
                required DateTime slotStart,
                Value<DateTime?> slotEnd = const Value.absent(),
                Value<bool> hasTime = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<bool> notify = const Value.absent(),
                Value<String?> additionalReminderMinutes = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceGroupId = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<String?> osReminderId = const Value.absent(),
                Value<String?> osReminderListId = const Value.absent(),
                Value<DateTime?> osReminderLastKnownModified =
                    const Value.absent(),
                Value<SyncStatus> reminderSyncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoItemsCompanion.insert(
                id: id,
                eventId: eventId,
                title: title,
                slotStart: slotStart,
                slotEnd: slotEnd,
                hasTime: hasTime,
                isDone: isDone,
                completedAt: completedAt,
                sortOrder: sortOrder,
                priority: priority,
                tags: tags,
                notify: notify,
                additionalReminderMinutes: additionalReminderMinutes,
                recurrenceRule: recurrenceRule,
                recurrenceGroupId: recurrenceGroupId,
                isPinned: isPinned,
                osReminderId: osReminderId,
                osReminderListId: osReminderListId,
                osReminderLastKnownModified: osReminderLastKnownModified,
                reminderSyncStatus: reminderSyncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodoItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false, todoSubtasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (todoSubtasksRefs) db.todoSubtasks],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable: $$TodoItemsTableReferences
                                    ._eventIdTable(db),
                                referencedColumn: $$TodoItemsTableReferences
                                    ._eventIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (todoSubtasksRefs)
                    await $_getPrefetchedData<
                      TodoRow,
                      $TodoItemsTable,
                      TodoSubtaskRow
                    >(
                      currentTable: table,
                      referencedTable: $$TodoItemsTableReferences
                          ._todoSubtasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TodoItemsTableReferences(
                            db,
                            table,
                            p0,
                          ).todoSubtasksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.todoId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TodoItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoItemsTable,
      TodoRow,
      $$TodoItemsTableFilterComposer,
      $$TodoItemsTableOrderingComposer,
      $$TodoItemsTableAnnotationComposer,
      $$TodoItemsTableCreateCompanionBuilder,
      $$TodoItemsTableUpdateCompanionBuilder,
      (TodoRow, $$TodoItemsTableReferences),
      TodoRow,
      PrefetchHooks Function({bool eventId, bool todoSubtasksRefs})
    >;
typedef $$TodoSubtasksTableCreateCompanionBuilder =
    TodoSubtasksCompanion Function({
      required String id,
      required String todoId,
      Value<String> title,
      Value<bool> isDone,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$TodoSubtasksTableUpdateCompanionBuilder =
    TodoSubtasksCompanion Function({
      Value<String> id,
      Value<String> todoId,
      Value<String> title,
      Value<bool> isDone,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$TodoSubtasksTableReferences
    extends BaseReferences<_$AppDatabase, $TodoSubtasksTable, TodoSubtaskRow> {
  $$TodoSubtasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TodoItemsTable _todoIdTable(_$AppDatabase db) =>
      db.todoItems.createAlias('todo_subtasks__todo_id__todo_items__id');

  $$TodoItemsTableProcessedTableManager get todoId {
    final $_column = $_itemColumn<String>('todo_id')!;

    final manager = $$TodoItemsTableTableManager(
      $_db,
      $_db.todoItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_todoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TodoSubtasksTableFilterComposer
    extends Composer<_$AppDatabase, $TodoSubtasksTable> {
  $$TodoSubtasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TodoItemsTableFilterComposer get todoId {
    final $$TodoItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoId,
      referencedTable: $db.todoItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemsTableFilterComposer(
            $db: $db,
            $table: $db.todoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoSubtasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoSubtasksTable> {
  $$TodoSubtasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TodoItemsTableOrderingComposer get todoId {
    final $$TodoItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoId,
      referencedTable: $db.todoItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemsTableOrderingComposer(
            $db: $db,
            $table: $db.todoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoSubtasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoSubtasksTable> {
  $$TodoSubtasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isDone =>
      $composableBuilder(column: $table.isDone, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TodoItemsTableAnnotationComposer get todoId {
    final $$TodoItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoId,
      referencedTable: $db.todoItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoSubtasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoSubtasksTable,
          TodoSubtaskRow,
          $$TodoSubtasksTableFilterComposer,
          $$TodoSubtasksTableOrderingComposer,
          $$TodoSubtasksTableAnnotationComposer,
          $$TodoSubtasksTableCreateCompanionBuilder,
          $$TodoSubtasksTableUpdateCompanionBuilder,
          (TodoSubtaskRow, $$TodoSubtasksTableReferences),
          TodoSubtaskRow,
          PrefetchHooks Function({bool todoId})
        > {
  $$TodoSubtasksTableTableManager(_$AppDatabase db, $TodoSubtasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoSubtasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoSubtasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoSubtasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> todoId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoSubtasksCompanion(
                id: id,
                todoId: todoId,
                title: title,
                isDone: isDone,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String todoId,
                Value<String> title = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoSubtasksCompanion.insert(
                id: id,
                todoId: todoId,
                title: title,
                isDone: isDone,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodoSubtasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({todoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (todoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.todoId,
                                referencedTable: $$TodoSubtasksTableReferences
                                    ._todoIdTable(db),
                                referencedColumn: $$TodoSubtasksTableReferences
                                    ._todoIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TodoSubtasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoSubtasksTable,
      TodoSubtaskRow,
      $$TodoSubtasksTableFilterComposer,
      $$TodoSubtasksTableOrderingComposer,
      $$TodoSubtasksTableAnnotationComposer,
      $$TodoSubtasksTableCreateCompanionBuilder,
      $$TodoSubtasksTableUpdateCompanionBuilder,
      (TodoSubtaskRow, $$TodoSubtasksTableReferences),
      TodoSubtaskRow,
      PrefetchHooks Function({bool todoId})
    >;
typedef $$SyncLogsTableCreateCompanionBuilder =
    SyncLogsCompanion Function({
      Value<int> id,
      Value<DateTime> at,
      Value<String?> eventTitle,
      required SyncResolution resolution,
      Value<String?> detail,
    });
typedef $$SyncLogsTableUpdateCompanionBuilder =
    SyncLogsCompanion Function({
      Value<int> id,
      Value<DateTime> at,
      Value<String?> eventTitle,
      Value<SyncResolution> resolution,
      Value<String?> detail,
    });

class $$SyncLogsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventTitle => $composableBuilder(
    column: $table.eventTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncResolution, SyncResolution, String>
  get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventTitle => $composableBuilder(
    column: $table.eventTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get eventTitle => $composableBuilder(
    column: $table.eventTitle,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SyncResolution, String> get resolution =>
      $composableBuilder(
        column: $table.resolution,
        builder: (column) => column,
      );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$SyncLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncLogsTable,
          SyncLogRow,
          $$SyncLogsTableFilterComposer,
          $$SyncLogsTableOrderingComposer,
          $$SyncLogsTableAnnotationComposer,
          $$SyncLogsTableCreateCompanionBuilder,
          $$SyncLogsTableUpdateCompanionBuilder,
          (
            SyncLogRow,
            BaseReferences<_$AppDatabase, $SyncLogsTable, SyncLogRow>,
          ),
          SyncLogRow,
          PrefetchHooks Function()
        > {
  $$SyncLogsTableTableManager(_$AppDatabase db, $SyncLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String?> eventTitle = const Value.absent(),
                Value<SyncResolution> resolution = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => SyncLogsCompanion(
                id: id,
                at: at,
                eventTitle: eventTitle,
                resolution: resolution,
                detail: detail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String?> eventTitle = const Value.absent(),
                required SyncResolution resolution,
                Value<String?> detail = const Value.absent(),
              }) => SyncLogsCompanion.insert(
                id: id,
                at: at,
                eventTitle: eventTitle,
                resolution: resolution,
                detail: detail,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncLogsTable,
      SyncLogRow,
      $$SyncLogsTableFilterComposer,
      $$SyncLogsTableOrderingComposer,
      $$SyncLogsTableAnnotationComposer,
      $$SyncLogsTableCreateCompanionBuilder,
      $$SyncLogsTableUpdateCompanionBuilder,
      (SyncLogRow, BaseReferences<_$AppDatabase, $SyncLogsTable, SyncLogRow>),
      SyncLogRow,
      PrefetchHooks Function()
    >;
typedef $$EventTemplatesTableCreateCompanionBuilder =
    EventTemplatesCompanion Function({
      required String id,
      required String name,
      Value<String> title,
      Value<String?> memo,
      Value<int> durationMinutes,
      Value<bool> isAllDay,
      Value<String?> colorTag,
      Value<bool> notify,
      Value<int> reminderMinutesBefore,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$EventTemplatesTableUpdateCompanionBuilder =
    EventTemplatesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> title,
      Value<String?> memo,
      Value<int> durationMinutes,
      Value<bool> isAllDay,
      Value<String?> colorTag,
      Value<bool> notify,
      Value<int> reminderMinutesBefore,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$EventTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $EventTemplatesTable> {
  $$EventTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorTag => $composableBuilder(
    column: $table.colorTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $EventTemplatesTable> {
  $$EventTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorTag => $composableBuilder(
    column: $table.colorTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventTemplatesTable> {
  $$EventTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAllDay =>
      $composableBuilder(column: $table.isAllDay, builder: (column) => column);

  GeneratedColumn<String> get colorTag =>
      $composableBuilder(column: $table.colorTag, builder: (column) => column);

  GeneratedColumn<bool> get notify =>
      $composableBuilder(column: $table.notify, builder: (column) => column);

  GeneratedColumn<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EventTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventTemplatesTable,
          EventTemplateRow,
          $$EventTemplatesTableFilterComposer,
          $$EventTemplatesTableOrderingComposer,
          $$EventTemplatesTableAnnotationComposer,
          $$EventTemplatesTableCreateCompanionBuilder,
          $$EventTemplatesTableUpdateCompanionBuilder,
          (
            EventTemplateRow,
            BaseReferences<
              _$AppDatabase,
              $EventTemplatesTable,
              EventTemplateRow
            >,
          ),
          EventTemplateRow,
          PrefetchHooks Function()
        > {
  $$EventTemplatesTableTableManager(
    _$AppDatabase db,
    $EventTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> colorTag = const Value.absent(),
                Value<bool> notify = const Value.absent(),
                Value<int> reminderMinutesBefore = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventTemplatesCompanion(
                id: id,
                name: name,
                title: title,
                memo: memo,
                durationMinutes: durationMinutes,
                isAllDay: isAllDay,
                colorTag: colorTag,
                notify: notify,
                reminderMinutesBefore: reminderMinutesBefore,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> title = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> colorTag = const Value.absent(),
                Value<bool> notify = const Value.absent(),
                Value<int> reminderMinutesBefore = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventTemplatesCompanion.insert(
                id: id,
                name: name,
                title: title,
                memo: memo,
                durationMinutes: durationMinutes,
                isAllDay: isAllDay,
                colorTag: colorTag,
                notify: notify,
                reminderMinutesBefore: reminderMinutesBefore,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventTemplatesTable,
      EventTemplateRow,
      $$EventTemplatesTableFilterComposer,
      $$EventTemplatesTableOrderingComposer,
      $$EventTemplatesTableAnnotationComposer,
      $$EventTemplatesTableCreateCompanionBuilder,
      $$EventTemplatesTableUpdateCompanionBuilder,
      (
        EventTemplateRow,
        BaseReferences<_$AppDatabase, $EventTemplatesTable, EventTemplateRow>,
      ),
      EventTemplateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$TodoItemsTableTableManager get todoItems =>
      $$TodoItemsTableTableManager(_db, _db.todoItems);
  $$TodoSubtasksTableTableManager get todoSubtasks =>
      $$TodoSubtasksTableTableManager(_db, _db.todoSubtasks);
  $$SyncLogsTableTableManager get syncLogs =>
      $$SyncLogsTableTableManager(_db, _db.syncLogs);
  $$EventTemplatesTableTableManager get eventTemplates =>
      $$EventTemplatesTableTableManager(_db, _db.eventTemplates);
}
