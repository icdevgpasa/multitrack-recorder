import 'package:material_ui/material_ui.dart';

import '../models/project.dart';
import '../studio/studio_controller.dart';
import 'theme.dart';
import 'widgets.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key, required this.controller});

  final StudioController controller;

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
              StudioPhase.ready => _Studio(controller: controller),
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
  const _Studio({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final p = controller.project;
    return Column(
      children: [
        _Header(controller: controller),
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final p = controller.project;
    final busy = controller.isPlaying || controller.isRecording;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
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
                : () => controller.setCountInBars((p.countInBars + 1) % 3),
          ),
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
    );
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

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final c = widget.controller;
    final color = AppColors.track(t.colorIndex);
    final pos = c.status.positionSeconds;
    final progress = c.isPlaying && t.durationSeconds > 0
        ? (pos / t.durationSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
                color: color.withValues(alpha: t.muted ? 0.05 : 0.14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 4),
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
                          color: t.muted ? AppColors.textDim : AppColors.text,
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
                    IconButton(
                      tooltip: t.muted ? 'Włącz dźwięk' : 'Wycisz',
                      onPressed: () => c.toggleMute(t),
                      icon: Icon(
                        t.muted ? Icons.volume_off : Icons.volume_up,
                        color: t.muted ? AppColors.record : AppColors.textDim,
                        size: 20,
                      ),
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
                  child: Slider(
                    value: _dragVolume ?? t.volume,
                    onChanged: (v) => setState(() => _dragVolume = v),
                    onChangeEnd: (v) {
                      setState(() => _dragVolume = null);
                      c.setVolume(t, v);
                    },
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
    final ctrl = TextEditingController(text: widget.track.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nazwa ścieżki'),
        content: TextField(controller: ctrl, autofocus: true),
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
    if (name != null) await widget.controller.rename(widget.track, name);
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 8),
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
