import Flutter
import UIKit

/// `coolvibes/glassbutton`: a system Liquid Glass button (iOS 26
/// `UIButton.Configuration.glass()` / `.prominentGlass()`), used by AppIconButton
/// and GlassButton where Flutter glass cannot see the backdrop (over the
/// WebView map). UIKit owns the material, the press lens and the highlight;
/// the tap is reported on `coolvibes/glassbutton_<id>` as `tap`, and later
/// looks arrive there as `update`.
final class NativeGlassButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeGlassButtonFactory(messenger: registrar.messenger()), withId: "coolvibes/glassbutton")
  }

  private init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    NativeGlassButton(
      frame: frame, viewId: viewId, messenger: messenger,
      arguments: args as? [String: Any] ?? [:])
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class NativeGlassButton: NSObject, FlutterPlatformView {
  private let container: UIView
  private let button = UIButton(type: .system)
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, arguments: [String: Any]
  ) {
    container = UIView(frame: frame)
    container.backgroundColor = .clear
    channel = FlutterMethodChannel(
      name: "coolvibes/glassbutton_\(viewId)", binaryMessenger: messenger)
    super.init()
    button.frame = container.bounds
    button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.addSubview(button)
    button.addAction(
      UIAction { [weak self] _ in self?.channel.invokeMethod("tap", arguments: nil) },
      for: .primaryActionTriggered)
    apply(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update", let args = call.arguments as? [String: Any] {
        self?.apply(args)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func apply(_ args: [String: Any]) {
    let prominent = args["prominent"] as? Bool ?? false
    var config: UIButton.Configuration
    if #available(iOS 26.0, *) {
      config = prominent ? .prominentGlass() : .glass()
    } else {
      config = prominent ? .filled() : .gray()
    }
    config.cornerStyle = .capsule
    config.contentInsets = .zero
    let pointSize = (args["pointSize"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 17
    if let symbol = args["symbol"] as? String {
      config.image = UIImage(systemName: symbol)
      config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
        pointSize: pointSize, weight: .medium, scale: .large)
    }
    if let title = args["title"] as? String {
      var text = AttributedString(title)
      text.font = UIFont.systemFont(ofSize: pointSize, weight: .semibold)
      config.attributedTitle = text
    }
    if let glyph = args["glyph"] as? NSNumber {
      config.baseForegroundColor = color(argb: glyph.uint32Value)
    }
    button.configuration = config
    if let tint = args["tint"] as? NSNumber {
      button.tintColor = color(argb: tint.uint32Value)
    }
    button.isEnabled = args["enabled"] as? Bool ?? true
    button.accessibilityLabel = args["label"] as? String
    container.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
  }
}

private func color(argb: UInt32) -> UIColor {
  UIColor(
    red: CGFloat((argb >> 16) & 0xff) / 255,
    green: CGFloat((argb >> 8) & 0xff) / 255,
    blue: CGFloat(argb & 0xff) / 255,
    alpha: CGFloat((argb >> 24) & 0xff) / 255)
}
