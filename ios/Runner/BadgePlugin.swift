import Flutter
import UIKit
import UserNotifications

/// Clears the app icon badge for the calendar reminders inbox.
///
/// Scheduled reminders set the badge themselves (each carries its number);
/// this only resets it to 0 when the owner has seen the inbox.
class BadgePlugin: NSObject {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "hmm/badge",
      binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "clear":
        clear(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func clear(result: @escaping FlutterResult) {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(
              code: "badge", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      }
    } else {
      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = 0
        result(nil)
      }
    }
  }
}
