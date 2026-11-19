import 'package:material_ui/material_ui.dart';
import 'package:multitrack_engine/multitrack_engine.dart';

import '../models/project.dart';
import '../studio/project_library.dart';
import '../studio/studio_controller.dart';
import 'studio_screen.dart';
import 'theme.dart';

/// Home screen: list of songs.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.library,
    required this.engine,
  });

  final ProjectLibrary library;
  final MultitrackEngine engine;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<ProjectSummary>? _projects;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.library.list();
    if (mounted) setState(() => _projects = list);
  }

  Future<void> _open(Project project) async {
    final controller = StudioController(
      engine: widget.engine,
      store: widget.library.storeFor(project.id),
      newProjectId: project.id,
    );
    final init = controller.init();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StudioScreen(
          controller: controller,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
    await init;
    await controller.close();
    controller.dispose();
    await _reload();
  }

  Future<void> _create() async {
    final project = await widget.library.create();
    await _open(project);
  }

  Future<void> _delete(Project project) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Usunąć „${project.name}”?'),
        content: const Text('Wszystkie nagrane ścieżki zostaną usunięte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Usuń',
              style: TextStyle(color: AppColors.record),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.library.delete(project.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final projects = _projects;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nowy utwór'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Twoje utwory',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (projects == null)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (projects.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Nie masz jeszcze żadnego utworu.\nZacznij od „Nowy utwór”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textDim),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.builder(
                    itemCount: projects.length,
                    itemBuilder: (context, i) => _ProjectCard(
                      summary: projects[i],
                      onTap: () => _open(projects[i].project),
                      onDelete: () => _delete(projects[i].project),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.summary,
    required this.onTap,
    required this.onDelete,
  });

  final ProjectSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = summary.project;
    final n = p.tracks.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
            child: Row(
              children: [
                // Colour strip: one segment per track.
                SizedBox(
                  width: 6,
                  height: 44,
                  child: Column(
                    children: [
                      if (n == 0)
                        Expanded(child: Container(color: Colors.white12))
                      else
                        for (var i = 0; i < n && i < 6; i++)
                          Expanded(
                            child: Container(
                              color: AppColors.track(p.tracks[i].colorIndex),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${trackCountLabel(n)} · ${formatTime(p.lengthSeconds)} · ${p.bpm.round()} BPM',
                        style: const TextStyle(
                          color: AppColors.textDim,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Usuń utwór',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Polish plural: 1 ścieżka, 2–4 ścieżki, 5+ ścieżek (12–14 ścieżek).
String trackCountLabel(int n) {
  if (n == 1) return '1 ścieżka';
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$n ścieżki';
  }
  return '$n ścieżek';
}
