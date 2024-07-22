import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:provider/provider.dart';

import 'view.dart' as view;
import 'input.dart';
import 'highlighter.dart';

void main() async {
  runApp(const MyApp());
}

class Editor extends StatefulWidget {
  const Editor({super.key, this.path = ''});
  final String path;
  @override
  State<Editor> createState() => _Editor();
}

class _Editor extends State<Editor> {
  late view.DocumentProvider doc;
  @override
  void initState() {
    doc = view.DocumentProvider();
    doc.openFile(widget.path);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(providers: [
      ChangeNotifierProvider(create: (context) => doc),
      Provider(create: (context) => Highlighter())
    ], child: const InputListener(child: view.View()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'FiraCode',
          primaryColor: foreground,
          scaffoldBackgroundColor: background,
        ),
        home: const Scaffold(body: Editor(path: './samples/test.txt')));
  }
}
