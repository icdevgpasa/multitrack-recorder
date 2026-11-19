import Flutter
import UIKit

public class MultitrackEnginePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let engine = AudioEngine()
  private var sink: FlutterEventSink?
  private var timer: Timer?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MultitrackEnginePlugin()
    let methods = FlutterMethodChannel(
      name: "multitrack_engine/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(
      name: "multitrack_engine/status", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    do {
      switch call.method {
      case "requestPermission":
        AudioEngine.requestPermission { granted in
          DispatchQueue.main.async { result(granted) }
        }
      case "initialize":
        try engine.start()
        result(nil)
      case "setTracks":
        let list = call.arguments as? [[String: Any]] ?? []
        try engine.setTracks(list.map(TrackConfig.init))
        result(nil)
      case "setMetronome":
        engine.setMetronome(MetronomeConfig(args))
        result(nil)
      case "setLatencyOffset":
        engine.setLatencyOffset(ms: (call.arguments as? NSNumber)?.doubleValue ?? 0)
        result(nil)
      case "play":
        try engine.play(from: (args["from"] as? NSNumber)?.doubleValue ?? 0)
        result(nil)
      case "stop":
        if engine.isRecording { _ = try engine.stopRecording() }
        engine.stopTransport()
        result(nil)
      case "startRecording":
        guard let path = args["path"] as? String else {
          result(FlutterError(code: "args", message: "path required", details: nil))
          return
        }
        try engine.startRecording(path: path)
        result(nil)
      case "stopRecording":
        result(try engine.stopRecording())
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "engine", message: error.localizedDescription, details: nil))
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
      guard let self = self, let sink = self.sink else { return }
      sink(self.engine.status())
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    timer?.invalidate()
    timer = nil
    sink = nil
    return nil
  }
}
