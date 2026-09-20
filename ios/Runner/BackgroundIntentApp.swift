import AppIntents

/// Allows iOS to continue an interactive widget action in the app process if
/// the extension's background execution window expires.
@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension PlanFitBackgroundIntent: ForegroundContinuableIntent {}
