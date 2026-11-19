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

  Future<void> save(Project project) async {
    await root.create(recursive: true);
    final tmp = File('${_jsonFile.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(project.toJson()),
    );
    await tmp.rename(_jsonFile.path);
  }

  Future<void> deleteAudio(String fileName) async {
    final f = File(audioPath(fileName));
    if (await f.exists()) await f.delete();
  }
}
