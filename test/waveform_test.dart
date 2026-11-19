import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:multitrack_recorder/audio/waveform.dart';

/// Builds a WAV with an extra chunk before `data`, like Apple's FLLR padding.
Uint8List wav({
  required int format,
  required int bits,
  required int channels,
  required int rate,
  required List<double> samples,
}) {
  final bps = bits ~/ 8;
  final data = ByteData(samples.length * bps);
  for (final (i, v) in samples.indexed) {
    final o = i * bps;
    switch (bits) {
      case 32 when format == 3:
        data.setFloat32(o, v, Endian.little);
      case 16:
        data.setInt16(o, (v * 32767).round(), Endian.little);
      case 24:
        final x = (v * 8388607).round() & 0xFFFFFF;
        data.setUint8(o, x & 0xFF);
        data.setUint8(o + 1, (x >> 8) & 0xFF);
        data.setUint8(o + 2, (x >> 16) & 0xFF);
    }
  }
  final b = BytesBuilder();
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  b.add('RIFF'.codeUnits);
  u32(0);
  b.add('WAVE'.codeUnits);
  b.add('fmt '.codeUnits);
  u32(16);
  u16(format);
  u16(channels);
  u32(rate);
  u32(rate * bps * channels);
  u16(bps * channels);
  u16(bits);
  b.add('FLLR'.codeUnits);
  u32(3);
  b.add([0, 0, 0, 0]); // 3 bytes + pad byte
  b.add('data'.codeUnits);
  u32(data.lengthInBytes);
  b.add(data.buffer.asUint8List());
  return b.toBytes();
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('wf'));
  tearDown(() => dir.delete(recursive: true));

  Waveform read(Uint8List bytes) {
    final f = File('${dir.path}/t.wav')..writeAsBytesSync(bytes);
    final raf = f.openSync();
    try {
      return Waveform.fromWavReader(raf);
    } finally {
      raf.closeSync();
    }
  }

  // 1 s at 100 Hz → 25 peaks of 4 samples each.
  final rate = 100;
  final samples = [
    for (var i = 0; i < 100; i++) i < 4 ? -0.5 : (i == 99 ? 0.75 : 0.0),
  ];

  test('float32 mono', () {
    final w = read(
      wav(format: 3, bits: 32, channels: 1, rate: rate, samples: samples),
    );
    expect(w.peaks, hasLength(25));
    expect(w.peaks.first, closeTo(0.5, 1e-6));
    expect(w.peaks[10], 0);
    expect(w.peaks.last, closeTo(0.75, 1e-6));
    expect(w.durationSeconds, 1);
  });

  test('16-bit and 24-bit PCM', () {
    for (final bits in [16, 24]) {
      final w = read(
        wav(format: 1, bits: bits, channels: 1, rate: rate, samples: samples),
      );
      expect(w.peaks.first, closeTo(0.5, 1e-3), reason: '$bits bit');
      expect(w.peaks.last, closeTo(0.75, 1e-3), reason: '$bits bit');
    }
  });

  test('not a wav', () {
    expect(
      () => read(Uint8List.fromList('hello world!'.codeUnits)),
      throwsFormatException,
    );
  });
}
