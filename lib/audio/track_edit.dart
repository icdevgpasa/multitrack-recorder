import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Non-destructive edit of a take, always applied to the original recording.
///
/// Times are in seconds of the original file. The kept region
/// [trimStart, trimEnd] plays at song time `trimStart + shift`.
@immutable
class TrackEdit {
  const TrackEdit({
    this.trimStart = 0,
    this.trimEnd,
    this.shift = 0,
    this.fadeIn = 0,
    this.fadeOut = 0,
    this.gain = 1,
  });

  factory TrackEdit.fromJson(Map<String, dynamic> j) => TrackEdit(
    trimStart: (j['trimStart'] as num?)?.toDouble() ?? 0,
    trimEnd: (j['trimEnd'] as num?)?.toDouble(),
    shift: (j['shift'] as num?)?.toDouble() ?? 0,
    fadeIn: (j['fadeIn'] as num?)?.toDouble() ?? 0,
    fadeOut: (j['fadeOut'] as num?)?.toDouble() ?? 0,
    gain: (j['gain'] as num?)?.toDouble() ?? 1,
  );

  final double trimStart;

  /// End of the kept region; null keeps everything to the end.
  final double? trimEnd;

  /// Positive moves the take later, negative earlier.
  final double shift;
  final double fadeIn;
  final double fadeOut;

  /// Linear gain (from "make louder").
  final double gain;

  TrackEdit copyWith({
    double? trimStart,
    double? trimEnd,
    double? shift,
    double? fadeIn,
    double? fadeOut,
    double? gain,
  }) => TrackEdit(
    trimStart: trimStart ?? this.trimStart,
    trimEnd: trimEnd ?? this.trimEnd,
    shift: shift ?? this.shift,
    fadeIn: fadeIn ?? this.fadeIn,
    fadeOut: fadeOut ?? this.fadeOut,
    gain: gain ?? this.gain,
  );

  Map<String, dynamic> toJson() => {
    'trimStart': trimStart,
    'trimEnd': ?trimEnd,
    'shift': shift,
    'fadeIn': fadeIn,
    'fadeOut': fadeOut,
    'gain': gain,
  };

  @override
  bool operator ==(Object other) =>
      other is TrackEdit &&
      other.trimStart == trimStart &&
      other.trimEnd == trimEnd &&
      other.shift == shift &&
      other.fadeIn == fadeIn &&
      other.fadeOut == fadeOut &&
      other.gain == gain;

  @override
  int get hashCode =>
      Object.hash(trimStart, trimEnd, shift, fadeIn, fadeOut, gain);
}

/// Renders [edit] of the 32-bit float WAV at [src] into a new float WAV at
/// [dst]. Returns the new length in seconds, or null when [src] is not a
/// float WAV or nothing would be left.
Future<double?> renderTrackEdit(String src, String dst, TrackEdit edit) =>
    compute(_render, (src, dst, edit), debugLabel: 'trackEdit');

double? _render((String, String, TrackEdit) args) {
  final (src, dst, e) = args;
  final bytes = File(src).readAsBytesSync();
  final d = ByteData.sublistView(bytes);
  if (bytes.length < 12 ||
      String.fromCharCodes(bytes, 0, 4) != 'RIFF' ||
      String.fromCharCodes(bytes, 8, 12) != 'WAVE') {
    return null;
  }
  var pos = 12;
  int? format, bits, channels, rate;
  while (pos + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, pos, pos + 4);
    final size = d.getUint32(pos + 4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ') {
      format = d.getUint16(body, Endian.little);
      channels = d.getUint16(body + 2, Endian.little);
      rate = d.getUint32(body + 4, Endian.little);
      bits = d.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE && size >= 26) {
        format = d.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      if (format != 3 || bits != 32 || channels == null || rate == null) {
        return null;
      }
      final ch = channels;
      final frames = (math.min(bytes.length, body + size) - body) ~/ (4 * ch);
      int frame(double s) => (s * rate!).round().clamp(0, frames);

      final a = frame(e.trimStart);
      final b = e.trimEnd == null ? frames : frame(e.trimEnd!);
      if (b <= a) return null;
      final keptFrames = b - a;
      final fadeInF = math.min(keptFrames, (e.fadeIn * rate).round());
      final fadeOutF = math.min(keptFrames, (e.fadeOut * rate).round());

      // Where the kept region lands in the song; before 0 is cut off.
      final startAt = ((e.trimStart + e.shift) * rate).round();
      final lead = math.max(0, startAt);
      final skip = math.max(0, -startAt);
      if (skip >= keptFrames) return null;
      final outFrames = lead + keptFrames - skip;

      final out = ByteData(44 + outFrames * ch * 4);
      _writeHeader(out, ch, rate, outFrames);
      for (var i = skip; i < keptFrames; i++) {
        var g = e.gain;
        if (i < fadeInF) g *= i / fadeInF;
        final fromEnd = keptFrames - 1 - i;
        if (fromEnd < fadeOutF) g *= fromEnd / fadeOutF;
        final si = body + (a + i) * ch * 4;
        final oi = 44 + (lead + i - skip) * ch * 4;
        for (var c = 0; c < ch; c++) {
          final v = d.getFloat32(si + c * 4, Endian.little) * g;
          out.setFloat32(oi + c * 4, v.clamp(-1.0, 1.0), Endian.little);
        }
      }
      File(dst).writeAsBytesSync(out.buffer.asUint8List(), flush: true);
      return outFrames / rate;
    }
    pos = body + size + (size & 1);
  }
  return null;
}

void _writeHeader(ByteData o, int channels, int rate, int frames) {
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      o.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  final dataSize = frames * channels * 4;
  tag(0, 'RIFF');
  o.setUint32(4, 36 + dataSize, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  o.setUint32(16, 16, Endian.little);
  o.setUint16(20, 3, Endian.little); // IEEE float
  o.setUint16(22, channels, Endian.little);
  o.setUint32(24, rate, Endian.little);
  o.setUint32(28, rate * channels * 4, Endian.little);
  o.setUint16(32, channels * 4, Endian.little);
  o.setUint16(34, 32, Endian.little);
  tag(36, 'data');
  o.setUint32(40, dataSize, Endian.little);
}
