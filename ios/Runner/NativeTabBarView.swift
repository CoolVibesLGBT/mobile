import Flutter
import UIKit

/// `coolvibes/tabbar`: the shell's tab bar as a system UITabBar, so iOS draws
/// its own Liquid Glass bar and selection lens over whatever is behind it,
/// including the WebView map, which Flutter's glass cannot sample.
/// AppTabBar (lib/components/app_tab_bar.dart) owns the API; selection,
/// titles, colours, appearance and direction arrive on `coolvibes/tabbar_<id>`,
/// taps go back as `select`, and the bar's fitted height as `height`.
final class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeTabBarFactory(messenger: registrar.messenger()), withId: "coolvibes/tabbar")
  }

  private init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    NativeTabBarView(
      frame: frame, viewId: viewId, messenger: messenger,
      arguments: args as? [String: Any] ?? [:])
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class TabBarContainer: UIView {
  let tabBar = UITabBar()
  var onHeight: ((CGFloat) -> Void)?
  private var reported: CGFloat = -1

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    tabBar.translatesAutoresizingMaskIntoConstraints = false
    addSubview(tabBar)
    NSLayoutConstraint.activate([
      tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
      tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
      tabBar.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  required init?(coder: NSCoder) { nil }

  override func layoutSubviews() {
    super.layoutSubviews()
    let fitted = tabBar.sizeThatFits(
      CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
    ).height
    if fitted > 0 && abs(fitted - reported) > 0.5 {
      reported = fitted
      onHeight?(fitted)
    }
  }
}

private final class NativeTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let container: TabBarContainer
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, arguments: [String: Any]
  ) {
    container = TabBarContainer(frame: frame)
    channel = FlutterMethodChannel(name: "coolvibes/tabbar_\(viewId)", binaryMessenger: messenger)
    super.init()
    container.tabBar.delegate = self
    container.onHeight = { [weak self] height in
      self?.channel.invokeMethod("height", arguments: Double(height))
    }
    apply(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      if call.method == "update", let args = call.arguments as? [String: Any] {
        self.apply(args)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func apply(_ args: [String: Any]) {
    let tabBar = container.tabBar
    let titles = args["titles"] as? [String] ?? []
    let symbols = args["symbols"] as? [String] ?? []
    let selectedSymbols = args["selectedSymbols"] as? [String] ?? []
    let font = UIFont.systemFont(ofSize: 10, weight: .semibold)
    let current = tabBar.items ?? []
    if current.map({ $0.title ?? "" }) != titles {
      tabBar.items = titles.enumerated().map { index, title in
        let item = UITabBarItem(
          title: title,
          image: UIImage(systemName: index < symbols.count ? symbols[index] : "circle"),
          selectedImage: UIImage(
            systemName: index < selectedSymbols.count ? selectedSymbols[index] : "circle.fill"))
        item.tag = index
        item.setTitleTextAttributes([.font: font], for: .normal)
        item.setTitleTextAttributes([.font: font], for: .selected)
        return item
      }
    }
    if let tint = args["tint"] as? NSNumber {
      tabBar.tintColor = color(argb: tint.uint32Value)
    }
    if let unselected = args["unselected"] as? NSNumber {
      tabBar.unselectedItemTintColor = color(argb: unselected.uint32Value)
    }
    container.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
    let rtl = args["rtl"] as? Bool ?? false
    tabBar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
    let selected = (args["selected"] as? NSNumber)?.intValue ?? 0
    if let items = tabBar.items, selected >= 0, selected < items.count,
      tabBar.selectedItem !== items[selected]
    {
      tabBar.selectedItem = items[selected]
    }
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("select", arguments: item.tag)
  }
}

private func color(argb: UInt32) -> UIColor {
  UIColor(
    red: CGFloat((argb >> 16) & 0xff) / 255,
    green: CGFloat((argb >> 8) & 0xff) / 255,
    blue: CGFloat(argb & 0xff) / 255,
    alpha: CGFloat((argb >> 24) & 0xff) / 255)
}
