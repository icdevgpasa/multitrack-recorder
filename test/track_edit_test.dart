import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:multitrack_recorder/audio/track_edit.dart';

import 'waveform_test.dart' show wav;

List<double> samplesOf(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(b, 44);
  return [
    for (var o = 0; o + 4 <= d.lengthInBytes; o += 4)
      d.getFloat32(o, Endian.little),
  ];
}

void main() {
  late Directory dir;
  late String src, dst;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('edit');
    src = '${dir.path}/a.wav';
    dst = '${dir.path}/b.wav';
    // 10 frames per second, 20 frames: 0.01, 0.02 ... 0.20
    File(src).writeAsBytesSync(
      wav(
        format: 3,
        bits: 32,
        channels: 1,
        rate: 10,
        samples: [for (var i = 1; i <= 20; i++) i / 100],
      ),
    );
  });

  tearDown(() => dir.delete(recursive: true));

  test('trim and move later pads silence in front', () async {
    final len = await renderTrackEdit(
      src,
      dst,
      const TrackEdit(trimStart: 0.5, trimEnd: 1.5, shift: 0.3),
    );
    expect(len, closeTo(1.8, 1e-9));
    final s = samplesOf(dst);
    expect(s.take(8), everyElement(0));
    expect(s[8], closeTo(0.06, 1e-6));
    expect(s.last, closeTo(0.15, 1e-6));
  });

  test('moving earlier cuts the start; fades and gain apply', () async {
    final len = await renderTrackEdit(
      src,
      dst,
      const TrackEdit(trimStart: 0.5, shift: -0.7, fadeOut: 0.2, gain: 2),
    );
    expect(len, closeTo(1.3, 1e-9));
    final s = samplesOf(dst);
    expect(s.first, closeTo(0.16, 1e-6)); // frame 7 (0.08) × 2
    expect(s.last, 0); // end of the fade-out
    expect(s[s.length - 2], closeTo(0.19 * 2 * 0.5, 1e-6));

    await renderTrackEdit(src, dst, const TrackEdit(fadeIn: 0.2));
    expect(samplesOf(dst).take(3), [
      0,
      closeTo(0.01, 1e-6),
      closeTo(0.03, 1e-6),
    ]);
  });

  test('nothing left or not a float WAV gives null', () async {
    expect(await renderTrackEdit(src, dst, const TrackEdit(shift: -3)), isNull);
    expect(
      await renderTrackEdit(
        src,
        dst,
        const TrackEdit(trimStart: 1, trimEnd: 1),
      ),
      isNull,
    );
    File(src).writeAsBytesSync(
      wav(format: 1, bits: 16, channels: 1, rate: 10, samples: [0.1]),
    );
    expect(await renderTrackEdit(src, dst, const TrackEdit()), isNull);
  });

  test('json round trip', () {
    const e = TrackEdit(trimStart: 1, trimEnd: 2, shift: -0.1, fadeIn: 0.5);
    expect(TrackEdit.fromJson(e.toJson()), e);
    expect(TrackEdit.fromJson(const TrackEdit().toJson()).trimEnd, isNull);
  });
}
