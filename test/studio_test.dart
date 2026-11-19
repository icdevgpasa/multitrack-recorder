import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multitrack_engine/multitrack_engine.dart';
import 'package:multitrack_recorder/main.dart';
import 'package:multitrack_recorder/models/project.dart';
import 'package:multitrack_recorder/studio/project_store.dart';
import 'package:multitrack_recorder/studio/studio_controller.dart';

class FakeEngine implements MultitrackEngine {
  final calls = <String>[];
  final statusCtrl = StreamController<EngineStatus>.broadcast();
  bool permission = true;
  double takeSeconds = 3.5;
  List<EngineTrack> tracks = [];
  MetronomeSettings? metronome;
  String? recordingPath;

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
      expect(c.project.tracks.single.name, 'Ścieżka 1');
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
    await tester.pumpWidget(MultitrackApp(controller: c));
    expect(find.text('120 BPM'), findsOneWidget);
    expect(find.textContaining('Nagraj pierwszą'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Nagrywaj'));
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
    expect(find.text('Ścieżka 1'), findsOneWidget);
  });
}
