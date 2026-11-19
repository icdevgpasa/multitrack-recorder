import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Peak level after normalising (-1 dBFS), leaving a little headroom.
const normalizeTarget = 0.89;

/// Writes a louder copy of a 32-bit float WAV take so its loudest sample
/// reaches [normalizeTarget]. Returns the gain applied, or null when the file
/// is silent, already loud enough, or not a float WAV.
Future<double?> normalizeWav(String src, String dst) =>
    compute(_normalize, (src, dst), debugLabel: 'normalize');

double? _normalize((String, String) args) {
  final (src, dst) = args;
  final bytes = File(src).readAsBytesSync();
  final d = ByteData.sublistView(bytes);
  if (bytes.length < 12 ||
      String.fromCharCodes(bytes, 0, 4) != 'RIFF' ||
      String.fromCharCodes(bytes, 8, 12) != 'WAVE') {
    return null;
  }
  var pos = 12;
  int? format, bits;
  while (pos + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, pos, pos + 4);
    final size = d.getUint32(pos + 4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ') {
      format = d.getUint16(body, Endian.little);
      bits = d.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE && size >= 26) {
        format = d.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      if (format != 3 || bits != 32) return null;
      final end = math.min(bytes.length, body + size);
      var peak = 0.0;
      for (var o = body; o + 4 <= end; o += 4) {
        final v = d.getFloat32(o, Endian.little).abs();
        if (v > peak) peak = v;
      }
      if (peak < 1e-4 || peak >= normalizeTarget) return null;
      final gain = normalizeTarget / peak;
      final out = Uint8List.fromList(bytes);
      final od = ByteData.sublistView(out);
      for (var o = body; o + 4 <= end; o += 4) {
        od.setFloat32(o, d.getFloat32(o, Endian.little) * gain, Endian.little);
      }
      File(dst).writeAsBytesSync(out, flush: true);
      return gain;
    }
    pos = body + size + (size & 1);
  }
  return null;
}
