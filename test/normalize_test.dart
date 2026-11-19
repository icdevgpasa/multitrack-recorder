import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:multitrack_recorder/audio/normalize.dart';

import 'waveform_test.dart' show wav;

void main() {
  test(
    'float WAV is scaled to -1 dB; loud or non-float files are left alone',
    () async {
      final dir = await Directory.systemTemp.createTemp('norm');
      addTearDown(() => dir.delete(recursive: true));
      final src = '${dir.path}/a.wav', dst = '${dir.path}/b.wav';

      File(src).writeAsBytesSync(
        wav(
          format: 3,
          bits: 32,
          channels: 1,
          rate: 100,
          samples: [0.1, -0.2, 0.05],
        ),
      );
      final gain = await normalizeWav(src, dst);
      expect(gain, closeTo(normalizeTarget / 0.2, 1e-4));
      final out = File(dst).readAsBytesSync();
      final data = ByteData.sublistView(out, out.length - 12);
      expect(
        data.getFloat32(4, Endian.little),
        closeTo(-normalizeTarget, 1e-4),
      );

      File(src).writeAsBytesSync(
        wav(format: 3, bits: 32, channels: 1, rate: 100, samples: [0.95]),
      );
      expect(await normalizeWav(src, dst), isNull);

      File(src).writeAsBytesSync(
        wav(format: 1, bits: 16, channels: 1, rate: 100, samples: [0.1]),
      );
      expect(await normalizeWav(src, dst), isNull);
    },
  );
}
