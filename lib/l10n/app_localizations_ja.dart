// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppL10nJa extends AppL10n {
  AppL10nJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'PlanFit';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingGetStarted => 'はじめる';

  @override
  String get onboardingPage1Title => '一日を、時間の流れとして';

  @override
  String get onboardingPage1Body => '夜明けから夜まで、一日の色が自然に流れるカレンダーです';

  @override
  String get onboardingPage2Title => '予定とやることを一箇所に';

  @override
  String get onboardingPage2Body => '日・月・年、どこからでも見られて、時間帯ごとのやることも一緒に管理できます';

  @override
  String get onboardingPage3Title => '見逃さないようお知らせします';

  @override
  String get onboardingPage3Body => '予定が始まる前、好きなタイミングで通知をお届けします';

  @override
  String get tabHome => 'ホーム';

  @override
  String get tabSchedule => 'スケジュール';

  @override
  String get tabSettings => '設定';

  @override
  String get homeGreetingDawn => '静かな夜明けです';

  @override
  String get homeGreetingMorning => 'おはようございます';

  @override
  String get homeGreetingAfternoon => '気持ちいい午後です';

  @override
  String get homeGreetingEvening => '夕方になりました';

  @override
  String get homeGreetingNight => '夜更けです';

  @override
  String get homeToday => '今日';

  @override
  String get homeTodayEmpty => '今日の予定もやることもありません';

  @override
  String get homeUpcoming => '次の予定';

  @override
  String get homeUpcomingEmpty => '予定はありません';

  @override
  String get homeTodayTodos => '今日のやること';

  @override
  String homeTodosDone(int done, int total) {
    return '$done/$total 完了';
  }

  @override
  String get homeNoTodos => '今日登録されたやることはありません';

  @override
  String homeTodosOverdue(int count) {
    return '$count件 期限切れ';
  }

  @override
  String get homeNowLabel => '今';

  @override
  String get homeTodosViewAll => 'やることをすべて見る';

  @override
  String get homeWeekTitle => '今週';

  @override
  String homeWeekSummary(int events, int done, int total) {
    return '予定 $events件 ・ やること $done/$total 完了';
  }

  @override
  String get homeWeekEmpty => '今週はまだ静かですね';

  @override
  String get scheduleTitle => 'スケジュール';

  @override
  String get viewDay => '日';

  @override
  String get viewWeek => '週';

  @override
  String get viewMonth => '月';

  @override
  String get viewYear => '年';

  @override
  String get viewAgenda => 'リスト';

  @override
  String get dayLayoutSwitchToClock => '円形時計表示';

  @override
  String get dayLayoutSwitchToTimeline => 'タイムライン表示';

  @override
  String get calendarLegendTooltip => 'カレンダーの点の色について';

  @override
  String get calendarLegendTitle => '点の色は何を意味しますか？';

  @override
  String get calendarLegendOverdueTodo => '期限切れのやることがあります';

  @override
  String get calendarLegendTodo => '未完了のやることがあります';

  @override
  String get calendarLegendEvent => '予定があります';

  @override
  String get calendarLegendMultiDayBarNote =>
      '複数日にまたがる予定の色バーはこのルールとは違います — 選んだ予定の色がそのまま表示されます。';

  @override
  String get monthSplitHandleLabel => 'カレンダーサイズの調整';

  @override
  String get dayEmpty => 'この日はまだ空いています';

  @override
  String get dayAddHint => '右下の + を押すか、空いている時間を長押しして予定を追加しましょう';

  @override
  String get agendaEmpty => '予定はありません';

  @override
  String get commonTomorrow => '明日';

  @override
  String get todosSectionTitle => 'やること';

  @override
  String get searchTooltip => '検索';

  @override
  String get quickAddEventTitle => 'クイック追加';

  @override
  String get quickAddEventHint => '日付と時間を自動で認識します';

  @override
  String get quickAddEventExample => '明日午後3時 会議';

  @override
  String quickAddEventCreated(String title, String day, String time) {
    return '「$title」・ $day $timeに追加しました';
  }

  @override
  String get searchHint => 'タイトルやメモで検索';

  @override
  String get searchEmpty => '検索結果がありません';

  @override
  String get searchPrompt => 'タイトルやメモを入力してください';

  @override
  String get searchSectionEvents => '予定';

  @override
  String get searchSectionTodos => 'やること';

  @override
  String get searchFilterAll => 'すべて';

  @override
  String get searchFilterTagLabel => 'タグ';

  @override
  String get searchFilterDateRangePick => '期間を選択';

  @override
  String get searchFilterDateRangeClear => '期間フィルターを解除';

  @override
  String get socialTitle => 'ソーシャル';

  @override
  String get socialComingSoonTitle => '近日公開';

  @override
  String get socialComingSoonBody =>
      '友達を追加して予定を共有する機能を準備しています。今は自分だけの時間に集中してみましょう。';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsNotificationSound => '通知音';

  @override
  String get settingsNotificationSoundDesc => '予定が始まるときに音でお知らせします';

  @override
  String get settingsExactAlarm => '正確な時刻通知';

  @override
  String get settingsExactAlarmDesc => '定刻どおりに通知するには権限が必要です';

  @override
  String get settingsCalendar => 'カレンダー連携';

  @override
  String get settingsCalendarSync => 'デバイスのカレンダーと同期';

  @override
  String get settingsCalendarSyncDesc => 'PlanFitの予定をデバイスのカレンダーにも反映します';

  @override
  String get settingsCalendarAutoImport => 'デバイスのカレンダーを自動で取り込む';

  @override
  String get settingsCalendarAutoImportDesc =>
      'カレンダーアプリで直接追加した予定もPlanFitに取り込みます';

  @override
  String get settingsSyncLog => '同期履歴';

  @override
  String get settingsLastSync => '最終同期';

  @override
  String get settingsLastSyncNever => 'まだ同期していません';

  @override
  String get settingsCalendarTarget => '同期先カレンダー';

  @override
  String get settingsCalendarTargetAuto => '自動';

  @override
  String get settingsCalendarTargetDisabledHint => '同期をオンにすると選択できます';

  @override
  String get settingsCalendarTargetEmpty => '選択できるカレンダーがありません';

  @override
  String get settingsCalendarImport => '他のカレンダーから取り込む';

  @override
  String get settingsCalendarImportDesc => '既存のカレンダーから取り込むか、購読を続けます';

  @override
  String get settingsHolidayCalendar => '祝日を表示';

  @override
  String get settingsHolidayCalendarDesc => '国ごとの祝日カレンダーを自動で読み込みます';

  @override
  String settingsHolidaySourceCurrent(String source) {
    return '現在: $source';
  }

  @override
  String get settingsHolidaySourceCustomLabel => 'カスタムカレンダー';

  @override
  String get settingsHolidaySourceEmpty => '未選択';

  @override
  String settingsHolidaySourceMore(String first, int count) {
    return '$first 他$count件';
  }

  @override
  String get holidayCountryKR => '韓国';

  @override
  String get holidayCountryUS => 'アメリカ';

  @override
  String get holidayCountryJP => '日本';

  @override
  String get holidayCountryGB => 'イギリス';

  @override
  String get holidayCountryDE => 'ドイツ';

  @override
  String get holidayCountryFR => 'フランス';

  @override
  String get holidayCountryCA => 'カナダ';

  @override
  String get holidayCountryAU => 'オーストラリア';

  @override
  String get holidayCalendarSourceTitle => '祝日カレンダーを選択';

  @override
  String get holidayCalendarSourceSectionCountries => '国を選択';

  @override
  String get holidayCalendarSourceCustomEntry => 'URLで直接追加';

  @override
  String get holidayCalendarSourceRemoveCustomUrl => '削除';

  @override
  String get holidayCalendarSourceCustomDialogTitle => 'カレンダーURLを入力';

  @override
  String get holidayCalendarSourceCustomDialogHint =>
      'https://example.com/calendar.ics';

  @override
  String get holidayCalendarSourceCustomInvalidUrl =>
      '正しいhttp/httpsリンクを入力してください';

  @override
  String get holidayCalendarSourceSyncFailed => 'カレンダーを読み込めませんでした。リンクをご確認ください';

  @override
  String get holidayCalendarSourceSyncFailedGeneric => '祝日カレンダーを読み込めませんでした';

  @override
  String get holidayCalendarSourceColorTooltip => '表示色を変更';

  @override
  String get holidayCalendarSourceColorTitle => 'カレンダーの色を選択';

  @override
  String get holidayCalendarSourceColorDefault => 'デフォルト';

  @override
  String get calendarImportTitle => '取り込み・購読するカレンダー';

  @override
  String get calendarImportEmpty => '取り込めるカレンダーがありません';

  @override
  String calendarImportConfirmTitle(String calendarName) {
    return '$calendarNameから取り込みますか？';
  }

  @override
  String get calendarImportConfirmBody =>
      '直近30日から1年先までの予定をPlanFitにコピーします。通知はオフの状態で取り込まれ、後でもう一度取り込むと重複する項目は更新されます。';

  @override
  String get calendarImportConfirmAction => '取り込む';

  @override
  String get calendarImportInProgress => '取り込み中…';

  @override
  String calendarImportSuccess(int count) {
    return '$count件の予定を取り込みました';
  }

  @override
  String get calendarImportFailed => '取り込みに失敗しました';

  @override
  String get calendarImportSubscribedHint => '購読中 — 常に最新の状態に保たれます';

  @override
  String get calendarImportMirroredReadOnlyNote =>
      '購読しているカレンダーから取り込んだ予定のため、PlanFitでは読み取り専用です。変更する場合は元のカレンダーアプリで行ってください。';

  @override
  String get holidayEventBadge => '祝日';

  @override
  String get holidayEventReadOnlyNote =>
      '信頼できるカレンダーから自動で読み込んだ祝日のため、PlanFitでは読み取り専用です。';

  @override
  String get settingsPermissionGranted => '許可済み';

  @override
  String get settingsPermissionDenied => '未許可';

  @override
  String get settingsPermissionDeniedMessage => '権限が拒否されています。デバイスの設定で許可してください。';

  @override
  String get settingsOpenAppSettings => '設定を開く';

  @override
  String get settingsGrant => '許可する';

  @override
  String get settingsAppearance => '画面';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsLanguageIosHint => 'iOSの設定 > PlanFit > 言語から変更できます';

  @override
  String get settingsWeekStart => '週の開始曜日';

  @override
  String get settingsWeekStartMonday => '月曜日';

  @override
  String get settingsWeekStartSunday => '日曜日';

  @override
  String get settingsThemeSystem => 'システム設定に従う';

  @override
  String get settingsThemeLight => 'ライト';

  @override
  String get settingsThemeDark => 'ダーク';

  @override
  String get settingsTimeFormatDisplay => '予定・やることの時間表示';

  @override
  String get settingsTimeFormatDial => '時間選択ダイヤル';

  @override
  String get settingsTimeFormatSystem => 'システム設定に従う';

  @override
  String get settingsTimeFormatH12 => '12時間制';

  @override
  String get settingsTimeFormatH24 => '24時間制';

  @override
  String get settingsTodo => 'やること';

  @override
  String get settingsReminderSync => 'デバイスのリマインダーと同期';

  @override
  String get settingsReminderSyncDesc => 'PlanFitのやることをデバイスのリマインダーにも反映します';

  @override
  String get settingsTodoRetention => '完了したやることを自動整理';

  @override
  String get settingsTodoRetentionDesc => '完了してから一定期間が過ぎたやることを自動で削除します';

  @override
  String get settingsTodoRetentionOff => '使用しない';

  @override
  String settingsTodoRetentionDays(int days) {
    return '$days日後';
  }

  @override
  String get settingsAbout => '情報';

  @override
  String get settingsVersion => 'バージョン';

  @override
  String get settingsData => 'データ';

  @override
  String get settingsDataBackupSection => 'バックアップ';

  @override
  String get settingsDataIcsSection => 'カレンダーファイル (.ics)';

  @override
  String get settingsExport => 'バックアップ全体を書き出す';

  @override
  String get settingsExportDesc => 'すべての予定とやることを1つのファイルに保存します';

  @override
  String get settingsImport => 'バックアップ全体を読み込む';

  @override
  String get settingsImportDesc => '書き出したファイルから予定とやることを復元します';

  @override
  String get settingsExportIcs => 'カレンダーファイルとして書き出す';

  @override
  String get settingsExportIcsDesc => '他のカレンダーアプリで開ける標準ファイル(.ics)です';

  @override
  String get settingsImportIcs => 'カレンダーファイルを読み込む';

  @override
  String get settingsImportIcsDesc =>
      '他のカレンダーアプリから書き出された.icsファイルを新しい予定として追加します';

  @override
  String icsImportSuccess(int count) {
    return '$count件の予定を取り込みました';
  }

  @override
  String icsImportSkipped(int count) {
    return '$count件は形式が不明のためスキップしました';
  }

  @override
  String get icsImportFailed => '取り込みに失敗しました';

  @override
  String get settingsAutoBackup => '自動バックアップの履歴';

  @override
  String get autoBackupTitle => '自動バックアップ';

  @override
  String get autoBackupEmpty => 'まだ自動バックアップはありません';

  @override
  String get autoBackupDesc => '24時間ごとに自動でバックアップし、直近7件を保管します';

  @override
  String get autoBackupRestore => 'このバックアップで復元';

  @override
  String get autoBackupRestoreConfirmTitle => 'このバックアップで復元しますか？';

  @override
  String get autoBackupRestoreConfirmBody =>
      '現在の予定・やることにこのバックアップの内容が統合されます。同じ項目はバックアップ時点の内容で上書きされます。';

  @override
  String get backupExportFailed => '書き出しに失敗しました';

  @override
  String backupImportSuccess(int events, int todos) {
    return '予定$events件、やること$todos件を取り込みました';
  }

  @override
  String get backupImportFailed => '取り込みに失敗しました。ファイル形式をご確認ください';

  @override
  String get eventNew => '新しい予定';

  @override
  String get eventEdit => '予定を編集';

  @override
  String get eventSectionBasic => '基本';

  @override
  String get eventSectionSchedule => '日時';

  @override
  String get eventSectionNotify => '通知';

  @override
  String get eventSectionDisplay => '表示';

  @override
  String get eventDuplicate => '予定を複製';

  @override
  String get eventShare => '予定を共有';

  @override
  String get eventShareFailed => '共有に失敗しました';

  @override
  String get eventTemplates => 'テンプレート';

  @override
  String get templatesTitle => 'よく使う予定';

  @override
  String get templatesEmpty => '保存されたテンプレートはありません';

  @override
  String get templatesSaveCurrent => '現在の内容をテンプレートとして保存';

  @override
  String get templatesNameHint => 'テンプレート名 (例: ジム)';

  @override
  String get templatesNameRequired => 'テンプレート名を入力してください';

  @override
  String get templatesSaved => 'テンプレートを保存しました';

  @override
  String get templatesDeleted => 'テンプレートを削除しました';

  @override
  String get eventTitle => 'タイトル';

  @override
  String get eventTitleHint => '何をしますか？';

  @override
  String get eventMemo => 'メモ';

  @override
  String get eventMemoHint => 'メモを残してみましょう';

  @override
  String get eventLocation => '場所';

  @override
  String get eventLocationHint => '場所を入力してみましょう';

  @override
  String get eventOpenInMaps => '地図で開く';

  @override
  String get eventOpenInMapsFailed => '地図を開けませんでした';

  @override
  String get eventAllDay => '終日';

  @override
  String get eventStart => '開始';

  @override
  String get eventEnd => '終了';

  @override
  String get eventNotify => '開始時に通知';

  @override
  String get eventReminderLead => '通知タイミング';

  @override
  String get eventReminderAtStart => '開始時刻ちょうど';

  @override
  String eventReminderMinutesBefore(int minutes) {
    return '$minutes分前';
  }

  @override
  String eventReminderHoursBefore(int hours) {
    return '$hours時間前';
  }

  @override
  String get eventReminderDayBefore => '1日前';

  @override
  String get eventReminderAdditional => '追加の通知（複数選択可）';

  @override
  String get eventRepeat => '繰り返し';

  @override
  String get eventRepeatNone => 'しない';

  @override
  String get eventRepeatDaily => '毎日';

  @override
  String get eventRepeatWeekly => '毎週';

  @override
  String get eventRepeatMonthly => '毎月';

  @override
  String get eventRepeatYearly => '毎年';

  @override
  String get eventRepeatUntil => '終了日';

  @override
  String get eventRepeatWeekdays => '繰り返す曜日';

  @override
  String get eventRepeatEndLabel => '終了条件';

  @override
  String get eventRepeatEndByDate => '日付まで';

  @override
  String get eventRepeatEndByCount => '回数まで';

  @override
  String eventRepeatCountTimes(int count) {
    return '$count回';
  }

  @override
  String get eventRepeatCountDecrease => '繰り返し回数を減らす';

  @override
  String get eventRepeatCountIncrease => '繰り返し回数を増やす';

  @override
  String get eventDeleteSeriesTitle => '繰り返し予定の削除';

  @override
  String get eventDeleteSeriesBody => 'この予定は繰り返し予定の一部です。どのように削除しますか？';

  @override
  String get eventDeleteThisOnly => 'この予定のみ削除';

  @override
  String get eventDeleteThisAndFuture => '以降の繰り返しをすべて削除';

  @override
  String get eventSaveSeriesTitle => '繰り返し予定の保存';

  @override
  String get eventSaveSeriesBody => 'この予定は繰り返し予定の一部です。変更をどのように適用しますか？';

  @override
  String get eventSaveThisOnly => 'この予定のみ保存';

  @override
  String get eventSaveThisAndFuture => '以降の繰り返しすべてに適用';

  @override
  String get eventColor => '色';

  @override
  String get eventColorAuto => '自動';

  @override
  String get eventColorCustom => '自分で選択';

  @override
  String get eventColorPickerTitle => '色を選択';

  @override
  String get eventSave => '保存';

  @override
  String get eventDelete => '削除';

  @override
  String get eventDeleted => '予定を削除しました';

  @override
  String get eventUndo => '元に戻す';

  @override
  String eventSelectionCount(int count) {
    return '$count件選択中';
  }

  @override
  String get eventSelectionDelete => '削除';

  @override
  String eventSelectionDeleted(int count) {
    return '$count件削除しました';
  }

  @override
  String get eventTitleRequired => 'タイトルを入力してください';

  @override
  String get eventRecurrenceTruncated => '繰り返し回数が多いため最大200回までのみ作成しました';

  @override
  String get todoAdd => 'やることを追加';

  @override
  String get todoHint => 'やることを入力してください';

  @override
  String get todoRepeat => '繰り返し';

  @override
  String get todoNoTime => '時間なし';

  @override
  String get todoMoreOptions => 'その他のオプション（優先度・繰り返し・時間なし）';

  @override
  String get todoFewerOptions => 'オプションを閉じる';

  @override
  String get todoRepeatIndicator => '繰り返すやること';

  @override
  String get todoDragHandle => '並び替え';

  @override
  String get todoDeleteSeriesTitle => '繰り返すやることの削除';

  @override
  String get todoDeleteSeriesBody => 'この項目は繰り返すやることの一部です。どのように削除しますか？';

  @override
  String get todoDeleteThisOnly => 'この項目のみ削除';

  @override
  String get todoDeleteThisAndFuture => '以降の繰り返しをすべて削除';

  @override
  String get todoDeleted => 'やることを削除しました';

  @override
  String todoQuickAddAddedToOtherDay(String day) {
    return '$dayに追加しました';
  }

  @override
  String todoSelectionCount(int count) {
    return '$count件選択中';
  }

  @override
  String get todoSelectionComplete => '完了にする';

  @override
  String get todoMarkDone => '完了状態';

  @override
  String get todoSelectItem => '選択';

  @override
  String get todoSelectionDelete => '削除';

  @override
  String todoSelectionDeleted(int count) {
    return '$count件削除しました';
  }

  @override
  String get todoEditTitle => 'やることを編集';

  @override
  String get todoTitleLabel => 'タイトル';

  @override
  String get todoReminderAdditional => '追加の通知（複数選択可）';

  @override
  String get todoPriorityLabel => '優先度';

  @override
  String get todoPriorityNone => 'なし';

  @override
  String get todoPriorityLow => '低い';

  @override
  String get todoPriorityMedium => '普通';

  @override
  String get todoPriorityHigh => '高い';

  @override
  String get todoTagsLabel => 'タグ';

  @override
  String get todoTagsHint => 'カンマ区切りで入力 (例: 仕事,急ぎ)';

  @override
  String get todoSubtasksLabel => 'サブタスク';

  @override
  String get todoSubtaskHint => 'サブタスクを追加';

  @override
  String get todoSubtaskDelete => 'サブタスクを削除';

  @override
  String get todoNotify => '指定時刻に通知';

  @override
  String get todoNotifyNoTimeHint => '時間を設定すると通知をオンにできます';

  @override
  String get todoPin => 'ピン留め';

  @override
  String get todoUnpin => 'ピン留め解除';

  @override
  String get todoPinned => 'ピン留め済み';

  @override
  String get smartListTitle => 'やることまとめ';

  @override
  String get smartListToday => '今日';

  @override
  String get smartListOverdue => '期限切れ';

  @override
  String get smartListHighPriority => '優先度高';

  @override
  String get smartListPinned => 'ピン留め済み';

  @override
  String get smartListByTag => 'タグ別';

  @override
  String get smartListEmptyToday => '今日のやることはありません';

  @override
  String get smartListEmptyOverdue => '期限切れのやることはありません';

  @override
  String get smartListEmptyHighPriority => '優先度の高いやることはありません';

  @override
  String get smartListEmptyPinned => 'ピン留めされたやることはありません';

  @override
  String get smartListEmptyByTag => 'このタグのやることはありません';

  @override
  String get smartListNoTags => 'まだ登録されたタグはありません';

  @override
  String get smartListPickTag => 'タグを選択してください';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonDone => '完了';

  @override
  String get commonToday => '今日';

  @override
  String get errorWidgetFallback => '問題が発生しました';

  @override
  String get notificationChannelName => '予定の通知';

  @override
  String get notificationChannelDescription => '予定が始まるときにお知らせします';

  @override
  String get notificationSnoozeLabel => '5分後に再通知';

  @override
  String get notificationEventFallbackTitle => '予定';

  @override
  String get notificationTodoFallbackTitle => 'やること';

  @override
  String lunarDateLabel(int month, int day) {
    return '旧暦 $month月$day日';
  }

  @override
  String lunarDateLabelLeap(int month, int day) {
    return '旧暦 閏$month月$day日';
  }

  @override
  String get settingsShowLunarDates => '旧暦を表示';

  @override
  String get settingsShowLunarDatesDesc => '日・週・月の画面に旧暦の日付も表示します';

  @override
  String lunarDateCompact(int month, int day) {
    return '$month.$day';
  }

  @override
  String get lunarLeapMarker => '閏';

  @override
  String get eventRepeatYearlyLunar => '毎年（旧暦基準）';

  @override
  String get eventLunarInputToggle => '旧暦で入力';

  @override
  String get eventLunarInputToggleOn => '旧暦の日付を入力しています — 対応する新暦の日付として保存されます';

  @override
  String get lunarDatePickerTitle => '旧暦の日付を選択';

  @override
  String get lunarLeapMonthToggle => '閏月';
}
