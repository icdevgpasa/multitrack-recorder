import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Peak values (0.0 – 1.0) at a fixed rate of [Waveform.peaksPerSecond], so
/// every track shares the same time axis.
class Waveform {
  const Waveform(this.peaks);

  static const peaksPerSecond = 25;

  final Float32List peaks;

  double get durationSeconds => peaks.length / peaksPerSecond;

  /// Reads a WAV file (16/24/32-bit PCM or 32-bit float) in a background
  /// isolate. Returns null when the file is missing or not a WAV we know.
  static Future<Waveform?> load(String path) =>
      compute(_loadSync, path, debugLabel: 'waveform');

  static Waveform? _loadSync(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final raf = file.openSync();
    try {
      return fromWavReader(raf);
    } on FormatException {
      return null;
    } finally {
      raf.closeSync();
    }
  }

  /// Streams the data chunk in blocks so long takes don't load into memory.
  @visibleForTesting
  static Waveform fromWavReader(RandomAccessFile raf) {
    final header = raf.readSync(12);
    if (header.length < 12 ||
        String.fromCharCodes(header, 0, 4) != 'RIFF' ||
        String.fromCharCodes(header, 8, 12) != 'WAVE') {
      throw const FormatException('Not a WAV file');
    }

    int? format, channels, sampleRate, bits;
    while (true) {
      final ch = raf.readSync(8);
      if (ch.length < 8) throw const FormatException('No data chunk');
      final id = String.fromCharCodes(ch, 0, 4);
      final size = ByteData.sublistView(ch).getUint32(4, Endian.little);
      if (id == 'fmt ') {
        final f = ByteData.sublistView(raf.readSync(size));
        format = f.getUint16(0, Endian.little);
        channels = f.getUint16(2, Endian.little);
        sampleRate = f.getUint32(4, Endian.little);
        bits = f.getUint16(14, Endian.little);
        if (format == 0xFFFE && size >= 26) {
          // WAVE_FORMAT_EXTENSIBLE: real format is the sub-format GUID's start.
          format = f.getUint16(24, Endian.little);
        }
        if (size.isOdd) raf.readSync(1);
      } else if (id == 'data') {
        if (format == null) throw const FormatException('data before fmt');
        return _readPeaks(raf, size, format, channels!, sampleRate!, bits!);
      } else {
        raf.setPositionSync(raf.positionSync() + size + (size & 1));
      }
    }
  }

  static Waveform _readPeaks(
    RandomAccessFile raf,
    int dataSize,
    int format,
    int channels,
    int sampleRate,
    int bits,
  ) {
    final isFloat = format == 3;
    if (!(isFloat && bits == 32) &&
        !(format == 1 && const [16, 24, 32].contains(bits))) {
      throw FormatException('Unsupported WAV: format $format, $bits bit');
    }
    final bytesPerSample = bits ~/ 8;
    final frameBytes = bytesPerSample * channels;
    final totalFrames = dataSize ~/ frameBytes;
    final framesPerPeak = math.max(1, sampleRate ~/ peaksPerSecond);
    final peaks = Float32List((totalFrames / framesPerPeak).ceil());

    const blockFrames = 32768;
    var frame = 0;
    var peakIndex = 0;
    var current = 0.0;
    var inPeak = 0;
    while (frame < totalFrames) {
      final n = math.min(blockFrames, totalFrames - frame);
      final bytes = raf.readSync(n * frameBytes);
      if (bytes.isEmpty) break;
      final data = ByteData.sublistView(bytes);
      final framesRead = bytes.length ~/ frameBytes;
      for (var i = 0; i < framesRead; i++) {
        // Channel 0 is enough for a picture.
        final o = i * frameBytes;
        final double v = switch (bits) {
          32 when isFloat => data.getFloat32(o, Endian.little).abs(),
          32 => data.getInt32(o, Endian.little).abs() / 2147483648.0,
          24 => _int24(data, o).abs() / 8388608.0,
          _ => data.getInt16(o, Endian.little).abs() / 32768.0,
        };
        if (v > current) current = v;
        if (++inPeak == framesPerPeak) {
          if (peakIndex < peaks.length) {
            peaks[peakIndex++] = math.min(1, current);
          }
          current = 0;
          inPeak = 0;
        }
      }
      frame += framesRead;
    }
    if (inPeak > 0 && peakIndex < peaks.length) {
      peaks[peakIndex] = math.min(1, current);
    }
    return Waveform(peaks);
  }

  static int _int24(ByteData d, int o) {
    final v =
        d.getUint8(o) | (d.getUint8(o + 1) << 8) | (d.getUint8(o + 2) << 16);
    return v & 0x800000 != 0 ? v - 0x1000000 : v;
  }
}
