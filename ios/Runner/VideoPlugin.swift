import AVFoundation
import AVKit
import Flutter
import Photos
import UIKit

/// Probes, plays and saves video files for notes.
///
/// Works from file URLs only: videos can be gigabytes and must never be
/// loaded into memory. Holds no rules; those live in Dart.
class VideoPlugin: NSObject {
  private static var instance: VideoPlugin?

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = VideoPlugin()
    instance = plugin
    let channel = FlutterMethodChannel(
      name: "hmm/video",
      binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      plugin.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    switch call.method {
    case "beginBackgroundTask":
      beginBackgroundTask(result: result)
      return
    case "releaseAudio":
      // The in-place (video_player) player has closed: hand the audio back
      // so other apps (Music) resume. Errors are ignored, as on full screen.
      try? AVAudioSession.sharedInstance().setActive(
        false, options: .notifyOthersOnDeactivation)
      result(nil)
      return
    case "endBackgroundTask":
      guard let id = args?["id"] as? Int else {
        result(FlutterError(code: "bad_args", message: "Missing id", details: nil))
        return
      }
      endBackgroundTask(id: id, result: result)
      return
    default:
      break
    }

    guard let path = args?["path"] as? String else {
      if call.method == "probe" || call.method == "play" || call.method == "saveToPhotos"
        || call.method == "excludeFromBackup" {
        result(FlutterError(code: "bad_args", message: "Missing path", details: nil))
      } else {
        result(FlutterMethodNotImplemented)
      }
      return
    }
    let url = URL(fileURLWithPath: path)

    switch call.method {
    case "probe":
      let posterPath = args?["posterPath"] as? String
      DispatchQueue.global(qos: .userInitiated).async {
        let value = Self.probe(url: url, posterPath: posterPath)
        DispatchQueue.main.async { result(value) }
      }

    case "play":
      let positionMs = (args?["positionMs"] as? NSNumber)?.int64Value ?? 0
      play(url: url, positionMs: positionMs, result: result)

    case "saveToPhotos":
      saveToPhotos(url: url, result: result)

    case "excludeFromBackup":
      excludeFromBackup(url: url, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: backup + background

  private func excludeFromBackup(url: URL, result: FlutterResult) {
    var target = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try target.setResourceValues(values)
      result(nil)
    } catch {
      result(FlutterError(code: "failed",
                          message: error.localizedDescription,
                          details: nil))
    }
  }

  private var backgroundTasks: [Int: UIBackgroundTaskIdentifier] = [:]

  private func beginBackgroundTask(result: FlutterResult) {
    var taskId = UIBackgroundTaskIdentifier.invalid
    taskId = UIApplication.shared.beginBackgroundTask(withName: "hmm.videoUpload") {
      [weak self] in
      self?.backgroundTasks[taskId.rawValue] = nil
      UIApplication.shared.endBackgroundTask(taskId)
    }
    if taskId == .invalid {
      result(nil)
      return
    }
    backgroundTasks[taskId.rawValue] = taskId
    result(taskId.rawValue)
  }

  private func endBackgroundTask(id: Int, result: FlutterResult) {
    if let taskId = backgroundTasks.removeValue(forKey: id) {
      UIApplication.shared.endBackgroundTask(taskId)
    }
    result(nil)
  }

  // MARK: probe

  private static func probe(url: URL, posterPath: String?) -> [String: Any] {
    let asset = AVURLAsset(url: url)
    var out: [String: Any] = ["posterWritten": false]

    let seconds = CMTimeGetSeconds(asset.duration)
    if seconds.isFinite && seconds >= 0 {
      out["durationMs"] = Int((seconds * 1000).rounded())
    }

    if let track = asset.tracks(withMediaType: .video).first {
      let size = track.naturalSize.applying(track.preferredTransform)
      let width = Int(abs(size.width).rounded())
      let height = Int(abs(size.height).rounded())
      if width > 0 && height > 0 {
        out["width"] = width
        out["height"] = height
      }
    }

    if let posterPath = posterPath {
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 1280, height: 1280)
      let at = seconds.isFinite ? min(1.0, seconds / 2) : 0
      if let image = try? generator.copyCGImage(
        at: CMTime(seconds: at, preferredTimescale: 600), actualTime: nil),
        let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.8),
        (try? data.write(to: URL(fileURLWithPath: posterPath), options: .atomic)) != nil
      {
        out["posterWritten"] = true
      }
    }
    return out
  }

  // MARK: play

  private func play(url: URL, positionMs: Int64, result: @escaping FlutterResult) {
    guard let host = Self.presenter() else {
      result(FlutterError(code: "failed",
                          message: "No view controller to present from",
                          details: nil))
      return
    }
    try? AVAudioSession.sharedInstance().setCategory(.playback)
    try? AVAudioSession.sharedInstance().setActive(true)

    let player = AVPlayer(url: url)
    let controller = ReleasingPlayerViewController()
    controller.player = player
    controller.modalPresentationStyle = .fullScreen
    if positionMs > 0 {
      // Continue where the in-place player stopped.
      player.seek(to: CMTime(value: positionMs, timescale: 1000),
                  toleranceBefore: .zero, toleranceAfter: .zero)
    }
    host.present(controller, animated: true) {
      player.play()
      result(nil)
    }
  }

  /// Resolved at call time: something may be presented over the root by now.
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

  // MARK: save

  private func saveToPhotos(url: URL, result: @escaping FlutterResult) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async { result(false) }
        return
      }
      PHPhotoLibrary.shared().performChanges({
        PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
      }) { success, error in
        DispatchQueue.main.async {
          if success {
            result(true)
          } else {
            result(FlutterError(code: "save_failed",
                                message: error?.localizedDescription,
                                details: nil))
          }
        }
      }
    }
  }
}

/// Hands the audio back when the player closes, so other apps (Music) can
/// resume.
private class ReleasingPlayerViewController: AVPlayerViewController {
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    player?.pause()
    try? AVAudioSession.sharedInstance().setActive(
      false, options: .notifyOthersOnDeactivation)
  }
}
