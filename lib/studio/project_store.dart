import 'dart:convert';
import 'dart:io';

import '../models/project.dart';

/// Stores a project as `project.json` plus its audio files in one folder.
class ProjectStore {
  ProjectStore(this.root);

  /// e.g. `<Documents>/projects/<projectId>`
  final Directory root;

  File get _jsonFile => File('${root.path}/project.json');

  String audioPath(String fileName) => '${root.path}/$fileName';

  Future<Project?> load() async {
    if (!await _jsonFile.exists()) return null;
    try {
      final data = jsonDecode(await _jsonFile.readAsString());
      return Project.fromJson(Map<String, dynamic>.from(data as Map));
    } on FormatException {
      return null;
    }
  }

  Future<void> _lastSave = Future.value();

  /// Saves are queued, so quick changes (e.g. dragging a slider) never write
  /// the same temporary file at once.
  Future<void> save(Project project) {
    final json = const JsonEncoder.withIndent('  ').convert(project.toJson());
    final done = _lastSave.then((_) => _write(json));
    _lastSave = done.catchError((Object _) {});
    return done;
  }

  Future<void> _write(String json) async {
    await root.create(recursive: true);
    final tmp = File('${_jsonFile.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_jsonFile.path);
  }

  Future<void> deleteAudio(String fileName) async {
    final f = File(audioPath(fileName));
    if (await f.exists()) await f.delete();
  }
}
