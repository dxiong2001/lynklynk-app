import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'view.dart' as view;
import 'input.dart';
import 'highlighter.dart';
import 'package:lynklynk/loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.focus();
  });
  runApp(const MyApp());
}

class Editor extends StatefulWidget {
  const Editor(
      {super.key,
      required this.path,
      this.isPath = false,
      required this.fileName});
  final String path;
  final bool isPath;
  final String fileName;
  @override
  State<Editor> createState() => _Editor();
}

class _Editor extends State<Editor> {
  late view.DocumentProvider doc;
  @override
  void initState() {
    doc = view.DocumentProvider();
    if (widget.isPath) {
      doc.openFile(widget.path);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => doc),
          Provider(create: (context) => Highlighter())
        ],
        child: InputListener(
            child: view.View(
          fileName: widget.fileName,
        )));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Times',
          primaryColor: foreground,
          scaffoldBackgroundColor: const Color(0xFFEFEFEF),
        ),
        home: const Scaffold(body: Loader()));
  }
}
