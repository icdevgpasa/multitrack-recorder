// Renders App Store screenshots of the real UI with demo data.
//
//   flutter test screenshots/app_screens_test.dart
//   python3 tool/frame_screenshots.py
//
// Raw screens land in screenshots/raw/<locale>/, framed store images in
// fastlane/screenshots/<locale>/ (iPhone 6.9", 1320 x 2868).
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:multitrack_engine/multitrack_engine.dart';
import 'package:multitrack_recorder/audio/waveform.dart';
import 'package:multitrack_recorder/ui/projects_screen.dart';
import 'package:multitrack_recorder/models/project.dart';
import 'package:multitrack_recorder/studio/audio_settings.dart';
import 'package:multitrack_recorder/studio/project_library.dart';
import 'package:multitrack_recorder/studio/project_store.dart';
import 'package:multitrack_recorder/studio/studio_controller.dart';
import 'package:multitrack_recorder/ui/l10n.dart';
import 'package:multitrack_recorder/ui/studio_screen.dart';
import 'package:multitrack_recorder/ui/theme.dart';

import '../test/studio_test.dart' show FakeEngine;

/// iPhone 6.9" (16/17 Pro Max) in points; x3 = 1320 x 2868 px.
const _size = Size(440, 956);
const _dpr = 3.0;

class _Demo {
  const _Demo(this.songs, this.tracks);
  final List<String> songs;
  final List<String> tracks;
}

const _demo = {
  'en-US': _Demo(
    [
      'Midnight Drive',
      'Chorus demo',
      'Band rehearsal',
      'Ballad in D',
      'Summer riff',
      'Acoustic take',
    ],
    ['Guitar', 'Bass', 'Vocals', 'Harmony'],
  ),
  'pl': _Demo(
    [
      'Nocna jazda',
      'Demo refrenu',
      'Próba z zespołem',
      'Ballada w D',
      'Letni riff',
      'Akustycznie',
    ],
    ['Gitara', 'Bas', 'Wokal', 'Chórki'],
  ),
};

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String n) async =>
      ByteData.sublistView(File('$dir/$n').readAsBytesSync());
  await (FontLoader('Roboto')
        ..addFont(f('Roboto-Regular.ttf'))
        ..addFont(f('Roboto-Medium.ttf'))
        ..addFont(f('Roboto-Bold.ttf'))
        ..addFont(f('Roboto-Light.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(f('MaterialIcons-Regular.otf'))).load();
}

/// Plausible-looking peaks: a riff, a bass line, a sung phrase...
Waveform _wave(int kind, double seconds) {
  final rnd = Random(kind * 7 + 1);
  final n = (seconds * Waveform.peaksPerSecond).round();
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final t = i / Waveform.peaksPerSecond;
    final beat = (t * 2) % 1; // 120 BPM
    double v;
    switch (kind % 4) {
      case 0: // strummed guitar
        v = 0.35 + 0.5 * exp(-beat * 4) + 0.1 * rnd.nextDouble();
      case 1: // bass: notes on beats
        v = 0.25 + 0.55 * exp(-((t * 2) % 2) * 1.5) + 0.05 * rnd.nextDouble();
      case 2: // vocals: phrases with breaths
        final phrase = (t % 8) < 6.5 ? 1.0 : 0.05;
        v =
            phrase *
            (0.4 + 0.35 * sin(t * 3.1).abs() + 0.15 * rnd.nextDouble());
      default: // harmony: comes in later, softer
        final on = t > 8 && (t % 8) < 6 ? 1.0 : 0.03;
        v = on * (0.3 + 0.25 * sin(t * 2.3).abs() + 0.1 * rnd.nextDouble());
    }
    out[i] = v.clamp(0.0, 1.0);
  }
  return Waveform(out);
}

List<double> _spectrum(int n, double phase) => [
  for (var i = 0; i < n; i++)
    (0.85 * exp(-i / (n * 0.45)) +
            0.15 * sin(i * 0.9 + phase).abs() +
            0.05 * Random(i).nextDouble())
        .clamp(0.0, 1.0),
];

Widget _app(String locale, Widget home) => MaterialApp(
  locale: Locale(locale.split('-').first),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  debugShowCheckedModeBanner: false,
  theme: buildTheme(),
  home: home,
);

Future<void> _shot(WidgetTester tester, String locale, String name) async {
  final ro = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shot')),
  );
  await tester.runAsync(() async {
    final img = await ro.toImage(pixelRatio: _dpr);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('screenshots/raw/$locale/$name.png')
      ..createSync(recursive: true);
    f.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  for (final locale in _demo.keys) {
    final demo = _demo[locale]!;

    Future<(Directory, StudioController, FakeEngine)> studio(
      WidgetTester tester,
    ) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('shots'),
      ))!;
      final engine = FakeEngine();
      final project = Project(id: 'p', name: demo.songs.first, bpm: 120)
        ..tracks.addAll([
          for (final (i, name) in demo.tracks.indexed)
            Track(
              id: 't$i',
              name: name,
              fileName: 't$i.wav',
              durationSeconds: 32,
              colorIndex: i,
              volume: [0.85, 0.7, 0.95, 0.6][i],
              pan: const [-0.3, 0.0, 0.0, 0.35][i],
            ),
        ]);
      final c = StudioController(
        engine: engine,
        store: ProjectStore(dir),
        newProjectId: 'p',
        waveformLoader: (path) async {
          final m = RegExp(r't(\d)\.wav').firstMatch(path);
          return m == null ? null : _wave(int.parse(m.group(1)!), 32);
        },
        trackName: (n) => demo.tracks[(n - 1) % demo.tracks.length],
        settingsStore: AudioSettingsStore.memory(),
      );
      await tester.runAsync(() async {
        await ProjectStore(dir).save(project);
        await c.init();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      return (dir, c, engine);
    }

    Future<void> setUp(WidgetTester tester) async {
      tester.view.physicalSize = _size * _dpr;
      tester.view.devicePixelRatio = _dpr;
      // Status bar / Dynamic Island and home indicator of a real iPhone.
      tester.view.padding = const FakeViewPadding(
        top: 62 * _dpr,
        bottom: 34 * _dpr,
      );
      tester.view.viewPadding = const FakeViewPadding(
        top: 62 * _dpr,
        bottom: 34 * _dpr,
      );
      addTearDown(tester.view.reset);
    }

    testWidgets('$locale 01 studio playing', (tester) async {
      await setUp(tester);
      final (dir, c, engine) = await studio(tester);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: _app(locale, StudioScreen(controller: c)),
        ),
      );
      for (var i = 0; i < 12; i++) {
        engine.statusCtrl.add(
          EngineStatus(
            isPlaying: true,
            isRecording: false,
            isCountingIn: false,
            positionSeconds: 12.4 + i * 0.05,
            inputLevel: 0,
            outputLevel: 0.7,
            beat: i % 4,
            spectrum: _spectrum(48, i * 0.4),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await _shot(tester, locale, '01_studio');
      c.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    });

    testWidgets('$locale 02 recording', (tester) async {
      await setUp(tester);
      final (dir, c, engine) = await studio(tester);
      // Only the first three tracks; the fourth is being recorded.
      c.project.tracks.removeLast();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: _app(locale, StudioScreen(controller: c)),
        ),
      );
      await tester.runAsync(c.startRecording);
      final w = _wave(3, 32).peaks;
      for (var i = 0; i < 20; i++) {
        final pos = 9.0 + i * 0.25;
        engine.statusCtrl.add(
          EngineStatus(
            isPlaying: true,
            isRecording: true,
            isCountingIn: false,
            positionSeconds: pos,
            inputLevel: w[(pos * Waveform.peaksPerSecond).floor()],
            outputLevel: 0.6,
            beat: i % 4,
            spectrum: _spectrum(48, i * 0.3),
          ),
        );
        await tester.pump(const Duration(milliseconds: 40));
      }
      // Fill the live waveform with the take's shape so far.
      c.liveLevels
        ..clear()
        ..addAll([for (var i = 0; i < 14 * 25; i++) w[i]]);
      engine.statusCtrl.add(
        EngineStatus(
          isPlaying: true,
          isRecording: true,
          isCountingIn: false,
          positionSeconds: 14,
          inputLevel: 0.55,
          outputLevel: 0.6,
          beat: 1,
          spectrum: _spectrum(48, 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      // Show the take being recorded above the transport panel.
      final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
      list.position.jumpTo(list.position.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 60));
      await _shot(tester, locale, '02_recording');
      c.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    });

    testWidgets('$locale 03 export', (tester) async {
      await setUp(tester);
      final (dir, c, _) = await studio(tester);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: _app(locale, StudioScreen(controller: c)),
        ),
      );
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(
        Locale(locale.split('-').first),
      );
      await tester.tap(find.byTooltip(l10n.export));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await _shot(tester, locale, '03_export');
      c.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    });

    testWidgets('$locale 04 song list', (tester) async {
      await setUp(tester);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('shots'),
      ))!;
      final library = ProjectLibrary(Directory('${dir.path}/projects'));
      await tester.runAsync(() async {
        // Oldest first, so the first song ends up on top.
        for (final (i, name) in demo.songs.reversed.indexed) {
          final n = demo.songs.length - i;
          final p = Project(id: 's$i', name: name, bpm: 84.0 + n * 7)
            ..tracks.addAll([
              for (var k = 0; k < 2 + n % 4; k++)
                Track(
                  id: 'k$k',
                  name: demo.tracks[k % 4],
                  fileName: 'k$k.wav',
                  durationSeconds: 40.0 + n * 23.5,
                  colorIndex: k,
                ),
            ]);
          await library.storeFor(p.id).save(p);
          await File('${library.root.path}/${p.id}/project.json')
              .setLastModified(DateTime(2026, 11, 1).add(Duration(hours: i)));
        }
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: _app(
            locale,
            ProjectsScreen(
              library: library,
              engine: FakeEngine(),
              settings: AudioSettingsStore.memory(),
            ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await _shot(tester, locale, '04_songs');
      await tester.runAsync(() => dir.delete(recursive: true));
    });
  }
}
