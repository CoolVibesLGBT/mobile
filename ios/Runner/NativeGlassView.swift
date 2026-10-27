import Flutter
import UIKit

/// `coolvibes/glass`: the UIKit glass behind GlassSurface where Flutter's
/// shader cannot sample (over a live platform view such as the WebView map).
/// Telegram GlassBackgroundView: UIGlassEffect(.regular) with a panel tint
/// (white 0.1 light / 0.025 dark), a custom tint, or `.clear`; corners use
/// the continuous curve. Before iOS 26 a system material blur stands in.
final class NativeGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(NativeGlassViewFactory(), withId: "coolvibes/glass")
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    NativeGlassView(frame: frame, arguments: args as? [String: Any] ?? [:])
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class NativeGlassView: NSObject, FlutterPlatformView {
  private let effectView: UIVisualEffectView

  init(frame: CGRect, arguments: [String: Any]) {
    effectView = UIVisualEffectView(effect: nil)
    effectView.frame = frame
    effectView.isUserInteractionEnabled = false
    super.init()
    let radius = (arguments["radius"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
    let dark = arguments["dark"] as? Bool ?? false
    let clear = arguments["clear"] as? Bool ?? false
    let tint = (arguments["tint"] as? NSNumber).map { color(argb: $0.uint32Value) }
    effectView.layer.cornerRadius = radius
    effectView.layer.cornerCurve = arguments["circular"] as? Bool == true ? .circular : .continuous
    effectView.clipsToBounds = true
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: clear ? .clear : .regular)
      if let tint {
        effect.tintColor = tint
      } else if clear {
        effect.tintColor = dark ? UIColor(white: 0, alpha: 0.28) : nil
      } else {
        effect.tintColor = UIColor(white: 1, alpha: dark ? 0.025 : 0.1)
      }
      effect.isInteractive = false
      effectView.effect = effect
    } else {
      effectView.effect = UIBlurEffect(
        style: dark ? .systemThinMaterialDark : .systemThinMaterialLight)
      if let tint {
        let overlay = UIView(frame: effectView.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = tint
        effectView.contentView.addSubview(overlay)
      }
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
