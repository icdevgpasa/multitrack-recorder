import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:multitrack_engine/multitrack_engine.dart';
import 'package:path_provider/path_provider.dart';

import 'studio/project_library.dart';
import 'ui/l10n.dart';
import 'ui/projects_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final docs = await getApplicationDocumentsDirectory();
  runApp(
    MultitrackApp(
      library: ProjectLibrary(Directory('${docs.path}/projects')),
      engine: MultitrackEngine(),
    ),
  );
}

class MultitrackApp extends StatelessWidget {
  const MultitrackApp({super.key, required this.library, required this.engine});

  final ProjectLibrary library;
  final MultitrackEngine engine;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => context.l10n.appTitle,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: ProjectsScreen(library: library, engine: engine),
  );
}
