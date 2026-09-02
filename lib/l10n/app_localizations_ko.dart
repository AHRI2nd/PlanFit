// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppL10nKo extends AppL10n {
  AppL10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => '플랜핏';

  @override
  String get onboardingSkip => '건너뛰기';

  @override
  String get onboardingNext => '다음';

  @override
  String get onboardingGetStarted => '시작하기';

  @override
  String get onboardingPage1Title => '하루를 시간의 흐름으로';

  @override
  String get onboardingPage1Body => '새벽부터 밤까지, 하루의 색이 자연스럽게 흐르는 캘린더예요';

  @override
  String get onboardingPage2Title => '일정과 할 일을 한 곳에';

  @override
  String get onboardingPage2Body => '일/월/년 어디서든 보고, 시간대별 할 일까지 함께 관리해요';

  @override
  String get onboardingPage3Title => '놓치지 않게 알려드려요';

  @override
  String get onboardingPage3Body => '일정이 시작되기 전, 원하는 시점에 알림을 보내드려요';

  @override
  String get tabHome => '홈';

  @override
  String get tabSchedule => '시간표';

  @override
  String get tabSocial => '소셜';

  @override
  String get tabSettings => '설정';

  @override
  String get homeGreetingDawn => '고요한 새벽이에요';

  @override
  String get homeGreetingMorning => '좋은 아침이에요';

  @override
  String get homeGreetingAfternoon => '기분좋은 오후예요';

  @override
  String get homeGreetingEvening => '저녁이 찾아왔어요';

  @override
  String get homeGreetingNight => '깊은 밤이에요';

  @override
  String get homeToday => '오늘';

  @override
  String get homeTodayEmpty => '오늘은 예정된 일정도, 할 일도 없어요';

  @override
  String get homeUpcoming => '다가오는 일정';

  @override
  String get homeUpcomingEmpty => '예정된 일정이 없어요';

  @override
  String get homeTodayTodos => '오늘의 할 일';

  @override
  String homeTodosDone(int done, int total) {
    return '$done/$total 완료';
  }

  @override
  String get homeNoTodos => '오늘 등록된 할 일이 없어요';

  @override
  String homeTodosOverdue(int count) {
    return '$count개 기한 지남';
  }

  @override
  String get homeNowLabel => '지금';

  @override
  String get homeTodosViewAll => '할 일 전체 보기';

  @override
  String get homeWeekTitle => '이번 주';

  @override
  String homeWeekSummary(int events, int done, int total) {
    return '일정 $events개 · 할 일 $done/$total 완료';
  }

  @override
  String get homeWeekEmpty => '이번 주는 아직 조용하네요';

  @override
  String get scheduleTitle => '시간표';

  @override
  String get viewDay => '일';

  @override
  String get viewWeek => '주';

  @override
  String get viewMonth => '월';

  @override
  String get viewYear => '년';

  @override
  String get viewAgenda => '목록';

  @override
  String get dayLayoutSwitchToClock => '원형 시계 보기';

  @override
  String get dayLayoutSwitchToTimeline => '타임라인 보기';

  @override
  String get calendarLegendTooltip => '캘린더 점 색상 안내';

  @override
  String get calendarLegendTitle => '점 색상이 뭘 뜻하나요?';

  @override
  String get calendarLegendOverdueTodo => '기한이 지난 할 일이 있어요';

  @override
  String get calendarLegendTodo => '끝내지 않은 할 일이 있어요';

  @override
  String get calendarLegendEvent => '일정이 있어요';

  @override
  String get calendarLegendMultiDayBarNote =>
      '여러 날에 걸친 일정의 색 막대는 이 규칙과 달라요 — 직접 고른 일정 색이 그대로 표시돼요.';

  @override
  String get monthSplitHandleLabel => '달력 크기 조절';

  @override
  String get dayEmpty => '이 날은 아직 비어 있어요';

  @override
  String get dayAddHint => '오른쪽 아래 + 를 누르거나, 빈 시간을 길게 눌러 일정을 더해보세요';

  @override
  String get agendaEmpty => '예정된 일정이 없어요';

  @override
  String get commonTomorrow => '내일';

  @override
  String get todosSectionTitle => '할 일';

  @override
  String get searchTooltip => '검색';

  @override
  String get quickAddEventTitle => '빠른 추가';

  @override
  String get quickAddEventHint => '날짜와 시간을 자동으로 알아들어요';

  @override
  String get quickAddEventExample => '내일 오후 3시 회의';

  @override
  String quickAddEventCreated(String title, String day, String time) {
    return '\"$title\" · $day $time에 추가했어요';
  }

  @override
  String get searchHint => '제목이나 메모로 검색';

  @override
  String get searchEmpty => '검색 결과가 없어요';

  @override
  String get searchPrompt => '제목이나 메모를 입력해보세요';

  @override
  String get searchSectionEvents => '일정';

  @override
  String get searchSectionTodos => '할 일';

  @override
  String get searchFilterAll => '전체';

  @override
  String get searchFilterTagLabel => '태그';

  @override
  String get searchFilterDateRangePick => '기간 선택';

  @override
  String get searchFilterDateRangeClear => '기간 필터 지우기';

  @override
  String get socialTitle => '소셜';

  @override
  String get socialComingSoonTitle => '곧 만나요';

  @override
  String get socialComingSoonBody =>
      '친구를 추가하고 일정을 나누는 기능을 준비하고 있어요. 지금은 나만의 시간에 집중해보세요.';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsNotifications => '알림';

  @override
  String get settingsNotificationSound => '알림 소리';

  @override
  String get settingsNotificationSoundDesc => '일정이 시작될 때 소리로 알려드려요';

  @override
  String get settingsExactAlarm => '정확한 시각 알림';

  @override
  String get settingsExactAlarmDesc => '정시에 정확히 알리려면 권한이 필요해요';

  @override
  String get settingsCalendar => '캘린더 연동';

  @override
  String get settingsCalendarSync => '기기 캘린더와 동기화';

  @override
  String get settingsCalendarSyncDesc => 'PlanFit 일정을 기기 캘린더에 함께 담아요';

  @override
  String get settingsCalendarAutoImport => '기기 캘린더 자동 불러오기';

  @override
  String get settingsCalendarAutoImportDesc =>
      '캘린더 앱에서 직접 추가한 일정도 PlanFit으로 가져와요';

  @override
  String get settingsSyncLog => '동기화 기록';

  @override
  String get settingsLastSync => '마지막 동기화';

  @override
  String get settingsLastSyncNever => '아직 동기화한 적 없어요';

  @override
  String get settingsCalendarTarget => '동기화 캘린더';

  @override
  String get settingsCalendarTargetAuto => '자동';

  @override
  String get settingsCalendarTargetDisabledHint => '동기화를 켜면 선택할 수 있어요';

  @override
  String get settingsCalendarTargetEmpty => '선택할 수 있는 캘린더가 없어요';

  @override
  String get settingsCalendarImport => '다른 캘린더에서 가져오기';

  @override
  String get settingsCalendarImportDesc => '기존 캘린더에서 가져오거나 계속 구독해요';

  @override
  String get settingsHolidayCalendar => '공휴일 표시';

  @override
  String get settingsHolidayCalendarDesc => '국가별 공휴일 캘린더를 자동으로 불러와요';

  @override
  String settingsHolidaySourceCurrent(String source) {
    return '현재: $source';
  }

  @override
  String get settingsHolidaySourceCustomLabel => '사용자 지정 캘린더';

  @override
  String get settingsHolidaySourceEmpty => '선택 안 함';

  @override
  String settingsHolidaySourceMore(String first, int count) {
    return '$first 외 $count곳';
  }

  @override
  String get holidayCountryKR => '대한민국';

  @override
  String get holidayCountryUS => '미국';

  @override
  String get holidayCountryJP => '일본';

  @override
  String get holidayCountryGB => '영국';

  @override
  String get holidayCountryDE => '독일';

  @override
  String get holidayCountryFR => '프랑스';

  @override
  String get holidayCountryCA => '캐나다';

  @override
  String get holidayCountryAU => '호주';

  @override
  String get holidayCalendarSourceTitle => '공휴일 캘린더 선택';

  @override
  String get holidayCalendarSourceSectionCountries => '국가 선택';

  @override
  String get holidayCalendarSourceCustomEntry => 'URL로 직접 추가';

  @override
  String get holidayCalendarSourceRemoveCustomUrl => '제거';

  @override
  String get holidayCalendarSourceCustomDialogTitle => '캘린더 URL 입력';

  @override
  String get holidayCalendarSourceCustomDialogHint =>
      'https://example.com/calendar.ics';

  @override
  String get holidayCalendarSourceCustomInvalidUrl =>
      '올바른 http/https 링크를 입력해주세요';

  @override
  String get holidayCalendarSourceSyncFailed => '캘린더를 불러오지 못했어요. 링크를 확인해주세요';

  @override
  String get holidayCalendarSourceSyncFailedGeneric => '공휴일 캘린더를 불러오지 못했어요';

  @override
  String get holidayCalendarSourceColorTooltip => '표시 색상 변경';

  @override
  String get holidayCalendarSourceColorTitle => '캘린더 색상 선택';

  @override
  String get holidayCalendarSourceColorDefault => '기본값';

  @override
  String get calendarImportTitle => '가져오기 · 구독할 캘린더';

  @override
  String get calendarImportEmpty => '가져올 수 있는 캘린더가 없어요';

  @override
  String calendarImportConfirmTitle(String calendarName) {
    return '$calendarName에서 가져올까요?';
  }

  @override
  String get calendarImportConfirmBody =>
      '최근 30일부터 앞으로 1년까지의 일정을 PlanFit에 복사해요. 알림은 꺼진 채로 들어오고, 나중에 다시 가져오면 겹치는 항목은 갱신돼요.';

  @override
  String get calendarImportConfirmAction => '가져오기';

  @override
  String get calendarImportInProgress => '가져오는 중이에요…';

  @override
  String calendarImportSuccess(int count) {
    return '$count개의 일정을 가져왔어요';
  }

  @override
  String get calendarImportFailed => '가져오기에 실패했어요';

  @override
  String get calendarImportSubscribedHint => '구독 중 — 계속 최신 상태로 유지돼요';

  @override
  String get calendarImportMirroredReadOnlyNote =>
      '구독한 캘린더에서 가져온 일정이라 PlanFit에서는 읽기 전용이에요. 수정하려면 원본 캘린더 앱에서 바꿔주세요.';

  @override
  String get holidayEventBadge => '공휴일';

  @override
  String get holidayEventReadOnlyNote =>
      '믿을 수 있는 캘린더에서 자동으로 불러온 공휴일이라 PlanFit에서는 읽기 전용이에요.';

  @override
  String get settingsPermissionGranted => '허용됨';

  @override
  String get settingsPermissionDenied => '허용 안 됨';

  @override
  String get settingsPermissionDeniedMessage =>
      '권한이 거부되어 있어요. 기기 설정에서 허용해 주세요.';

  @override
  String get settingsOpenAppSettings => '설정 열기';

  @override
  String get settingsGrant => '허용하기';

  @override
  String get settingsAppearance => '화면';

  @override
  String get settingsWeekStart => '주 시작 요일';

  @override
  String get settingsWeekStartMonday => '월요일';

  @override
  String get settingsWeekStartSunday => '일요일';

  @override
  String get settingsThemeSystem => '시스템 설정';

  @override
  String get settingsThemeLight => '밝게';

  @override
  String get settingsThemeDark => '어둡게';

  @override
  String get settingsTimeFormatDisplay => '일정/할 일 시간 표시';

  @override
  String get settingsTimeFormatDial => '시간 선택 다이얼';

  @override
  String get settingsTimeFormatSystem => '시스템 설정';

  @override
  String get settingsTimeFormatH12 => '12시간제';

  @override
  String get settingsTimeFormatH24 => '24시간제';

  @override
  String get settingsTodo => '할 일';

  @override
  String get settingsReminderSync => '기기 미리알림과 동기화';

  @override
  String get settingsReminderSyncDesc => 'PlanFit 할 일을 기기 미리알림에 함께 담아요';

  @override
  String get settingsTodoRetention => '완료된 할 일 자동 정리';

  @override
  String get settingsTodoRetentionDesc => '완료한 지 일정 기간이 지난 할 일을 자동으로 삭제해요';

  @override
  String get settingsTodoRetentionOff => '사용 안 함';

  @override
  String settingsTodoRetentionDays(int days) {
    return '$days일 후';
  }

  @override
  String get settingsAbout => '정보';

  @override
  String get settingsVersion => '버전';

  @override
  String get settingsData => '데이터';

  @override
  String get settingsExport => '내보내기';

  @override
  String get settingsExportDesc => '모든 일정과 할 일을 파일 하나로 저장해요';

  @override
  String get settingsImport => '가져오기';

  @override
  String get settingsImportDesc => '내보낸 파일에서 일정과 할 일을 복원해요';

  @override
  String get settingsExportIcs => '캘린더 파일로 내보내기';

  @override
  String get settingsExportIcsDesc => '다른 캘린더 앱에서 열 수 있는 표준 파일(.ics)이에요';

  @override
  String get settingsImportIcs => '캘린더 파일 가져오기';

  @override
  String get settingsImportIcsDesc => '다른 캘린더 앱에서 내보낸 .ics 파일을 새 일정으로 추가해요';

  @override
  String icsImportSuccess(int count) {
    return '$count개의 일정을 가져왔어요';
  }

  @override
  String icsImportSkipped(int count) {
    return '$count개는 형식을 알 수 없어 건너뛰었어요';
  }

  @override
  String get icsImportFailed => '가져오기에 실패했어요';

  @override
  String get settingsAutoBackup => '자동 백업 기록';

  @override
  String get autoBackupTitle => '자동 백업';

  @override
  String get autoBackupEmpty => '아직 자동 백업이 없어요';

  @override
  String get autoBackupDesc => '24시간마다 자동으로 백업하고, 최근 7개만 보관해요';

  @override
  String get autoBackupRestore => '이 백업으로 복원';

  @override
  String get autoBackupRestoreConfirmTitle => '이 백업으로 복원할까요?';

  @override
  String get autoBackupRestoreConfirmBody =>
      '지금 있는 일정/할 일에 이 백업 내용이 합쳐져요. 같은 항목은 백업 시점 내용으로 덮어써요.';

  @override
  String get backupExportFailed => '내보내기에 실패했어요';

  @override
  String backupImportSuccess(int events, int todos) {
    return '일정 $events개, 할 일 $todos개를 가져왔어요';
  }

  @override
  String get backupImportFailed => '가져오기에 실패했어요. 파일 형식을 확인해주세요';

  @override
  String get eventNew => '새 일정';

  @override
  String get eventEdit => '일정 편집';

  @override
  String get eventDuplicate => '일정 복제';

  @override
  String get eventShare => '일정 공유';

  @override
  String get eventShareFailed => '공유에 실패했어요';

  @override
  String get eventTemplates => '템플릿';

  @override
  String get templatesTitle => '자주 쓰는 일정';

  @override
  String get templatesEmpty => '저장된 템플릿이 없어요';

  @override
  String get templatesSaveCurrent => '현재 내용을 템플릿으로 저장';

  @override
  String get templatesNameHint => '템플릿 이름 (예: 헬스)';

  @override
  String get templatesNameRequired => '템플릿 이름을 입력해주세요';

  @override
  String get templatesSaved => '템플릿을 저장했어요';

  @override
  String get templatesDeleted => '템플릿을 삭제했어요';

  @override
  String get eventTitle => '제목';

  @override
  String get eventTitleHint => '무엇을 하나요?';

  @override
  String get eventMemo => '메모';

  @override
  String get eventMemoHint => '메모를 남겨보세요';

  @override
  String get eventLocation => '장소';

  @override
  String get eventLocationHint => '장소를 입력해보세요';

  @override
  String get eventOpenInMaps => '지도에서 열기';

  @override
  String get eventOpenInMapsFailed => '지도를 열지 못했어요';

  @override
  String get eventAllDay => '종일';

  @override
  String get eventStart => '시작';

  @override
  String get eventEnd => '종료';

  @override
  String get eventNotify => '시작할 때 알림';

  @override
  String get eventReminderLead => '알림 시점';

  @override
  String get eventReminderAtStart => '정시';

  @override
  String eventReminderMinutesBefore(int minutes) {
    return '$minutes분 전';
  }

  @override
  String eventReminderHoursBefore(int hours) {
    return '$hours시간 전';
  }

  @override
  String get eventReminderDayBefore => '하루 전';

  @override
  String get eventReminderAdditional => '추가 알림 (여러 개 선택 가능)';

  @override
  String get eventRepeat => '반복';

  @override
  String get eventRepeatNone => '안 함';

  @override
  String get eventRepeatDaily => '매일';

  @override
  String get eventRepeatWeekly => '매주';

  @override
  String get eventRepeatMonthly => '매월';

  @override
  String get eventRepeatYearly => '매년';

  @override
  String get eventRepeatUntil => '종료일';

  @override
  String get eventRepeatWeekdays => '반복 요일';

  @override
  String get eventRepeatEndLabel => '종료 조건';

  @override
  String get eventRepeatEndByDate => '날짜까지';

  @override
  String get eventRepeatEndByCount => '횟수만큼';

  @override
  String eventRepeatCountTimes(int count) {
    return '$count회';
  }

  @override
  String get eventRepeatCountDecrease => '반복 횟수 줄이기';

  @override
  String get eventRepeatCountIncrease => '반복 횟수 늘리기';

  @override
  String get eventDeleteSeriesTitle => '반복 일정 삭제';

  @override
  String get eventDeleteSeriesBody => '이 일정은 반복 일정의 일부예요. 어떻게 삭제할까요?';

  @override
  String get eventDeleteThisOnly => '이 일정만 삭제';

  @override
  String get eventDeleteThisAndFuture => '이후 모든 반복 삭제';

  @override
  String get eventSaveSeriesTitle => '반복 일정 저장';

  @override
  String get eventSaveSeriesBody => '이 일정은 반복 일정의 일부예요. 변경 사항을 어떻게 적용할까요?';

  @override
  String get eventSaveThisOnly => '이 일정만 저장';

  @override
  String get eventSaveThisAndFuture => '이후 모든 반복에 적용';

  @override
  String get eventColor => '색상';

  @override
  String get eventColorAuto => '자동';

  @override
  String get eventColorCustom => '직접 선택';

  @override
  String get eventColorPickerTitle => '색상 선택';

  @override
  String get eventSave => '저장';

  @override
  String get eventDelete => '삭제';

  @override
  String get eventDeleted => '일정을 삭제했어요';

  @override
  String get eventUndo => '실행 취소';

  @override
  String eventSelectionCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get eventSelectionDelete => '삭제';

  @override
  String eventSelectionDeleted(int count) {
    return '$count개를 삭제했어요';
  }

  @override
  String get eventTitleRequired => '제목을 입력해주세요';

  @override
  String get eventRecurrenceTruncated => '반복 횟수가 많아 최대 200회까지만 생성했어요';

  @override
  String get todoAdd => '할 일 추가';

  @override
  String get todoHint => '할 일을 입력하세요';

  @override
  String get todoRepeat => '반복';

  @override
  String get todoNoTime => '시간 없음';

  @override
  String get todoRepeatIndicator => '반복되는 할 일';

  @override
  String get todoDragHandle => '순서 변경';

  @override
  String get todoDeleteSeriesTitle => '반복 할 일 삭제';

  @override
  String get todoDeleteSeriesBody => '이 항목은 반복되는 할 일의 일부예요. 어떻게 삭제할까요?';

  @override
  String get todoDeleteThisOnly => '이 항목만 삭제';

  @override
  String get todoDeleteThisAndFuture => '이후 모든 반복 삭제';

  @override
  String get todoDeleted => '할 일을 삭제했어요';

  @override
  String todoQuickAddAddedToOtherDay(String day) {
    return '$day에 추가했어요';
  }

  @override
  String todoSelectionCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get todoSelectionComplete => '완료 처리';

  @override
  String get todoMarkDone => '완료 여부';

  @override
  String get todoSelectItem => '선택';

  @override
  String get todoSelectionDelete => '삭제';

  @override
  String todoSelectionDeleted(int count) {
    return '$count개를 삭제했어요';
  }

  @override
  String get todoEditTitle => '할 일 편집';

  @override
  String get todoTitleLabel => '제목';

  @override
  String get todoReminderAdditional => '추가 알림 (여러 개 선택 가능)';

  @override
  String get todoPriorityLabel => '우선순위';

  @override
  String get todoPriorityNone => '없음';

  @override
  String get todoPriorityLow => '낮음';

  @override
  String get todoPriorityMedium => '보통';

  @override
  String get todoPriorityHigh => '높음';

  @override
  String get todoTagsLabel => '태그';

  @override
  String get todoTagsHint => '쉼표로 구분해 입력 (예: 업무,급함)';

  @override
  String get todoSubtasksLabel => '하위 작업';

  @override
  String get todoSubtaskHint => '하위 작업 추가';

  @override
  String get todoSubtaskDelete => '하위 작업 삭제';

  @override
  String get todoNotify => '정해진 시간에 알림';

  @override
  String get todoNotifyNoTimeHint => '시간을 정해야 알림을 켤 수 있어요';

  @override
  String get todoPin => '고정';

  @override
  String get todoUnpin => '고정 해제';

  @override
  String get todoPinned => '고정됨';

  @override
  String get smartListTitle => '할 일 모아보기';

  @override
  String get smartListToday => '오늘';

  @override
  String get smartListOverdue => '기한 지남';

  @override
  String get smartListHighPriority => '우선순위 높음';

  @override
  String get smartListPinned => '고정됨';

  @override
  String get smartListByTag => '태그별';

  @override
  String get smartListEmptyToday => '오늘 할 일이 없어요';

  @override
  String get smartListEmptyOverdue => '기한 지난 할 일이 없어요';

  @override
  String get smartListEmptyHighPriority => '우선순위 높은 할 일이 없어요';

  @override
  String get smartListEmptyPinned => '고정된 할 일이 없어요';

  @override
  String get smartListEmptyByTag => '이 태그의 할 일이 없어요';

  @override
  String get smartListNoTags => '아직 등록된 태그가 없어요';

  @override
  String get smartListPickTag => '태그를 선택하세요';

  @override
  String get commonCancel => '취소';

  @override
  String get commonDone => '완료';

  @override
  String get commonToday => '오늘';

  @override
  String get errorWidgetFallback => '문제가 발생했어요';
}
