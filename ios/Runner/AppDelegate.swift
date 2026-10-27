import Flutter
import UIKit

// Shared controls render through Flutter; the local glass bridge reports
// reserved UIKit regions without adding a plugin/package dependency.
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let glassRegistrar = registrar(forPlugin: "CoolvibesLiquidGlass") {
      LiquidGlassWidgetsPlugin.register(with: glassRegistrar)
    }
    if let nativeGlass = registrar(forPlugin: "CoolvibesNativeGlass") {
      NativeGlassViewFactory.register(with: nativeGlass)
    }
    if let nativeTabs = registrar(forPlugin: "CoolvibesNativeTabBar") {
      NativeTabBarFactory.register(with: nativeTabs)
    }
    if let nativeButtons = registrar(forPlugin: "CoolvibesNativeGlassButton") {
      NativeGlassButtonFactory.register(with: nativeButtons)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
