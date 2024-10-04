import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:lynklynk/utils/suggestions.dart' as suggestions;
import 'package:lynklynk/layout/constellation.dart';
import 'package:searchfield/searchfield.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Test extends StatefulWidget {
  const Test({super.key, required this.path, required this.fileName});

  final String path;
  final String fileName;

  @override
  State<Test> createState() => _Test();
}

class TabIntent extends Intent {
  const TabIntent(this.index);

  final int index;
}

class TabAction extends Action<TabIntent> {
  TabAction();

  @override
  void invoke(covariant TabIntent intent) {}
}

class EnterIntent extends Intent {
  const EnterIntent(this.index);

  final int index;
}

class EnterAction extends Action<EnterIntent> {
  EnterAction();

  @override
  void invoke(covariant EnterIntent intent) {}
}

class ArrowIntent extends Intent {
  const ArrowIntent(this.index);

  final int index;
}

class ArrowAction extends Action<ArrowIntent> {
  ArrowAction();

  @override
  void invoke(covariant ArrowIntent intent) {}
}

class _Test extends State<Test> {
  bool maximized = false;
  suggestions.Suggestions suggestion = new suggestions.Suggestions();
  List<Widget> bulletList = [];
  int focused = -1;
  bool shift = false;
  List<int> bulletLevelList = [];
  List<Key> bulletKeyList = [];
  List<FocusNode> bulletFocusList = [];
  List<TextEditingController> bulletControllerList = [];
  SearchController searchbarController = SearchController();
  final ScrollController pageViewScrollController = ScrollController();
  final ScrollController reorderScrollController = ScrollController();
  List<String> suggestionList = [];
  String searchbarText = "";
  bool inSuggestionArea = false;

  var db;

  double suggestionHeight = 100;
  @override
  void initState() {
    ServicesBinding.instance.keyboard.addHandler(_onKey);
    openFile(widget.path);

    super.initState();
  }

  Future<bool> openFile(String path) async {
    Database retrievedDB = db = await openDatabase('constellation_db.db');
    String fileName = widget.fileName;
    List<Map> queryResultsList =
        await db.rawQuery("SELECT * FROM constellation_table");
    Map queryResult = queryResultsList
        .where((item) => item["name"] == widget.fileName)
        .toList()[0];
    print(queryResult.length);

    var queryLevelList = jsonDecode(queryResult["bullet_list"]);

    File f = File(path);
    String fileString = await f.readAsString();
    // fileString = fileString.replaceAll(r'\n', '\n');
    const splitter = LineSplitter();
    final linesList = splitter.convert(fileString);
    for (var i = 0; i < linesList.length; i++) {
      setState(() => suggestion.addTerm(linesList[i]));
      bulletLevelList.add(queryLevelList[i]);
      bulletControllerList.add(TextEditingController(text: linesList[i]));
      bulletFocusList.add(FocusNode());

      bulletList.add(bullet(
          bulletList.length, bulletLevelList[bulletLevelList.length - 1]));
      bulletKeyList.add(UniqueKey());
    }

    setState(() => {});

    return true;
  }

  Future<bool> saveFile(String path) async {
    File f = File(path);
    String content = '';
    int i;
    await db.rawUpdate(
        'UPDATE constellation_table SET bullet_list = ? WHERE name = ?',
        [bulletLevelList.toString(), widget.fileName]);
    for (i = 0; i < bulletControllerList.length; i++) {
      if (bulletControllerList[i].text.isEmpty) continue;
      if (i < bulletControllerList.length - 1) {
        content += bulletControllerList[i].text + '\n';
      } else {
        content += bulletControllerList[i].text;
      }
    }
    f.writeAsString(content);

    return true;
  }

  List<String> getBulletText() {
    List<String> s = [];
    for (int i = 0; i < bulletControllerList.length; i++) {
      s.add(bulletControllerList[i].text);
    }
    return s;
  }

  double getHeight(int h) {
    return 54 + 50 * h.toDouble();
  }

  bool _onKey(KeyEvent event) {
    final key = event.logicalKey.keyLabel;
    if (event is KeyDownEvent) {
      if (key == "Shift Left" || key == "Shift Right") {
        shift = true;
      }
      if (key == "Arrow Up") {
        if (focused < 1) return false;
        setState(() {
          focused -= 1;
        });
      }
      if (key == "Arrow Down") {
        if (focused >= bulletList.length - 1) return false;
        setState(() {
          focused += 1;
        });
      }
      if (key == "Tab") {
        if (shift) {
          if (bulletLevelList[focused] == 0) return false;
          setState(() => bulletLevelList[focused] -= 1);
        } else {
          if (bulletLevelList[focused] == 6) return false;
          setState(() => bulletLevelList[focused] += 1);
        }
      }
      if (key == "Enter") {
        if (!shift && focused > -1) {
          int insertLevel = focused + 1;
          setState(() {
            bulletLevelList.insert(insertLevel, bulletLevelList[focused]);
            if (bulletControllerList[focused]
                .selection
                .textInside(bulletControllerList[focused].text)
                .isNotEmpty) {
              bulletControllerList.insert(
                  insertLevel,
                  TextEditingController(
                      text: bulletControllerList[focused]
                          .selection
                          .textInside(bulletControllerList[focused].text)));
            } else {
              bulletControllerList.insert(
                  insertLevel, TextEditingController(text: ""));
            }

            suggestion.insertTerm(insertLevel, "");
            bulletKeyList.insert(insertLevel, UniqueKey());
            bulletFocusList.insert(insertLevel, FocusNode());

            bulletFocusList[insertLevel].requestFocus();
            bulletList.insert(
                insertLevel,
                bullet(bulletList.length,
                    bulletLevelList[bulletLevelList.length - 1]));
            focused = insertLevel;
          });
        }
        if (shift && focused > -1) {
          int insertLevel = focused + 1;
          setState(() {
            bulletLevelList.insert(insertLevel, bulletLevelList[focused] + 1);
            if (bulletControllerList[focused]
                .selection
                .textInside(bulletControllerList[focused].text)
                .isNotEmpty) {
              bulletControllerList.insert(
                  insertLevel,
                  TextEditingController(
                      text: bulletControllerList[focused]
                          .selection
                          .textInside(bulletControllerList[focused].text)));
            } else {
              bulletControllerList.insert(
                  insertLevel, TextEditingController(text: ""));
            }
            bulletFocusList.insert(insertLevel, FocusNode());
            bulletFocusList[insertLevel].requestFocus();
            bulletList.insert(
                insertLevel,
                bullet(bulletList.length,
                    bulletLevelList[bulletLevelList.length - 1]));
            suggestion.insertTerm(insertLevel, "");
            bulletKeyList.insert(insertLevel, UniqueKey());

            focused = insertLevel;
          });
        }
      }
    } else if (event is KeyUpEvent) {
      if (key == "Shift Left" || key == "Shift Right") {
        shift = false;
      }
    } else if (event is KeyRepeatEvent) {
      print("Key repeat: $key");
    }

    return false;
  }

  void makeMain(int index, int level) {
    int levelTracker = level;
    int minRange = index;
    int maxRange = index;
    List<int> nodePoints = [index];
    for (int i = index - 1; i >= 0; i--) {
      if (bulletLevelList[i] < levelTracker) {
        nodePoints.add(i);
        levelTracker = bulletLevelList[i];
        if (levelTracker <= 0) {
          break;
        }
      }
    }
    Map<int, List<int>> nodeMapping = {};
    minRange = nodePoints[nodePoints.length - 1];
    for (int i = 0; i < nodePoints.length; i++) {
      int nodeIndex = nodePoints[i];
      nodeMapping.addEntries(<int, List<int>>{nodeIndex: []}.entries);
      bool existingSubnode = false;
      int existingSubnodeLevel = 0;
      for (int j = nodeIndex + 1; j < bulletList.length; j++) {
        if (bulletLevelList[j] <= bulletLevelList[nodeIndex]) {
          if (maxRange < j) {
            print(j);
            maxRange = j;
          }
          break;
        } else {
          if (j + 1 == bulletList.length) {
            maxRange = bulletList.length;
          }
          if (existingSubnode && existingSubnodeLevel < bulletLevelList[j]) {
            continue;
          } else {
            existingSubnode = false;
          }
          if (nodePoints.contains(j)) {
            existingSubnode = true;
            existingSubnodeLevel = bulletLevelList[j];
            continue;
          }
          nodeMapping[nodeIndex]?.add(j);
        }
      }
      setState(() => {});
    }
    print(nodeMapping);
    List<int> newBulletOrdering = [];
    List<int> newBulletLevelList = [];
    for (int i = nodePoints.length - 1; i >= 0; i--) {
      int nodePointIndex = nodePoints[i];
      newBulletOrdering.insert(0, nodePointIndex);
      newBulletOrdering += nodeMapping[nodePointIndex] ?? [];
      newBulletLevelList.insert(0, i);
      newBulletLevelList += List.generate(
          nodeMapping[nodePointIndex]?.length ?? 0,
          (int index) =>
              bulletLevelList[nodeMapping[nodePointIndex]?[index] ?? 0] -
              (bulletLevelList[nodePointIndex] - i));
    }
    print("new ordering: $newBulletOrdering");
    print(newBulletLevelList);

    List<Widget> newBulletList =
        newBulletOrdering.map((e) => bulletList[e]).toList();
    List<TextEditingController> newBulletControllerList =
        newBulletOrdering.map((e) => bulletControllerList[e]).toList();
    List<Key> newBulletKeyList =
        newBulletOrdering.map((e) => bulletKeyList[e]).toList();
    List<FocusNode> newBulletFocusList =
        newBulletOrdering.map((e) => bulletFocusList[e]).toList();
    print(minRange);
    print(maxRange);
    // if (newBulletList.length == bulletList.length || ) {
    //   maxRange += 1;
    // }
    print(maxRange);
    bulletList.removeRange(minRange, maxRange);
    bulletLevelList.removeRange(minRange, maxRange);
    bulletControllerList.removeRange(minRange, maxRange);
    bulletKeyList.removeRange(minRange, maxRange);
    bulletFocusList.removeRange(minRange, maxRange);

    bulletList = newBulletList + bulletList;
    bulletControllerList = newBulletControllerList + bulletControllerList;
    bulletKeyList = newBulletKeyList + bulletKeyList;
    bulletLevelList = newBulletLevelList + bulletLevelList;
    bulletFocusList = newBulletFocusList + bulletFocusList;

    focused = 0;
  }

  Future<void> showPopUpMenu(Offset globalPosition, int index) async {
    double left = globalPosition.dx;
    double top = globalPosition.dy;
    print(left);
    print(top);
    print("-----------");
    await showMenu(
      color: Colors.white,
      //add your color
      context: context,
      position: RelativeRect.fromLTRB(left, top, 0, 0),
      items: [
        const PopupMenuItem(
          value: 1,
          child: Padding(
            padding: const EdgeInsets.only(left: 0, right: 40),
            child: Row(
              children: [
                Icon(Icons.edit_sharp),
                SizedBox(
                  width: 10,
                ),
                Text(
                  "Edit",
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuItem(
          value: 2,
          child: Padding(
            padding: const EdgeInsets.only(left: 0, right: 40),
            child: Row(
              children: [
                Icon(Icons.delete_forever_sharp),
                SizedBox(
                  width: 10,
                ),
                Text(
                  "Delete",
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
        ),
      ],
      elevation: 8.0,
    ).then((value) {
      print(value);
      if (value == 1) {}
      if (value == 2) {
        int newIndex = index;

        if (newIndex != 0 || bulletList.length == 1) {
          newIndex -= 1;
        }
        setState(() => suggestion.removeAt(index));
        setState(() {
          bulletList.removeAt(index);
          bulletLevelList.removeAt(index);
          bulletControllerList.removeAt(index);
          bulletKeyList.removeAt(index);
          bulletFocusList.removeAt(index);
          focused = newIndex;
        });
      }
    });
  }

  Widget bullet(int index, int level) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (TapDownDetails details) {
          showPopUpMenu(details.globalPosition, index);
        },
        onDoubleTap: () {
          if (bulletControllerList[index].text == "") return;

          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Constellation(
                    bulletList: bulletLevelList,
                    textList: bulletControllerList
                        .map((controller) => controller.text)
                        .toList(),
                    line: bulletControllerList[index].text),
              ));
        },
        child: Container(
            padding: const EdgeInsets.only(left: 0, right: 10),
            child: Row(children: [
              Container(
                  padding: EdgeInsets.all(15),
                  child: focused == index
                      ? const Icon(size: 10, Icons.circle)
                      : const Icon(size: 10, Icons.circle_outlined)),
              Container(
                  alignment: Alignment.center,
                  child: IntrinsicWidth(
                      child: Container(
                    width: MediaQuery.of(context).size.width -
                        200 -
                        25 * bulletLevelList[index].toDouble(),
                    // constraints: BoxConstraints(
                    //     maxWidth: 600 -
                    //         min(500, 25 * bulletLevelList[index].toDouble())),
                    decoration: BoxDecoration(
                        border: focused == index
                            ? const Border(
                                left: BorderSide(width: 0.5),
                                right: BorderSide(width: 0.5))
                            : const Border(
                                left:
                                    BorderSide(width: 0.5, color: Colors.white),
                                right: BorderSide(
                                    width: 0.5, color: Colors.white)),
                        borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Focus(
                        onFocusChange: (hasFocus) {
                          if (!hasFocus &&
                              suggestion.getTerm(index) !=
                                  bulletControllerList[index].text) {
                            print(bulletControllerList[index].text);
                            setState(() => suggestion.setTerm(
                                bulletControllerList[index].text, index));
                          }
                        },
                        child: TextField(
                          maxLines: null,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                          onChanged: (e) {
                            if (e.contains("\n")) {
                              var splitLines = e.split('\n');
                              bulletControllerList[index].text = splitLines[0];
                              for (int i = 1; i < splitLines.length; i++) {
                                insertBullet(index + i, splitLines[i]);
                              }
                              setState(() {});
                              return;
                            }
                            print(suggestion.getSuggestion(e));
                            setState(() {
                              suggestionList = suggestion.getSuggestion(e);
                              var suggestionSet = {...suggestionList};
                              suggestionList = suggestionSet.toList();
                            });
                          },
                          focusNode: bulletFocusList[index],
                          decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              border: InputBorder.none),
                          controller: bulletControllerList[index],
                        )),
                  ))),
              Spacer(),
              level == 0
                  ? ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.star)))
                  : ReorderableDragStartListener(
                      index: index,
                      child: IconButton(
                          onPressed: () {
                            makeMain(index, level);
                          },
                          icon: Icon(Icons.star_border))),
              SizedBox(width: 8),
            ])));
  }

  addBullet() {
    bulletLevelList.add(0);
    bulletControllerList.add(TextEditingController(text: ""));
    bulletFocusList.add(FocusNode());

    bulletList.add(
        bullet(bulletList.length, bulletLevelList[bulletLevelList.length - 1]));
    bulletKeyList.add(UniqueKey());
    suggestion.addTerm("");
  }

  insertBullet(int index, String bulletText) {
    bulletLevelList.insert(index, 0);
    bulletControllerList.insert(index, TextEditingController(text: bulletText));
    bulletFocusList.insert(index, FocusNode());

    bulletList.insert(index,
        bullet(bulletList.length, bulletLevelList[bulletLevelList.length - 1]));
    bulletKeyList.insert(index, UniqueKey());
    suggestion.addTerm(bulletText);
  }

  Widget proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(0, 6, animValue)!;
        return Material(
          elevation: elevation,
          color: Colors.transparent,
          shadowColor: Colors.transparent,
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_onKey);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          LogicalKeySet(LogicalKeyboardKey.tab): const TabIntent(2),
          LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
              const TabIntent(2),
          LogicalKeySet(LogicalKeyboardKey.enter): const EnterIntent(2),
          LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.enter):
              const EnterIntent(2),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const ArrowIntent(2),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const ArrowIntent(2),
        },
        child: Actions(
            actions: <Type, Action<Intent>>{
              TabIntent: TabAction(),
              EnterIntent: EnterAction(),
              ArrowIntent: ArrowAction(),
            },
            child: Scaffold(
                appBar: AppBar(
                  toolbarHeight: 40,
                  titleSpacing: 0,
                  primary: false,

                  shape: const Border(
                      bottom: BorderSide(
                          color: Color.fromARGB(255, 64, 70, 81), width: 0.5)),
                  backgroundColor: Color.fromARGB(255, 255, 255, 255),
                  // backgroundColor: const Color.fromARGB(255, 75, 185, 233),
                  title: Container(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: GestureDetector(
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
                              color: Color.fromARGB(255, 255, 255, 255),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const SizedBox(width: 10),
                                  Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        style: IconButton.styleFrom(
                                          foregroundColor:
                                              Color.fromARGB(255, 0, 0, 0),
                                        ),
                                        onPressed: () {
                                          WindowManager.instance.minimize();
                                          if (maximized) {
                                            maximized = !maximized;
                                          }
                                        },
                                        icon: const Icon(
                                            size: 12,
                                            Icons.horizontal_rule_sharp),
                                      )),
                                  const SizedBox(width: 10),
                                  Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: IconButton(
                                          style: IconButton.styleFrom(
                                            foregroundColor:
                                                Color.fromARGB(255, 0, 0, 0),
                                          ),
                                          onPressed: () {
                                            if (maximized) {
                                              WindowManager.instance
                                                  .setFullScreen(false);
                                            } else {
                                              WindowManager.instance
                                                  .setFullScreen(true);
                                            }
                                            maximized = !maximized;
                                          },
                                          icon: const Icon(
                                              size: 12,
                                              Icons.web_asset_sharp))),
                                  const SizedBox(width: 10),
                                  Container(
                                      width: 20,
                                      height: 20,
                                      // decoration: BoxDecoration(
                                      //     borderRadius:
                                      //         BorderRadius.circular(30),
                                      //     border: Border.all()),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        style: IconButton.styleFrom(
                                          foregroundColor:
                                              Color.fromARGB(255, 0, 0, 0),
                                        ),
                                        onPressed: () {
                                          WindowManager.instance.close();
                                        },
                                        icon: const Icon(
                                          Icons.clear,
                                          size: 14,
                                        ),
                                      )),
                                  const SizedBox(width: 10),
                                ],
                              ),
                            ),
                          ))),
                  leading: Builder(
                    builder: (context) => Icon(Icons.rocket_launch_sharp),
                  ),
                ),
                body: Column(children: [
                  Container(
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(width: 0.5, color: Colors.black)),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      height: 55,
                      child: Row(
                        children: [
                          Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: Color.fromARGB(255, 0, 0, 0),
                                      width: 0.5)),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                style: const ButtonStyle(
                                    shape: WidgetStatePropertyAll(
                                        ContinuousRectangleBorder())),
                                icon: const Icon(
                                    size: 24, Icons.arrow_left_rounded),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              )),
                          const SizedBox(width: 10),
                          Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: Color.fromARGB(255, 0, 0, 0),
                                      width: 0.5)),
                              child: IconButton(
                                  padding: EdgeInsets.zero,
                                  style: const ButtonStyle(
                                      shape: WidgetStatePropertyAll(
                                          ContinuousRectangleBorder())),
                                  onPressed: () {
                                    saveFile(widget.path);
                                  },
                                  icon: Icon(size: 20, Icons.save_sharp))),
                          Spacer(),
                          Container(
                              width: min(
                                  MediaQuery.of(context).size.width - 200, 700),
                              height: 40,
                              margin: EdgeInsets.all(10),
                              child: SearchField<String>(
                                  dynamicHeight: true,
                                  searchInputDecoration: SearchInputDecoration(
                                      cursorWidth: 1,
                                      filled: true,
                                      fillColor:
                                          Color.fromARGB(49, 165, 165, 165),
                                      focusedBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 8, 128, 183),
                                            width: 1,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      border: OutlineInputBorder(
                                          borderSide: const BorderSide(
                                            width: 0.5,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 0, horizontal: 18),
                                      searchStyle: const TextStyle(
                                          letterSpacing: 0.4, fontSize: 15)),
                                  onSuggestionTap: (SearchFieldListItem term) {
                                    List terms = bulletControllerList
                                        .map((e) => e.text)
                                        .toList();
                                    for (int i = 0; i < terms.length; i++) {
                                      if (term.item == terms[i] &&
                                          bulletLevelList[i] > 0) {
                                        makeMain(i, bulletLevelList[i]);
                                        break;
                                      }
                                    }
                                  },
                                  suggestions: suggestion
                                      .getTerms()
                                      .map((e) => SearchFieldListItem<String>(e,
                                          item: e,
                                          child: Container(
                                              constraints: const BoxConstraints(
                                                  minHeight: 30),
                                              child: Row(children: [
                                                Expanded(
                                                    child: Text(e,
                                                        softWrap: false,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis))
                                              ]))))
                                      .toList())),
                        ],
                      )),
                  Expanded(
                      child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    width: 0.5, color: Colors.black)),
                            color: Color.fromARGB(255, 215, 222, 235),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 15, horizontal: 15),
                          child: Column(children: [
                            Expanded(
                                child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    controller: pageViewScrollController,
                                    child: Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 15, horizontal: 15),
                                        child: Column(children: [
                                          ReorderableListView.builder(
                                            scrollController:
                                                reorderScrollController,
                                            proxyDecorator: proxyDecorator,
                                            shrinkWrap: true,
                                            onReorder:
                                                (int oldIndex, int newIndex) {
                                              if (oldIndex == newIndex) {
                                                return;
                                              }

                                              if (newIndex >
                                                  bulletList.length) {
                                                newIndex = bulletList.length;
                                              }
                                              if (oldIndex < newIndex) {
                                                newIndex -= 1;
                                              }
                                              bulletList[oldIndex];
                                              setState(() =>
                                                  suggestion.swapLocation(
                                                      oldIndex, newIndex));
                                              setState(() {
                                                final Widget item = bulletList
                                                    .removeAt(oldIndex);
                                                focused = newIndex;
                                                bulletList.insert(
                                                    newIndex, item);
                                                bulletKeyList.insert(
                                                    newIndex,
                                                    bulletKeyList
                                                        .removeAt(oldIndex));
                                                bulletFocusList.insert(
                                                    newIndex,
                                                    bulletFocusList
                                                        .removeAt(oldIndex));
                                                bulletControllerList.insert(
                                                    newIndex,
                                                    bulletControllerList
                                                        .removeAt(oldIndex));
                                                bulletLevelList.insert(
                                                    newIndex,
                                                    bulletLevelList
                                                        .removeAt(oldIndex));
                                              });
                                            },
                                            buildDefaultDragHandles: false,
                                            itemCount: bulletList.length,
                                            itemBuilder: (BuildContext context,
                                                int index) {
                                              return Container(
                                                  key: Key(bulletKeyList[index]
                                                      .toString()),
                                                  child: (TapRegion(
                                                      onTapInside: (tap) {
                                                        if (focused == index) {
                                                          return;
                                                        }
                                                        setState(() {
                                                          focused = index;
                                                        });
                                                      },
                                                      onTapOutside: (tap) {
                                                        if (focused != index) {
                                                          return;
                                                        }

                                                        setState() {
                                                          focused = -1;
                                                        }
                                                      },
                                                      child: Card(
                                                          shadowColor:
                                                              const Color.fromARGB(
                                                                  255,
                                                                  187,
                                                                  59,
                                                                  59),
                                                          shape: const Border(
                                                              left: BorderSide(
                                                                  color: Color
                                                                      .fromARGB(
                                                                          93,
                                                                          0,
                                                                          0,
                                                                          0),
                                                                  width: 0.5)),
                                                          color: Colors.white,
                                                          margin:
                                                              EdgeInsets.only(
                                                            left: (25 *
                                                                bulletLevelList[
                                                                        index]
                                                                    .toDouble()),
                                                            top: 1.5,
                                                            bottom: index + 1 <
                                                                        bulletLevelList
                                                                            .length &&
                                                                    bulletLevelList[index +
                                                                            1] ==
                                                                        0
                                                                ? 5
                                                                : 0,
                                                          ),
                                                          child: Column(
                                                              children: [
                                                                bullet(
                                                                    index,
                                                                    bulletLevelList[
                                                                        index]),
                                                                focused == index &&
                                                                        (inSuggestionArea ||
                                                                            bulletFocusList[index]
                                                                                .hasFocus) &&
                                                                        bulletControllerList[index]
                                                                            .text
                                                                            .isNotEmpty &&
                                                                        suggestionList
                                                                            .isNotEmpty
                                                                    ? MouseRegion(
                                                                        onEnter:
                                                                            (e) {
                                                                          setState(
                                                                              () {
                                                                            inSuggestionArea =
                                                                                true;
                                                                          });
                                                                        },
                                                                        onExit:
                                                                            (e) {
                                                                          setState(
                                                                              () {
                                                                            inSuggestionArea =
                                                                                false;
                                                                          });
                                                                        },
                                                                        child:
                                                                            Column(
                                                                          children: [
                                                                            Container(
                                                                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 56),
                                                                                alignment: Alignment.centerLeft,
                                                                                child: const Text(style: TextStyle(fontWeight: FontWeight.bold), "Suggestions")),
                                                                            ListView.builder(
                                                                                shrinkWrap: true,
                                                                                itemCount: suggestionList.length < 6 ? suggestionList.length : 6,
                                                                                itemBuilder: (BuildContext context, int suggestionIndex) {
                                                                                  return Container(
                                                                                    padding: const EdgeInsets.only(bottom: 10, left: 56),
                                                                                    // decoration:
                                                                                    //     const BoxDecoration(border: Border(top: BorderSide(width: 1, color: Colors.black))),
                                                                                    height: 30,

                                                                                    child: InkWell(
                                                                                        child: Text(
                                                                                          overflow: TextOverflow.ellipsis,
                                                                                          suggestionList[suggestionIndex],
                                                                                          textAlign: TextAlign.left,
                                                                                        ),
                                                                                        onTap: () {
                                                                                          setState(() {
                                                                                            print("test");
                                                                                            bulletControllerList[index].text = suggestionList[suggestionIndex];
                                                                                            suggestionList = [];
                                                                                          });
                                                                                        }),
                                                                                  );
                                                                                })
                                                                          ],
                                                                        ))
                                                                    : SizedBox()
                                                              ])))));
                                            },
                                          ),
                                          SizedBox(height: 10),
                                          Container(
                                              width: 80,
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                    Radius.circular(25.0),
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color:
                                                          const Color.fromARGB(
                                                                  255, 0, 0, 0)
                                                              .withOpacity(0.2),
                                                      spreadRadius: 0.5,
                                                      blurRadius: 1,
                                                      offset: Offset(0, 1),
                                                    )
                                                  ]),
                                              child: IconButton(
                                                  style: ButtonStyle(
                                                      backgroundColor:
                                                          WidgetStateProperty
                                                              .all(const Color
                                                                  .fromARGB(
                                                                  255,
                                                                  255,
                                                                  255,
                                                                  255))),
                                                  color: Colors.black,
                                                  onPressed: () {
                                                    setState(() {
                                                      addBullet();
                                                      pageViewScrollController
                                                          .jumpTo(2 *
                                                              pageViewScrollController
                                                                  .position
                                                                  .maxScrollExtent);
                                                    });
                                                  },
                                                  icon: const Icon(Icons.add)))
                                        ]))))
                          ])))
                ]))));
  }
}
