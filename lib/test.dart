import 'dart:math';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:lynklynk/utils/suggestions.dart' as suggestions;
import 'package:lynklynk/layout/constellation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lynklynk/utils/bullet.dart' as Bullet;
import 'package:path/path.dart' as Path;

class Node {
  final int id;
  String nodeTerm;
  List<String> auxiliaries;
  String color;
  final String createDate;
  String updateDate;

  Node(
      {required this.id,
      required this.nodeTerm,
      required this.auxiliaries,
      required this.color,
      required this.createDate,
      required this.updateDate});
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nodeTerm': nodeTerm,
      'auxiliaries': auxiliaries.toString(),
      'color': color,
      'createDate': createDate,
      'updateDate': updateDate,
    };
  }
}

class Test extends StatefulWidget {
  const Test({super.key, required this.constellationName, required this.id});

  final String constellationName;
  final int id;

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
  suggestions.Suggestions suggestion = suggestions.Suggestions();
  List<Bullet.Bullet> bulletList = [];
  int focused = -1;
  bool shift = false;

  SearchController searchbarController = SearchController();
  final ScrollController pageViewScrollController = ScrollController();
  final ScrollController reorderScrollController = ScrollController();
  List<String> suggestionList = [];
  String searchbarText = "";
  bool inSuggestionArea = false;
  int selectBulletRangeMin = -1;

  late String constellationName;
  late int constellationID;

  //page number
  int pageIndex = 1;

  //max number of bullets on a page
  int pageMaxBulletNumber = 20;

  //number of bullets on a page
  int? pageBulletNumber;

  //list of all nodes in the constellation
  List<Node> nodeList = [];

  bool showPageNavigateLeftButton = false;
  bool showPageNavigateRightButton = false;

  Color backgroundColor = const Color.fromRGBO(252, 231, 200, 1);
  Color primary1 = const Color.fromRGBO(177, 194, 158, 1);
  Color primary2 = const Color.fromRGBO(250, 218, 122, 1);
  Color primary3 = const Color.fromRGBO(240, 160, 75, 1);

  var database;

  double suggestionHeight = 100;
  @override
  void initState() {
    constellationID = widget.id;
    constellationName = widget.constellationName;
    print("---------------------");
    ServicesBinding.instance.keyboard.addHandler(_onKey);
    _asyncLoadDB();

    super.initState();
  }

  _asyncLoadDB() async {
    database = openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      Path.join(await getDatabasesPath(), 'lynklynk_file_database.db'),
      // When the database is first created, create a table to store files.
      onCreate: (db, version) {
        // Run the CREATE TABLE statement on the database.
        return db.execute(
          'CREATE TABLE "${constellationName}_${constellationID.toString()}"(id INTEGER PRIMARY KEY, nodeTerm TEXT, auxiliaries TEXT, color TEXT, createDate TEXT, updateDate TEXT)',
        );
      },
      onUpgrade: _onUpgrade,
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 1,
    );

    try {
      List<Node> queryResultsList = await getNodeList();
      print(queryResultsList);
      setState(() {
        nodeList = queryResultsList;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<List<Node>> getNodeList() async {
    // Get a reference to the database.
    final db = await database;
    // Query the table for all the files.
    final List<Map<String, Object?>> fileMaps =
        await db.query('"${constellationName}_$constellationID"');
    // Convert the list of each file's fields into a list of `file` objects.
    return [
      for (final {
            'id': id as int,
            'nodeTerm': nodeTerm as String,
            'auxiliaries': auxiliaries as String,
            'color': color as String,
            'createDate': createDate as String,
            'updateDate': updateDate as String,
          } in fileMaps)
        Node(
          id: id,
          nodeTerm: nodeTerm,
          auxiliaries: json.decode(auxiliaries),
          color: color,
          createDate: createDate,
          updateDate: updateDate,
        )
    ];
  }

  Future<void> updateNode(Node file) async {
    // Get a reference to the database.
    final db = await database;

    // Update the given Dfile.
    await db.update(
      constellationName,
      file.toMap(),
      // Ensure that the file has a matching id.
      where: 'id = ?',
      // Pass the file's id as a whereArg to prevent SQL injection.
      whereArgs: [file.id],
    );

    updateFiles();
  }

  Future<void> deleteNode(int id, String fileName) async {
    // Get a reference to the database.
    final db = await database;

    // Remove the file from the database.
    await db.delete(
      constellationName,
      // Use a `where` clause to delete a specific file.
      where: 'id = ?',
      // Pass the file's id as a whereArg to prevent SQL injection.
      whereArgs: [id],
    );

    await db.execute("DROP TABLE IF EXISTS $fileName");
    updateFiles();
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) {
    if (oldVersion < 2) {
      db.execute(
          "ALTER TABLE files ADD COLUMN starred INTEGER NOT NULL DEFAULT (0);");
    }
  }

  Future<void> updateFiles() async {
    try {
      List<Node> queryResultsList = await getNodeList();
      print(queryResultsList);
      setState(() {
        nodeList = queryResultsList;
      });
    } catch (e) {
      print(e);
    }
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
      if (shift) {
        if (key == "Arrow Up") {
          if (focused < 1) return false;
          setState(() {
            focused -= 1;
            bulletList[focused].focus.requestFocus();
          });
        }
        if (key == "Arrow Down") {
          if (focused >= bulletList.length - 1) return false;
          setState(() {
            focused += 1;
            bulletList[focused].focus.requestFocus();
          });
        }
        if (key == "Arrow Right") {
          increasePageNumber();
        }
        if (key == "Arrow Left") {
          decreasePageNumber();
        }
      }
      if (key == "Tab") {
        int bulletLevel = bulletList[focused].level;
        if (shift) {
          if (bulletLevel == 0) return false;
          setState(() => bulletList[focused].level -= 1);
        } else {
          if (bulletLevel == 6) return false;
          setState(() => bulletList[focused].level += 1);
        }
      }
      if (key == "Enter") {
        if (!shift && focused > -1) {
          int insertLevel = focused + 1;
          TextEditingController newController = TextEditingController(text: "");
          if (bulletList[focused]
              .controller
              .selection
              .textInside(bulletList[focused].controller.text)
              .isNotEmpty) {
            newController = TextEditingController(
                text: bulletList[focused]
                    .controller
                    .selection
                    .textInside(bulletList[focused].controller.text));
          }
          Bullet.Bullet newBullet = Bullet.Bullet(bulletList[focused].level,
              UniqueKey(), FocusNode(), newController);
          setState(() {
            bulletList.insert(insertLevel, newBullet);
            suggestion.insertTerm(insertLevel, "");
            bulletList[insertLevel].focus.requestFocus();
            focused = insertLevel;
          });
        }
        if (shift && focused > -1) {
          int insertLevel = focused + 1;
          TextEditingController newController = TextEditingController(text: "");
          if (bulletList[focused]
              .controller
              .selection
              .textInside(bulletList[focused].controller.text)
              .isNotEmpty) {
            newController = TextEditingController(
                text: bulletList[focused]
                    .controller
                    .selection
                    .textInside(bulletList[focused].controller.text));
          }
          Bullet.Bullet newBullet = Bullet.Bullet(bulletList[focused].level + 1,
              UniqueKey(), FocusNode(), newController);
          setState(() {
            bulletList.insert(insertLevel, newBullet);
            bulletList[insertLevel].focus.requestFocus();
            suggestion.insertTerm(insertLevel, "");
            focused = insertLevel;
          });
        }
      }
    } else if (event is KeyUpEvent) {
      if (key == "Shift Left" || key == "Shift Right") {
        shift = false;
      }
    } else if (event is KeyRepeatEvent) {
      // print("Key repeat: $key");
    }

    return false;
  }

  bool inSelectBulletRange(int i) {
    int rangeMin = selectBulletRangeMin;
    int rangeMax = focused;
    if (focused < selectBulletRangeMin) {
      rangeMin = rangeMax;
      rangeMax = selectBulletRangeMin;
    }

    if (selectBulletRangeMin < 0) {
      return false;
    }
    if (rangeMin <= i && i <= rangeMax) {
      return true;
    }
    return false;
  }

  void decreasePageNumber() {
    if (pageIndex > 1) {
      setState(() {
        pageIndex -= 1;
        showPageNavigateRightButton = true;
        if (pageIndex == 1) {
          showPageNavigateLeftButton = false;
        }
        pageBulletNumber = calculatePageBulletNumber();
      });
    }
  }

  void increasePageNumber() {
    int end = pageMaxBulletNumber * pageIndex;
    if (bulletList.length > end) {
      setState(() {
        pageIndex += 1;
        showPageNavigateLeftButton = true;
        print(bulletList.length);
        print(pageMaxBulletNumber * pageIndex);
        if (pageMaxBulletNumber * pageIndex >= bulletList.length) {
          showPageNavigateRightButton = false;
        }
        pageBulletNumber = calculatePageBulletNumber();
        print(pageBulletNumber);
      });
    }
  }

  int calculatePageBulletNumber() {
    int end = pageMaxBulletNumber * pageIndex;
    if (bulletList.length < end) {
      return bulletList.length - pageMaxBulletNumber * (pageIndex - 1);
    }

    return pageMaxBulletNumber;
  }

  (int, int) returnValidRange() {
    if (bulletList.length < pageMaxBulletNumber) {
      return (0, bulletList.length);
    } else {
      int start = (pageIndex - 1) * pageMaxBulletNumber;
      int end = pageMaxBulletNumber * pageIndex;

      if (end > bulletList.length) {
        end = bulletList.length;
      }
      return (start, end);
    }
  }

  void makeMain(int index, int level) {
    int levelTracker = level;
    int minRange = index;
    int maxRange = index;
    List<int> nodePoints = [index];
    for (int i = index - 1; i >= 0; i--) {
      if (bulletList[i].level < levelTracker) {
        nodePoints.add(i);
        levelTracker = bulletList[i].level;
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
        if (bulletList[j].level <= bulletList[nodeIndex].level) {
          if (maxRange < j) {
            print(j);
            maxRange = j;
          }
          break;
        } else {
          if (j + 1 == bulletList.length) {
            maxRange = bulletList.length;
          }
          if (existingSubnode && existingSubnodeLevel < bulletList[j].level) {
            continue;
          } else {
            existingSubnode = false;
          }
          if (nodePoints.contains(j)) {
            existingSubnode = true;
            existingSubnodeLevel = bulletList[j].level;
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
              bulletList[nodeMapping[nodePointIndex]?[index] ?? 0].level -
              (bulletList[nodePointIndex].level - i));
    }
    print("new ordering: $newBulletOrdering");
    print(newBulletLevelList);

    List<Bullet.Bullet> newBulletList =
        newBulletOrdering.map((e) => bulletList[e]).toList();

    print(minRange);
    print(maxRange);
    // if (newBulletList.length == bulletList.length || ) {
    //   maxRange += 1;
    // }
    print(maxRange);
    bulletList.removeRange(minRange, maxRange);

    bulletList = newBulletList + bulletList;

    focused = 0;
  }

  Future<void> showPopUpMenu(Offset globalPosition, int index) async {
    double left = globalPosition.dx;
    double top = globalPosition.dy;
    await showMenu(
      color: Colors.white,
      //add your color
      context: context,
      position: RelativeRect.fromLTRB(left, top, 0, 0),
      items: [
        const PopupMenuItem(
          value: 1,
          child: Padding(
            padding: EdgeInsets.only(left: 0, right: 40),
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
            padding: EdgeInsets.only(left: 0, right: 40),
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

          focused = newIndex;
        });
      }
    });
  }

  Widget BulletWidget(int index, int level) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (TapDownDetails details) {
          showPopUpMenu(details.globalPosition, index);
        },
        onDoubleTap: () {
          if (bulletList[index].controller.text.isEmpty) return;

          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Constellation(
                    bulletList: bulletList.map((e) => e.level).toList(),
                    textList: bulletList.map((e) => e.controller.text).toList(),
                    line: bulletList[index].controller.text),
              ));
        },
        child: Container(
            padding: const EdgeInsets.only(left: 0, right: 10),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(15),
                  child: focused == index || inSelectBulletRange(index)
                      ? const Icon(size: 10, Icons.circle)
                      : const Icon(size: 10, Icons.circle_outlined)),
              Container(
                  alignment: Alignment.center,
                  child: IntrinsicWidth(
                      child: Container(
                    width: MediaQuery.of(context).size.width -
                        200 -
                        25 * bulletList[index].level.toDouble(),
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
                                  bulletList[index].controller.text) {
                            print(bulletList[index].controller.text);
                            setState(() => suggestion.setTerm(
                                bulletList[index].controller.text, index));
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
                              bulletList[index].controller.text = splitLines[0];
                              splitLines.removeWhere((e) => e.isEmpty);
                              bulletList[index].controller.text = splitLines[0];
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
                          focusNode: bulletList[index].focus,
                          decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              border: InputBorder.none),
                          controller: bulletList[index].controller,
                        )),
                  ))),
              const Spacer(),
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
                          icon: const Icon(Icons.star_border))),
              const SizedBox(width: 8),
            ])));
  }

  addBullet() {
    bulletList.add(Bullet.Bullet(
        0, UniqueKey(), FocusNode(), TextEditingController(text: "")));
    suggestion.addTerm("");
  }

  insertBullet(int index, String bulletText) {
    bulletList.insert(
        index,
        Bullet.Bullet(0, UniqueKey(), FocusNode(),
            TextEditingController(text: bulletText)));
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
          LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowUp):
              const ArrowIntent(2),
          LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowDown):
              const ArrowIntent(2),
        },
        child: Actions(
            actions: <Type, Action<Intent>>{
              TabIntent: TabAction(),
              EnterIntent: EnterAction(),
              ArrowIntent: ArrowAction(),
            },
            child: Scaffold(
                appBar: AppBar(
                  scrolledUnderElevation: 0,
                  toolbarHeight: 40,
                  titleSpacing: 0,
                  primary: false,

                  shape: const Border(
                      bottom: BorderSide(
                          color: Color.fromARGB(255, 64, 70, 81), width: 0.5)),
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  // backgroundColor: const Color.fromARGB(255, 75, 185, 233),
                  title: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
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
                              color: const Color.fromARGB(255, 255, 255, 255),
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
                                          foregroundColor: const Color.fromARGB(
                                              255, 0, 0, 0),
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
                                                const Color.fromARGB(
                                                    255, 0, 0, 0),
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
                                  SizedBox(
                                      width: 20,
                                      height: 20,
                                      // decoration: BoxDecoration(
                                      //     borderRadius:
                                      //         BorderRadius.circular(30),
                                      //     border: Border.all()),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        style: IconButton.styleFrom(
                                          foregroundColor: const Color.fromARGB(
                                              255, 0, 0, 0),
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
                    builder: (context) => const Icon(Icons.rocket_launch_sharp),
                  ),
                ),
                body: Column(children: [
                  Container(
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(width: 0.5, color: Colors.black)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
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
                                      color: const Color.fromARGB(255, 0, 0, 0),
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
                                      color: const Color.fromARGB(255, 0, 0, 0),
                                      width: 0.5)),
                              child: IconButton(
                                  padding: EdgeInsets.zero,
                                  style: const ButtonStyle(
                                      shape: WidgetStatePropertyAll(
                                          ContinuousRectangleBorder())),
                                  onPressed: () {
                                    // saveFile(widget.path);
                                  },
                                  icon:
                                      const Icon(size: 20, Icons.save_sharp))),
                          const SizedBox(width: 10),
                          Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: const Color.fromARGB(255, 0, 0, 0),
                                      width: 0.5)),
                              child: IconButton(
                                  padding: EdgeInsets.zero,
                                  style: const ButtonStyle(
                                      shape: WidgetStatePropertyAll(
                                          ContinuousRectangleBorder())),
                                  onPressed: () {
                                    // saveFile(widget.path);
                                  },
                                  icon: const Icon(
                                      size: 20, Icons.settings_sharp))),
                          const Spacer(),
                          Container(
                            width: min(
                                MediaQuery.of(context).size.width - 200, 700),
                            height: 40,
                            margin: const EdgeInsets.all(10),
                            // child: SearchField<String>(
                            //     onSearchTextChanged: (String e) {
                            //       if (e.isEmpty) return [];
                            //       return suggestion
                            //           .getSuggestion(e)
                            //           .map((e) => SearchFieldListItem<String>(
                            //               e,
                            //               item: e,
                            //               child: Container(
                            //                   constraints:
                            //                       const BoxConstraints(
                            //                           minHeight: 30),
                            //                   child: Row(children: [
                            //                     Expanded(
                            //                         child: Text(e,
                            //                             softWrap: false,
                            //                             maxLines: 2,
                            //                             overflow: TextOverflow
                            //                                 .ellipsis))
                            //                   ]))))
                            //           .toList()
                            //           .getRange(
                            //               0,
                            //               suggestion.getSuggestion(e).length <
                            //                       6
                            //                   ? suggestion
                            //                       .getSuggestion(e)
                            //                       .length
                            //                   : 6)
                            //           .toList();
                            //     },
                            //     dynamicHeight: true,
                            //     searchInputDecoration: SearchInputDecoration(
                            //         cursorWidth: 1,
                            //         filled: true,
                            //         fillColor: const Color.fromARGB(
                            //             49, 165, 165, 165),
                            //         focusedBorder: OutlineInputBorder(
                            //             borderSide: const BorderSide(
                            //               color: Color.fromARGB(
                            //                   255, 8, 128, 183),
                            //               width: 1,
                            //             ),
                            //             borderRadius:
                            //                 BorderRadius.circular(20)),
                            //         border: OutlineInputBorder(
                            //             borderSide: const BorderSide(
                            //               width: 0.5,
                            //             ),
                            //             borderRadius:
                            //                 BorderRadius.circular(20)),
                            //         contentPadding:
                            //             const EdgeInsets.symmetric(
                            //                 vertical: 0, horizontal: 18),
                            //         searchStyle: const TextStyle(
                            //             letterSpacing: 0.4, fontSize: 15)),
                            //     onSuggestionTap: (SearchFieldListItem term) {
                            //       List terms = bulletList
                            //           .map((e) => e.controller.text)
                            //           .toList();
                            //       for (int i = 0; i < terms.length; i++) {
                            //         if (term.item == terms[i] &&
                            //             bulletList[i].level > 0) {
                            //           makeMain(i, bulletList[i].level);
                            //           break;
                            //         }
                            //       }
                            //     },
                            //     suggestions: suggestion
                            //         .getTerms()
                            //         .map((e) => SearchFieldListItem<String>(e,
                            //             item: e,
                            //             child: Container(
                            //                 constraints: const BoxConstraints(
                            //                     minHeight: 30),
                            //                 child: Row(children: [
                            //                   Expanded(
                            //                       child: Text(e,
                            //                           softWrap: false,
                            //                           maxLines: 2,
                            //                           overflow: TextOverflow
                            //                               .ellipsis))
                            //                 ]))))
                            // .toList())
                          ),
                        ],
                      )),
                  Expanded(
                      child: Container(
                          decoration: BoxDecoration(
                            border: const Border(
                                bottom: BorderSide(
                                    width: 0.5, color: Colors.black)),
                            color: backgroundColor,
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 1, horizontal: 15),
                          child: Column(children: [
                            Expanded(
                                child: Container(
                                    clipBehavior: Clip.hardEdge,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: const BoxDecoration(
                                        // borderRadius: BorderRadius.only(
                                        //     bottomLeft: Radius.circular(5),
                                        //     bottomRight: Radius.circular(5)),
                                        border: Border(
                                            bottom: BorderSide(
                                                color: Color.fromARGB(
                                                    255, 169, 169, 169)))),
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
                                                onReorder: (int oldIndex,
                                                    int newIndex) {
                                                  if (oldIndex == newIndex) {
                                                    return;
                                                  }

                                                  if (newIndex >
                                                      bulletList.length) {
                                                    newIndex =
                                                        bulletList.length;
                                                  }
                                                  if (oldIndex < newIndex) {
                                                    newIndex -= 1;
                                                  }
                                                  bulletList[oldIndex];
                                                  setState(() =>
                                                      suggestion.swapLocation(
                                                          oldIndex, newIndex));
                                                  setState(() {
                                                    focused = newIndex;

                                                    bulletList.insert(
                                                        newIndex,
                                                        bulletList.removeAt(
                                                            oldIndex));
                                                  });
                                                },
                                                buildDefaultDragHandles: false,
                                                itemCount:
                                                    calculatePageBulletNumber(),
                                                itemBuilder:
                                                    (BuildContext context,
                                                        int index) {
                                                  index = index +
                                                      (pageIndex - 1) *
                                                          pageMaxBulletNumber;
                                                  return Container(
                                                      key: Key(bulletList[index]
                                                          .uniqueKey
                                                          .toString()),
                                                      child: (TapRegion(
                                                          onTapInside: (tap) {
                                                            if (focused ==
                                                                index) {
                                                              return;
                                                            }
                                                            setState(() {
                                                              if (shift) {
                                                                selectBulletRangeMin =
                                                                    focused;
                                                                ;
                                                              } else {
                                                                selectBulletRangeMin =
                                                                    -1;
                                                              }
                                                              focused = index;
                                                            });
                                                          },
                                                          onTapOutside: (tap) {
                                                            if (focused !=
                                                                index) {
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
                                                                      color:
                                                                          Color.fromARGB(
                                                                              93,
                                                                              0,
                                                                              0,
                                                                              0),
                                                                      width:
                                                                          0.5)),
                                                              color:
                                                                  Colors.white,
                                                              margin: EdgeInsets
                                                                  .only(
                                                                left: (25 *
                                                                    bulletList[
                                                                            index]
                                                                        .level
                                                                        .toDouble()),
                                                                top: 1.5,
                                                                bottom: index + 1 <
                                                                            bulletList
                                                                                .length &&
                                                                        bulletList[index + 1].level ==
                                                                            0
                                                                    ? 5
                                                                    : 0,
                                                              ),
                                                              child: Column(
                                                                  children: [
                                                                    BulletWidget(
                                                                        index,
                                                                        bulletList[index]
                                                                            .level),
                                                                    focused == index &&
                                                                            (inSuggestionArea ||
                                                                                bulletList[index].focus.hasFocus) &&
                                                                            bulletList[index].controller.text.isNotEmpty &&
                                                                            suggestionList.isNotEmpty
                                                                        ? MouseRegion(
                                                                            onEnter: (e) {
                                                                              setState(() {
                                                                                inSuggestionArea = true;
                                                                              });
                                                                            },
                                                                            onExit: (e) {
                                                                              setState(() {
                                                                                inSuggestionArea = false;
                                                                              });
                                                                            },
                                                                            child: Column(
                                                                              children: [
                                                                                Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 56), alignment: Alignment.centerLeft, child: const Text(style: TextStyle(fontWeight: FontWeight.bold), "Suggestions")),
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
                                                                                                bulletList[index].controller.text = suggestionList[suggestionIndex];
                                                                                                suggestionList = [];
                                                                                              });
                                                                                            }),
                                                                                      );
                                                                                    })
                                                                              ],
                                                                            ))
                                                                        : const SizedBox()
                                                                  ])))));
                                                },
                                              ),
                                            ]))))),
                            Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: Row(children: [
                                  showPageNavigateLeftButton
                                      ? Container(
                                          height: 30,
                                          width: 30,
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              border: Border.all(
                                                  color: const Color.fromARGB(
                                                      255, 0, 0, 0),
                                                  width: 0.5)),
                                          child: IconButton(
                                              padding: EdgeInsets.zero,
                                              style: const ButtonStyle(
                                                  shape: WidgetStatePropertyAll(
                                                      ContinuousRectangleBorder())),
                                              onPressed: () {
                                                decreasePageNumber();
                                              },
                                              icon: const Icon(
                                                  size: 15,
                                                  Icons
                                                      .arrow_back_ios_new_sharp)))
                                      : const SizedBox(
                                          height: 30,
                                          width: 30,
                                        ),
                                  // Spacer(),
                                  // Container(
                                  //     width: 80,
                                  //     decoration: BoxDecoration(
                                  //         borderRadius: const BorderRadius.all(
                                  //           Radius.circular(25.0),
                                  //         ),
                                  //         boxShadow: [
                                  //           BoxShadow(
                                  //             color:
                                  //                 const Color.fromARGB(255, 0, 0, 0)
                                  //                     .withOpacity(0.2),
                                  //             spreadRadius: 0.5,
                                  //             blurRadius: 1,
                                  //             offset: Offset(0, 1),
                                  //           )
                                  //         ]),
                                  //     child: IconButton(
                                  //         style: ButtonStyle(
                                  //             backgroundColor:
                                  //                 WidgetStateProperty.all(
                                  //                     const Color.fromARGB(
                                  //                         255, 255, 255, 255))),
                                  //         color: Colors.black,
                                  //         onPressed: () {
                                  //           setState(() {
                                  //             addBullet();
                                  //             pageViewScrollController.jumpTo(2 *
                                  //                 pageViewScrollController
                                  //                     .position.maxScrollExtent);
                                  //           });
                                  //         },
                                  //         icon: const Icon(Icons.add))),
                                  const Spacer(),
                                  showPageNavigateRightButton
                                      ? Container(
                                          height: 30,
                                          width: 30,
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              border: Border.all(
                                                  color: const Color.fromARGB(
                                                      255, 0, 0, 0),
                                                  width: 0.5)),
                                          child: IconButton(
                                              padding: EdgeInsets.zero,
                                              style: const ButtonStyle(
                                                  shape: WidgetStatePropertyAll(
                                                      ContinuousRectangleBorder())),
                                              onPressed: () {
                                                increasePageNumber();
                                              },
                                              icon: const Icon(
                                                  size: 15,
                                                  Icons
                                                      .arrow_forward_ios_sharp)))
                                      : const SizedBox(
                                          height: 30,
                                          width: 30,
                                        ),
                                ]))
                          ])))
                ]))));
  }
}
