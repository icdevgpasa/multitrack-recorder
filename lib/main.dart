import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:multitrack_engine/multitrack_engine.dart';
import 'package:path_provider/path_provider.dart';

import 'studio/project_store.dart';
import 'studio/studio_controller.dart';
import 'ui/studio_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  // Step 1: a single project. Project list comes with step 2.
  const projectId = 'default';
  final controller = StudioController(
    engine: MultitrackEngine(),
    store: ProjectStore(Directory('${docs.path}/projects/$projectId')),
    newProjectId: projectId,
  );
  runApp(MultitrackApp(controller: controller));
  await controller.init();
}

class MultitrackApp extends StatelessWidget {
  const MultitrackApp({super.key, required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Multitrack',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: StudioScreen(controller: controller),
  );
}
