import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multitrack_engine/multitrack_engine.dart';

import '../audio/normalize.dart';
import '../audio/track_edit.dart';
import '../audio/waveform.dart';
import '../models/project.dart';
import 'audio_settings.dart';
import 'project_store.dart';

enum StudioPhase { loading, noPermission, ready, error }

/// App state for the recording screen: owns the project and drives the engine.
class StudioController extends ChangeNotifier {
  StudioController({
    required this.engine,
    required this.store,
    required this.newProjectId,
    String Function()? idGenerator,
    Future<Waveform?> Function(String path)? waveformLoader,
    Future<double?> Function(String src, String dst)? normalizer,
    Future<double?> Function(String src, String dst, TrackEdit edit)?
    trackEditor,
    String Function(int number)? trackName,
    AudioSettingsStore? settingsStore,
  }) : _loadWaveform = waveformLoader ?? Waveform.load,
       _normalize = normalizer ?? normalizeWav,
       _renderEdit = trackEditor ?? renderTrackEdit,
       _trackName = trackName ?? ((n) => 'Track $n'),
       settingsStore = settingsStore ?? AudioSettingsStore.memory(),
       _newId =
           idGenerator ??
           (() => DateTime.now().microsecondsSinceEpoch.toRadixString(36));

  final MultitrackEngine engine;
  final ProjectStore store;
  final String newProjectId;
  final String Function() _newId;
  final Future<Waveform?> Function(String path) _loadWaveform;
  final Future<double?> Function(String src, String dst) _normalize;
  final Future<double?> Function(String src, String dst, TrackEdit edit)
  _renderEdit;
  final String Function(int number) _trackName;
  final AudioSettingsStore settingsStore;
  AudioSettings audio = AudioSettings();
  String? _appliedRoute;
  bool calibrating = false;

  /// Waveforms by track id, filled in the background.
  final waveforms = <String, Waveform>{};

  /// Input peaks of the take being recorded, at [Waveform.peaksPerSecond].
  final liveLevels = <double>[];

  /// Seconds shown on the shared timeline.
  double get timelineSeconds {
    final live = isRecording
        ? liveLevels.length / Waveform.peaksPerSecond
        : 0.0;
    final len = project.lengthSeconds > live ? project.lengthSeconds : live;
    return len < 1 ? 1 : len;
  }

  StudioPhase phase = StudioPhase.loading;
  String? errorMessage;

  /// Set when a take failed: the engine's error, or '' when the take came
  /// back empty (no sound from the microphone). The screen shows it once and
  /// clears it with [clearRecordingProblem].
  String? recordingProblem;

  void clearRecordingProblem() => recordingProblem = null;
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
      audio = await settingsStore.load();
      await _applyMonitoring();
      await _syncEngine();
      _sub = engine.status.listen(_onStatus);
      unawaited(_loadWaveforms());
      phase = StudioPhase.ready;
    } catch (e) {
      phase = StudioPhase.error;
      errorMessage = '$e';
    }
    notifyListeners();
  }

  void _onStatus(EngineStatus s) {
    status = s;
    if (s.route.isNotEmpty && s.route != _appliedRoute) {
      // New output (headphones plugged in, AirPods connected...): use its
      // own calibration.
      _appliedRoute = s.route;
      unawaited(engine.setLatencyOffset(audio.latencyOffsetsMs[s.route] ?? 0));
    }
    if (isRecording && s.isRecording && s.positionSeconds >= 0) {
      final target = (s.positionSeconds * Waveform.peaksPerSecond).floor();
      while (liveLevels.length < target) {
        liveLevels.add(s.inputLevel);
      }
    }
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
    await engine.setInputGain(project.inputGainDb);
  }

  Future<void> _commit() async {
    notifyListeners();
    try {
      await store.save(project);
    } on FileSystemException catch (e) {
      // Keep the engine in step even if the disk write failed.
      errorMessage = e.message;
      notifyListeners();
    }
    await _syncEngine();
  }

  // Transport ---------------------------------------------------------------

  Future<void> play({double from = 0}) async {
    if (isRecording) return;
    await engine.play(fromSeconds: from);
  }

  /// Jump to [seconds] on the timeline and play from there.
  Future<void> seek(double seconds) async {
    if (isRecording || project.tracks.isEmpty) return;
    final to = seconds.clamp(0.0, project.lengthSeconds);
    await engine.play(fromSeconds: to);
  }

  Future<void> _loadWaveforms() async {
    for (final t in List.of(project.tracks)) {
      if (waveforms.containsKey(t.id)) continue;
      final w = await _loadWaveform(store.audioPath(t.fileName));
      if (w != null) {
        waveforms[t.id] = w;
        notifyListeners();
      }
    }
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
    liveLevels.clear();
    notifyListeners();
    try {
      await engine.startRecording(store.audioPath('take_$id.wav'));
    } catch (e) {
      _pendingTrackId = null;
      recordingProblem = _describe(e);
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    final id = _pendingTrackId;
    if (id == null) return;
    _pendingTrackId = null;
    final pastCountIn = status.isPlaying && status.positionSeconds > 0.5;
    final RecordingResult result;
    try {
      result = await engine.stopRecording();
    } catch (e) {
      recordingProblem = _describe(e);
      notifyListeners();
      return;
    }
    if (result.durationSeconds < 0.2) {
      // Stopped during the count-in: nothing worth keeping. Past it, an
      // empty take means the microphone gave no sound.
      await store.deleteAudio('take_$id.wav');
      if (pastCountIn) recordingProblem = '';
      notifyListeners();
      return;
    }
    project.tracks.add(
      Track(
        id: id,
        name: _trackName(project.tracks.length + 1),
        fileName: 'take_$id.wav',
        durationSeconds: result.durationSeconds,
        colorIndex: project.tracks.length,
      ),
    );
    await _commit();
    unawaited(_loadWaveforms());
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

  /// Sets the mic gain. While a slider is dragged pass `save: false`: the
  /// engine follows at once and the song is saved when the drag ends.
  Future<void> setInputGain(double db, {bool save = true}) async {
    project.inputGainDb = db.clamp(0.0, 36.0).roundToDouble();
    if (!save) {
      notifyListeners();
      await engine.setInputGain(project.inputGainDb);
      return;
    }
    await _commit();
  }

  /// Makes a quiet take louder (peak to -1 dB). Returns false when there was
  /// nothing to do (already loud, silent, or not a float WAV).
  Future<bool> normalizeTrack(Track t) async {
    if (isRecording) return false;
    if (isPlaying) await engine.stop();
    final oldName = t.fileName;
    final newName = 'take_${t.id}_${_newId()}.wav';
    final gain = await _normalize(
      store.audioPath(oldName),
      store.audioPath(newName),
    );
    if (gain == null) return false;
    if (t.isEdited) {
      // Keep the gain so later edits of the original stay louder too.
      final e = t.edit ?? const TrackEdit();
      t.edit = e.copyWith(gain: e.gain * gain);
    }
    t.fileName = newName;
    waveforms.remove(t.id);
    await _commit();
    await store.deleteAudio(oldName);
    unawaited(_loadWaveforms());
    return true;
  }

  // Editing -----------------------------------------------------------------

  /// Waveform of the untouched recording, for the editor.
  Future<Waveform?> originalWaveform(Track t) =>
      _loadWaveform(store.audioPath(t.originalFileName ?? t.fileName));

  /// Length of the untouched recording.
  double originalDuration(Track t) =>
      t.originalDurationSeconds ?? t.durationSeconds;

  /// Applies [edit] to the original recording of [t]. Returns false when
  /// nothing would be left or the file can't be edited.
  Future<bool> editTrack(Track t, TrackEdit edit) async {
    if (isRecording) return false;
    if (isPlaying) await engine.stop();
    final source = t.originalFileName ?? t.fileName;
    final newName = 'take_${t.id}_${_newId()}.wav';
    final duration = await _renderEdit(
      store.audioPath(source),
      store.audioPath(newName),
      edit,
    );
    if (duration == null) return false;
    final old = t.fileName;
    if (!t.isEdited) {
      t.originalFileName = source;
      t.originalDurationSeconds = t.durationSeconds;
    }
    t
      ..fileName = newName
      ..edit = edit
      ..durationSeconds = duration;
    waveforms.remove(t.id);
    await _commit();
    if (old != t.originalFileName) await store.deleteAudio(old);
    unawaited(_loadWaveforms());
    return true;
  }

  /// Goes back to the untouched recording.
  Future<void> resetEdit(Track t) async {
    final original = t.originalFileName;
    if (original == null || isRecording) return;
    if (isPlaying) await engine.stop();
    final old = t.fileName;
    t
      ..fileName = original
      ..durationSeconds = t.originalDurationSeconds ?? t.durationSeconds
      ..originalFileName = null
      ..originalDurationSeconds = null
      ..edit = null;
    waveforms.remove(t.id);
    await _commit();
    await store.deleteAudio(old);
    unawaited(_loadWaveforms());
  }

  // Monitoring & calibration ----------------------------------------------

  Future<void> _applyMonitoring() => engine.setMonitoring(
    enabled: audio.monitorOn,
    volume: audio.monitorVolume,
    reverb: audio.monitorReverb,
  );

  Future<void> setMonitoring({bool? on, double? volume, double? reverb}) async {
    if (on != null) audio.monitorOn = on;
    if (volume != null) audio.monitorVolume = volume.clamp(0.0, 1.0);
    if (reverb != null) audio.monitorReverb = reverb.clamp(0.0, 1.0);
    notifyListeners();
    await _applyMonitoring();
    await settingsStore.save(audio);
  }

  /// Calibration stored for the current output, in ms (null = never run).
  double? get currentOffsetMs => audio.latencyOffsetsMs[status.route];

  /// Measures the round trip on the current output and remembers it.
  /// Returns null on failure ([errorMessage] is set).
  Future<CalibrationResult?> calibrate() async {
    if (isRecording || calibrating) return null;
    if (isPlaying) await engine.stop();
    calibrating = true;
    errorMessage = null;
    notifyListeners();
    try {
      final r = await engine.calibrateLatency();
      final route = r.route.isNotEmpty ? r.route : status.route;
      audio.latencyOffsetsMs[route] = r.offsetMs;
      _appliedRoute = route;
      await settingsStore.save(audio);
      return r;
    } catch (e) {
      errorMessage = '$e';
      return null;
    } finally {
      calibrating = false;
      notifyListeners();
    }
  }

  Future<void> resetCalibration() async {
    audio.latencyOffsetsMs.remove(status.route);
    await engine.setLatencyOffset(0);
    await settingsStore.save(audio);
    notifyListeners();
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
    final original = t.originalFileName;
    if (original != null) await store.deleteAudio(original);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

String _describe(Object e) =>
    e is PlatformException ? (e.message ?? e.code) : '$e';

/// Turns a song/track name into something safe for a file name.
String safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  return cleaned.isEmpty ? 'song' : cleaned;
}
