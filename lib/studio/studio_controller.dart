import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:multitrack_engine/multitrack_engine.dart';

import '../models/project.dart';
import 'project_store.dart';

enum StudioPhase { loading, noPermission, ready, error }

/// App state for the recording screen: owns the project and drives the engine.
class StudioController extends ChangeNotifier {
  StudioController({
    required this.engine,
    required this.store,
    required this.newProjectId,
    String Function()? idGenerator,
  }) : _newId =
           idGenerator ??
           (() => DateTime.now().microsecondsSinceEpoch.toRadixString(36));

  final MultitrackEngine engine;
  final ProjectStore store;
  final String newProjectId;
  final String Function() _newId;

  StudioPhase phase = StudioPhase.loading;
  String? errorMessage;
  late Project project;
  EngineStatus status = EngineStatus.idle;
  StreamSubscription<EngineStatus>? _sub;
  String? _pendingTrackId;

  bool get isPlaying => status.isPlaying;
  bool get isRecording => _pendingTrackId != null;
  bool exporting = false;

  Future<void> init() async {
    project = await store.load() ?? Project(id: newProjectId);
    try {
      if (!await engine.requestPermission()) {
        phase = StudioPhase.noPermission;
        notifyListeners();
        return;
      }
      await engine.initialize();
      await _syncEngine();
      _sub = engine.status.listen(_onStatus);
      phase = StudioPhase.ready;
    } catch (e) {
      phase = StudioPhase.error;
      errorMessage = '$e';
    }
    notifyListeners();
  }

  void _onStatus(EngineStatus s) {
    status = s;
    // Playback reached the end of the song.
    if (s.isPlaying &&
        !isRecording &&
        project.tracks.isNotEmpty &&
        s.positionSeconds > project.lengthSeconds + 0.2) {
      unawaited(stop());
    }
    notifyListeners();
  }

  Future<void> _syncEngine() async {
    await engine.setMetronome(
      MetronomeSettings(
        enabled: project.metronomeOn,
        bpm: project.bpm,
        beatsPerBar: project.beatsPerBar,
        countInBars: project.countInBars,
      ),
    );
    await engine.setTracks([
      for (final t in project.tracks)
        EngineTrack(
          id: t.id,
          path: store.audioPath(t.fileName),
          volume: t.volume,
          pan: t.pan,
          muted: !project.isAudible(t),
        ),
    ]);
    await engine.setMasterVolume(project.masterVolume);
  }

  Future<void> _commit() async {
    notifyListeners();
    await store.save(project);
    await _syncEngine();
  }

  // Transport ---------------------------------------------------------------

  Future<void> play() async {
    if (isRecording) return;
    await engine.play();
  }

  Future<void> stop() async {
    if (isRecording) {
      await stopRecording();
    } else {
      await engine.stop();
    }
  }

  Future<void> toggleRecord() =>
      isRecording ? stopRecording() : startRecording();

  Future<void> startRecording() async {
    if (isRecording) return;
    final id = _newId();
    _pendingTrackId = id;
    notifyListeners();
    try {
      await engine.startRecording(store.audioPath('take_$id.wav'));
    } catch (e) {
      _pendingTrackId = null;
      errorMessage = '$e';
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    final id = _pendingTrackId;
    if (id == null) return;
    _pendingTrackId = null;
    final RecordingResult result;
    try {
      result = await engine.stopRecording();
    } catch (e) {
      errorMessage = '$e';
      notifyListeners();
      return;
    }
    if (result.durationSeconds < 0.2) {
      // Stopped during the count-in: nothing worth keeping.
      await store.deleteAudio('take_$id.wav');
      notifyListeners();
      return;
    }
    project.tracks.add(
      Track(
        id: id,
        name: 'Ścieżka ${project.tracks.length + 1}',
        fileName: 'take_$id.wav',
        durationSeconds: result.durationSeconds,
        colorIndex: project.tracks.length,
      ),
    );
    await _commit();
  }

  // Tempo -------------------------------------------------------------------

  Future<void> setBpm(double bpm) async {
    project.bpm = bpm.clamp(40, 240).roundToDouble();
    await _commit();
  }

  Future<void> toggleMetronome() async {
    project.metronomeOn = !project.metronomeOn;
    await _commit();
  }

  Future<void> setCountInBars(int bars) async {
    project.countInBars = bars.clamp(0, 4);
    await _commit();
  }

  // Tracks ------------------------------------------------------------------

  Future<void> setVolume(Track t, double v) async {
    t.volume = v;
    await _commit();
  }

  Future<void> toggleMute(Track t) async {
    t.muted = !t.muted;
    await _commit();
  }

  Future<void> toggleSolo(Track t) async {
    t.solo = !t.solo;
    await _commit();
  }

  Future<void> setPan(Track t, double pan) async {
    t.pan = pan.clamp(-1.0, 1.0);
    await _commit();
  }

  Future<void> setMasterVolume(double v) async {
    project.masterVolume = v.clamp(0.0, 1.0);
    await _commit();
  }

  Future<void> renameProject(String name) async {
    if (name.trim().isEmpty) return;
    project.name = name.trim();
    await _commit();
  }

  // Export ------------------------------------------------------------------

  String get _exportDir => store.audioPath('exports');

  /// Renders the whole song as heard (mute/solo/volume/pan/master).
  /// Returns the file path, or null on error ([errorMessage] is set).
  Future<String?> exportMix(ExportFormat format) async {
    final path = '$_exportDir/${safeFileName(project.name)}.${format.name}';
    final ok = await _export(
      () => engine.exportMix(
        tracks: [
          for (final t in project.tracks)
            EngineTrack(
              id: t.id,
              path: store.audioPath(t.fileName),
              volume: t.volume,
              pan: t.pan,
              muted: !project.isAudible(t),
            ),
        ],
        outputPath: path,
        format: format,
        masterVolume: project.masterVolume,
      ),
    );
    return ok ? path : null;
  }

  /// Each track on its own, raw (full volume, centre), for use in a DAW.
  Future<List<String>> exportStems(ExportFormat format) async {
    final paths = <String>[];
    final song = safeFileName(project.name);
    for (final (i, t) in project.tracks.indexed) {
      final path =
          '$_exportDir/$song - ${(i + 1).toString().padLeft(2, '0')} ${safeFileName(t.name)}.${format.name}';
      final ok = await _export(
        () => engine.exportMix(
          tracks: [EngineTrack(id: t.id, path: store.audioPath(t.fileName))],
          outputPath: path,
          format: format,
        ),
      );
      if (!ok) return [];
      paths.add(path);
    }
    return paths;
  }

  Future<bool> _export(Future<double> Function() run) async {
    if (isRecording) return false;
    if (isPlaying) await engine.stop();
    exporting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await run();
      return true;
    } catch (e) {
      errorMessage = '$e';
      return false;
    } finally {
      exporting = false;
      notifyListeners();
    }
  }

  /// Stops audio and unloads this project's tracks (leaving the screen).
  Future<void> close() async {
    if (isRecording) await stopRecording();
    await _sub?.cancel();
    _sub = null;
    if (phase == StudioPhase.ready) {
      await engine.stop();
      await engine.setTracks(const []);
    }
  }

  Future<void> rename(Track t, String name) async {
    if (name.trim().isEmpty) return;
    t.name = name.trim();
    await _commit();
  }

  Future<void> deleteTrack(Track t) async {
    if (isPlaying) await stop();
    project.tracks.remove(t);
    await _commit();
    await store.deleteAudio(t.fileName);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Turns a song/track name into something safe for a file name.
String safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  return cleaned.isEmpty ? 'utwor' : cleaned;
}
