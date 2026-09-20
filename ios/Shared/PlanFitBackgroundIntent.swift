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
        UserDefaults(suiteName: group)?.set(url.absoluteString, forKey: pendingWidgetActionKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "PlanFitWidget")
        return .result()
    }
}
