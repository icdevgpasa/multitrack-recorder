/// Dart side of the native multi-track audio engine.
///
/// Every call goes over a [MethodChannel]; live meters and the transport
/// position arrive on an [EventChannel] as [EngineStatus] snapshots (~30/s).
library;

import 'dart:async';

import 'package:flutter/services.dart';

/// File type for exported audio.
enum ExportFormat {
  /// Compressed AAC, small and easy to share.
  m4a,

  /// 24-bit PCM, lossless (for further work in a DAW).
  wav,
}

/// One track the engine should play back during playback or overdubbing.
class EngineTrack {
  const EngineTrack({
    required this.id,
    required this.path,
    this.volume = 1.0,
    this.pan = 0.0,
    this.muted = false,
  });

  final String id;

  /// Absolute path to an audio file (WAV/CAF/M4A).
  final String path;

  /// 0.0 – 1.0
  final double volume;

  /// -1.0 (left) – 1.0 (right)
  final double pan;
  final bool muted;

  Map<String, Object?> toMap() => {
    'id': id,
    'path': path,
    'volume': volume,
    'pan': pan,
    'muted': muted,
  };
}

/// Metronome / tempo settings.
class MetronomeSettings {
  const MetronomeSettings({
    this.enabled = true,
    this.bpm = 120,
    this.beatsPerBar = 4,
    this.countInBars = 1,
    this.volume = 0.6,
  });

  final bool enabled;
  final double bpm;
  final int beatsPerBar;

  /// Bars of clicks played before recording starts (0 = none).
  final int countInBars;
  final double volume;

  Map<String, Object?> toMap() => {
    'enabled': enabled,
    'bpm': bpm,
    'beatsPerBar': beatsPerBar,
    'countInBars': countInBars,
    'volume': volume,
  };
}

/// Result of a finished take.
class RecordingResult {
  const RecordingResult({
    required this.path,
    required this.durationSeconds,
    required this.latencyCompensationSeconds,
  });

  factory RecordingResult.fromMap(Map<Object?, Object?> m) => RecordingResult(
    path: m['path']! as String,
    durationSeconds: (m['duration']! as num).toDouble(),
    latencyCompensationSeconds: (m['latency']! as num).toDouble(),
  );

  final String path;
  final double durationSeconds;

  /// How much audio was trimmed from the start so the take lines up with
  /// the tracks the musician heard.
  final double latencyCompensationSeconds;
}

/// Live snapshot pushed by the engine.
class EngineStatus {
  const EngineStatus({
    required this.isPlaying,
    required this.isRecording,
    required this.isCountingIn,
    required this.positionSeconds,
    required this.inputLevel,
    required this.outputLevel,
    required this.beat,
    this.spectrum = const [],
  });

  factory EngineStatus.fromMap(Map<Object?, Object?> m) => EngineStatus(
    isPlaying: m['playing'] as bool? ?? false,
    isRecording: m['recording'] as bool? ?? false,
    isCountingIn: m['countingIn'] as bool? ?? false,
    positionSeconds: (m['position'] as num? ?? 0).toDouble(),
    inputLevel: (m['inputLevel'] as num? ?? 0).toDouble(),
    outputLevel: (m['outputLevel'] as num? ?? 0).toDouble(),
    beat: (m['beat'] as num? ?? -1).toInt(),
    spectrum: [
      for (final v in (m['spectrum'] as List? ?? const []))
        (v as num).toDouble(),
    ],
  );

  static const idle = EngineStatus(
    isPlaying: false,
    isRecording: false,
    isCountingIn: false,
    positionSeconds: 0,
    inputLevel: 0,
    outputLevel: 0,
    beat: -1,
  );

  final bool isPlaying;
  final bool isRecording;
  final bool isCountingIn;

  /// Seconds since the start of the song (negative during count-in).
  final double positionSeconds;

  /// Peak levels, 0.0 – 1.0.
  final double inputLevel;
  final double outputLevel;

  /// Current metronome beat index within the bar, or -1.
  final int beat;

  /// Band levels 0.0 – 1.0, low to high frequency (input while recording,
  /// output otherwise). Empty when the engine sends none.
  final List<double> spectrum;
}

class MultitrackEngine {
  MultitrackEngine({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('multitrack_engine/methods'),
      _events = events ?? const EventChannel('multitrack_engine/status');

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<EngineStatus>? _status;

  /// Asks for microphone access. Returns true when granted.
  Future<bool> requestPermission() async =>
      await _methods.invokeMethod<bool>('requestPermission') ?? false;

  /// Configures the audio session and starts the engine (metering begins).
  Future<void> initialize() => _methods.invokeMethod('initialize');

  Future<void> setTracks(List<EngineTrack> tracks) =>
      _methods.invokeMethod('setTracks', tracks.map((t) => t.toMap()).toList());

  Future<void> setMetronome(MetronomeSettings settings) =>
      _methods.invokeMethod('setMetronome', settings.toMap());

  /// Extra manual latency offset (ms) on top of what iOS reports; for
  /// calibration on a specific device/interface.
  Future<void> setLatencyOffset(double milliseconds) =>
      _methods.invokeMethod('setLatencyOffset', milliseconds);

  /// Software gain on the microphone input, 0 – 36 dB (recording and meter).
  Future<void> setInputGain(double db) =>
      _methods.invokeMethod('setInputGain', db);

  /// Output volume of the whole mix (0.0 – 1.0).
  Future<void> setMasterVolume(double volume) =>
      _methods.invokeMethod('setMasterVolume', volume);

  /// Renders [tracks] (offline, faster than real time) into a stereo file at
  /// [outputPath]. Muted tracks are left out. Returns the length in seconds.
  Future<double> exportMix({
    required List<EngineTrack> tracks,
    required String outputPath,
    ExportFormat format = ExportFormat.m4a,
    double masterVolume = 1.0,
  }) async {
    final m = await _methods.invokeMapMethod<Object?, Object?>('exportMix', {
      'tracks': tracks.map((t) => t.toMap()).toList(),
      'path': outputPath,
      'format': format.name,
      'masterVolume': masterVolume,
    });
    return (m!['duration']! as num).toDouble();
  }

  Future<void> play({double fromSeconds = 0}) =>
      _methods.invokeMethod('play', {'from': fromSeconds});

  Future<void> stop() => _methods.invokeMethod('stop');

  /// Plays existing tracks (after the count-in) and records the input into
  /// [outputPath] (WAV).
  Future<void> startRecording(String outputPath) =>
      _methods.invokeMethod('startRecording', {'path': outputPath});

  Future<RecordingResult> stopRecording() async {
    final m = await _methods.invokeMapMethod<Object?, Object?>('stopRecording');
    return RecordingResult.fromMap(m!);
  }

  Stream<EngineStatus> get status => _status ??= _events
      .receiveBroadcastStream()
      .map((e) => EngineStatus.fromMap(e as Map<Object?, Object?>))
      .asBroadcastStream();
}
