import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:multitrack_engine/multitrack_engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:multitrack_recorder/audio/waveform.dart';
import 'package:multitrack_recorder/models/project.dart';
import 'package:multitrack_recorder/studio/project_library.dart';
import 'package:multitrack_recorder/studio/project_store.dart';
import 'package:multitrack_recorder/ui/studio_screen.dart';
import 'package:multitrack_recorder/ui/l10n.dart';
import 'package:multitrack_recorder/ui/theme.dart';
import 'package:multitrack_recorder/studio/studio_controller.dart';

class FakeEngine implements MultitrackEngine {
  final calls = <String>[];
  final statusCtrl = StreamController<EngineStatus>.broadcast();
  bool permission = true;
  double takeSeconds = 3.5;
  List<EngineTrack> tracks = [];
  MetronomeSettings? metronome;
  String? recordingPath;
  double master = 1;
  double gainDb = 0;

  @override
  Future<void> setInputGain(double db) async => gainDb = db;
  final exports =
      <({List<EngineTrack> tracks, String path, ExportFormat format})>[];

  @override
  Future<void> setMasterVolume(double v) async => master = v;

  @override
  Future<double> exportMix({
    required List<EngineTrack> tracks,
    required String outputPath,
    ExportFormat format = ExportFormat.m4a,
    double masterVolume = 1.0,
  }) async {
    exports.add((tracks: tracks, path: outputPath, format: format));
    return 1;
  }

  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> initialize() async => calls.add('initialize');
  @override
  Future<void> setTracks(List<EngineTrack> t) async => tracks = t;
  @override
  Future<void> setMetronome(MetronomeSettings s) async => metronome = s;
  @override
  Future<void> setLatencyOffset(double ms) async {}
  @override
  Future<void> play({double fromSeconds = 0}) async => calls.add('play');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> startRecording(String path) async {
    recordingPath = path;
    calls.add('record');
  }

  @override
  Future<RecordingResult> stopRecording() async {
    calls.add('stopRecording');
    return RecordingResult(
      path: recordingPath!,
      durationSeconds: takeSeconds,
      latencyCompensationSeconds: 0.01,
    );
  }

  @override
  Stream<EngineStatus> get status => statusCtrl.stream;
}

void main() {
  late Directory dir;
  late FakeEngine engine;
  late StudioController c;
  var n = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mt');
    engine = FakeEngine();
    c = StudioController(
      engine: engine,
      store: ProjectStore(dir),
      newProjectId: 'p1',
      idGenerator: () => 'id${n++}',
      waveformLoader: (path) async => Waveform(Float32List.fromList([0.5, 1])),
      normalizer: (src, dst) async {
        File(dst).writeAsStringSync('louder');
        return 2.0;
      },
    );
  });

  tearDown(() => dir.delete(recursive: true));

  test(
    'recording a take adds a track, saves the project and feeds the engine',
    () async {
      await c.init();
      expect(c.phase, StudioPhase.ready);
      await c.startRecording();
      expect(c.isRecording, isTrue);
      expect(engine.recordingPath, startsWith(dir.path));
      await c.stopRecording();

      expect(c.project.tracks, hasLength(1));
      expect(c.project.tracks.single.name, 'Track 1');
      expect(engine.tracks.single.path, engine.recordingPath);

      final reloaded = await ProjectStore(dir).load();
      expect(reloaded!.tracks.single.durationSeconds, 3.5);
    },
  );

  test('take stopped during count-in is discarded', () async {
    engine.takeSeconds = 0;
    await c.init();
    await c.startRecording();
    await c.stopRecording();
    expect(c.project.tracks, isEmpty);
  });

  test('mute and bpm reach the engine', () async {
    await c.init();
    await c.startRecording();
    await c.stopRecording();
    await c.toggleMute(c.project.tracks.single);
    expect(engine.tracks.single.muted, isTrue);
    await c.setBpm(300);
    expect(engine.metronome!.bpm, 240);
  });

  test('no microphone permission', () async {
    engine.permission = false;
    await c.init();
    expect(c.phase, StudioPhase.noPermission);
  });

  test('project json round trip', () {
    final p = Project(
      id: 'x',
      bpm: 95,
      tracks: [
        Track(
          id: 't',
          name: 'Gitara',
          fileName: 'a.wav',
          durationSeconds: 12,
          muted: true,
        ),
      ],
    );
    final back = Project.fromJson(p.toJson());
    expect(back.bpm, 95);
    expect(back.tracks.single.name, 'Gitara');
    expect(back.tracks.single.muted, isTrue);
    expect(back.lengthSeconds, 12);
  });

  testWidgets('studio screen renders and records', (tester) async {
    await tester.runAsync(c.init);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: StudioScreen(controller: c),
      ),
    );
    expect(find.text('120 BPM'), findsOneWidget);
    expect(find.textContaining('Record your first track'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Record'));
    await tester.pump();
    engine.statusCtrl.add(
      const EngineStatus(
        isPlaying: true,
        isRecording: true,
        isCountingIn: true,
        positionSeconds: -1.2,
        inputLevel: 0.5,
        outputLevel: 0.1,
        beat: 2,
      ),
    );
    await tester.pump();
    expect(find.text('-0:01.2'), findsOneWidget);

    await tester.runAsync(c.stopRecording);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Track 1'), findsOneWidget);
  });

  Future<void> recordTakes(int n) async {
    for (var i = 0; i < n; i++) {
      await c.startRecording();
      await c.stopRecording();
    }
  }

  test('solo silences the other tracks in the engine and in the mix', () async {
    await c.init();
    await recordTakes(3);
    await c.toggleSolo(c.project.tracks[1]);
    expect(engine.tracks.map((t) => t.muted), [true, false, true]);

    await c.toggleMute(c.project.tracks[1]);
    expect(engine.tracks.every((t) => t.muted), isTrue);
  });

  test('pan and master volume reach the engine', () async {
    await c.init();
    await recordTakes(1);
    await c.setPan(c.project.tracks.single, -0.5);
    await c.setMasterVolume(0.7);
    expect(engine.tracks.single.pan, -0.5);
    expect(engine.master, 0.7);
  });

  test('export mix and stems', () async {
    await c.init();
    await recordTakes(2);
    await c.renameProject('Moja/piosenka');
    await c.rename(c.project.tracks[0], 'Gitara');

    final mix = await c.exportMix(ExportFormat.m4a);
    expect(mix, endsWith('/exports/Moja_piosenka.m4a'));
    expect(engine.exports.last.tracks, hasLength(2));

    final stems = await c.exportStems(ExportFormat.wav);
    expect(stems, hasLength(2));
    expect(stems.first, endsWith('/exports/Moja_piosenka - 01 Gitara.wav'));
    expect(engine.exports.last.tracks.single.volume, 1.0);
  });

  test('project library: create, list, delete', () async {
    final lib = ProjectLibrary(Directory('${dir.path}/projects'));
    expect(await lib.list(), isEmpty);
    final a = await lib.create();
    final b = await lib.create();
    expect(b.name, 'Song 2');
    expect(
      (await lib.list()).map((s) => s.project.id),
      containsAll([a.id, b.id]),
    );
    await lib.delete(a.id);
    expect((await lib.list()).single.project.id, b.id);
  });

  test('track count plural and pan label in both languages', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final pl = await AppLocalizations.delegate.load(const Locale('pl'));
    expect(en.trackCount(1), '1 track');
    expect(en.trackCount(3), '3 tracks');
    expect(pl.trackCount(1), '1 ścieżka');
    expect(pl.trackCount(3), '3 ścieżki');
    expect(pl.trackCount(5), '5 ścieżek');
    expect(pl.trackCount(12), '12 ścieżek');
    expect(pl.trackCount(22), '22 ścieżki');
    expect(panLabel(en, -0.4), 'L40');
    expect(panLabel(en, 0.25), 'R25');
    expect(panLabel(pl, 0.25), 'P25');
    expect(panLabel(en, 0), 'C');
  });

  test('English by default, Polish only for a Polish phone', () {
    expect(resolveAppLocale(null), const Locale('en'));
    expect(resolveAppLocale([const Locale('de')]), const Locale('en'));
    expect(resolveAppLocale([const Locale('pl', 'PL')]), const Locale('pl'));
    expect(
      resolveAppLocale([const Locale('en'), const Locale('pl')]),
      const Locale('en'),
    );
  });

  test(
    'live levels follow the recording and waveforms load for new takes',
    () async {
      await c.init();
      await c.startRecording();
      EngineStatus st(double pos) => EngineStatus(
        isPlaying: true,
        isRecording: true,
        isCountingIn: pos < 0,
        positionSeconds: pos,
        inputLevel: 0.4,
        outputLevel: 0,
        beat: 0,
      );
      engine.statusCtrl.add(st(-0.5));
      engine.statusCtrl.add(st(1.0));
      await Future<void>.delayed(Duration.zero);
      expect(c.liveLevels, hasLength(Waveform.peaksPerSecond));
      expect(c.timelineSeconds, 1.0);

      await c.stopRecording();
      await Future<void>.delayed(Duration.zero);
      expect(c.waveforms[c.project.tracks.single.id]!.peaks, [0.5, 1]);
    },
  );

  test('seek clamps to the song length', () async {
    await c.init();
    await recordTakes(1); // 3.5 s
    final played = <double>[];
    final seekEngine = _SeekEngine(engine, played);
    final c2 = StudioController(
      engine: seekEngine,
      store: ProjectStore(dir),
      newProjectId: 'p1',
      waveformLoader: (_) async => null,
    );
    await c2.init();
    await c2.seek(10);
    await c2.seek(-1);
    expect(played, [3.5, 0]);
  });

  test('input gain reaches the engine and new songs inherit it', () async {
    await c.init();
    expect(engine.gainDb, 12);
    await c.setInputGain(24.4);
    expect(engine.gainDb, 24);

    final lib = ProjectLibrary(dir.parent.createTempSync('lib'));
    final first = await lib.create();
    final store = lib.storeFor(first.id);
    first.inputGainDb = 30;
    await store.save(first);
    expect((await lib.create()).inputGainDb, 30);
  });

  test('normalize swaps the take file and reloads it', () async {
    await c.init();
    await recordTakes(1);
    final t = c.project.tracks.single;
    final old = t.fileName;
    File(c.store.audioPath(old)).writeAsStringSync('quiet');
    expect(await c.normalizeTrack(t), isTrue);
    expect(t.fileName, isNot(old));
    expect(File(c.store.audioPath(old)).existsSync(), isFalse);
    expect(engine.tracks.single.path, endsWith(t.fileName));
  });
}

class _SeekEngine extends FakeEngine {
  _SeekEngine(FakeEngine _, this.played);
  final List<double> played;

  @override
  Future<void> play({double fromSeconds = 0}) async => played.add(fromSeconds);
}
