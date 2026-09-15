import EventKit
import Flutter

/// Bridges to-do ↔ EventKit Reminders sync (see lib/core/reminders_sync/
/// reminders_service.dart) over a plain MethodChannel — no existing Flutter
/// plugin talks to EKReminder (device_calendar_plus only covers EKEvent), so
/// this is hand-written the same way PlanFitWidgetProvider.kt is on Android.
/// iOS-only by construction: there's nothing to register on Android.
public class RemindersPlugin: NSObject, FlutterPlugin {
  // EventKit documents that a store created before access is granted does
  // not contain calendars for that entity type. The store then announces a
  // change notification after access changes; rebuild it so the first
  // resolve immediately after the permission prompt sees the new lists.
  private var store = EKEventStore()
  private var storeChangedObserver: NSObjectProtocol?

  override init() {
    super.init()
    storeChangedObserver = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.store = EKEventStore()
    }
  }

  deinit {
    if let observer = storeChangedObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.arisair.planfit/reminders",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(RemindersPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestAccess":
      requestAccess(result: result)
    case "resolveTargetListId":
      resolveTargetListId(result: result)
    case "pushTodo":
      pushTodo(call: call, result: result)
    case "deleteTodo":
      deleteTodo(call: call, result: result)
    case "fetchReminders":
      fetchReminders(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Permissions

  private func requestAccess(result: @escaping FlutterResult) {
    if #available(iOS 17.0, *) {
      store.requestFullAccessToReminders { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    } else {
      store.requestAccess(to: .reminder) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    }
  }

  // MARK: - Target list resolution (mirrors CalendarService.resolveTargetCalendarId)

  private static let ownListName = "PlanFit"

  private func findOwnList() -> EKCalendar? {
    store.calendars(for: .reminder).first { $0.title == Self.ownListName }
  }

  /// Finds or creates a dedicated "PlanFit" reminders list, same reasoning
  /// as CalendarService's dedicated calendar: to-dos show up as their own
  /// toggleable list in the Reminders app rather than mixed into the user's
  /// default list, and reusing a same-named list on reinstall avoids piling
  /// up duplicates (the list itself lives in EventKit, outside the app's own
  /// storage, so uninstalling PlanFit doesn't remove it).
  private func resolveTargetListId(result: @escaping FlutterResult) {
    // EKEventStore's synchronous calls (calendars(for:), saveCalendar) do
    // real disk/IPC work — off the main thread so a to-do save doesn't jank
    // the UI while it runs, same as pushTodo/deleteTodo below.
    DispatchQueue.global(qos: .userInitiated).async { [self] in
      if let existing = findOwnList() {
        DispatchQueue.main.async { result(existing.calendarIdentifier) }
        return
      }
      guard
        let source = store.defaultCalendarForNewReminders()?.source
          ?? store.sources.first(where: { $0.sourceType == .local })
          ?? store.sources.first
      else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let list = EKCalendar(for: .reminder, eventStore: store)
      list.title = Self.ownListName
      list.source = source
      do {
        try store.saveCalendar(list, commit: true)
        DispatchQueue.main.async { result(list.calendarIdentifier) }
      } catch {
        // List creation can fail on some accounts (e.g. no local/iCloud source
        // eligible to host a new list) — fall back to the OS default list
        // rather than leaving sync silently broken, same fallback CalendarService
        // takes when calendar creation fails.
        if let fallback = store.defaultCalendarForNewReminders() {
          DispatchQueue.main.async { result(fallback.calendarIdentifier) }
        } else {
          DispatchQueue.main.async { result(nil) }
        }
      }
    }
  }

  // MARK: - Push (create/update)

  private func pushTodo(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let listId = args["listId"] as? String,
      let title = args["title"] as? String
    else {
      result(nil)
      return
    }
    let isCompleted = args["isCompleted"] as? Bool ?? false
    let dueDateMillis = args["dueDateMillis"] as? Int64
    let existingId = args["osReminderId"] as? String

    // store.calendar(withIdentifier:)/calendarItem(withIdentifier:)/save are
    // all synchronous EventKit calls that hit disk/IPC — off the main thread
    // so every to-do save while Reminders sync is on doesn't jank the UI.
    DispatchQueue.global(qos: .userInitiated).async { [self] in
      guard let list = store.calendar(withIdentifier: listId) else {
        DispatchQueue.main.async { result(nil) }
        return
      }

      let reminder: EKReminder
      if let existingId = existingId,
        let existing = store.calendarItem(withIdentifier: existingId) as? EKReminder
      {
        reminder = existing
      } else {
        reminder = EKReminder(eventStore: store)
        reminder.calendar = list
      }

      reminder.title = title.isEmpty ? " " : title
      reminder.isCompleted = isCompleted
      if let millis = dueDateMillis {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        reminder.dueDateComponents = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute], from: date)
      } else {
        reminder.dueDateComponents = nil
      }

      do {
        try store.save(reminder, commit: true)
        DispatchQueue.main.async { result(reminder.calendarItemIdentifier) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "save_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - Delete

  private func deleteTodo(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let osReminderId = args["osReminderId"] as? String
    else {
      result(nil)
      return
    }
    // calendarItem(withIdentifier:)/remove are synchronous EventKit calls —
    // off the main thread, same reasoning as pushTodo/resolveTargetListId.
    DispatchQueue.global(qos: .userInitiated).async { [self] in
      if let item = store.calendarItem(withIdentifier: osReminderId) as? EKReminder {
        // Best-effort, same reasoning as CalendarService.deleteEvent: already
        // gone from Reminders is already the desired end state, not a failure.
        try? store.remove(item, commit: true)
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  // MARK: - Pull (fetch for the reconciler)

  // `store.calendar(withIdentifier:)` returns nil both when the list was
  // genuinely deleted from the Reminders app AND when Reminders access is no
  // longer authorized (permission revoked) — EventKit raises no error for
  // the latter, it just can't resolve anything. Returning `nil` (not an
  // empty array) here lets the Dart side tell "couldn't confirm the list's
  // real contents" apart from "confirmed empty" — RemindersReconciler
  // used to treat an empty array as ground truth and delete every synced
  // to-do it couldn't find in it, which fired on a bare permission
  // revocation with none of the underlying reminders actually gone.
  private func fetchReminders(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let listId = args["listId"] as? String
    else {
      result(nil)
      return
    }
    // store.calendar(withIdentifier:) is a synchronous EventKit call that
    // hits disk/IPC, same as pushTodo/deleteTodo/resolveTargetListId above —
    // but unlike those, this one used to run inline on whatever thread
    // `handle(_:result:)` was called on (the main thread, since Flutter
    // dispatches every MethodChannel call there), blocking the UI on every
    // foreground-resume RemindersReconciler.reconcile() pass. Off the main
    // thread now, matching the rest of this file.
    DispatchQueue.global(qos: .userInitiated).async { [self] in
      guard let list = store.calendar(withIdentifier: listId) else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let predicate = store.predicateForReminders(in: [list])
      store.fetchReminders(matching: predicate) { reminders in
        let items = (reminders ?? []).map { r -> [String: Any?] in
          let dueDate = r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
          return [
            "osReminderId": r.calendarItemIdentifier,
            "title": r.title ?? "",
            "isCompleted": r.isCompleted,
            "dueDateMillis": dueDate.map { Int64($0.timeIntervalSince1970 * 1000) },
            "lastModifiedMillis": r.lastModifiedDate.map {
              Int64($0.timeIntervalSince1970 * 1000)
            },
          ]
        }
        DispatchQueue.main.async { result(items) }
      }
    }
  }
}
