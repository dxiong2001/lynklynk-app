import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'view.dart' as view;
import 'input.dart';
import 'highlighter.dart';
import 'package:lynklynk/dashboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
    await windowManager.focus();
  });
  if (Platform.isWindows) {
    WindowManager.instance.setMinimumSize(const Size(600, 600));
  }
  runApp(const ProviderScope(child: MyApp()));
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
    return provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (context) => doc),
          provider.Provider(create: (context) => Highlighter())
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
            textTheme: GoogleFonts.latoTextTheme(
              Theme.of(context).textTheme,
            ),
            primaryColor: foreground,
            scaffoldBackgroundColor: Colors.white,
            scrollbarTheme: ScrollbarThemeData(
              thumbVisibility: WidgetStateProperty.all<bool>(true),
            )),
        home: const Scaffold(body: Loader()));
  }
}
