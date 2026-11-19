import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../audio/waveform.dart';
import 'theme.dart';

/// Mirrored waveform bars on a shared timeline.
///
/// [peaks] are at [Waveform.peaksPerSecond]; the widget's width represents
/// [timelineSeconds], so tracks of different lengths line up. Bars left of
/// [playheadSeconds] are drawn brighter.
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.peaks,
    required this.timelineSeconds,
    required this.color,
    this.playheadSeconds,
    this.dimmed = false,
    this.height = 44,
  });

  final List<double> peaks;
  final double timelineSeconds;
  final Color color;
  final double? playheadSeconds;
  final bool dimmed;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: _WaveformPainter(
        peaks: peaks,
        timelineSeconds: timelineSeconds,
        color: color,
        playheadSeconds: playheadSeconds,
        dimmed: dimmed,
      ),
    ),
  );
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.timelineSeconds,
    required this.color,
    required this.playheadSeconds,
    required this.dimmed,
  });

  final List<double> peaks;
  final double timelineSeconds;
  final Color color;
  final double? playheadSeconds;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || timelineSeconds <= 0) return;
    const barWidth = 2.0;
    const gap = 1.0;
    final columns = (size.width / (barWidth + gap)).floor();
    final secondsPerColumn = timelineSeconds / columns;
    final peaksPerColumn = secondsPerColumn * Waveform.peaksPerSecond;
    final mid = size.height / 2;
    final playX = playheadSeconds == null
        ? -1.0
        : playheadSeconds! / timelineSeconds * size.width;

    final base = color.withValues(alpha: dimmed ? 0.18 : 0.45);
    final bright = dimmed ? color.withValues(alpha: 0.3) : color;
    final paintBase = Paint()..color = base;
    final paintBright = Paint()..color = bright;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (var c = 0; c < columns; c++) {
      final from = (c * peaksPerColumn).floor();
      if (from >= peaks.length) break;
      final to = math.min(peaks.length, ((c + 1) * peaksPerColumn).ceil());
      var v = 0.0;
      for (var i = from; i < math.max(to, from + 1); i++) {
        if (peaks[i] > v) v = peaks[i];
      }
      // Square root makes quiet playing visible without flattening loud parts.
      final h = math.max(1.5, math.sqrt(v) * (size.height - 4));
      final x = c * (barWidth + gap);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, mid),
          width: barWidth,
          height: h,
        ),
        const Radius.circular(1),
      );
      final played = x < playX;
      if (played && !dimmed) canvas.drawRRect(r, glow);
      canvas.drawRRect(r, played ? paintBright : paintBase);
    }

    if (playX >= 0 && playX <= size.width) {
      canvas.drawRect(
        Rect.fromLTWH(playX - 1, 0, 2, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.peaks != peaks ||
      old.peaks.length != peaks.length ||
      old.timelineSeconds != timelineSeconds ||
      old.playheadSeconds != playheadSeconds ||
      old.color != color ||
      old.dimmed != dimmed;
}

/// Frequency bars with a soft reflection.
class SpectrumBars extends StatelessWidget {
  const SpectrumBars({super.key, required this.levels, this.height = 40});

  final List<double> levels;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _SpectrumPainter(levels)),
  );
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter(this.levels);

  final List<double> levels;

  static const _colors = [
    Color(0xFF7C5CFF),
    Color(0xFF00D1C1),
    Color(0xFFFFB238),
    Color(0xFFFF5CA8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final n = levels.length;
    final slot = size.width / n;
    final barW = slot * 0.62;
    final floor = size.height * 0.78;
    final shader = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, 0),
      _colors,
      const [0, 0.35, 0.7, 1],
    );
    final bar = Paint()..shader = shader;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final h = math.max(2.0, v * floor);
      final x = i * slot + (slot - barW) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, floor - h, barW, h),
          Radius.circular(barW / 2),
        ),
        bar,
      );
      final rh = h * 0.25;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, floor + 2, barW, rh),
          Radius.circular(barW / 2),
        ),
        Paint()
          ..color = _colors[(i * _colors.length) ~/ n].withValues(alpha: 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) => true;
}

/// Dark gradient with slowly drifting colour glows that swell with the music
/// and flash softly on each metronome beat.
class ReactiveBackground extends StatefulWidget {
  const ReactiveBackground({
    super.key,
    required this.level,
    required this.beat,
    required this.recording,
    required this.child,
  });

  /// Output (or input while recording) peak, 0.0 – 1.0.
  final double level;
  final int beat;
  final bool recording;
  final Widget child;

  @override
  State<ReactiveBackground> createState() => _ReactiveBackgroundState();
}

class _ReactiveBackgroundState extends State<ReactiveBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  double _energy = 0;
  double _flash = 0;
  int _lastBeat = -1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final target = widget.level.clamp(0.0, 1.0);
      _energy += (target - _energy) * (target > _energy ? 0.35 : 0.06);
      _flash *= 0.9;
      _time.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void didUpdateWidget(ReactiveBackground old) {
    super.didUpdateWidget(old);
    if (widget.beat >= 0 && widget.beat != _lastBeat) {
      _flash = widget.beat == 0 ? 1 : 0.55;
    }
    _lastBeat = widget.beat;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _BackgroundPainter(
                time: _time,
                energy: () => reduceMotion ? 0 : _energy,
                flash: () => reduceMotion ? 0 : _flash,
                recording: widget.recording,
                still: reduceMotion,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({
    required this.time,
    required this.energy,
    required this.flash,
    required this.recording,
    required this.still,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final double Function() energy;
  final double Function() flash;
  final bool recording;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = AppColors.backgroundGradient.createShader(rect),
    );
    final t = still ? 0.0 : time.value;
    final e = energy();
    final f = flash();
    final blobs = [
      (recording ? AppColors.record : AppColors.accent, 0.25, 0.22, 0.07),
      (const Color(0xFF00D1C1), 0.8, 0.45, 0.05),
      (const Color(0xFFFF5CA8), 0.35, 0.8, 0.06),
    ];
    for (final (i, (color, bx, by, speed)) in blobs.indexed) {
      final cx = size.width * (bx + 0.08 * math.sin(t * speed * 6 + i * 2.1));
      final cy = size.height * (by + 0.06 * math.cos(t * speed * 5 + i * 1.3));
      final radius = size.shortestSide * (0.45 + 0.25 * e + 0.08 * f);
      final alpha = (0.10 + 0.22 * e + 0.12 * f).clamp(0.0, 0.5);
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = ui.Gradient.radial(Offset(cx, cy), radius, [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.recording != recording || old.still != still;
}
