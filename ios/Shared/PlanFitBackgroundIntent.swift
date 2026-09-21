import AppIntents
import Foundation
import WidgetKit

private let planFitAppGroupId = "group.com.arisair.planfit"
private let pendingWidgetActionKey = "widget_pending_action"

/// App Intent used by interactive widget rows to invoke the existing
/// App Group action queue consumed by the Flutter app on its next foreground.
///
/// This source is compiled into both the widget extension and the Runner app.
/// The extension executes `perform()` directly; the app target adds the
/// `ForegroundContinuableIntent` conformance in `BackgroundIntentApp.swift`.
@available(iOS 17, *)
public struct PlanFitBackgroundIntent: AppIntent {
    private static let queueLock = NSLock()
    public static var title: LocalizedStringResource = "PlanFit 위젯 배경 작업"
    public static var openAppWhenRun: Bool = true

    @Parameter(title: "Widget URI")
    public var url: URL?

    @Parameter(title: "AppGroup")
    public var appGroup: String?

    public init() {}

    public init(url: URL?, appGroup: String?) {
        self.url = url
        self.appGroup = appGroup
    }

    public func perform() async throws -> some IntentResult {
        guard let url else { return .result() }
        let group = appGroup ?? planFitAppGroupId
        // Keep the read/append/write section serialized inside the widget
        // extension process. The old single string write let a second rapid
        // tap overwrite the first before the Flutter app resumed. A JSON
        // array preserves every tap in order; a plain string remains accepted
        // below for one-release compatibility with an older pending value.
        let defaults = UserDefaults(suiteName: group)
        Self.queueLock.lock()
        defer { Self.queueLock.unlock() }
        var actions: [String] = []
        if let raw = defaults?.string(forKey: pendingWidgetActionKey), !raw.isEmpty {
            if let data = raw.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                actions = decoded
            } else {
                actions = [raw]
            }
        }
        actions.append(url.absoluteString)
        defaults?.set(actions, forKey: pendingWidgetActionKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "PlanFitWidget")
        return .result()
    }
}
