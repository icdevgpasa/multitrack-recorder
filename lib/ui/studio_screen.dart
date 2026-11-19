import 'package:material_ui/material_ui.dart';
import 'package:multitrack_engine/multitrack_engine.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project.dart';
import '../studio/studio_controller.dart';
import 'audio_settings_sheet.dart';
import 'l10n.dart';
import 'theme.dart';
import 'track_editor_sheet.dart';
import 'visuals.dart';
import 'widgets.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, required this.controller, this.onClose});

  final StudioController controller;

  /// Back button; when null (single-screen use) no back button is shown.
  final VoidCallback? onClose;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  StudioController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_showRecordingProblem);
  }

  @override
  void didUpdateWidget(StudioScreen old) {
    super.didUpdateWidget(old);
    if (old.controller != controller) {
      old.controller.removeListener(_showRecordingProblem);
      controller.addListener(_showRecordingProblem);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_showRecordingProblem);
    super.dispose();
  }

  void _showRecordingProblem() {
    final problem = controller.recordingProblem;
    if (problem == null || !mounted) return;
    controller.clearRecordingProblem();
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          problem.isEmpty ? l.takeEmpty : l.recordingFailed(problem),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ReactiveBackground(
          level: controller.isRecording
              ? controller.status.inputLevel
              : controller.status.outputLevel,
          beat: controller.status.beat,
          recording: controller.isRecording,
          child: SafeArea(
            child: switch (controller.phase) {
              StudioPhase.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              StudioPhase.noPermission => _Message(
                icon: Icons.mic_off,
                text: context.l10n.noMicPermission,
              ),
              StudioPhase.error => _Message(
                icon: Icons.error_outline,
                text: context.l10n.audioStartFailed(
                  controller.errorMessage ?? '',
                ),
              ),
              StudioPhase.ready => _Studio(
                controller: controller,
                onClose: widget.onClose,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textDim),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text),
          ),
        ],
      ),
    ),
  );
}

class _Studio extends StatelessWidget {
  const _Studio({required this.controller, this.onClose});

  final StudioController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final p = controller.project;
    return Stack(
      children: [
        Column(
          children: [
            _Header(controller: controller, onClose: onClose),
            Expanded(
              child: p.tracks.isEmpty && !controller.isRecording
                  ? _Message(
                      icon: Icons.graphic_eq,
                      text: context.l10n.recordFirstTrack,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount:
                          p.tracks.length + (controller.isRecording ? 1 : 0),
                      itemBuilder: (context, i) => i < p.tracks.length
                          ? TrackTile(
                              key: ValueKey(p.tracks[i].id),
                              track: p.tracks[i],
                              controller: controller,
                            )
                          : _RecordingTile(controller: controller),
                    ),
            ),
            _Transport(controller: controller),
          ],
        ),
        if (controller.exporting)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.exporting,
                    style: const TextStyle(color: AppColors.text),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, this.onClose});

  final StudioController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final p = controller.project;
    final busy = controller.isPlaying || controller.isRecording;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        children: [
          Row(
            children: [
              if (onClose != null)
                IconButton(
                  tooltip: context.l10n.backToSongs,
                  onPressed: busy ? null : onClose,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                )
              else
                const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: busy ? null : () => _renameProject(context),
                  child: Text(
                    p.name,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.audioSettings,
                onPressed: busy
                    ? null
                    : () => showAudioSettings(context, controller),
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                tooltip: context.l10n.export,
                onPressed: busy || p.tracks.isEmpty
                    ? null
                    : () => _export(context),
                icon: const Icon(Icons.ios_share),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _Chip(
                  label: '${p.bpm.round()} BPM',
                  onTap: busy ? null : () => _editBpm(context),
                ),
                const SizedBox(width: 6),
                _Chip(
                  label: p.countInBars == 0
                      ? context.l10n.noCountIn
                      : context.l10n.countInBars(p.countInBars),
                  onTap: busy
                      ? null
                      : () =>
                            controller.setCountInBars((p.countInBars + 1) % 3),
                ),
                const Spacer(),
                IconButton(
                  tooltip: p.metronomeOn
                      ? context.l10n.metronomeOff
                      : context.l10n.metronomeOn,
                  onPressed: busy ? null : controller.toggleMetronome,
                  icon: Icon(
                    Icons.av_timer,
                    color: p.metronomeOn ? AppColors.accent : AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameProject(BuildContext context) async {
    final name = await promptText(
      context,
      title: context.l10n.songName,
      initial: controller.project.name,
    );
    if (name != null) await controller.renameProject(name);
  }

  Future<void> _editBpm(BuildContext context) async {
    var bpm = controller.project.bpm;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${bpm.round()} BPM',
                style: const TextStyle(fontSize: 32, color: AppColors.text),
              ),
              Slider(
                min: 40,
                max: 240,
                value: bpm,
                onChanged: (v) => setState(() => bpm = v.roundToDouble()),
              ),
            ],
          ),
        ),
      ),
    );
    await controller.setBpm(bpm);
  }

  Future<void> _export(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final choice = await showModalBottomSheet<_ExportChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                context.l10n.exportTitle,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final c in _ExportChoice.values)
              ListTile(
                leading: Icon(c.icon, color: AppColors.accent),
                title: Text(c.title(context.l10n)),
                subtitle: Text(c.subtitle(context.l10n)),
                onTap: () => Navigator.pop(context, c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final paths = switch (choice) {
      _ExportChoice.mixM4a => [?await controller.exportMix(ExportFormat.m4a)],
      _ExportChoice.mixWav => [?await controller.exportMix(ExportFormat.wav)],
      _ExportChoice.stems => await controller.exportStems(ExportFormat.wav),
    };
    if (!context.mounted) return;
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.exportFailed(
              controller.errorMessage ?? context.l10n.nothingToExport,
            ),
          ),
        ),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final p in paths) XFile(p)],
        sharePositionOrigin: origin,
      ),
    );
  }
}

enum _ExportChoice {
  mixM4a(Icons.music_note),
  mixWav(Icons.high_quality),
  stems(Icons.view_list);

  const _ExportChoice(this.icon);

  final IconData icon;

  String title(AppLocalizations l) => switch (this) {
    mixM4a => l.exportMixM4a,
    mixWav => l.exportMixWav,
    stems => l.exportStems,
  };

  String subtitle(AppLocalizations l) => switch (this) {
    mixM4a => l.exportMixM4aHint,
    mixWav => l.exportMixWavHint,
    stems => l.exportStemsHint,
  };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceHigh,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
        ),
      ),
    ),
  );
}

class TrackTile extends StatefulWidget {
  const TrackTile({super.key, required this.track, required this.controller});

  final Track track;
  final StudioController controller;

  @override
  State<TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<TrackTile> {
  double? _dragVolume;
  double? _dragPan;

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final c = widget.controller;
    final audible = c.project.isAudible(t);
    final color = AppColors.track(t.colorIndex);
    final pos = c.status.positionSeconds;
    final pan = _dragPan ?? t.pan;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: audible ? 0.35 : 0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.name,
                        style: TextStyle(
                          color: audible ? AppColors.text : AppColors.textDim,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (t.isEdited)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.content_cut,
                          size: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                    Text(
                      formatTime(t.durationSeconds),
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 12,
                      ),
                    ),
                    _ToggleButton(
                      label: 'S',
                      tooltip: t.solo
                          ? context.l10n.soloOff
                          : context.l10n.soloOn,
                      active: t.solo,
                      activeColor: AppColors.solo,
                      onPressed: () => c.toggleSolo(t),
                    ),
                    _ToggleButton(
                      label: 'M',
                      tooltip: t.muted
                          ? context.l10n.unmute
                          : context.l10n.mute,
                      active: t.muted,
                      activeColor: AppColors.record,
                      onPressed: () => c.toggleMute(t),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.textDim,
                        size: 20,
                      ),
                      onSelected: (v) => switch (v) {
                        'edit' => showTrackEditor(context, c, t),
                        'rename' => _rename(context),
                        'louder' => _normalize(context),
                        _ => c.deleteTrack(t),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          enabled: !c.isRecording,
                          child: Text(context.l10n.editTrack),
                        ),
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(context.l10n.rename),
                        ),
                        PopupMenuItem(
                          value: 'louder',
                          child: Text(context.l10n.makeLouder),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(context.l10n.deleteTrack),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2),
                  child: LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => c.seek(
                        d.localPosition.dx / box.maxWidth * c.timelineSeconds,
                      ),
                      child: Semantics(
                        label: context.l10n.waveformLabel(t.name),
                        child: WaveformView(
                          peaks: c.waveforms[t.id]?.peaks ?? const <double>[],
                          timelineSeconds: c.timelineSeconds,
                          color: color,
                          dimmed: !audible,
                          playheadSeconds: c.isPlaying && pos >= 0 ? pos : null,
                        ),
                      ),
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: color,
                    thumbColor: color,
                    inactiveTrackColor: Colors.white12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.volume_up,
                        size: 14,
                        color: AppColors.textDim,
                      ),
                      Expanded(
                        flex: 3,
                        child: Slider(
                          value: _dragVolume ?? t.volume,
                          onChanged: (v) => setState(() => _dragVolume = v),
                          onChangeEnd: (v) {
                            setState(() => _dragVolume = null);
                            c.setVolume(t, v);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          panLabel(context.l10n, pan),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textDim,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onDoubleTap: () => c.setPan(t, 0),
                          child: Slider(
                            min: -1,
                            max: 1,
                            value: pan,
                            onChanged: (v) => setState(
                              () => _dragPan = v.abs() < 0.06 ? 0 : v,
                            ),
                            onChangeEnd: (_) {
                              final v = _dragPan ?? t.pan;
                              setState(() => _dragPan = null);
                              c.setPan(t, v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _normalize(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final done = await widget.controller.normalizeTrack(widget.track);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          done ? l10n.madeLouder(widget.track.name) : l10n.alreadyLoud,
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final name = await promptText(
      context,
      title: context.l10n.trackName,
      initial: widget.track.name,
    );
    if (name != null) await widget.controller.rename(widget.track, name);
  }
}

/// "L40", "C", "P25" (Polish: lewo/prawo).
String panLabel(AppLocalizations l10n, double pan) {
  final v = (pan * 100).round();
  if (v == 0) return l10n.panCenter;
  return v < 0 ? l10n.panLeft(-v) : l10n.panRight(v);
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.activeColor,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final bool active;
  final Color activeColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      toggled: active,
      label: tooltip,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? activeColor : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : AppColors.textDim,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Transport extends StatefulWidget {
  const _Transport({required this.controller});

  final StudioController controller;

  @override
  State<_Transport> createState() => _TransportState();
}

class _TransportState extends State<_Transport> {
  double? _dragMaster;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final s = controller.status;
    final p = controller.project;
    final recording = controller.isRecording;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                formatTime(s.isPlaying ? s.positionSeconds : 0),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (p.metronomeOn)
                BeatDots(
                  beats: p.beatsPerBar,
                  current: s.beat,
                  countingIn: s.isCountingIn,
                ),
            ],
          ),
          const SizedBox(height: 8),
          SpectrumBars(levels: s.spectrum, height: 36),
          const SizedBox(height: 6),
          Row(
            children: [
              _GainChip(controller: controller),
              const SizedBox(width: 8),
              Expanded(child: LevelMeter(level: s.inputLevel)),
              _MonitorToggle(controller: controller),
            ],
          ),
          Row(
            children: [
              Text(
                context.l10n.master,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _dragMaster ?? p.masterVolume,
                  onChanged: (v) => setState(() => _dragMaster = v),
                  onChangeEnd: (v) {
                    setState(() => _dragMaster = null);
                    controller.setMasterVolume(v);
                  },
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                iconSize: 32,
                tooltip: context.l10n.stop,
                onPressed: s.isPlaying || recording ? controller.stop : null,
                icon: const Icon(Icons.stop_rounded),
              ),
              RecordButton(
                recording: recording,
                onPressed: controller.toggleRecord,
              ),
              IconButton.filledTonal(
                iconSize: 32,
                tooltip: context.l10n.play,
                onPressed: !s.isPlaying && !recording && p.tracks.isNotEmpty
                    ? controller.play
                    : null,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple text prompt; returns null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final ctrl = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return value;
}

/// Take being recorded: live waveform growing on the shared timeline.
class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.record.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.record.withValues(alpha: 0.25),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fiber_manual_record,
                color: AppColors.record,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                s.isCountingIn
                    ? context.l10n.countingIn
                    : context.l10n.recording,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          WaveformView(
            peaks: controller.liveLevels,
            timelineSeconds: controller.timelineSeconds,
            color: AppColors.record,
            playheadSeconds: s.positionSeconds >= 0 ? s.positionSeconds : null,
          ),
        ],
      ),
    );
  }
}

/// Shows the mic gain; tap to adjust it while watching the input meter.
class _GainChip extends StatelessWidget {
  const _GainChip({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final db = controller.project.inputGainDb.round();
    return Semantics(
      button: true,
      label: context.l10n.micGainLabel(db),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: controller.isRecording ? null : () => _edit(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, size: 14, color: AppColors.textDim),
              const SizedBox(width: 4),
              Text(
                '+$db dB',
                style: const TextStyle(color: AppColors.text, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    var db = controller.project.inputGainDb;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.micGainTitle(db.round()),
                style: const TextStyle(color: AppColors.text, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.micGainHint,
                style: const TextStyle(color: AppColors.textDim, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) =>
                    LevelMeter(level: controller.status.inputLevel, height: 10),
              ),
              Slider(
                min: 0,
                max: 36,
                divisions: 36,
                value: db,
                onChanged: (v) {
                  setState(() => db = v);
                  controller.setInputGain(v, save: false);
                },
                onChangeEnd: controller.setInputGain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick on/off for hearing yourself; long-press opens the audio settings.
class _MonitorToggle extends StatelessWidget {
  const _MonitorToggle({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final on = controller.audio.monitorOn;
    final blocked = on && controller.status.monitorBlocked;
    return GestureDetector(
      onLongPress: () => showAudioSettings(context, controller),
      child: IconButton(
        tooltip: on ? context.l10n.monitoringOff : context.l10n.monitoringOn,
        onPressed: () => controller.setMonitoring(on: !on),
        icon: Icon(
          blocked ? Icons.headset_off : Icons.headphones,
          size: 20,
          color: !on
              ? AppColors.textDim
              : blocked
              ? AppColors.solo
              : AppColors.accent,
        ),
      ),
    );
  }
}
