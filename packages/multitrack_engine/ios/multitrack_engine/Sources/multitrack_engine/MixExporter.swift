import AVFoundation

enum ExportFormat: String {
  case wav
  case m4a
}

/// Renders tracks to a stereo file faster than real time, using a separate
/// AVAudioEngine in offline manual-rendering mode (the live engine keeps running).
enum MixExporter {
  static func export(
    tracks: [TrackConfig], masterVolume: Float, to path: String, format: ExportFormat
  ) throws -> Double {
    let audible = tracks.filter { !$0.muted }
    guard !audible.isEmpty else { throw EngineError.nothingToExport }

    var inputs: [(TrackConfig, AVAudioFile)] = []
    for t in audible {
      do {
        inputs.append((t, try AVAudioFile(forReading: URL(fileURLWithPath: t.path))))
      } catch {
        throw EngineError.cannotOpen(t.path)
      }
    }

    let rate = inputs.map { $0.1.processingFormat.sampleRate }.max() ?? 48_000
    guard let renderFormat = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else {
      throw EngineError.cannotOpen(path)
    }

    let engine = AVAudioEngine()
    var players: [AVAudioPlayerNode] = []
    for (cfg, file) in inputs {
      let p = AVAudioPlayerNode()
      engine.attach(p)
      engine.connect(p, to: engine.mainMixerNode, format: file.processingFormat)
      p.volume = cfg.volume
      p.pan = cfg.pan
      p.scheduleFile(file, at: nil)
      players.append(p)
    }
    engine.mainMixerNode.outputVolume = masterVolume

    try engine.enableManualRenderingMode(.offline, format: renderFormat, maximumFrameCount: 4096)
    try engine.start()
    defer {
      players.forEach { $0.stop() }
      engine.stop()
    }
    players.forEach { $0.play() }

    let totalFrames =
      inputs.map {
        AVAudioFramePosition(Double($0.1.length) / $0.1.processingFormat.sampleRate * rate)
      }.max() ?? 0

    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: url)

    let settings: [String: Any]
    switch format {
    case .wav:
      settings = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: rate,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 24,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
      ]
    case .m4a:
      settings = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: rate,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 256_000,
      ]
    }
    let out = try AVAudioFile(
      forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)

    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: engine.manualRenderingFormat,
        frameCapacity: engine.manualRenderingMaximumFrameCount)
    else { throw EngineError.cannotOpen(path) }

    while engine.manualRenderingSampleTime < totalFrames {
      let remaining = totalFrames - engine.manualRenderingSampleTime
      let frames = min(AVAudioFrameCount(remaining), buffer.frameCapacity)
      switch try engine.renderOffline(frames, to: buffer) {
      case .success:
        try out.write(from: buffer)
      case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
        continue
      case .error:
        throw EngineError.renderFailed
      @unknown default:
        throw EngineError.renderFailed
      }
    }
    return Double(totalFrames) / rate
  }
}
