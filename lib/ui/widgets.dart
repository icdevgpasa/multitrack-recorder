import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Smoothed horizontal peak meter (fast attack, slow release).
class LevelMeter extends StatefulWidget {
  const LevelMeter({super.key, required this.level, this.height = 6});

  final double level;
  final double height;

  @override
  State<LevelMeter> createState() => _LevelMeterState();
}

class _LevelMeterState extends State<LevelMeter> {
  double _shown = 0;

  @override
  Widget build(BuildContext context) {
    // Display in dB-ish scale so quiet instruments still move the meter.
    final db = widget.level <= 0.0001
        ? -60.0
        : 20 * math.log(widget.level) / math.ln10;
    final target = ((db + 60) / 60).clamp(0.0, 1.0);
    _shown = target > _shown ? target : _shown * 0.85 + target * 0.15;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            Container(color: Colors.white10),
            FractionallySizedBox(
              widthFactor: _shown,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF00D1C1),
                      Color(0xFF8BE04E),
                      Color(0xFFFFB238),
                      AppColors.record,
                    ],
                    stops: [0, 0.6, 0.85, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of dots that light up on each metronome beat.
class BeatDots extends StatelessWidget {
  const BeatDots({
    super.key,
    required this.beats,
    required this.current,
    this.countingIn = false,
  });

  final int beats;
  final int current;
  final bool countingIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < beats; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == 0 ? 12 : 9,
            height: i == 0 ? 12 : 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current
                  ? (countingIn ? AppColors.record : AppColors.accent)
                  : Colors.white12,
              boxShadow: i == current
                  ? [
                      BoxShadow(
                        color:
                            (countingIn ? AppColors.record : AppColors.accent)
                                .withValues(alpha: 0.7),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Big round record button that pulses while recording.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.recording,
    required this.onPressed,
  });

  final bool recording;
  final VoidCallback? onPressed;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didUpdateWidget(RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.recording && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.recording ? 'Zatrzymaj nagrywanie' : 'Nagrywaj',
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = _pulse.value;
            return SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.recording)
                    Container(
                      width: 72 + 24 * t,
                      height: 72 + 24 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.record.withValues(alpha: 1 - t),
                          width: 3,
                        ),
                      ),
                    ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceHigh,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.record.withValues(
                            alpha: widget.recording ? 0.6 : 0.25,
                          ),
                          blurRadius: widget.recording ? 28 : 14,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: widget.recording ? 26 : 50,
                      height: widget.recording ? 26 : 50,
                      decoration: BoxDecoration(
                        color: AppColors.record,
                        borderRadius: BorderRadius.circular(
                          widget.recording ? 6 : 25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
