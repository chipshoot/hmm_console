import Flutter
import UIKit
import VisionKit

/// Presents VisionKit's document camera and returns JPEG bytes per page.
///
/// Deliberately knows nothing about licences, sides or page limits: those
/// rules live in Dart (`licence_scan_mapping.dart`) where a test can reach
/// them. This file cannot be unit-tested and does not even run on the
/// simulator, so it does as little thinking as possible.
class DocumentScannerPlugin: NSObject {
  /// Held for the lifetime of the app: the channel's handler closure captures
  /// it, and the delegate callbacks arrive long after registration returns.
  private static var instance: DocumentScannerPlugin?

  private var pendingResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = DocumentScannerPlugin()
    instance = plugin
    let channel = FlutterMethodChannel(
      name: "hmm/document_scanner",
      binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      plugin.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(VNDocumentCameraViewController.isSupported)

    case "scan":
      guard VNDocumentCameraViewController.isSupported else {
        result(FlutterError(code: "unavailable",
                            message: "No document camera on this device",
                            details: nil))
        return
      }
      guard pendingResult == nil else {
        result(FlutterError(code: "already_presenting",
                            message: "A scan is already in progress",
                            details: nil))
        return
      }
      guard let host = Self.presenter() else {
        result(FlutterError(code: "failed",
                            message: "No view controller to present from",
                            details: nil))
        return
      }
      pendingResult = result
      let scanner = VNDocumentCameraViewController()
      scanner.delegate = self
      host.present(scanner, animated: true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Resolved at scan time rather than captured at registration: with the
  /// implicit-engine AppDelegate the root controller is not reliably in place
  /// when plugins register, and by now something may be presented over it.
  private static func presenter() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }

  private func finish(_ value: Any?) {
    pendingResult?(value)
    pendingResult = nil
  }
}

extension DocumentScannerPlugin: VNDocumentCameraViewControllerDelegate {
  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFinishWith scan: VNDocumentCameraScan
  ) {
    var pages: [FlutterStandardTypedData] = []
    for index in 0..<scan.pageCount {
      if let data = scan.imageOfPage(at: index).jpegData(compressionQuality: 0.85) {
        pages.append(FlutterStandardTypedData(bytes: data))
      }
    }
    controller.dismiss(animated: true)
    finish(pages)
  }

  func documentCameraViewControllerDidCancel(
    _ controller: VNDocumentCameraViewController
  ) {
    controller.dismiss(animated: true)
    finish([])
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFailWithError error: Error
  ) {
    controller.dismiss(animated: true)
    finish(FlutterError(code: "failed",
                        message: error.localizedDescription,
                        details: nil))
  }
}
