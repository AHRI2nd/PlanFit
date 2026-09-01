import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appName.
  ///
  /// In ko, this message translates to:
  /// **'플랜핏'**
  String get appName;

  /// No description provided for @onboardingSkip.
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingPage1Title.
  ///
  /// In ko, this message translates to:
  /// **'하루를 시간의 흐름으로'**
  String get onboardingPage1Title;

  /// No description provided for @onboardingPage1Body.
  ///
  /// In ko, this message translates to:
  /// **'새벽부터 밤까지, 하루의 색이 자연스럽게 흐르는 캘린더예요'**
  String get onboardingPage1Body;

  /// No description provided for @onboardingPage2Title.
  ///
  /// In ko, this message translates to:
  /// **'일정과 할 일을 한 곳에'**
  String get onboardingPage2Title;

  /// No description provided for @onboardingPage2Body.
  ///
  /// In ko, this message translates to:
  /// **'일/월/년 어디서든 보고, 시간대별 할 일까지 함께 관리해요'**
  String get onboardingPage2Body;

  /// No description provided for @onboardingPage3Title.
  ///
  /// In ko, this message translates to:
  /// **'놓치지 않게 알려드려요'**
  String get onboardingPage3Title;

  /// No description provided for @onboardingPage3Body.
  ///
  /// In ko, this message translates to:
  /// **'일정이 시작되기 전, 원하는 시점에 알림을 보내드려요'**
  String get onboardingPage3Body;

  /// No description provided for @tabHome.
  ///
  /// In ko, this message translates to:
  /// **'홈'**
  String get tabHome;

  /// No description provided for @tabSchedule.
  ///
  /// In ko, this message translates to:
  /// **'시간표'**
  String get tabSchedule;

  /// No description provided for @tabSocial.
  ///
  /// In ko, this message translates to:
  /// **'소셜'**
  String get tabSocial;

  /// No description provided for @tabSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get tabSettings;

  /// No description provided for @homeGreetingDawn.
  ///
  /// In ko, this message translates to:
  /// **'고요한 새벽이에요'**
  String get homeGreetingDawn;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In ko, this message translates to:
  /// **'좋은 아침이에요'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In ko, this message translates to:
  /// **'기분좋은 오후예요'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In ko, this message translates to:
  /// **'저녁이 찾아왔어요'**
  String get homeGreetingEvening;

  /// No description provided for @homeGreetingNight.
  ///
  /// In ko, this message translates to:
  /// **'깊은 밤이에요'**
  String get homeGreetingNight;

  /// No description provided for @homeToday.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get homeToday;

  /// No description provided for @homeTodayEmpty.
  ///
  /// In ko, this message translates to:
  /// **'오늘은 예정된 일정도, 할 일도 없어요'**
  String get homeTodayEmpty;

  /// No description provided for @homeUpcoming.
  ///
  /// In ko, this message translates to:
  /// **'다가오는 일정'**
  String get homeUpcoming;

  /// No description provided for @homeUpcomingEmpty.
  ///
  /// In ko, this message translates to:
  /// **'예정된 일정이 없어요'**
  String get homeUpcomingEmpty;

  /// No description provided for @homeTodayTodos.
  ///
  /// In ko, this message translates to:
  /// **'오늘의 할 일'**
  String get homeTodayTodos;

  /// No description provided for @homeTodosDone.
  ///
  /// In ko, this message translates to:
  /// **'{done}/{total} 완료'**
  String homeTodosDone(int done, int total);

  /// No description provided for @homeNoTodos.
  ///
  /// In ko, this message translates to:
  /// **'오늘 등록된 할 일이 없어요'**
  String get homeNoTodos;

  /// No description provided for @homeTodosOverdue.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 기한 지남'**
  String homeTodosOverdue(int count);

  /// No description provided for @homeNowLabel.
  ///
  /// In ko, this message translates to:
  /// **'지금'**
  String get homeNowLabel;

  /// No description provided for @homeTodosViewAll.
  ///
  /// In ko, this message translates to:
  /// **'할 일 전체 보기'**
  String get homeTodosViewAll;

  /// No description provided for @homeWeekTitle.
  ///
  /// In ko, this message translates to:
  /// **'이번 주'**
  String get homeWeekTitle;

  /// No description provided for @homeWeekSummary.
  ///
  /// In ko, this message translates to:
  /// **'일정 {events}개 · 할 일 {done}/{total} 완료'**
  String homeWeekSummary(int events, int done, int total);

  /// No description provided for @homeWeekEmpty.
  ///
  /// In ko, this message translates to:
  /// **'이번 주는 아직 조용하네요'**
  String get homeWeekEmpty;

  /// No description provided for @scheduleTitle.
  ///
  /// In ko, this message translates to:
  /// **'시간표'**
  String get scheduleTitle;

  /// No description provided for @viewDay.
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get viewDay;

  /// No description provided for @viewWeek.
  ///
  /// In ko, this message translates to:
  /// **'주'**
  String get viewWeek;

  /// No description provided for @viewMonth.
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get viewMonth;

  /// No description provided for @viewYear.
  ///
  /// In ko, this message translates to:
  /// **'년'**
  String get viewYear;

  /// No description provided for @viewAgenda.
  ///
  /// In ko, this message translates to:
  /// **'목록'**
  String get viewAgenda;

  /// No description provided for @dayLayoutSwitchToClock.
  ///
  /// In ko, this message translates to:
  /// **'원형 시계 보기'**
  String get dayLayoutSwitchToClock;

  /// No description provided for @dayLayoutSwitchToTimeline.
  ///
  /// In ko, this message translates to:
  /// **'타임라인 보기'**
  String get dayLayoutSwitchToTimeline;

  /// No description provided for @calendarLegendTooltip.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 점 색상 안내'**
  String get calendarLegendTooltip;

  /// No description provided for @calendarLegendTitle.
  ///
  /// In ko, this message translates to:
  /// **'점 색상이 뭘 뜻하나요?'**
  String get calendarLegendTitle;

  /// No description provided for @calendarLegendOverdueTodo.
  ///
  /// In ko, this message translates to:
  /// **'기한이 지난 할 일이 있어요'**
  String get calendarLegendOverdueTodo;

  /// No description provided for @calendarLegendTodo.
  ///
  /// In ko, this message translates to:
  /// **'끝내지 않은 할 일이 있어요'**
  String get calendarLegendTodo;

  /// No description provided for @calendarLegendEvent.
  ///
  /// In ko, this message translates to:
  /// **'일정이 있어요'**
  String get calendarLegendEvent;

  /// No description provided for @calendarLegendMultiDayBarNote.
  ///
  /// In ko, this message translates to:
  /// **'여러 날에 걸친 일정의 색 막대는 이 규칙과 달라요 — 직접 고른 일정 색이 그대로 표시돼요.'**
  String get calendarLegendMultiDayBarNote;

  /// No description provided for @monthSplitHandleLabel.
  ///
  /// In ko, this message translates to:
  /// **'달력 크기 조절'**
  String get monthSplitHandleLabel;

  /// No description provided for @dayEmpty.
  ///
  /// In ko, this message translates to:
  /// **'이 날은 아직 비어 있어요'**
  String get dayEmpty;

  /// No description provided for @dayAddHint.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽 아래 + 로 일정을 더해보세요'**
  String get dayAddHint;

  /// No description provided for @agendaEmpty.
  ///
  /// In ko, this message translates to:
  /// **'예정된 일정이 없어요'**
  String get agendaEmpty;

  /// No description provided for @commonTomorrow.
  ///
  /// In ko, this message translates to:
  /// **'내일'**
  String get commonTomorrow;

  /// No description provided for @todosSectionTitle.
  ///
  /// In ko, this message translates to:
  /// **'할 일'**
  String get todosSectionTitle;

  /// No description provided for @searchTooltip.
  ///
  /// In ko, this message translates to:
  /// **'검색'**
  String get searchTooltip;

  /// No description provided for @quickAddEventTitle.
  ///
  /// In ko, this message translates to:
  /// **'빠른 추가'**
  String get quickAddEventTitle;

  /// No description provided for @quickAddEventHint.
  ///
  /// In ko, this message translates to:
  /// **'날짜와 시간을 자동으로 알아들어요'**
  String get quickAddEventHint;

  /// No description provided for @quickAddEventExample.
  ///
  /// In ko, this message translates to:
  /// **'내일 오후 3시 회의'**
  String get quickAddEventExample;

  /// No description provided for @quickAddEventCreated.
  ///
  /// In ko, this message translates to:
  /// **'\"{title}\" · {day} {time}에 추가했어요'**
  String quickAddEventCreated(String title, String day, String time);

  /// No description provided for @searchHint.
  ///
  /// In ko, this message translates to:
  /// **'제목이나 메모로 검색'**
  String get searchHint;

  /// No description provided for @searchEmpty.
  ///
  /// In ko, this message translates to:
  /// **'검색 결과가 없어요'**
  String get searchEmpty;

  /// No description provided for @searchPrompt.
  ///
  /// In ko, this message translates to:
  /// **'제목이나 메모를 입력해보세요'**
  String get searchPrompt;

  /// No description provided for @searchSectionEvents.
  ///
  /// In ko, this message translates to:
  /// **'일정'**
  String get searchSectionEvents;

  /// No description provided for @searchSectionTodos.
  ///
  /// In ko, this message translates to:
  /// **'할 일'**
  String get searchSectionTodos;

  /// No description provided for @searchFilterAll.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get searchFilterAll;

  /// No description provided for @searchFilterTagLabel.
  ///
  /// In ko, this message translates to:
  /// **'태그'**
  String get searchFilterTagLabel;

  /// No description provided for @searchFilterDateRangePick.
  ///
  /// In ko, this message translates to:
  /// **'기간 선택'**
  String get searchFilterDateRangePick;

  /// No description provided for @searchFilterDateRangeClear.
  ///
  /// In ko, this message translates to:
  /// **'기간 필터 지우기'**
  String get searchFilterDateRangeClear;

  /// No description provided for @socialTitle.
  ///
  /// In ko, this message translates to:
  /// **'소셜'**
  String get socialTitle;

  /// No description provided for @socialComingSoonTitle.
  ///
  /// In ko, this message translates to:
  /// **'곧 만나요'**
  String get socialComingSoonTitle;

  /// No description provided for @socialComingSoonBody.
  ///
  /// In ko, this message translates to:
  /// **'친구를 추가하고 일정을 나누는 기능을 준비하고 있어요. 지금은 나만의 시간에 집중해보세요.'**
  String get socialComingSoonBody;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @settingsNotifications.
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationSound.
  ///
  /// In ko, this message translates to:
  /// **'알림 소리'**
  String get settingsNotificationSound;

  /// No description provided for @settingsNotificationSoundDesc.
  ///
  /// In ko, this message translates to:
  /// **'일정이 시작될 때 소리로 알려드려요'**
  String get settingsNotificationSoundDesc;

  /// No description provided for @settingsExactAlarm.
  ///
  /// In ko, this message translates to:
  /// **'정확한 시각 알림'**
  String get settingsExactAlarm;

  /// No description provided for @settingsExactAlarmDesc.
  ///
  /// In ko, this message translates to:
  /// **'정시에 정확히 알리려면 권한이 필요해요'**
  String get settingsExactAlarmDesc;

  /// No description provided for @settingsCalendar.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 연동'**
  String get settingsCalendar;

  /// No description provided for @settingsCalendarSync.
  ///
  /// In ko, this message translates to:
  /// **'기기 캘린더와 동기화'**
  String get settingsCalendarSync;

  /// No description provided for @settingsCalendarSyncDesc.
  ///
  /// In ko, this message translates to:
  /// **'PlanFit 일정을 기기 캘린더에 함께 담아요'**
  String get settingsCalendarSyncDesc;

  /// No description provided for @settingsCalendarAutoImport.
  ///
  /// In ko, this message translates to:
  /// **'기기 캘린더 자동 불러오기'**
  String get settingsCalendarAutoImport;

  /// No description provided for @settingsCalendarAutoImportDesc.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 앱에서 직접 추가한 일정도 PlanFit으로 가져와요'**
  String get settingsCalendarAutoImportDesc;

  /// No description provided for @settingsSyncLog.
  ///
  /// In ko, this message translates to:
  /// **'동기화 기록'**
  String get settingsSyncLog;

  /// No description provided for @settingsLastSync.
  ///
  /// In ko, this message translates to:
  /// **'마지막 동기화'**
  String get settingsLastSync;

  /// No description provided for @settingsLastSyncNever.
  ///
  /// In ko, this message translates to:
  /// **'아직 동기화한 적 없어요'**
  String get settingsLastSyncNever;

  /// No description provided for @settingsCalendarTarget.
  ///
  /// In ko, this message translates to:
  /// **'동기화 캘린더'**
  String get settingsCalendarTarget;

  /// No description provided for @settingsCalendarTargetAuto.
  ///
  /// In ko, this message translates to:
  /// **'자동'**
  String get settingsCalendarTargetAuto;

  /// No description provided for @settingsCalendarTargetDisabledHint.
  ///
  /// In ko, this message translates to:
  /// **'동기화를 켜면 선택할 수 있어요'**
  String get settingsCalendarTargetDisabledHint;

  /// No description provided for @settingsCalendarTargetEmpty.
  ///
  /// In ko, this message translates to:
  /// **'선택할 수 있는 캘린더가 없어요'**
  String get settingsCalendarTargetEmpty;

  /// No description provided for @settingsCalendarImport.
  ///
  /// In ko, this message translates to:
  /// **'다른 캘린더에서 가져오기'**
  String get settingsCalendarImport;

  /// No description provided for @settingsCalendarImportDesc.
  ///
  /// In ko, this message translates to:
  /// **'기존 캘린더에서 가져오거나 계속 구독해요'**
  String get settingsCalendarImportDesc;

  /// No description provided for @settingsHolidayCalendar.
  ///
  /// In ko, this message translates to:
  /// **'공휴일 표시'**
  String get settingsHolidayCalendar;

  /// No description provided for @settingsHolidayCalendarDesc.
  ///
  /// In ko, this message translates to:
  /// **'국가별 공휴일 캘린더를 자동으로 불러와요'**
  String get settingsHolidayCalendarDesc;

  /// No description provided for @settingsHolidaySourceCurrent.
  ///
  /// In ko, this message translates to:
  /// **'현재: {source}'**
  String settingsHolidaySourceCurrent(String source);

  /// No description provided for @settingsHolidaySourceCustomLabel.
  ///
  /// In ko, this message translates to:
  /// **'사용자 지정 캘린더'**
  String get settingsHolidaySourceCustomLabel;

  /// No description provided for @settingsHolidaySourceEmpty.
  ///
  /// In ko, this message translates to:
  /// **'선택 안 함'**
  String get settingsHolidaySourceEmpty;

  /// No description provided for @settingsHolidaySourceMore.
  ///
  /// In ko, this message translates to:
  /// **'{first} 외 {count}곳'**
  String settingsHolidaySourceMore(String first, int count);

  /// No description provided for @holidayCountryKR.
  ///
  /// In ko, this message translates to:
  /// **'대한민국'**
  String get holidayCountryKR;

  /// No description provided for @holidayCountryUS.
  ///
  /// In ko, this message translates to:
  /// **'미국'**
  String get holidayCountryUS;

  /// No description provided for @holidayCountryJP.
  ///
  /// In ko, this message translates to:
  /// **'일본'**
  String get holidayCountryJP;

  /// No description provided for @holidayCountryGB.
  ///
  /// In ko, this message translates to:
  /// **'영국'**
  String get holidayCountryGB;

  /// No description provided for @holidayCountryDE.
  ///
  /// In ko, this message translates to:
  /// **'독일'**
  String get holidayCountryDE;

  /// No description provided for @holidayCountryFR.
  ///
  /// In ko, this message translates to:
  /// **'프랑스'**
  String get holidayCountryFR;

  /// No description provided for @holidayCountryCA.
  ///
  /// In ko, this message translates to:
  /// **'캐나다'**
  String get holidayCountryCA;

  /// No description provided for @holidayCountryAU.
  ///
  /// In ko, this message translates to:
  /// **'호주'**
  String get holidayCountryAU;

  /// No description provided for @holidayCalendarSourceTitle.
  ///
  /// In ko, this message translates to:
  /// **'공휴일 캘린더 선택'**
  String get holidayCalendarSourceTitle;

  /// No description provided for @holidayCalendarSourceSectionCountries.
  ///
  /// In ko, this message translates to:
  /// **'국가 선택'**
  String get holidayCalendarSourceSectionCountries;

  /// No description provided for @holidayCalendarSourceCustomEntry.
  ///
  /// In ko, this message translates to:
  /// **'URL로 직접 추가'**
  String get holidayCalendarSourceCustomEntry;

  /// No description provided for @holidayCalendarSourceRemoveCustomUrl.
  ///
  /// In ko, this message translates to:
  /// **'제거'**
  String get holidayCalendarSourceRemoveCustomUrl;

  /// No description provided for @holidayCalendarSourceCustomDialogTitle.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 URL 입력'**
  String get holidayCalendarSourceCustomDialogTitle;

  /// No description provided for @holidayCalendarSourceCustomDialogHint.
  ///
  /// In ko, this message translates to:
  /// **'https://example.com/calendar.ics'**
  String get holidayCalendarSourceCustomDialogHint;

  /// No description provided for @holidayCalendarSourceCustomInvalidUrl.
  ///
  /// In ko, this message translates to:
  /// **'올바른 http/https 링크를 입력해주세요'**
  String get holidayCalendarSourceCustomInvalidUrl;

  /// No description provided for @holidayCalendarSourceSyncFailed.
  ///
  /// In ko, this message translates to:
  /// **'캘린더를 불러오지 못했어요. 링크를 확인해주세요'**
  String get holidayCalendarSourceSyncFailed;

  /// No description provided for @holidayCalendarSourceSyncFailedGeneric.
  ///
  /// In ko, this message translates to:
  /// **'공휴일 캘린더를 불러오지 못했어요'**
  String get holidayCalendarSourceSyncFailedGeneric;

  /// No description provided for @holidayCalendarSourceColorTooltip.
  ///
  /// In ko, this message translates to:
  /// **'표시 색상 변경'**
  String get holidayCalendarSourceColorTooltip;

  /// No description provided for @holidayCalendarSourceColorTitle.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 색상 선택'**
  String get holidayCalendarSourceColorTitle;

  /// No description provided for @holidayCalendarSourceColorDefault.
  ///
  /// In ko, this message translates to:
  /// **'기본값'**
  String get holidayCalendarSourceColorDefault;

  /// No description provided for @calendarImportTitle.
  ///
  /// In ko, this message translates to:
  /// **'가져오기 · 구독할 캘린더'**
  String get calendarImportTitle;

  /// No description provided for @calendarImportEmpty.
  ///
  /// In ko, this message translates to:
  /// **'가져올 수 있는 캘린더가 없어요'**
  String get calendarImportEmpty;

  /// No description provided for @calendarImportConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'{calendarName}에서 가져올까요?'**
  String calendarImportConfirmTitle(String calendarName);

  /// No description provided for @calendarImportConfirmBody.
  ///
  /// In ko, this message translates to:
  /// **'최근 30일부터 앞으로 1년까지의 일정을 PlanFit에 복사해요. 알림은 꺼진 채로 들어오고, 나중에 다시 가져오면 겹치는 항목은 갱신돼요.'**
  String get calendarImportConfirmBody;

  /// No description provided for @calendarImportConfirmAction.
  ///
  /// In ko, this message translates to:
  /// **'가져오기'**
  String get calendarImportConfirmAction;

  /// No description provided for @calendarImportInProgress.
  ///
  /// In ko, this message translates to:
  /// **'가져오는 중이에요…'**
  String get calendarImportInProgress;

  /// No description provided for @calendarImportSuccess.
  ///
  /// In ko, this message translates to:
  /// **'{count}개의 일정을 가져왔어요'**
  String calendarImportSuccess(int count);

  /// No description provided for @calendarImportFailed.
  ///
  /// In ko, this message translates to:
  /// **'가져오기에 실패했어요'**
  String get calendarImportFailed;

  /// No description provided for @calendarImportSubscribedHint.
  ///
  /// In ko, this message translates to:
  /// **'구독 중 — 계속 최신 상태로 유지돼요'**
  String get calendarImportSubscribedHint;

  /// No description provided for @calendarImportMirroredReadOnlyNote.
  ///
  /// In ko, this message translates to:
  /// **'구독한 캘린더에서 가져온 일정이라 PlanFit에서는 읽기 전용이에요. 수정하려면 원본 캘린더 앱에서 바꿔주세요.'**
  String get calendarImportMirroredReadOnlyNote;

  /// No description provided for @holidayEventBadge.
  ///
  /// In ko, this message translates to:
  /// **'공휴일'**
  String get holidayEventBadge;

  /// No description provided for @holidayEventReadOnlyNote.
  ///
  /// In ko, this message translates to:
  /// **'믿을 수 있는 캘린더에서 자동으로 불러온 공휴일이라 PlanFit에서는 읽기 전용이에요.'**
  String get holidayEventReadOnlyNote;

  /// No description provided for @settingsPermissionGranted.
  ///
  /// In ko, this message translates to:
  /// **'허용됨'**
  String get settingsPermissionGranted;

  /// No description provided for @settingsPermissionDenied.
  ///
  /// In ko, this message translates to:
  /// **'허용 안 됨'**
  String get settingsPermissionDenied;

  /// No description provided for @settingsPermissionDeniedMessage.
  ///
  /// In ko, this message translates to:
  /// **'권한이 거부되어 있어요. 기기 설정에서 허용해 주세요.'**
  String get settingsPermissionDeniedMessage;

  /// No description provided for @settingsOpenAppSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 열기'**
  String get settingsOpenAppSettings;

  /// No description provided for @settingsGrant.
  ///
  /// In ko, this message translates to:
  /// **'허용하기'**
  String get settingsGrant;

  /// No description provided for @settingsAppearance.
  ///
  /// In ko, this message translates to:
  /// **'화면'**
  String get settingsAppearance;

  /// No description provided for @settingsWeekStart.
  ///
  /// In ko, this message translates to:
  /// **'주 시작 요일'**
  String get settingsWeekStart;

  /// No description provided for @settingsWeekStartMonday.
  ///
  /// In ko, this message translates to:
  /// **'월요일'**
  String get settingsWeekStartMonday;

  /// No description provided for @settingsWeekStartSunday.
  ///
  /// In ko, this message translates to:
  /// **'일요일'**
  String get settingsWeekStartSunday;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ko, this message translates to:
  /// **'밝게'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ko, this message translates to:
  /// **'어둡게'**
  String get settingsThemeDark;

  /// No description provided for @settingsTimeFormatDisplay.
  ///
  /// In ko, this message translates to:
  /// **'일정/할 일 시간 표시'**
  String get settingsTimeFormatDisplay;

  /// No description provided for @settingsTimeFormatDial.
  ///
  /// In ko, this message translates to:
  /// **'시간 선택 다이얼'**
  String get settingsTimeFormatDial;

  /// No description provided for @settingsTimeFormatSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정'**
  String get settingsTimeFormatSystem;

  /// No description provided for @settingsTimeFormatH12.
  ///
  /// In ko, this message translates to:
  /// **'12시간제'**
  String get settingsTimeFormatH12;

  /// No description provided for @settingsTimeFormatH24.
  ///
  /// In ko, this message translates to:
  /// **'24시간제'**
  String get settingsTimeFormatH24;

  /// No description provided for @settingsTodo.
  ///
  /// In ko, this message translates to:
  /// **'할 일'**
  String get settingsTodo;

  /// No description provided for @settingsReminderSync.
  ///
  /// In ko, this message translates to:
  /// **'기기 미리알림과 동기화'**
  String get settingsReminderSync;

  /// No description provided for @settingsReminderSyncDesc.
  ///
  /// In ko, this message translates to:
  /// **'PlanFit 할 일을 기기 미리알림에 함께 담아요'**
  String get settingsReminderSyncDesc;

  /// No description provided for @settingsTodoRetention.
  ///
  /// In ko, this message translates to:
  /// **'완료된 할 일 자동 정리'**
  String get settingsTodoRetention;

  /// No description provided for @settingsTodoRetentionDesc.
  ///
  /// In ko, this message translates to:
  /// **'완료한 지 일정 기간이 지난 할 일을 자동으로 삭제해요'**
  String get settingsTodoRetentionDesc;

  /// No description provided for @settingsTodoRetentionOff.
  ///
  /// In ko, this message translates to:
  /// **'사용 안 함'**
  String get settingsTodoRetentionOff;

  /// No description provided for @settingsTodoRetentionDays.
  ///
  /// In ko, this message translates to:
  /// **'{days}일 후'**
  String settingsTodoRetentionDays(int days);

  /// No description provided for @settingsAbout.
  ///
  /// In ko, this message translates to:
  /// **'정보'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In ko, this message translates to:
  /// **'버전'**
  String get settingsVersion;

  /// No description provided for @settingsData.
  ///
  /// In ko, this message translates to:
  /// **'데이터'**
  String get settingsData;

  /// No description provided for @settingsExport.
  ///
  /// In ko, this message translates to:
  /// **'내보내기'**
  String get settingsExport;

  /// No description provided for @settingsExportDesc.
  ///
  /// In ko, this message translates to:
  /// **'모든 일정과 할 일을 파일 하나로 저장해요'**
  String get settingsExportDesc;

  /// No description provided for @settingsImport.
  ///
  /// In ko, this message translates to:
  /// **'가져오기'**
  String get settingsImport;

  /// No description provided for @settingsImportDesc.
  ///
  /// In ko, this message translates to:
  /// **'내보낸 파일에서 일정과 할 일을 복원해요'**
  String get settingsImportDesc;

  /// No description provided for @settingsExportIcs.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 파일로 내보내기'**
  String get settingsExportIcs;

  /// No description provided for @settingsExportIcsDesc.
  ///
  /// In ko, this message translates to:
  /// **'다른 캘린더 앱에서 열 수 있는 표준 파일(.ics)이에요'**
  String get settingsExportIcsDesc;

  /// No description provided for @settingsImportIcs.
  ///
  /// In ko, this message translates to:
  /// **'캘린더 파일 가져오기'**
  String get settingsImportIcs;

  /// No description provided for @settingsImportIcsDesc.
  ///
  /// In ko, this message translates to:
  /// **'다른 캘린더 앱에서 내보낸 .ics 파일을 새 일정으로 추가해요'**
  String get settingsImportIcsDesc;

  /// No description provided for @icsImportSuccess.
  ///
  /// In ko, this message translates to:
  /// **'{count}개의 일정을 가져왔어요'**
  String icsImportSuccess(int count);

  /// No description provided for @icsImportSkipped.
  ///
  /// In ko, this message translates to:
  /// **'{count}개는 형식을 알 수 없어 건너뛰었어요'**
  String icsImportSkipped(int count);

  /// No description provided for @icsImportFailed.
  ///
  /// In ko, this message translates to:
  /// **'가져오기에 실패했어요'**
  String get icsImportFailed;

  /// No description provided for @settingsAutoBackup.
  ///
  /// In ko, this message translates to:
  /// **'자동 백업 기록'**
  String get settingsAutoBackup;

  /// No description provided for @autoBackupTitle.
  ///
  /// In ko, this message translates to:
  /// **'자동 백업'**
  String get autoBackupTitle;

  /// No description provided for @autoBackupEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 자동 백업이 없어요'**
  String get autoBackupEmpty;

  /// No description provided for @autoBackupDesc.
  ///
  /// In ko, this message translates to:
  /// **'24시간마다 자동으로 백업하고, 최근 7개만 보관해요'**
  String get autoBackupDesc;

  /// No description provided for @autoBackupRestore.
  ///
  /// In ko, this message translates to:
  /// **'이 백업으로 복원'**
  String get autoBackupRestore;

  /// No description provided for @autoBackupRestoreConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 백업으로 복원할까요?'**
  String get autoBackupRestoreConfirmTitle;

  /// No description provided for @autoBackupRestoreConfirmBody.
  ///
  /// In ko, this message translates to:
  /// **'지금 있는 일정/할 일에 이 백업 내용이 합쳐져요. 같은 항목은 백업 시점 내용으로 덮어써요.'**
  String get autoBackupRestoreConfirmBody;

  /// No description provided for @backupExportFailed.
  ///
  /// In ko, this message translates to:
  /// **'내보내기에 실패했어요'**
  String get backupExportFailed;

  /// No description provided for @backupImportSuccess.
  ///
  /// In ko, this message translates to:
  /// **'일정 {events}개, 할 일 {todos}개를 가져왔어요'**
  String backupImportSuccess(int events, int todos);

  /// No description provided for @backupImportFailed.
  ///
  /// In ko, this message translates to:
  /// **'가져오기에 실패했어요. 파일 형식을 확인해주세요'**
  String get backupImportFailed;

  /// No description provided for @eventNew.
  ///
  /// In ko, this message translates to:
  /// **'새 일정'**
  String get eventNew;

  /// No description provided for @eventEdit.
  ///
  /// In ko, this message translates to:
  /// **'일정 편집'**
  String get eventEdit;

  /// No description provided for @eventDuplicate.
  ///
  /// In ko, this message translates to:
  /// **'일정 복제'**
  String get eventDuplicate;

  /// No description provided for @eventShare.
  ///
  /// In ko, this message translates to:
  /// **'일정 공유'**
  String get eventShare;

  /// No description provided for @eventShareFailed.
  ///
  /// In ko, this message translates to:
  /// **'공유에 실패했어요'**
  String get eventShareFailed;

  /// No description provided for @eventTemplates.
  ///
  /// In ko, this message translates to:
  /// **'템플릿'**
  String get eventTemplates;

  /// No description provided for @templatesTitle.
  ///
  /// In ko, this message translates to:
  /// **'자주 쓰는 일정'**
  String get templatesTitle;

  /// No description provided for @templatesEmpty.
  ///
  /// In ko, this message translates to:
  /// **'저장된 템플릿이 없어요'**
  String get templatesEmpty;

  /// No description provided for @templatesSaveCurrent.
  ///
  /// In ko, this message translates to:
  /// **'현재 내용을 템플릿으로 저장'**
  String get templatesSaveCurrent;

  /// No description provided for @templatesNameHint.
  ///
  /// In ko, this message translates to:
  /// **'템플릿 이름 (예: 헬스)'**
  String get templatesNameHint;

  /// No description provided for @templatesNameRequired.
  ///
  /// In ko, this message translates to:
  /// **'템플릿 이름을 입력해주세요'**
  String get templatesNameRequired;

  /// No description provided for @templatesSaved.
  ///
  /// In ko, this message translates to:
  /// **'템플릿을 저장했어요'**
  String get templatesSaved;

  /// No description provided for @templatesDeleted.
  ///
  /// In ko, this message translates to:
  /// **'템플릿을 삭제했어요'**
  String get templatesDeleted;

  /// No description provided for @eventTitle.
  ///
  /// In ko, this message translates to:
  /// **'제목'**
  String get eventTitle;

  /// No description provided for @eventTitleHint.
  ///
  /// In ko, this message translates to:
  /// **'무엇을 하나요?'**
  String get eventTitleHint;

  /// No description provided for @eventMemo.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get eventMemo;

  /// No description provided for @eventMemoHint.
  ///
  /// In ko, this message translates to:
  /// **'메모를 남겨보세요'**
  String get eventMemoHint;

  /// No description provided for @eventLocation.
  ///
  /// In ko, this message translates to:
  /// **'장소'**
  String get eventLocation;

  /// No description provided for @eventLocationHint.
  ///
  /// In ko, this message translates to:
  /// **'장소를 입력해보세요'**
  String get eventLocationHint;

  /// No description provided for @eventOpenInMaps.
  ///
  /// In ko, this message translates to:
  /// **'지도에서 열기'**
  String get eventOpenInMaps;

  /// No description provided for @eventOpenInMapsFailed.
  ///
  /// In ko, this message translates to:
  /// **'지도를 열지 못했어요'**
  String get eventOpenInMapsFailed;

  /// No description provided for @eventAllDay.
  ///
  /// In ko, this message translates to:
  /// **'종일'**
  String get eventAllDay;

  /// No description provided for @eventStart.
  ///
  /// In ko, this message translates to:
  /// **'시작'**
  String get eventStart;

  /// No description provided for @eventEnd.
  ///
  /// In ko, this message translates to:
  /// **'종료'**
  String get eventEnd;

  /// No description provided for @eventNotify.
  ///
  /// In ko, this message translates to:
  /// **'시작할 때 알림'**
  String get eventNotify;

  /// No description provided for @eventReminderLead.
  ///
  /// In ko, this message translates to:
  /// **'알림 시점'**
  String get eventReminderLead;

  /// No description provided for @eventReminderAtStart.
  ///
  /// In ko, this message translates to:
  /// **'정시'**
  String get eventReminderAtStart;

  /// No description provided for @eventReminderMinutesBefore.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 전'**
  String eventReminderMinutesBefore(int minutes);

  /// No description provided for @eventReminderHoursBefore.
  ///
  /// In ko, this message translates to:
  /// **'{hours}시간 전'**
  String eventReminderHoursBefore(int hours);

  /// No description provided for @eventReminderDayBefore.
  ///
  /// In ko, this message translates to:
  /// **'하루 전'**
  String get eventReminderDayBefore;

  /// No description provided for @eventReminderAdditional.
  ///
  /// In ko, this message translates to:
  /// **'추가 알림 (여러 개 선택 가능)'**
  String get eventReminderAdditional;

  /// No description provided for @eventRepeat.
  ///
  /// In ko, this message translates to:
  /// **'반복'**
  String get eventRepeat;

  /// No description provided for @eventRepeatNone.
  ///
  /// In ko, this message translates to:
  /// **'안 함'**
  String get eventRepeatNone;

  /// No description provided for @eventRepeatDaily.
  ///
  /// In ko, this message translates to:
  /// **'매일'**
  String get eventRepeatDaily;

  /// No description provided for @eventRepeatWeekly.
  ///
  /// In ko, this message translates to:
  /// **'매주'**
  String get eventRepeatWeekly;

  /// No description provided for @eventRepeatMonthly.
  ///
  /// In ko, this message translates to:
  /// **'매월'**
  String get eventRepeatMonthly;

  /// No description provided for @eventRepeatYearly.
  ///
  /// In ko, this message translates to:
  /// **'매년'**
  String get eventRepeatYearly;

  /// No description provided for @eventRepeatUntil.
  ///
  /// In ko, this message translates to:
  /// **'종료일'**
  String get eventRepeatUntil;

  /// No description provided for @eventRepeatWeekdays.
  ///
  /// In ko, this message translates to:
  /// **'반복 요일'**
  String get eventRepeatWeekdays;

  /// No description provided for @eventRepeatEndLabel.
  ///
  /// In ko, this message translates to:
  /// **'종료 조건'**
  String get eventRepeatEndLabel;

  /// No description provided for @eventRepeatEndByDate.
  ///
  /// In ko, this message translates to:
  /// **'날짜까지'**
  String get eventRepeatEndByDate;

  /// No description provided for @eventRepeatEndByCount.
  ///
  /// In ko, this message translates to:
  /// **'횟수만큼'**
  String get eventRepeatEndByCount;

  /// No description provided for @eventRepeatCountTimes.
  ///
  /// In ko, this message translates to:
  /// **'{count}회'**
  String eventRepeatCountTimes(int count);

  /// No description provided for @eventRepeatCountDecrease.
  ///
  /// In ko, this message translates to:
  /// **'반복 횟수 줄이기'**
  String get eventRepeatCountDecrease;

  /// No description provided for @eventRepeatCountIncrease.
  ///
  /// In ko, this message translates to:
  /// **'반복 횟수 늘리기'**
  String get eventRepeatCountIncrease;

  /// No description provided for @eventDeleteSeriesTitle.
  ///
  /// In ko, this message translates to:
  /// **'반복 일정 삭제'**
  String get eventDeleteSeriesTitle;

  /// No description provided for @eventDeleteSeriesBody.
  ///
  /// In ko, this message translates to:
  /// **'이 일정은 반복 일정의 일부예요. 어떻게 삭제할까요?'**
  String get eventDeleteSeriesBody;

  /// No description provided for @eventDeleteThisOnly.
  ///
  /// In ko, this message translates to:
  /// **'이 일정만 삭제'**
  String get eventDeleteThisOnly;

  /// No description provided for @eventDeleteThisAndFuture.
  ///
  /// In ko, this message translates to:
  /// **'이후 모든 반복 삭제'**
  String get eventDeleteThisAndFuture;

  /// No description provided for @eventSaveSeriesTitle.
  ///
  /// In ko, this message translates to:
  /// **'반복 일정 저장'**
  String get eventSaveSeriesTitle;

  /// No description provided for @eventSaveSeriesBody.
  ///
  /// In ko, this message translates to:
  /// **'이 일정은 반복 일정의 일부예요. 변경 사항을 어떻게 적용할까요?'**
  String get eventSaveSeriesBody;

  /// No description provided for @eventSaveThisOnly.
  ///
  /// In ko, this message translates to:
  /// **'이 일정만 저장'**
  String get eventSaveThisOnly;

  /// No description provided for @eventSaveThisAndFuture.
  ///
  /// In ko, this message translates to:
  /// **'이후 모든 반복에 적용'**
  String get eventSaveThisAndFuture;

  /// No description provided for @eventColor.
  ///
  /// In ko, this message translates to:
  /// **'색상'**
  String get eventColor;

  /// No description provided for @eventColorAuto.
  ///
  /// In ko, this message translates to:
  /// **'자동'**
  String get eventColorAuto;

  /// No description provided for @eventColorCustom.
  ///
  /// In ko, this message translates to:
  /// **'직접 선택'**
  String get eventColorCustom;

  /// No description provided for @eventColorPickerTitle.
  ///
  /// In ko, this message translates to:
  /// **'색상 선택'**
  String get eventColorPickerTitle;

  /// No description provided for @eventSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get eventSave;

  /// No description provided for @eventDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get eventDelete;

  /// No description provided for @eventDeleted.
  ///
  /// In ko, this message translates to:
  /// **'일정을 삭제했어요'**
  String get eventDeleted;

  /// No description provided for @eventUndo.
  ///
  /// In ko, this message translates to:
  /// **'실행 취소'**
  String get eventUndo;

  /// No description provided for @eventSelectionCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 선택됨'**
  String eventSelectionCount(int count);

  /// No description provided for @eventSelectionDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get eventSelectionDelete;

  /// No description provided for @eventSelectionDeleted.
  ///
  /// In ko, this message translates to:
  /// **'{count}개를 삭제했어요'**
  String eventSelectionDeleted(int count);

  /// No description provided for @eventTitleRequired.
  ///
  /// In ko, this message translates to:
  /// **'제목을 입력해주세요'**
  String get eventTitleRequired;

  /// No description provided for @eventRecurrenceTruncated.
  ///
  /// In ko, this message translates to:
  /// **'반복 횟수가 많아 최대 200회까지만 생성했어요'**
  String get eventRecurrenceTruncated;

  /// No description provided for @todoAdd.
  ///
  /// In ko, this message translates to:
  /// **'할 일 추가'**
  String get todoAdd;

  /// No description provided for @todoHint.
  ///
  /// In ko, this message translates to:
  /// **'할 일을 입력하세요'**
  String get todoHint;

  /// No description provided for @todoRepeat.
  ///
  /// In ko, this message translates to:
  /// **'반복'**
  String get todoRepeat;

  /// No description provided for @todoNoTime.
  ///
  /// In ko, this message translates to:
  /// **'시간 없음'**
  String get todoNoTime;

  /// No description provided for @todoRepeatIndicator.
  ///
  /// In ko, this message translates to:
  /// **'반복되는 할 일'**
  String get todoRepeatIndicator;

  /// No description provided for @todoDragHandle.
  ///
  /// In ko, this message translates to:
  /// **'순서 변경'**
  String get todoDragHandle;

  /// No description provided for @todoDeleteSeriesTitle.
  ///
  /// In ko, this message translates to:
  /// **'반복 할 일 삭제'**
  String get todoDeleteSeriesTitle;

  /// No description provided for @todoDeleteSeriesBody.
  ///
  /// In ko, this message translates to:
  /// **'이 항목은 반복되는 할 일의 일부예요. 어떻게 삭제할까요?'**
  String get todoDeleteSeriesBody;

  /// No description provided for @todoDeleteThisOnly.
  ///
  /// In ko, this message translates to:
  /// **'이 항목만 삭제'**
  String get todoDeleteThisOnly;

  /// No description provided for @todoDeleteThisAndFuture.
  ///
  /// In ko, this message translates to:
  /// **'이후 모든 반복 삭제'**
  String get todoDeleteThisAndFuture;

  /// No description provided for @todoDeleted.
  ///
  /// In ko, this message translates to:
  /// **'할 일을 삭제했어요'**
  String get todoDeleted;

  /// No description provided for @todoQuickAddAddedToOtherDay.
  ///
  /// In ko, this message translates to:
  /// **'{day}에 추가했어요'**
  String todoQuickAddAddedToOtherDay(String day);

  /// No description provided for @todoSelectionCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 선택됨'**
  String todoSelectionCount(int count);

  /// No description provided for @todoSelectionComplete.
  ///
  /// In ko, this message translates to:
  /// **'완료 처리'**
  String get todoSelectionComplete;

  /// No description provided for @todoMarkDone.
  ///
  /// In ko, this message translates to:
  /// **'완료 여부'**
  String get todoMarkDone;

  /// No description provided for @todoSelectItem.
  ///
  /// In ko, this message translates to:
  /// **'선택'**
  String get todoSelectItem;

  /// No description provided for @todoSelectionDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get todoSelectionDelete;

  /// No description provided for @todoSelectionDeleted.
  ///
  /// In ko, this message translates to:
  /// **'{count}개를 삭제했어요'**
  String todoSelectionDeleted(int count);

  /// No description provided for @todoEditTitle.
  ///
  /// In ko, this message translates to:
  /// **'할 일 편집'**
  String get todoEditTitle;

  /// No description provided for @todoTitleLabel.
  ///
  /// In ko, this message translates to:
  /// **'제목'**
  String get todoTitleLabel;

  /// No description provided for @todoReminderAdditional.
  ///
  /// In ko, this message translates to:
  /// **'추가 알림 (여러 개 선택 가능)'**
  String get todoReminderAdditional;

  /// No description provided for @todoPriorityLabel.
  ///
  /// In ko, this message translates to:
  /// **'우선순위'**
  String get todoPriorityLabel;

  /// No description provided for @todoPriorityNone.
  ///
  /// In ko, this message translates to:
  /// **'없음'**
  String get todoPriorityNone;

  /// No description provided for @todoPriorityLow.
  ///
  /// In ko, this message translates to:
  /// **'낮음'**
  String get todoPriorityLow;

  /// No description provided for @todoPriorityMedium.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get todoPriorityMedium;

  /// No description provided for @todoPriorityHigh.
  ///
  /// In ko, this message translates to:
  /// **'높음'**
  String get todoPriorityHigh;

  /// No description provided for @todoTagsLabel.
  ///
  /// In ko, this message translates to:
  /// **'태그'**
  String get todoTagsLabel;

  /// No description provided for @todoTagsHint.
  ///
  /// In ko, this message translates to:
  /// **'쉼표로 구분해 입력 (예: 업무,급함)'**
  String get todoTagsHint;

  /// No description provided for @todoSubtasksLabel.
  ///
  /// In ko, this message translates to:
  /// **'하위 작업'**
  String get todoSubtasksLabel;

  /// No description provided for @todoSubtaskHint.
  ///
  /// In ko, this message translates to:
  /// **'하위 작업 추가'**
  String get todoSubtaskHint;

  /// No description provided for @todoSubtaskDelete.
  ///
  /// In ko, this message translates to:
  /// **'하위 작업 삭제'**
  String get todoSubtaskDelete;

  /// No description provided for @todoNotify.
  ///
  /// In ko, this message translates to:
  /// **'정해진 시간에 알림'**
  String get todoNotify;

  /// No description provided for @todoNotifyNoTimeHint.
  ///
  /// In ko, this message translates to:
  /// **'시간을 정해야 알림을 켤 수 있어요'**
  String get todoNotifyNoTimeHint;

  /// No description provided for @todoPin.
  ///
  /// In ko, this message translates to:
  /// **'고정'**
  String get todoPin;

  /// No description provided for @todoUnpin.
  ///
  /// In ko, this message translates to:
  /// **'고정 해제'**
  String get todoUnpin;

  /// No description provided for @todoPinned.
  ///
  /// In ko, this message translates to:
  /// **'고정됨'**
  String get todoPinned;

  /// No description provided for @smartListTitle.
  ///
  /// In ko, this message translates to:
  /// **'할 일 모아보기'**
  String get smartListTitle;

  /// No description provided for @smartListToday.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get smartListToday;

  /// No description provided for @smartListOverdue.
  ///
  /// In ko, this message translates to:
  /// **'기한 지남'**
  String get smartListOverdue;

  /// No description provided for @smartListHighPriority.
  ///
  /// In ko, this message translates to:
  /// **'우선순위 높음'**
  String get smartListHighPriority;

  /// No description provided for @smartListPinned.
  ///
  /// In ko, this message translates to:
  /// **'고정됨'**
  String get smartListPinned;

  /// No description provided for @smartListByTag.
  ///
  /// In ko, this message translates to:
  /// **'태그별'**
  String get smartListByTag;

  /// No description provided for @smartListEmptyToday.
  ///
  /// In ko, this message translates to:
  /// **'오늘 할 일이 없어요'**
  String get smartListEmptyToday;

  /// No description provided for @smartListEmptyOverdue.
  ///
  /// In ko, this message translates to:
  /// **'기한 지난 할 일이 없어요'**
  String get smartListEmptyOverdue;

  /// No description provided for @smartListEmptyHighPriority.
  ///
  /// In ko, this message translates to:
  /// **'우선순위 높은 할 일이 없어요'**
  String get smartListEmptyHighPriority;

  /// No description provided for @smartListEmptyPinned.
  ///
  /// In ko, this message translates to:
  /// **'고정된 할 일이 없어요'**
  String get smartListEmptyPinned;

  /// No description provided for @smartListEmptyByTag.
  ///
  /// In ko, this message translates to:
  /// **'이 태그의 할 일이 없어요'**
  String get smartListEmptyByTag;

  /// No description provided for @smartListNoTags.
  ///
  /// In ko, this message translates to:
  /// **'아직 등록된 태그가 없어요'**
  String get smartListNoTags;

  /// No description provided for @smartListPickTag.
  ///
  /// In ko, this message translates to:
  /// **'태그를 선택하세요'**
  String get smartListPickTag;

  /// No description provided for @commonCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get commonCancel;

  /// No description provided for @commonDone.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get commonDone;

  /// No description provided for @commonToday.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get commonToday;

  /// No description provided for @errorWidgetFallback.
  ///
  /// In ko, this message translates to:
  /// **'문제가 발생했어요'**
  String get errorWidgetFallback;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'ko':
      return AppL10nKo();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
