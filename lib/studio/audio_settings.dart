import 'dart:convert';
import 'dart:io';

/// Device-wide audio settings (not per song): monitoring and the latency
/// calibration for each output (speaker, wired headphones, AirPods...).
class AudioSettings {
  AudioSettings({
    Map<String, double>? latencyOffsetsMs,
    this.monitorOn = false,
    this.monitorVolume = 0.8,
    this.monitorReverb = 0.2,
  }) : latencyOffsetsMs = latencyOffsetsMs ?? {};

  factory AudioSettings.fromJson(Map<String, dynamic> j) => AudioSettings(
    latencyOffsetsMs: {
      for (final e in (j['latencyOffsetsMs'] as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toDouble(),
    },
    monitorOn: j['monitorOn'] as bool? ?? false,
    monitorVolume: (j['monitorVolume'] as num?)?.toDouble() ?? 0.8,
    monitorReverb: (j['monitorReverb'] as num?)?.toDouble() ?? 0.2,
  );

  /// Output route id → correction in ms on top of what iOS reports.
  final Map<String, double> latencyOffsetsMs;
  bool monitorOn;
  double monitorVolume;
  double monitorReverb;

  Map<String, dynamic> toJson() => {
    'latencyOffsetsMs': latencyOffsetsMs,
    'monitorOn': monitorOn,
    'monitorVolume': monitorVolume,
    'monitorReverb': monitorReverb,
  };
}

class AudioSettingsStore {
  AudioSettingsStore(this.file);

  /// In-memory only (tests, previews).
  AudioSettingsStore.memory() : file = null;

  final File? file;
  AudioSettings? _cached;

  Future<AudioSettings> load() async {
    if (_cached != null) return _cached!;
    final f = file;
    if (f != null && await f.exists()) {
      try {
        _cached = AudioSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map),
        );
      } on FormatException {
        _cached = null;
      }
    }
    return _cached ??= AudioSettings();
  }

  Future<void> save(AudioSettings s) async {
    _cached = s;
    final f = file;
    if (f == null) return;
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(s.toJson()));
    await tmp.rename(f.path);
  }
}
