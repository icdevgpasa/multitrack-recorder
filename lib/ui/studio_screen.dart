import 'package:material_ui/material_ui.dart';
import 'package:multitrack_engine/multitrack_engine.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project.dart';
import '../studio/studio_controller.dart';
import 'theme.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => switch (controller.phase) {
              StudioPhase.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              StudioPhase.noPermission => const _Message(
                icon: Icons.mic_off,
                text:
                    'Brak dostępu do mikrofonu.\nWłącz go w Ustawieniach iOS.',
              ),
              StudioPhase.error => _Message(
                icon: Icons.error_outline,
                text:
                    'Nie udało się uruchomić audio.\n${controller.errorMessage ?? ''}',
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
              child: p.tracks.isEmpty
                  ? const _Message(
                      icon: Icons.graphic_eq,
                      text: 'Nagraj pierwszą ścieżkę.\nKolejne nagrasz, słuchając poprzednich.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: p.tracks.length,
                      itemBuilder: (context, i) => TrackTile(
                        key: ValueKey(p.tracks[i].id),
                        track: p.tracks[i],
                        controller: controller,
                      ),
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
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Eksportuję…', style: TextStyle(color: AppColors.text)),
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
                  tooltip: 'Utwory',
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
                tooltip: 'Eksportuj',
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
                      ? 'Bez odliczania'
                      : 'Odliczanie ${p.countInBars}',
                  onTap: busy
                      ? null
                      : () =>
                            controller.setCountInBars((p.countInBars + 1) % 3),
                ),
                const Spacer(),
                IconButton(
                  tooltip: p.metronomeOn ? 'Wyłącz metronom' : 'Włącz metronom',
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
      title: 'Nazwa utworu',
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
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Eksport',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final c in _ExportChoice.values)
              ListTile(
                leading: Icon(c.icon, color: AppColors.accent),
                title: Text(c.title),
                subtitle: Text(c.subtitle),
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
            'Eksport nie wyszedł: ${controller.errorMessage ?? 'brak ścieżek do eksportu'}',
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
  mixM4a(
    Icons.music_note,
    'Cały utwór (M4A)',
    'Mały plik do wysłania lub odsłuchu',
  ),
  mixWav(Icons.high_quality, 'Cały utwór (WAV)', 'Bez strat jakości, 24 bit'),
  stems(
    Icons.view_list,
    'Pojedyncze ścieżki (WAV)',
    'Każda ścieżka osobno, do dalszej pracy w DAW',
  );

  const _ExportChoice(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
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
    final progress = c.isPlaying && t.durationSeconds > 0
        ? (pos / t.durationSeconds).clamp(0.0, 1.0)
        : 0.0;
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
          // Playhead fill: placeholder until real waveforms arrive (step 3).
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                color: color.withValues(alpha: audible ? 0.14 : 0.05),
              ),
            ),
          ),
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
                    Text(
                      formatTime(t.durationSeconds),
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 12,
                      ),
                    ),
                    _ToggleButton(
                      label: 'S',
                      tooltip: t.solo ? 'Wyłącz solo' : 'Solo',
                      active: t.solo,
                      activeColor: AppColors.solo,
                      onPressed: () => c.toggleSolo(t),
                    ),
                    _ToggleButton(
                      label: 'M',
                      tooltip: t.muted ? 'Włącz dźwięk' : 'Wycisz',
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
                      onSelected: (v) =>
                          v == 'rename' ? _rename(context) : c.deleteTrack(t),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Zmień nazwę'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Usuń ścieżkę'),
                        ),
                      ],
                    ),
                  ],
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
                          panLabel(pan),
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

  Future<void> _rename(BuildContext context) async {
    final name = await promptText(
      context,
      title: 'Nazwa ścieżki',
      initial: widget.track.name,
    );
    if (name != null) await widget.controller.rename(widget.track, name);
  }
}

/// "L40", "C", "P25" (Polish: lewo/prawo).
String panLabel(double pan) {
  final v = (pan * 100).round();
  if (v == 0) return 'C';
  return v < 0 ? 'L${-v}' : 'P$v';
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
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.mic, size: 16, color: AppColors.textDim),
              const SizedBox(width: 8),
              Expanded(child: LevelMeter(level: s.inputLevel)),
            ],
          ),
          Row(
            children: [
              const Text(
                'Master',
                style: TextStyle(color: AppColors.textDim, fontSize: 12),
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
                tooltip: 'Stop',
                onPressed: s.isPlaying || recording ? controller.stop : null,
                icon: const Icon(Icons.stop_rounded),
              ),
              RecordButton(
                recording: recording,
                onPressed: controller.toggleRecord,
              ),
              IconButton.filledTonal(
                iconSize: 32,
                tooltip: 'Odtwórz',
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
          child: const Text('Anuluj'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Zapisz'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return value;
}
