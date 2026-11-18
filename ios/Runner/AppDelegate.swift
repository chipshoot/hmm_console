import Flutter
import UIKit
import UserNotifications
// For FlutterLocalNotificationsPlugin.setPluginRegistrantCallback.
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: the plugin handles notification taps and
    // foreground presentation through the app delegate.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // flutter_local_notifications (UIScene lifecycle): lets the plugin's
    // background action isolate reach the other plugins.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Hand-registered: this is the app's own plugin, not a pub package, so
    // GeneratedPluginRegistrant does not know about it.
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "DocumentScannerPlugin") {
      DocumentScannerPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "VideoPlugin") {
      VideoPlugin.register(with: registrar)
    }
  }
}
