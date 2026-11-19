import 'dart:io';

import '../models/project.dart';
import 'project_store.dart';

/// Summary row for the projects list.
class ProjectSummary {
  ProjectSummary({required this.project, required this.modified});

  final Project project;
  final DateTime modified;
}

/// All projects, each in its own folder under [root].
class ProjectLibrary {
  ProjectLibrary(this.root, {String Function()? idGenerator})
    : _newId =
          idGenerator ??
          (() => DateTime.now().microsecondsSinceEpoch.toRadixString(36));

  /// e.g. `<Documents>/projects`
  final Directory root;
  final String Function() _newId;

  ProjectStore storeFor(String id) =>
      ProjectStore(Directory('${root.path}/$id'));

  /// Newest first.
  Future<List<ProjectSummary>> list() async {
    if (!await root.exists()) return [];
    final out = <ProjectSummary>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final store = ProjectStore(entity);
      final project = await store.load();
      if (project == null) continue;
      final modified = await File('${entity.path}/project.json').lastModified();
      out.add(ProjectSummary(project: project, modified: modified));
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  /// [nameFor] gives the default name from the song's number (localised).
  Future<Project> create({String Function(int number)? nameFor}) async {
    final existing = await list();
    final project = Project(
      id: _newId(),
      name: (nameFor ?? (n) => 'Song $n')(existing.length + 1),
      // The mic doesn't change between songs: keep the last gain used.
      inputGainDb: existing.isEmpty ? 12 : existing.first.project.inputGainDb,
    );
    await storeFor(project.id).save(project);
    return project;
  }

  Future<void> delete(String id) async {
    final dir = Directory('${root.path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
