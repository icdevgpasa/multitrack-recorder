import AVFoundation

struct TrackConfig {
  let id: String
  let path: String
  let volume: Float
  let pan: Float
  let muted: Bool

  init(_ m: [String: Any]) {
    id = m["id"] as? String ?? UUID().uuidString
    path = m["path"] as? String ?? ""
    volume = (m["volume"] as? NSNumber)?.floatValue ?? 1
    pan = (m["pan"] as? NSNumber)?.floatValue ?? 0
    muted = m["muted"] as? Bool ?? false
  }
}

struct MetronomeConfig: Equatable {
  var enabled = true
  var bpm: Double = 120
  var beatsPerBar = 4
  var countInBars = 1
  var volume: Float = 0.6

  init() {}

  init(_ m: [String: Any]) {
    enabled = m["enabled"] as? Bool ?? true
    bpm = max(20, min(400, (m["bpm"] as? NSNumber)?.doubleValue ?? 120))
    beatsPerBar = max(1, (m["beatsPerBar"] as? NSNumber)?.intValue ?? 4)
    countInBars = max(0, (m["countInBars"] as? NSNumber)?.intValue ?? 1)
    volume = (m["volume"] as? NSNumber)?.floatValue ?? 0.6
  }

  var beatSeconds: Double { 60 / bpm }
  var barSeconds: Double { beatSeconds * Double(beatsPerBar) }
}

enum EngineError: LocalizedError {
  case noInput
  case notRecording
  case cannotOpen(String)
  case nothingToExport
  case renderFailed

  var errorDescription: String? {
    switch self {
    case .noInput: return "No audio input available (microphone permission?)"
    case .notRecording: return "Not recording"
    case .cannotOpen(let p): return "Cannot open audio file: \(p)"
    case .nothingToExport: return "Nothing to export (all tracks muted?)"
    case .renderFailed: return "Rendering the mix failed"
    }
  }
}

/// Multi-track engine: plays existing takes while recording a new one, with a
/// sample-accurate metronome and round-trip latency compensation.
///
/// Timing model: every node is started at an explicit host time. `songStartHost`
/// is the render time of song position 0. A sound rendered at host time T is
/// heard at T + outputLatency, the musician plays along, and it reaches the tap
/// at about + inputLatency. So the recorded take starts at
/// `songStartHost + inputLatency + outputLatency + manualOffset`.
final class AudioEngine {
  private let engine = AVAudioEngine()
  private var players: [String: (node: AVAudioPlayerNode, file: AVAudioFile, path: String)] = [:]
  private let clickNode = AVAudioPlayerNode()
  private var clickBar: AVAudioPCMBuffer?
  private var metronome = MetronomeConfig()
  private var manualOffset: Double = 0
  private var graphReady = false

  // Transport (main thread).
  private(set) var isPlaying = false
  private var songStartHost: UInt64 = 0
  private var songStartPosition: Double = 0

  // Shared with the audio tap threads, guarded by `lock`.
  private let lock = NSLock()
  private var writer: AVAudioFile?
  private var recordingPath: String?
  private var recordFromHost: UInt64 = 0
  private var framesWritten: AVAudioFramePosition = 0
  private var appliedLatency: Double = 0
  private var inputPeak: Float = 0
  private var outputPeak: Float = 0
  private let spectrum = SpectrumAnalyzer()

  init() {
    let nc = NotificationCenter.default
    nc.addObserver(
      self, selector: #selector(configurationChanged),
      name: .AVAudioEngineConfigurationChange, object: engine)
    nc.addObserver(
      self, selector: #selector(interrupted(_:)),
      name: AVAudioSession.interruptionNotification, object: nil)
  }

  static func requestPermission(_ done: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission(completionHandler: done)
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission(done)
    }
  }

  // MARK: - Engine lifecycle

  func start() throws {
    if engine.isRunning { return }
    let session = AVAudioSession.sharedInstance()
    // .measurement switches off the voice processing / AGC that would
    // squash an instrument.
    try session.setCategory(
      .playAndRecord, mode: .measurement,
      options: [.defaultToSpeaker, .allowBluetoothA2DP])
    try session.setPreferredIOBufferDuration(0.005)
    try session.setActive(true)

    if !graphReady {
      engine.attach(clickNode)
      graphReady = true
    }
    let outRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
    let clickFormat = AVAudioFormat(standardFormatWithSampleRate: outRate, channels: 1)!
    engine.connect(clickNode, to: engine.mainMixerNode, format: clickFormat)
    clickBar = nil
    try installTaps()
    engine.prepare()
    try engine.start()
  }

  private func installTaps() throws {
    let input = engine.inputNode
    input.removeTap(onBus: 0)
    engine.mainMixerNode.removeTap(onBus: 0)

    let inFormat = input.outputFormat(forBus: 0)
    guard inFormat.channelCount > 0, inFormat.sampleRate > 0 else { throw EngineError.noInput }
    input.installTap(onBus: 0, bufferSize: 512, format: inFormat) { [weak self] buffer, when in
      self?.handleInput(buffer, when)
    }
    engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
      guard let self = self else { return }
      let p = Self.peak(buffer)
      self.lock.lock()
      self.outputPeak = max(self.outputPeak, p)
      // While recording the spectrum follows the input instead.
      if self.writer == nil, let ch = buffer.floatChannelData {
        self.spectrum.process(
          ch[0], count: Int(buffer.frameLength), sampleRate: buffer.format.sampleRate)
      }
      self.lock.unlock()
    }
  }

  @objc private func configurationChanged() {
    // Route changed (headphones, audio interface...): formats may differ now.
    DispatchQueue.main.async {
      _ = try? self.stopRecording()
      self.stopTransport()
      try? self.start()
    }
  }

  @objc private func interrupted(_ note: Notification) {
    guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw)
    else { return }
    DispatchQueue.main.async {
      if type == .began {
        _ = try? self.stopRecording()
        self.stopTransport()
      } else {
        try? self.start()
      }
    }
  }

  // MARK: - Configuration

  func setTracks(_ configs: [TrackConfig]) throws {
    let wanted = Set(configs.map(\.id))
    for (id, p) in players where !wanted.contains(id) {
      p.node.stop()
      engine.detach(p.node)
      players[id] = nil
    }
    for c in configs {
      if let existing = players[c.id], existing.path != c.path {
        existing.node.stop()
        engine.detach(existing.node)
        players[c.id] = nil
      }
      if players[c.id] == nil {
        let file: AVAudioFile
        do {
          file = try AVAudioFile(forReading: URL(fileURLWithPath: c.path))
        } catch {
          throw EngineError.cannotOpen(c.path)
        }
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
        players[c.id] = (node, file, c.path)
      }
      let node = players[c.id]!.node
      node.volume = c.muted ? 0 : c.volume
      node.pan = c.pan
    }
  }

  func setMetronome(_ config: MetronomeConfig) {
    if config != metronome { clickBar = nil }
    metronome = config
    clickNode.volume = config.volume
  }

  func setMasterVolume(_ v: Float) {
    engine.mainMixerNode.outputVolume = v
  }

  func setLatencyOffset(ms: Double) {
    manualOffset = ms / 1000
  }

  // MARK: - Transport

  /// Starts playback. Returns the host time of song position `from`.
  @discardableResult
  func play(from: Double, countIn: Bool = false) throws -> UInt64 {
    try start()
    stopTransport()

    let countInSeconds =
      countIn && metronome.enabled ? Double(metronome.countInBars) * metronome.barSeconds : 0
    let lead = 0.1  // time to schedule everything before the first sample
    let now = mach_absolute_time()
    let songStart = now + AVAudioTime.hostTime(forSeconds: lead + countInSeconds)

    for (_, p) in players {
      let rate = p.file.processingFormat.sampleRate
      let startFrame = AVAudioFramePosition(from * rate)
      guard startFrame < p.file.length else { continue }
      p.node.scheduleSegment(
        p.file, startingFrame: startFrame,
        frameCount: AVAudioFrameCount(p.file.length - startFrame), at: nil)
      p.node.play(at: AVAudioTime(hostTime: songStart))
    }

    if metronome.enabled, let bar = clickBarBuffer() {
      // Keep the click on the song's bar grid when starting mid-song.
      let intoBar = from.truncatingRemainder(dividingBy: metronome.barSeconds)
      let delay = intoBar < 0.001 ? 0 : metronome.barSeconds - intoBar
      let clickStart = songStart - AVAudioTime.hostTime(forSeconds: countInSeconds)
        + AVAudioTime.hostTime(forSeconds: delay)
      clickNode.scheduleBuffer(bar, at: nil, options: .loops)
      clickNode.play(at: AVAudioTime(hostTime: clickStart))
    }

    songStartHost = songStart
    songStartPosition = from
    isPlaying = true
    return songStart
  }

  func stopTransport() {
    for (_, p) in players { p.node.stop() }
    clickNode.stop()
    isPlaying = false
  }

  // MARK: - Recording

  func startRecording(path: String) throws {
    try start()
    _ = try? stopRecording()

    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let rate = engine.inputNode.outputFormat(forBus: 0).sampleRate
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: rate,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 32,
      AVLinearPCMIsFloatKey: true,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let file = try AVAudioFile(
      forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)

    let session = AVAudioSession.sharedInstance()
    let latency = max(0, session.inputLatency + session.outputLatency + manualOffset)
    let songStart = try play(from: 0, countIn: true)

    lock.lock()
    writer = file
    recordingPath = path
    framesWritten = 0
    appliedLatency = latency
    recordFromHost = songStart + AVAudioTime.hostTime(forSeconds: latency)
    lock.unlock()
  }

  func stopRecording() throws -> [String: Any] {
    lock.lock()
    let file = writer
    let path = recordingPath
    let frames = framesWritten
    let latency = appliedLatency
    writer = nil
    recordingPath = nil
    lock.unlock()

    stopTransport()
    guard let file = file, let path = path else { throw EngineError.notRecording }
    let duration = Double(frames) / file.processingFormat.sampleRate
    return ["path": path, "duration": duration, "latency": latency]
  }

  var isRecording: Bool {
    lock.lock()
    defer { lock.unlock() }
    return writer != nil
  }

  private func handleInput(_ buffer: AVAudioPCMBuffer, _ when: AVAudioTime) {
    let p = Self.peak(buffer)
    lock.lock()
    defer { lock.unlock() }
    inputPeak = max(inputPeak, p)
    guard let writer = writer else { return }
    if let ch = buffer.floatChannelData {
      spectrum.process(ch[0], count: Int(buffer.frameLength), sampleRate: buffer.format.sampleRate)
    }

    var skip: AVAudioFrameCount = 0
    if framesWritten == 0 && when.isHostTimeValid {
      let rate = buffer.format.sampleRate
      if recordFromHost > when.hostTime {
        // Captured before the take's first beat: drop it.
        let s = AVAudioTime.seconds(forHostTime: recordFromHost - when.hostTime)
        skip = AVAudioFrameCount(s * rate)
        if skip >= buffer.frameLength { return }
      } else {
        // First buffer arrived late: pad so the take still lines up.
        let s = AVAudioTime.seconds(forHostTime: when.hostTime - recordFromHost)
        let pad = AVAudioFrameCount(s * rate)
        if pad > 0, let silence = AVAudioPCMBuffer(pcmFormat: writer.processingFormat, frameCapacity: pad) {
          silence.frameLength = pad
          try? writer.write(from: silence)
          framesWritten += AVAudioFramePosition(pad)
        }
      }
    }
    guard let mono = Self.mono(buffer, from: skip, format: writer.processingFormat) else { return }
    do {
      try writer.write(from: mono)
      framesWritten += AVAudioFramePosition(mono.frameLength)
    } catch {
      NSLog("multitrack_engine: write failed: \(error)")
    }
  }

  // MARK: - Status

  func status() -> [String: Any] {
    lock.lock()
    let inPeak = inputPeak
    let outPeak = outputPeak
    let recording = writer != nil
    if !recording && !isPlaying { spectrum.decay() }
    let bands = spectrum.levels.map { Double($0) }
    inputPeak = 0
    outputPeak = 0
    lock.unlock()

    var position = 0.0
    var beat = -1
    if isPlaying {
      let now = mach_absolute_time()
      position =
        now >= songStartHost
        ? AVAudioTime.seconds(forHostTime: now - songStartHost)
        : -AVAudioTime.seconds(forHostTime: songStartHost - now)
      position += songStartPosition
      if metronome.enabled {
        let b = Int(floor(position / metronome.beatSeconds))
        beat = ((b % metronome.beatsPerBar) + metronome.beatsPerBar) % metronome.beatsPerBar
      }
    }
    return [
      "playing": isPlaying,
      "recording": recording,
      "countingIn": isPlaying && position < 0,
      "position": position,
      "inputLevel": Double(inPeak),
      "outputLevel": Double(outPeak),
      "beat": beat,
      "spectrum": bands,
    ]
  }

  // MARK: - Helpers

  /// One bar of clicks (accented first beat), looped by the click node.
  private func clickBarBuffer() -> AVAudioPCMBuffer? {
    if let bar = clickBar { return bar }
    let format = engine.outputNode.outputFormat(forBus: 0)
    let rate = format.sampleRate > 0 ? format.sampleRate : 48_000
    guard let mono = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return nil }
    let frames = AVAudioFrameCount(metronome.barSeconds * rate)
    guard let buf = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: frames),
      let data = buf.floatChannelData?[0]
    else { return nil }
    buf.frameLength = frames
    for i in 0..<Int(frames) { data[i] = 0 }

    let beatFrames = Int(metronome.beatSeconds * rate)
    let clickFrames = min(Int(0.03 * rate), beatFrames)
    for beat in 0..<metronome.beatsPerBar {
      let freq = beat == 0 ? 1600.0 : 1000.0
      let amp: Float = beat == 0 ? 1.0 : 0.7
      let start = beat * beatFrames
      for i in 0..<clickFrames where start + i < Int(frames) {
        let t = Double(i) / rate
        let env = Float(exp(-t * 120))
        data[start + i] = amp * env * Float(sin(2 * .pi * freq * t))
      }
    }
    clickBar = buf
    return buf
  }

  static func peak(_ buffer: AVAudioPCMBuffer) -> Float {
    guard let ch = buffer.floatChannelData else { return 0 }
    var p: Float = 0
    for c in 0..<Int(buffer.format.channelCount) {
      let d = ch[c]
      for i in 0..<Int(buffer.frameLength) { p = max(p, abs(d[i])) }
    }
    return min(1, p)
  }

  /// Copies channel 0 of `buffer` starting at `from` into a mono buffer.
  static func mono(_ buffer: AVAudioPCMBuffer, from: AVAudioFrameCount, format: AVAudioFormat)
    -> AVAudioPCMBuffer?
  {
    guard from < buffer.frameLength, let src = buffer.floatChannelData?[0] else { return nil }
    let count = buffer.frameLength - from
    guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
      let dst = out.floatChannelData?[0]
    else { return nil }
    out.frameLength = count
    dst.update(from: src.advanced(by: Int(from)), count: Int(count))
    return out
  }
}
