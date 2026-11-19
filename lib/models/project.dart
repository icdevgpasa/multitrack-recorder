/// Song project: tempo settings plus the recorded tracks.
library;

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
  );

  final String id;
  String name;

  /// File name relative to the project's folder.
  String fileName;
  final double durationSeconds;
  double volume;
  double pan;
  bool muted;
  bool solo;
  int colorIndex;

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
  };
}

class Project {
  Project({
    required this.id,
    this.name = 'Nowy utwór',
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
    name: j['name'] as String? ?? 'Nowy utwór',
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
