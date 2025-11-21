import 'package:flutter/material.dart';
import 'package:lynklynk/layout/constellation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:lynklynk/layout/document.dart';
import 'highlighter.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:convert';

class DocumentProvider extends ChangeNotifier {
  Document doc = Document();

  Future<bool> openFile(String path) async {
    bool res = await doc.openFile(path);
    touch();
    return res;
  }

  void touch() {
    notifyListeners();
  }
}

String inlineSpansToString(List<InlineSpan> spans) {
  StringBuffer buffer = StringBuffer();

  for (InlineSpan span in spans) {
    if (span is TextSpan) {
      buffer.write(span.text);
      // If the TextSpan has children, process them recursively
      if (span.children != null) {
        buffer.write(inlineSpansToString(span.children!));
      }
    } else if (span is WidgetSpan) {
      // Handle WidgetSpan if necessary
      // For now, we'll just add a placeholder text for widgets
      buffer.write('[WIDGET]');
    }
  }

  return buffer.toString();
}

class ViewLine extends StatelessWidget {
  const ViewLine({this.lineNumber = 0, this.text = '', super.key});

  final int lineNumber;
  final String text;

  @override
  Widget build(BuildContext context) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    Highlighter hl = Provider.of<Highlighter>(context);
    List<InlineSpan> spans = hl.run(text, lineNumber, doc.doc);

    final gutterStyle = TextStyle(
        fontFamily: 'Times', fontSize: gutterFontSize, color: comment);
    double gutterWidth =
        getTextExtents(' ${doc.doc.lines.length} ', gutterStyle).width;
    bool bulleted = doc.doc.bulletActive[lineNumber];
    int bulletLevel = doc.doc.bulletLevel[lineNumber];
    bool highlight = doc.doc.cursor.line == lineNumber;
    List<String> suggestionList = doc.doc.getSuggestList();
    return Container(
        // margin: highlight
        //     ? suggestionList.isEmpty
        //         ? const EdgeInsets.symmetric(vertical: 10)
        //         : const EdgeInsets.only(top: 10, bottom: 0)
        //     : null,
        child: Column(
      children: [
        Row(children: [
          bulleted
              ? Padding(
                  padding:
                      EdgeInsets.only(left: 20.0 + 25 * bulletLevel, top: 3),
                  child: bulletLevel % 2 == 0
                      ? Container(
                          width: 5,
                          height: 5,
                          color: Colors.black,
                          alignment: Alignment.center,
                        )
                      : Container(
                          width: 5,
                          height: 5,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 0, 0, 0),
                              border: Border.all(),
                              borderRadius: BorderRadius.circular(20))))
              : const SizedBox.shrink(),
          Expanded(
              // child: WordWrapWidget(
              //     text: inlineSpansToString(spans),
              //     textStyle: TextStyle(fontSize: 18))),
              child: Container(
                  child: Padding(
                      padding: bulleted
                          ? const EdgeInsets.only(left: 8, right: 16.0)
                          : const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Stack(clipBehavior: Clip.none, children: [
                        Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color:
                                        const Color.fromARGB(255, 29, 29, 29))),
                            margin: const EdgeInsets.symmetric(vertical: 7),
                            padding: const EdgeInsets.only(
                                top: 5, bottom: 6, left: 9, right: 9),
                            child: RichText(
                                text: TextSpan(
                                    children: spans,
                                    style:
                                        const TextStyle(color: Colors.black)),
                                softWrap: true)),
                        highlight && suggestionList.isNotEmpty
                            ? Positioned(
                                bottom: -20,
                                child: Container(
                                    height: 200,
                                    color: Colors.green,
                                    padding: const EdgeInsets.all(5),
                                    child: highlight &&
                                            suggestionList.isNotEmpty
                                        ? const SizedBox()
                                        // ? ListView.builder(
                                        //     scrollDirection: Axis.vertical,
                                        //     itemCount: suggestionList.length,
                                        //     itemBuilder: (BuildContext context,
                                        //         int index) {
                                        //       return Container(
                                        //           margin: EdgeInsets.all(2),
                                        //           child: Text(
                                        //             suggestionList[index]
                                        //                         .length >
                                        //                     20
                                        //                 ? suggestionList[index]
                                        //                         .substring(
                                        //                             0, 20) +
                                        //                     '...'
                                        //                 : suggestionList[index],
                                        //           ));
                                        //     })
                                        : const SizedBox()),
                              )
                            : const SizedBox(),
                      ])))),
        ])
      ],
    ));
  }
}

class View extends StatefulWidget {
  const View({super.key, required this.fileName});
  final String fileName;
  @override
  _View createState() => _View();
}

class _View extends State<View> {
  late ScrollController scroller;
  late FocusNode _focusNode;
  bool maximized = false;
  bool init = false;
  double fontSize = 40;
  var db;
  List<int> bulletList = List.generate(0, (index) => -1);
  @override
  void initState() {
    scroller = ScrollController();
    _asyncLoadDB();

    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      print("Has focus: ${_focusNode.hasFocus}");
    });
    init = true;
  }

  @override
  void dispose() {
    scroller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  _asyncLoadDB() async {
    Database retrievedDB = db = await openDatabase('constellation_db.db');
    try {
      String fileName = widget.fileName;
      print(fileName);
      List<Map> queryResultsList =
          await db.rawQuery("SELECT * FROM constellation_table");

      print(queryResultsList);
      String bulletListString = "";
      for (int i = 0; i < queryResultsList.length; i++) {
        if (queryResultsList[i]['name'] == fileName) {
          bulletListString = queryResultsList[i]['bullet_list'];
        }
      }
      setState(() {
        bulletList = json.decode(bulletListString).cast<int>().toList();
        init = true;
      });
    } catch (e) {
      print(e);
    }
  }

  void _onEnterSpecial(PointerEvent event, DocumentProvider doc) {
    print("entered special area");
    doc.doc.setDisableClick(true);
    // setState(() {
    //   doc.doc.setDisableClick(true);
    // });
  }

  void _onExitSpecial(PointerEvent event, DocumentProvider doc) {
    doc.doc.setDisableClick(false);
    // setState(() {
    //   doc.doc.setDisableClick(false);
    // });
  }

  Widget controllerButton(
      DocumentProvider doc, IconData buttonIcon, VoidCallback behavior) {
    return Container(
        height: 20,
        width: 20,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
              bottom:
                  BorderSide(color: Color.fromARGB(255, 64, 70, 81), width: 2),
              right: BorderSide(
                  color: Color.fromARGB(255, 181, 227, 247), width: 2),
              left: BorderSide(
                  color: Color.fromARGB(255, 181, 227, 247), width: 2),
              top: BorderSide(
                  color: Color.fromARGB(255, 181, 227, 247), width: 2)),
        ),
        child: IconButton(
            padding: const EdgeInsets.all(0.0),
            style: IconButton.styleFrom(
              foregroundColor: const Color.fromARGB(255, 255, 255, 255),
              backgroundColor: const Color.fromARGB(255, 75, 185, 233),
              shape: const ContinuousRectangleBorder(),
            ),
            onPressed: behavior,
            iconSize: 15,
            icon: Icon(buttonIcon)));
  }

  @override
  Widget build(BuildContext context) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    if (init) {
      doc.doc.initBulletLists(bulletList);
      init = false;
    }
    return Scaffold(
        appBar: AppBar(
          shape: const Border(
              bottom:
                  BorderSide(color: Color.fromARGB(255, 64, 70, 81), width: 3),
              right: BorderSide(
                  color: Color.fromARGB(255, 205, 209, 218), width: 3),
              left: BorderSide(
                  color: Color.fromARGB(255, 205, 209, 218), width: 3),
              top: BorderSide(
                  color: Color.fromARGB(255, 205, 209, 218), width: 3)),
          titleSpacing: 0,
          primary: false,
          backgroundColor: const Color.fromARGB(255, 75, 185, 233),
          title: GestureDetector(
              onHorizontalDragStart: (e) {
                WindowManager.instance.startDragging();
              },
              onVerticalDragStart: (e) {
                WindowManager.instance.startDragging();
              },
              child: Container(
                color: const Color.fromARGB(255, 233, 237, 246),
                // Color.fromARGB(255, 75, 185, 233),

                child: Container(
                    color: const Color.fromARGB(255, 50, 73, 126),
                    child: Container(
                      color: const Color.fromARGB(255, 75, 185, 233),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(width: 10),
                          Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color.fromARGB(255, 64, 70, 81),
                                        width: 2),
                                    right: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2),
                                    left: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2),
                                    top: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2)),
                              ),
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  foregroundColor:
                                      const Color.fromARGB(255, 255, 255, 255),
                                  backgroundColor:
                                      const Color.fromARGB(255, 75, 185, 233),
                                  shape: const ContinuousRectangleBorder(),
                                ),
                                onPressed: () {
                                  WindowManager.instance.setFullScreen(false);
                                  WindowManager.instance.minimize();
                                  if (maximized) {
                                    maximized = !maximized;
                                  }
                                },
                                icon: const Icon(Icons.minimize_sharp),
                              )),
                          const SizedBox(width: 10),
                          Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color.fromARGB(255, 64, 70, 81),
                                        width: 2),
                                    right: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2),
                                    left: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2),
                                    top: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2)),
                              ),
                              child: IconButton(
                                  style: IconButton.styleFrom(
                                    foregroundColor: const Color.fromARGB(
                                        255, 255, 255, 255),
                                    backgroundColor:
                                        const Color.fromARGB(255, 75, 185, 233),
                                    shape: const ContinuousRectangleBorder(),
                                  ),
                                  onPressed: () {
                                    print("close");
                                    if (maximized) {
                                      WindowManager.instance
                                          .setFullScreen(false);
                                    } else {
                                      WindowManager.instance
                                          .setFullScreen(true);
                                    }
                                    maximized = !maximized;
                                  },
                                  icon: const Icon(Icons.web_asset_sharp))),
                          const SizedBox(width: 10),
                          Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color.fromARGB(255, 64, 70, 81),
                                        width: 2),
                                    right: BorderSide(
                                        color:
                                            Color.fromARGB(255, 253, 165, 171),
                                        width: 2),
                                    left: BorderSide(
                                        color:
                                            Color.fromARGB(255, 253, 165, 171),
                                        width: 2),
                                    top: BorderSide(
                                        color:
                                            Color.fromARGB(255, 253, 165, 171),
                                        width: 2)),
                              ),
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  foregroundColor:
                                      const Color.fromARGB(255, 255, 255, 255),
                                  backgroundColor:
                                      const Color.fromARGB(255, 216, 31, 81),
                                  shape: const ContinuousRectangleBorder(),
                                ),
                                onPressed: () {
                                  print("close");
                                  doc.doc.saveFile();
                                  WindowManager.instance.close();
                                },
                                icon: const Icon(Icons.clear),
                              )),
                          const SizedBox(width: 10),
                        ],
                      ),
                    )),
              )),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          child: ListView(
            children: <Widget>[
              SizedBox(
                  height: 120,
                  child: DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                    child: Container(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Menu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                          ),
                        )),
                  )),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () {
                  // Handle menu item tap
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  // Handle menu item tap
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Logout'),
                onTap: () {},
              ),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 233, 237, 246), // Background color
            border: Border(
              bottom:
                  BorderSide(color: Color.fromARGB(255, 64, 70, 81), width: 3),
              right: BorderSide(
                  color: Color.fromARGB(255, 205, 209, 218), width: 3),
              left: BorderSide(
                  color: Color.fromARGB(255, 205, 209, 218), width: 3),
            ),
          ),
          child: Column(children: <Widget>[
            Container(
                width: 800,
                height: 510,
                constraints: const BoxConstraints(minWidth: 700, maxWidth: 900),
                decoration: BoxDecoration(
                    color: const Color.fromARGB(
                        255, 255, 255, 255), // Background color
                    border: Border.all(
                        color: const Color.fromARGB(255, 214, 218, 226))),
                margin: const EdgeInsets.only(
                    left: 15.0, right: 15.0, bottom: 15.0, top: 15.0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        border: Border(
                            bottom: BorderSide(
                                color: Color.fromARGB(255, 64, 70, 81),
                                width: 2),
                            right: BorderSide(
                                color: Color.fromARGB(255, 181, 227, 247),
                                width: 2),
                            left: BorderSide(
                                color: Color.fromARGB(255, 181, 227, 247),
                                width: 2),
                            top: BorderSide(
                                color: Color.fromARGB(255, 181, 227, 247),
                                width: 2)),
                      ),
                      child: Row(
                        children: [
                          MouseRegion(
                            onEnter: (event) => _onEnterSpecial(event, doc),
                            onExit: (event) => _onExitSpecial(event, doc),
                            child: IconButton(
                              color: Colors.white,
                              iconSize: 20,
                              icon:
                                  const Icon(Icons.format_list_bulleted_sharp),
                              onPressed: () {
                                doc.doc.bulletMode();
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          controllerButton(doc, Icons.arrow_drop_down_sharp,
                              () {
                            doc.doc.setFontSize(doc.doc.getFontSize() - 1);
                            setState(() {});
                          }),
                          const SizedBox(width: 4),
                          Container(
                              decoration: const BoxDecoration(),
                              alignment: Alignment.center,
                              width: 40,
                              height: 40,
                              child: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                      (doc.doc.getFontSize())
                                          .toStringAsFixed(0),
                                      style: const TextStyle(
                                          fontFamily: "PressStart2P",
                                          color: Colors.white,
                                          fontSize: 13)))),
                          const SizedBox(width: 4),
                          controllerButton(doc, Icons.arrow_drop_up_sharp, () {
                            doc.doc.setFontSize(doc.doc.getFontSize() + 1);
                            setState(() {});
                          }),
                          const SizedBox(width: 10),
                          controllerButton(
                            doc,
                            Icons.arrow_right_sharp,
                            () {
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(
                              //       builder: (context) =>
                              //           const Constellation()),
                              // );
                            },
                          ),
                          const SizedBox(width: 10),
                          controllerButton(
                            doc,
                            Icons.save_sharp,
                            () async {
                              List<int> valuesToSave =
                                  List.from(doc.doc.bulletLevel);
                              for (int i = 0; i < valuesToSave.length; i++) {
                                if (!doc.doc.bulletActive[i]) {
                                  valuesToSave[i] -= 1;
                                }
                              }
                              await db.rawUpdate(
                                  'UPDATE constellation_table SET bullet_list = ? WHERE name = ?',
                                  [valuesToSave.toString(), widget.fileName]);
                              doc.doc.saveFile();
                            },
                          ),
                          TextButton(
                            child: const Text('RETURN'),
                            onPressed: () async {
                              List<int> valuesToSave =
                                  List.from(doc.doc.bulletLevel);
                              for (int i = 0; i < valuesToSave.length; i++) {
                                if (!doc.doc.bulletActive[i]) {
                                  valuesToSave[i] -= 1;
                                }
                              }
                              await db.rawUpdate(
                                  'UPDATE constellation_table SET bullet_list = ? WHERE name = ?',
                                  [valuesToSave.toString(), widget.fileName]);
                              doc.doc.saveFile();
                              Navigator.pop(context);
                            },
                          ),
                          TextButton(
                            child: const Text('CONST'),
                            onPressed: () => {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => Constellation(
                                        bulletList: doc.doc.bulletLevel,
                                        textList: doc.doc.lines,
                                        line: doc
                                            .doc.lines[doc.doc.cursor.line])),
                              )
                            },
                          ),
                        ],
                      )),
                  const SizedBox(
                    height: 20,
                    width: 1000,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 233, 237, 246),
                      ),
                    ),
                  ),
                  Expanded(
                      child: Focus(
                          onFocusChange: (hasFocus) {
                            doc.doc.setFocus(hasFocus);
                          },
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: ListView.builder(
                                  scrollDirection: Axis.vertical,
                                  shrinkWrap: true,
                                  controller: scroller,
                                  itemCount: doc.doc.lines.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    return ViewLine(
                                        lineNumber: index,
                                        text: doc.doc.lines[index]);
                                  }))))
                ]))
          ]),
        ));
  }
}
