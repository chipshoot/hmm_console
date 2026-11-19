import Flutter
import UIKit
import UserNotifications

/// Sets the app icon badge for the calendar reminders inbox.
///
/// Scheduled reminders set the badge themselves when they fire (each carries
/// its number); `set` makes it follow the unseen count on every ReminderSync
/// run (0 when the inbox was seen, reminders are off on this device, or the
/// app is in Cloud API mode). `clear` is kept as `set` with 0.
class BadgePlugin: NSObject {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "hmm/badge",
      binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "set":
        let args = call.arguments as? [String: Any]
        let count = (args?["count"] as? NSNumber)?.intValue ?? 0
        setBadge(max(0, count), result: result)
      case "clear":
        setBadge(0, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func setBadge(_ count: Int, result: @escaping FlutterResult) {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(count) { error in
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
        UIApplication.shared.applicationIconBadgeNumber = count
        result(nil)
      }
    }
  }
}
