import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../audio/track_edit.dart';
import '../audio/waveform.dart';
import '../models/project.dart';
import '../studio/studio_controller.dart';
import 'l10n.dart';
import 'theme.dart';

/// Trim, fades and moving a take in time.
Future<void> showTrackEditor(
  BuildContext context,
  StudioController c,
  Track t,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: _TrackEditor(controller: c, track: t),
    ),
  );
}

class _TrackEditor extends StatefulWidget {
  const _TrackEditor({required this.controller, required this.track});

  final StudioController controller;
  final Track track;

  @override
  State<_TrackEditor> createState() => _TrackEditorState();
}

class _TrackEditorState extends State<_TrackEditor> {
  late final double _length = widget.controller.originalDuration(widget.track);
  late TrackEdit _edit = widget.track.edit ?? const TrackEdit();
  Waveform? _waveform;
  bool _busy = false;

  static const _title = TextStyle(
    color: AppColors.text,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
  static const _hint = TextStyle(color: AppColors.textDim, fontSize: 13);

  double get _end => _edit.trimEnd ?? _length;
  double get _kept => _end - _edit.trimStart;
  double get _beat => 60 / widget.controller.project.bpm;
  double get _maxShift =>
      math.max(4.0, 2 * widget.controller.project.beatsPerBar * _beat);
  double get _maxFade => math.max(0.0, math.min(5.0, _kept / 2));

  @override
  void initState() {
    super.initState();
    widget.controller.originalWaveform(widget.track).then((w) {
      if (mounted) setState(() => _waveform = w);
    });
  }

  void _set(TrackEdit e) => setState(() {
    _edit = e;
    // Keep fades inside the shorter region.
    if (_edit.fadeIn > _maxFade || _edit.fadeOut > _maxFade) {
      _edit = _edit.copyWith(
        fadeIn: math.min(_edit.fadeIn, _maxFade),
        fadeOut: math.min(_edit.fadeOut, _maxFade),
      );
    }
  });

  void _nudge(double seconds) => _set(
    _edit.copyWith(shift: (_edit.shift + seconds).clamp(-_maxShift, _maxShift)),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = widget.track;
    final color = AppColors.track(t.colorIndex);
    final shiftMs = (_edit.shift * 1000).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.editTrackTitle(t.name), style: _title.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _EditPreviewPainter(
                peaks: _waveform?.peaks ?? const <double>[],
                length: _length,
                edit: _edit,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Trim -----------------------------------------------------------
          Row(
            children: [
              Expanded(child: Text(l.trimTitle, style: _title)),
              Text(
                '${formatTime(_edit.trimStart)} – ${formatTime(_end)}',
                style: _hint,
              ),
            ],
          ),
          Text(l.trimHint, style: _hint),
          SliderTheme(
            data: SliderTheme.of(context)
                .copyWith(activeTrackColor: color, thumbColor: color),
            child: RangeSlider(
              max: _length,
              values: RangeValues(_edit.trimStart, _end),
              onChanged: (r) {
                if (r.end - r.start < 0.1) return;
                _set(
                  TrackEdit(
                    trimStart: r.start,
                    trimEnd: r.end,
                    shift: _edit.shift,
                    fadeIn: _edit.fadeIn,
                    fadeOut: _edit.fadeOut,
                    gain: _edit.gain,
                  ),
                );
              },
            ),
          ),

          // Fades ----------------------------------------------------------
          _FadeRow(
            label: l.fadeIn,
            value: _edit.fadeIn,
            max: _maxFade,
            onChanged: (v) => _set(_edit.copyWith(fadeIn: v)),
          ),
          _FadeRow(
            label: l.fadeOut,
            value: _edit.fadeOut,
            max: _maxFade,
            onChanged: (v) => _set(_edit.copyWith(fadeOut: v)),
          ),
          const Divider(height: 28, color: Colors.white12),

          // Shift ----------------------------------------------------------
          Row(
            children: [
              Expanded(child: Text(l.shiftTitle, style: _title)),
              Text(
                l.shiftValue('${shiftMs > 0 ? '+' : ''}$shiftMs'),
                style: const TextStyle(
                  color: AppColors.text,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Text(l.shiftHint, style: _hint),
          Slider(
            min: -_maxShift,
            max: _maxShift,
            value: _edit.shift.clamp(-_maxShift, _maxShift),
            onChanged: (v) =>
                _set(_edit.copyWith(shift: (v * 100).roundToDouble() / 100)),
          ),
          Wrap(
            spacing: 8,
            children: [
              _NudgeButton('−1 ${l.beatShort}', () => _nudge(-_beat)),
              _NudgeButton('−10 ms', () => _nudge(-0.01)),
              _NudgeButton('0', () => _set(_edit.copyWith(shift: 0))),
              _NudgeButton('+10 ms', () => _nudge(0.01)),
              _NudgeButton('+1 ${l.beatShort}', () => _nudge(_beat)),
            ],
          ),
          const SizedBox(height: 20),

          // Actions --------------------------------------------------------
          Row(
            children: [
              if (t.isEdited)
                TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(l.restoreOriginal),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _apply,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.apply),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _apply() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    final ok = await widget.controller.editTrack(widget.track, _edit);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? l.editApplied(widget.track.name) : l.editFailed),
      ),
    );
    if (ok) nav.pop();
  }

  Future<void> _restore() async {
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    await widget.controller.resetEdit(widget.track);
    if (mounted) nav.pop();
  }
}

class _FadeRow extends StatelessWidget {
  const _FadeRow({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 120,
        child: Text(label, style: const TextStyle(color: AppColors.textDim)),
      ),
      Expanded(
        child: Slider(
          max: max <= 0 ? 1 : max,
          value: max <= 0 ? 0 : value.clamp(0, max),
          onChanged: max <= 0
              ? null
              : (v) => onChanged((v * 10).roundToDouble() / 10),
        ),
      ),
      SizedBox(
        width: 44,
        child: Text(
          '${value.toStringAsFixed(1)} s',
          textAlign: TextAlign.end,
          style: const TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
      ),
    ],
  );
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.text,
      side: const BorderSide(color: Colors.white24),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(0, 36),
    ),
    child: Text(label),
  );
}

/// The original take: kept part bright, trimmed parts dim, fades as ramps.
class _EditPreviewPainter extends CustomPainter {
  _EditPreviewPainter({
    required this.peaks,
    required this.length,
    required this.edit,
    required this.color,
  });

  final List<double> peaks;
  final double length;
  final TrackEdit edit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.surfaceHigh;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      bg,
    );
    if (length <= 0) return;
    final mid = size.height / 2;
    double x(double s) => s / length * size.width;
    final start = edit.trimStart, end = edit.trimEnd ?? length;

    double envelope(double s) {
      if (s < start || s > end) return 0;
      var g = 1.0;
      if (edit.fadeIn > 0 && s - start < edit.fadeIn) {
        g *= (s - start) / edit.fadeIn;
      }
      if (edit.fadeOut > 0 && end - s < edit.fadeOut) {
        g *= (end - s) / edit.fadeOut;
      }
      return g;
    }

    final bright = Paint()..color = color;
    final dim = Paint()..color = color.withValues(alpha: 0.25);
    const barW = 2.0;
    for (var px = 0.0; px < size.width; px += barW + 1) {
      final s = px / size.width * length;
      final i = (s * Waveform.peaksPerSecond).floor();
      final p = i < peaks.length ? peaks[i] : 0.0;
      final inside = s >= start && s <= end;
      final h = math.max(1.0, p * (mid - 4) * (inside ? envelope(s) : 1));
      canvas.drawRect(
        Rect.fromLTWH(px, mid - h, barW, h * 2),
        inside ? bright : dim,
      );
    }

    final handle = Paint()
      ..color = AppColors.text
      ..strokeWidth = 2;
    canvas
      ..drawLine(Offset(x(start), 0), Offset(x(start), size.height), handle)
      ..drawLine(Offset(x(end), 0), Offset(x(end), size.height), handle);
  }

  @override
  bool shouldRepaint(_EditPreviewPainter old) =>
      old.peaks != peaks ||
      old.edit != edit ||
      old.length != length ||
      old.color != color;
}
