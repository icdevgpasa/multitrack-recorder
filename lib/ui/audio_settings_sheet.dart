import 'package:material_ui/material_ui.dart';

import '../studio/studio_controller.dart';
import 'l10n.dart';
import 'theme.dart';

/// Monitoring and latency calibration.
Future<void> showAudioSettings(BuildContext context, StudioController c) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => _AudioSettings(controller: c),
        ),
      ),
    );

class _AudioSettings extends StatelessWidget {
  const _AudioSettings({required this.controller});

  final StudioController controller;

  static const _title = TextStyle(
    color: AppColors.text,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
  static const _hint = TextStyle(color: AppColors.textDim, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = controller;
    final a = c.audio;
    final s = c.status;
    final bluetooth = s.route.startsWith('Bluetooth');
    final offset = c.currentOffsetMs;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.audioSettings, style: _title.copyWith(fontSize: 20)),
          const SizedBox(height: 20),

          // Monitoring -------------------------------------------------------
          Row(
            children: [
              Expanded(child: Text(l.monitoringTitle, style: _title)),
              Switch(
                value: a.monitorOn,
                onChanged: (v) => c.setMonitoring(on: v),
              ),
            ],
          ),
          Text(l.monitoringHint, style: _hint),
          if (a.monitorOn && s.monitorBlocked)
            _Warning(icon: Icons.headset_off, text: l.monitoringBlocked)
          else if (a.monitorOn && bluetooth)
            _Warning(icon: Icons.bluetooth, text: l.monitoringBluetooth),
          if (a.monitorOn) ...[
            _SliderRow(
              label: l.monitorVolume,
              value: a.monitorVolume,
              onChanged: (v) => c.setMonitoring(volume: v),
            ),
            _SliderRow(
              label: l.monitorReverb,
              value: a.monitorReverb,
              onChanged: (v) => c.setMonitoring(reverb: v),
            ),
          ],
          const Divider(height: 36, color: Colors.white12),

          // Calibration ------------------------------------------------------
          Text(l.calibrationTitle, style: _title),
          const SizedBox(height: 4),
          Text(l.calibrationHint, style: _hint),
          const SizedBox(height: 12),
          Text(
            l.currentOutput(s.routeName.isEmpty ? '-' : s.routeName),
            style: const TextStyle(color: AppColors.text),
          ),
          const SizedBox(height: 2),
          Text(
            offset == null
                ? l.notCalibrated
                : l.calibratedOffset(
                    '${offset >= 0 ? '+' : ''}${offset.toStringAsFixed(0)}',
                  ),
            style: _hint,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: c.calibrating || c.isRecording
                    ? null
                    : () => _calibrate(context),
                icon: c.calibrating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.graphic_eq),
                label: Text(c.calibrating ? l.calibrating : l.calibrate),
              ),
              const SizedBox(width: 12),
              if (offset != null && !c.calibrating)
                TextButton(
                  onPressed: c.resetCalibration,
                  child: Text(l.resetCalibration),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _calibrate(BuildContext context) async {
    final l = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.calibrationTitle),
        content: Text(l.calibrationHowTo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.start),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final r = await controller.calibrate();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          r == null
              ? l.calibrationFailed
              : l.calibrationDone(r.measuredMs.toStringAsFixed(0)),
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.solo.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.solo),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppColors.text)),
        ),
      ],
    ),
  );
}

class _SliderRow extends StatefulWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  double? _drag;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 90,
        child: Text(
          widget.label,
          style: const TextStyle(color: AppColors.textDim),
        ),
      ),
      Expanded(
        child: Slider(
          value: _drag ?? widget.value,
          onChanged: (v) => setState(() => _drag = v),
          onChangeEnd: (v) {
            setState(() => _drag = null);
            widget.onChanged(v);
          },
        ),
      ),
    ],
  );
}
