import Flutter
import UIKit

/// The shared GlassSurface material. Telegram GlassBackgroundComponent uses
/// UIGlassEffect(.regular), panel white 0.1 / 0.025, or .clear. Flutter owns
/// content and gestures; UIKit owns the material and accessibility fallback.
final class NativeGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  private init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeGlassViewFactory(messenger: registrar.messenger()), withId: "coolvibes/glass")
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    NativeGlassView(
      frame: frame, viewId: viewId, messenger: messenger,
      arguments: args as? [String: Any] ?? [:])
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class GlassEffectView: UIVisualEffectView {
  var requestedRadius: CGFloat = 0
  var circular = false

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = circular ? min(bounds.width, bounds.height) / 2
      : min(requestedRadius, min(bounds.width, bounds.height) / 2)
  }
}

private final class NativeGlassView: NSObject, FlutterPlatformView {
  private let effectView = GlassEffectView(effect: nil)
  private let channel: FlutterMethodChannel
  private var arguments: [String: Any]
  private var transparencyObserver: NSObjectProtocol?

  init(
    frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger,
    arguments: [String: Any]
  ) {
    self.arguments = arguments
    channel = FlutterMethodChannel(
      name: "coolvibes/glass_\(viewId)", binaryMessenger: messenger)
    super.init()
    effectView.frame = frame
    effectView.isUserInteractionEnabled = false
    effectView.isAccessibilityElement = false
    effectView.clipsToBounds = true
    apply(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update", let args = call.arguments as? [String: Any] {
        self?.apply(args)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    transparencyObserver = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil, queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      self.apply(self.arguments)
    }
  }

  deinit {
    if let transparencyObserver { NotificationCenter.default.removeObserver(transparencyObserver) }
    channel.setMethodCallHandler(nil)
  }

  private func apply(_ args: [String: Any]) {
    arguments = args
    let dark = args["dark"] as? Bool ?? false
    let clear = args["clear"] as? Bool ?? false
    let tint = (args["tint"] as? NSNumber).map { color(argb: $0.uint32Value) }
    effectView.overrideUserInterfaceStyle = dark ? .dark : .light
    effectView.requestedRadius = (args["radius"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
    effectView.circular = args["circular"] as? Bool ?? false
    effectView.layer.cornerCurve = effectView.circular ? .circular : .continuous
    effectView.layer.maskedCorners = args["topOnly"] as? Bool == true
      ? [.layerMinXMinYCorner, .layerMaxXMinYCorner]
      : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    effectView.setNeedsLayout()
    effectView.contentView.backgroundColor = .clear
    if UIAccessibility.isReduceTransparencyEnabled || args["reduceTransparency"] as? Bool == true {
      effectView.effect = nil
      effectView.backgroundColor = tint?.withAlphaComponent(1)
        ?? (dark ? UIColor(white: 0.11, alpha: 1) : .white)
      return
    }
    effectView.backgroundColor = .clear
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: clear ? .clear : .regular)
      effect.tintColor = tint ?? (clear
        ? (dark ? UIColor(white: 0, alpha: 0.28) : nil)
        : UIColor(white: 1, alpha: dark ? 0.025 : 0.1))
      // AppPressable owns down/up/cancel/long-press and the lift transform.
      effect.isInteractive = false
      effectView.effect = effect
    } else {
      effectView.effect = UIBlurEffect(
        style: dark ? .systemThinMaterialDark : .systemThinMaterialLight)
      effectView.contentView.backgroundColor = tint ?? .clear
    }
  }

  func view() -> UIView { effectView }
}

private func color(argb: UInt32) -> UIColor {
  UIColor(
    red: CGFloat((argb >> 16) & 0xff) / 255,
    green: CGFloat((argb >> 8) & 0xff) / 255,
    blue: CGFloat(argb & 0xff) / 255,
    alpha: CGFloat((argb >> 24) & 0xff) / 255)
}
