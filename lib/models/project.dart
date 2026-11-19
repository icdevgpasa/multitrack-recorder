/// Song project: tempo settings plus the recorded tracks.
library;

import '../audio/track_edit.dart';

class Track {
  Track({
    required this.id,
    required this.name,
    required this.fileName,
    required this.durationSeconds,
    this.volume = 0.9,
    this.pan = 0,
    this.muted = false,
    this.solo = false,
    this.colorIndex = 0,
    this.edit,
    this.originalFileName,
    this.originalDurationSeconds,
  });

  factory Track.fromJson(Map<String, dynamic> j) => Track(
    id: j['id'] as String,
    name: j['name'] as String,
    fileName: j['fileName'] as String,
    durationSeconds: (j['durationSeconds'] as num).toDouble(),
    volume: (j['volume'] as num?)?.toDouble() ?? 0.9,
    pan: (j['pan'] as num?)?.toDouble() ?? 0,
    muted: j['muted'] as bool? ?? false,
    solo: j['solo'] as bool? ?? false,
    colorIndex: j['colorIndex'] as int? ?? 0,
    edit: j['edit'] == null
        ? null
        : TrackEdit.fromJson(Map<String, dynamic>.from(j['edit'] as Map)),
    originalFileName: j['originalFileName'] as String?,
    originalDurationSeconds: (j['originalDurationSeconds'] as num?)?.toDouble(),
  );

  final String id;
  String name;

  /// File name relative to the project's folder.
  String fileName;
  double durationSeconds;
  double volume;
  double pan;
  bool muted;
  bool solo;
  int colorIndex;

  /// Current edit (trim, shift, fades), applied to [originalFileName].
  TrackEdit? edit;

  /// The untouched recording, kept while the track is edited.
  String? originalFileName;
  double? originalDurationSeconds;

  bool get isEdited => originalFileName != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fileName': fileName,
    'durationSeconds': durationSeconds,
    'volume': volume,
    'pan': pan,
    'muted': muted,
    'solo': solo,
    'colorIndex': colorIndex,
    'edit': ?edit?.toJson(),
    'originalFileName': ?originalFileName,
    'originalDurationSeconds': ?originalDurationSeconds,
  };
}

class Project {
  Project({
    required this.id,
    this.name = 'New song',
    this.bpm = 120,
    this.beatsPerBar = 4,
    this.metronomeOn = true,
    this.countInBars = 1,
    this.masterVolume = 1.0,
    this.inputGainDb = 12,
    List<Track>? tracks,
  }) : tracks = tracks ?? [];

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'New song',
    bpm: (j['bpm'] as num?)?.toDouble() ?? 120,
    beatsPerBar: j['beatsPerBar'] as int? ?? 4,
    metronomeOn: j['metronomeOn'] as bool? ?? true,
    countInBars: j['countInBars'] as int? ?? 1,
    masterVolume: (j['masterVolume'] as num?)?.toDouble() ?? 1.0,
    inputGainDb: (j['inputGainDb'] as num?)?.toDouble() ?? 12,
    tracks: [
      for (final t in (j['tracks'] as List? ?? const []))
        Track.fromJson(Map<String, dynamic>.from(t as Map)),
    ],
  );

  final String id;
  String name;
  double bpm;
  int beatsPerBar;
  bool metronomeOn;
  int countInBars;
  double masterVolume;

  /// Software gain on the microphone, 0 – 36 dB.
  double inputGainDb;
  final List<Track> tracks;

  bool get anySolo => tracks.any((t) => t.solo);

  /// Whether [t] is heard: not muted, and soloed when any track is soloed.
  bool isAudible(Track t) => !t.muted && (!anySolo || t.solo);

  /// Length of the longest track.
  double get lengthSeconds =>
      tracks.fold(0, (m, t) => t.durationSeconds > m ? t.durationSeconds : m);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bpm': bpm,
    'beatsPerBar': beatsPerBar,
    'metronomeOn': metronomeOn,
    'countInBars': countInBars,
    'masterVolume': masterVolume,
    'inputGainDb': inputGainDb,
    'tracks': [for (final t in tracks) t.toJson()],
  };
}
