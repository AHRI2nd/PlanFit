import Flutter
import UIKit

/// Streams UIKit window traits and iOS reserved regions to Flutter.
///
/// The probe is laid out with the Flutter view. UIKit tracks reserved-region
/// queries made during layout and schedules another layout when a region
/// changes, including the fold and the inner camera occlusion.
public final class WindowLayoutPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private weak var viewController: FlutterViewController?
  private var probe: ReservedRegionLayoutProbe?
  private var eventSink: FlutterEventSink?
  private var lastSnapshot: NSDictionary?

  private init(viewController: FlutterViewController?) {
    self.viewController = viewController
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = WindowLayoutPlugin(viewController: registrar.viewController as? FlutterViewController)
    let channel = FlutterEventChannel(
      name: "com.arisair.planfit/window_layout",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(plugin)
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard let rootView = viewController?.view else {
      return FlutterError(
        code: "window_unavailable",
        message: "The Flutter view is not attached.",
        details: nil
      )
    }

    eventSink = events
    let layoutProbe = ReservedRegionLayoutProbe(frame: rootView.bounds)
    layoutProbe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    layoutProbe.backgroundColor = .clear
    layoutProbe.isUserInteractionEnabled = false
    layoutProbe.accessibilityElementsHidden = true
    layoutProbe.sourceView = rootView
    layoutProbe.onLayout = { [weak self] in self?.sendSnapshot() }
    rootView.addSubview(layoutProbe)
    probe = layoutProbe
    sendSnapshot()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    probe?.removeFromSuperview()
    probe = nil
    eventSink = nil
    lastSnapshot = nil
    return nil
  }

  private func sendSnapshot() {
    guard let eventSink, let rootView = viewController?.view else { return }
    let value = snapshot(for: rootView) as NSDictionary
    guard lastSnapshot?.isEqual(to: value as! [AnyHashable: Any]) != true else { return }
    lastSnapshot = value
    eventSink(value)
  }

  private func snapshot(for view: UIView) -> [String: Any] {
    var regions: [[String: Any]] = []
    if #available(iOS 27.1, *) {
      let divisionRegions = view.reservedRegions(kind: .division, options: .includeInactive)
      let occlusionRegions = view.reservedRegions(kind: .occlusion, options: .includeInactive)
      regions = (divisionRegions.map { ($0, "division") } + occlusionRegions.map { ($0, "occlusion") })
        .map { pair in
          let (region, kind) = pair
          return [
            "id": region.id.description,
            "kind": kind,
            "left": region.frame.minX,
            "top": region.frame.minY,
            "width": region.frame.width,
            "height": region.frame.height,
            "active": region.isActive,
          ]
        }
    }

    return [
      "version": 1,
      "width": view.bounds.width,
      "height": view.bounds.height,
      "safeTop": view.safeAreaInsets.top,
      "safeRight": view.safeAreaInsets.right,
      "safeBottom": view.safeAreaInsets.bottom,
      "safeLeft": view.safeAreaInsets.left,
      "horizontalSizeClass": Self.sizeClassName(view.traitCollection.horizontalSizeClass),
      "verticalSizeClass": Self.sizeClassName(view.traitCollection.verticalSizeClass),
      "regions": regions,
    ]
  }

  private static func sizeClassName(_ sizeClass: UIUserInterfaceSizeClass) -> String {
    switch sizeClass {
    case .compact: "compact"
    case .regular: "regular"
    default: "unspecified"
    }
  }
}

private final class ReservedRegionLayoutProbe: UIView {
  weak var sourceView: UIView?
  var onLayout: (() -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }
}
