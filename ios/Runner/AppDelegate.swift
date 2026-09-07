import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Hand-registered: this is the app's own plugin, not a pub package, so
    // GeneratedPluginRegistrant does not know about it.
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "DocumentScannerPlugin") {
      DocumentScannerPlugin.register(with: registrar)
    }
  }
}
