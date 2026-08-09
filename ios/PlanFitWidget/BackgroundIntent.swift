import AppIntents
import Foundation
import home_widget

// Not wired into the Xcode project yet — see PlanFitWidget.swift's own doc
// comment for the target-creation step this depends on. Once the
// PlanFitWidget Widget Extension target exists, add this file to it — but
// unlike PlanFitWidget.swift, this one must ALSO be added to the main
// Runner app target's "Compile Sources" (Xcode > Runner target > Build
// Phases > Compile Sources > +). That dual membership is what lets
// `ForegroundContinuableIntent` below actually work: the same
// `BackgroundIntent` type is compiled twice — once into the extension
// (where perform() runs a background-only headless engine call) and once
// into the app (where the `ForegroundContinuableIntent` conformance lets
// iOS fall back to briefly foregrounding PlanFit if the extension's
// background execution time runs out mid-toggle). The
// `@available(iOSApplicationExtension, unavailable)` annotation is what
// makes that safe to compile into the extension target at all — the
// extension build simply skips that one conformance.
//
// Mirrors home_widget's own example at
// example/ios/Runner/BackgroundIntent.swift — same shape, renamed only for
// clarity in this app's own source tree.

@available(iOS 17, *)
public struct PlanFitBackgroundIntent: AppIntent {
    public static var title: LocalizedStringResource = "PlanFit 위젯 배경 작업"

    @Parameter(title: "Widget URI")
    var url: URL?

    @Parameter(title: "AppGroup")
    var appGroup: String?

    public init() {}

    public init(url: URL?, appGroup: String?) {
        self.url = url
        self.appGroup = appGroup
    }

    public func perform() async throws -> some IntentResult {
        await HomeWidgetBackgroundWorker.run(url: url, appGroup: appGroup!)
        return .result()
    }
}

@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension PlanFitBackgroundIntent: ForegroundContinuableIntent {}
