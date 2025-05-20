import 'dart:collection';
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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lynklynk/utils/bullet.dart' as Bullet;
import 'package:path/path.dart' as Path;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/gestures.dart';

class Node {
  final int id;
  final int constellationID;
  String text;
  int type; //0: text, 1: image, 2: article (source -> url)
  String source;
  final String createdAt;
  final String updatedAt;

  Node(
      {required this.id,
      required this.constellationID,
      required this.text,
      required this.type,
      required this.source,
      required this.createdAt,
      required this.updatedAt});
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'constellation_id': constellationID,
      'text': text,
      'type': type,
      'source': source,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class Test extends StatefulWidget {
  const Test({
    super.key,
    required this.constellationID,
    required this.constellationName,
  });

  final int constellationID;
  final String constellationName;

  @override
  State<Test> createState() => _Test();
}

class _Test extends State<Test> with TickerProviderStateMixin {
  bool maximized = false;
  suggestions.Suggestions suggestion = suggestions.Suggestions();
  List<Bullet.Bullet> bulletList = [];
  int focused = -1;
  bool shift = false;

  SearchController searchbarController = SearchController();
  List<String> validSearch = [];
  final ScrollController pageViewScrollController = ScrollController();
  final ScrollController reorderScrollController = ScrollController();
  List<String> suggestionList = [];
  String searchbarText = "";
  bool inSuggestionArea = false;
  int selectBulletRangeMin = -1;

  late int constellationID;
  late String constellationName;

  Map<int, List<int>> generalToDetail = {};
  Map<int, List<int>> detailToGeneral = {};

  //list of all nodes in the constellation
  List<Node> nodeList = [];
  Map<int, Node> nodeMap = {};

  //bool for editing mode
  bool editingMode = true;
  bool editingModeCurrentNode = false;
  bool editingModeTextUpload = true;
  bool editingModePhotoUploaded = false;
  bool bottomDisplayOpen = false;

  //main node with default set
  late Node focusedNode;

  //main node hovering bool
  bool mainNodeHover = false;

  Color nodeMasteryColorDefault = const Color.fromARGB(255, 224, 224, 224);
  Color nodeMasteryColorKnown = const Color.fromARGB(255, 76, 177, 79);
  Color nodeMasteryColorPractice = const Color.fromARGB(255, 255, 226, 95);
  Color nodeMasteryColorDifficult = const Color.fromARGB(255, 241, 68, 56);
  Color nodeMasteryColorLearned = const Color.fromARGB(255, 0, 140, 255);

  Map<String, Color> nodeMasteryColorMap = {};

  //Main node input TextEditingController
  TextEditingController mainNodeTextController = TextEditingController();

  List<String> auxiliaryNodePriorEditList = [];

  //Int index for selected auxiliary node input
  int selectedAuxiliaryNodeInput = -1;

  ScrollController addNodeController = ScrollController();

  //display loading screen boolean
  bool loading = true;

  bool _loadingVisible = false;

  // Color backgroundColor = const Color.fromRGBO(252, 231, 200, 1);
  // Color primary1 = const Color.fromRGBO(177, 194, 158, 1);
  // Color primary2 = const Color.fromRGBO(250, 218, 122, 1);
  // Color primary3 = const Color.fromRGBO(240, 160, 75, 1);

  Color backgroundColor = Color.fromARGB(255, 255, 255, 255);
  Color primary1 = const Color.fromARGB(255, 112, 103, 179);
  Color primary2 = const Color.fromRGBO(203, 128, 171, 1);
  Color primary3 = const Color.fromRGBO(238, 165, 166, 1);

  ScrollController bottomDisplayScrollController1 = ScrollController();
  ScrollController bottomDisplayScrollController2 = ScrollController();
  SearchController search = SearchController();

  var database;

  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _controller1;
  late final Animation<double> _slideAnimation1;
  late final Animation<double> _fadeAnimation1;

  double suggestionHeight = 100;

  Map<int, Node> idNodeMap = {};
  Map<int, List<Node>> edgeMap = {};
  @override
  void initState() {
    constellationID = widget.constellationID;
    constellationName = widget.constellationName;
    nodeMasteryColorMap = {
      "New": nodeMasteryColorDefault,
      "Know Well": nodeMasteryColorKnown,
      "Need to Practice": nodeMasteryColorPractice,
      "Difficult": nodeMasteryColorDifficult,
      "Just Learned": nodeMasteryColorLearned
    };

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller1 = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );

    _slideAnimation1 = Tween<double>(begin: -1.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller1, curve: Curves.easeInOut));

    _fadeAnimation1 = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller1, curve: Curves.easeInOut));

    _asyncLoadDB();

    super.initState();
  }

  _asyncLoadDB() async {
    //loading screen animation
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _loadingVisible = true;
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      _loadingVisible = false;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    database = openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      Path.join(await getDatabasesPath(), 'lynklynk_database.db'),
      // When the database is first created, create a table to store files.

      onUpgrade: _onUpgrade,
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 1,
    );

    try {
      List<Node> queryResultsList = await getNodeList(constellationID);
      if (queryResultsList.isNotEmpty) {
        editingMode = false;
        focusedNode = queryResultsList[0];
      }

      setState(() {
        nodeList = queryResultsList;
        nodeMap = {for (Node n in queryResultsList) n.id: n};

        print(nodeList);
        loading = false;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<List<Node>> getNodeList(int constellationId) async {
    // Get a reference to the database.
    final db = await database;
    // Query the table for all the files.
    final List<Map<String, Object?>> nodeMaps = await db.query(
      'nodes',
      where: 'constellation_id = ?',
      whereArgs: [constellationId],
    );
    // Convert the list of each file's fields into a list of `file` objects.
    return [
      for (final {
            'id': id as int,
            'constellation_id': constellationID as int,
            'text': text as String,
            'type': type as int,
            'source': source as String,
            'created_at': createdAt as String,
            'updated_at': updatedAt as String,
          } in nodeMaps)
        Node(
          id: id,
          constellationID: constellationID,
          text: text,
          type: type,
          source: source,
          createdAt: createdAt,
          updatedAt: updatedAt,
        )
    ];
  }

  List<Node> getNodeConnections(int nodeID) {
    return (generalToDetail[nodeID]!
        .map((e) => nodeMap[e])
        .whereType<Node>()
        .toList());
  }

  List<String> getNodeConnectionsParsed(int nodeID) {
    return getNodeConnections(nodeID).map((e) => e.text).toList();
  }

  void insertNodeConnectionLocal(int node1, int node2,
      {int index = -1, String relation = ""}) {
    if (index == -1) {
      generalToDetail[node1]!.add(node2);
    } else {
      generalToDetail[node1]!.insert(node2, index);
    }
  }

  deleteNodeConnectionLocal(int node1, int node2, {String relation = ""}) {
    generalToDetail[node1]!.removeWhere((item) => item == node2);
    detailToGeneral[node2]!.removeWhere((item) => item == node1);
  }

  reorderableListNodeSwap(int node, int oldIndex, int newIndex) {
    setState(() {
      int term = generalToDetail[node]!.removeAt(oldIndex);
      generalToDetail[node]!.insert(term, newIndex);
    });
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) {
    if (oldVersion < 2) {
      // db.execute(
      //     "ALTER TABLE files ADD COLUMN starred INTEGER NOT NULL DEFAULT (0);");
    }
  }

// -------------------------------------------------------------------------------------------------------------------------------------
// nodeSearchSuggestion method
// parameters: TextEditingController controller [controller for node search bar that is to get the search parameter]
// optional parameters: bool matchCase [match by upper/lowercase], bool matchStart [match from beginning of string], int searchLimit [max number of search results to return]
// return: List<Node> | returns a list of nodes that fit the search parameters
// -------------------------------------------------------------------------------------------------------------------------------------
  List<Node> nodeSearchSuggestion(TextEditingController controller,
      {bool matchCase = false, bool matchStart = true, int searchLimit = 8}) {
    if (controller.text.isEmpty) {
      return [];
    }

    List<Node> returnList = [];

    if (!matchCase) {
      returnList =
          nodeList.where((e) => e.text.startsWith(controller.text)).toList();
    } else {
      returnList =
          nodeList.where((e) => e.text.startsWith(controller.text)).toList();
    }
    print(returnList.map((e) => e.text));
    if (returnList.isEmpty) {
      return [];
    } else {
      returnList =
          returnList.getRange(0, min(returnList.length, searchLimit)).toList();

      return returnList;
    }
  }
// -------------------------------------------------------------------------------------------------------------------------------------
// Node Edit Functions
// 1. updatetext: updates a node (and any relevant auxiliaries) with a new node term
// 2. removeAuxiliaries: disconnects a node from its auxiliaries
// 3. editNode: wrapper functions that uses all the above functions to update a node to its most recently edited version
// 4. removeNode: deletes a node and uncouples all auxiliaries
// -------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------
// nodeMasterySelectButton method
// parameters:
// return: Widget | returns a widgt that comprises of a dropdown button that is used to select the node mastery for a node
// -------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------
// auxiliaryDisplayProxyDecorator method
// - used for the ReorderableListView that displays the auxiliary nodes
// -------------------------------------------------------------------------------------------------------------------------------------

  Widget auxiliaryDisplayProxyDecoratorTier1(
      Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(1, 6, animValue)!;
        final double scale = lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(
          scale: scale,
          // Create a Card based on the color and the content of the dragged one
          // and set its elevation to the animated value.
          child: auxiliaryDisplay(
              getNodeConnectionsParsed(focusedNode.id)[index], 1),
        );
      },
      child: child,
    );
  }

  Widget auxiliaryDisplayProxyDecoratorTier2(
      Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(1, 6, animValue)!;
        final double scale = lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(
          scale: scale,
          // Create a Card based on the color and the content of the dragged one
          // and set its elevation to the animated value.
          child: auxiliaryDisplay(
              getNodeConnectionsParsed(secondaryNode!.id)[index], 2),
        );
      },
      child: child,
    );
  }

// -------------------------------------------------------------------------------------------------------------------------------------
// auxiliaryDisplay method
// - parameters: String term [the text of the node whose auxiliary nodes are to be displayed]
// - return: Widget | returns a widget that displays a card with auxiliary node information (term and color)
// -------------------------------------------------------------------------------------------------------------------------------------

  Widget auxiliaryDisplay(String term, int index) {
    // print(term);
    // print(nodeMap);
    // print("display");
    // print(nodeMap.containsKey(term));
    if (!nodeMap.containsKey(term)) {
      return Container(
        key: UniqueKey(),
      );
    }
    Node auxNode = nodeMap[term]!;
    return Container(
        key: UniqueKey(),
        child: Row(
          children: [
            Expanded(
                child: GestureDetector(
                    onTap: () async {
                      if (index == 1) {
                        if (secondaryNode == null ||
                            auxNode.text == secondaryNode!.text) {
                          if (!showSecond) {
                            // Showing center
                            setState(() {
                              secondaryNode = auxNode;
                              showSecond = true;
                            });

                            // First animate left container
                            await Future.delayed(Duration(milliseconds: 400));

                            // Then animate center
                            _controller1.forward();
                          } else {
                            // Hiding center
                            _controller1.reverse();

                            await Future.delayed(Duration(milliseconds: 350));

                            setState(() {
                              secondaryNode = null;
                              showSecond = false;
                            });
                          }
                        } else {
                          //when another secondary node is selected

                          _controller1.reverse();
                          await Future.delayed(Duration(milliseconds: 400));

                          setState(() {
                            secondaryNode = auxNode;
                            showSecond = true;
                          });

                          // First animate left container
                          await Future.delayed(Duration(milliseconds: 400));

                          // Then animate center
                          _controller1.forward();
                        }
                      }
                    },
                    onDoubleTap: () async {
                      print("aux pressed");
                      // Hiding center
                      setState(() {
                        switchMain = true;
                      });
                      _controller1.reverse();
                      _controller.reverse();
                      setState(() {
                        secondaryNode = null;
                        showSecond = false;
                      });
                      await Future.delayed(Duration(milliseconds: 400));
                      setState(() {
                        focusedNode = nodeMap[term]!;
                      });
                      await Future.delayed(Duration(milliseconds: 400));
                      _controller.forward();
                      setState(() {
                        switchMain = false;
                      });
                    },
                    child: Card(
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        color: Colors.white,
                        child: Container(
                            // decoration: BoxDecoration(

                            //     border: Border(
                            //         left: BorderSide(
                            //             width: 5,
                            //             color:
                            //                 colorFromString(auxNode.color)))),
                            decoration: BoxDecoration(
                              border: Border.all(width: 1, color: Colors.black),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: EdgeInsets.all(10),
                            child: auxNode.type == 1
                                ? Image.file(File(term))
                                : Text(term)))))
          ],
        ));
  }

// -------------------------------------------------------------------------------------------------------------------------------------
// copyFile method
// - parameters: File file [the file that is copied from]
// - return: Future<String> | Returns a string containing the full path of the newly copied file
// -------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Submission Component
// -------------------------------------------------------------------------------------------------------------------------------------

  bool showSecond = false;
  bool showCenter = false;
  bool showRight = false;
  bool midTransition = false;
  double angle = 0.0;
  final double radius = 180.0;
  final List<String> items = [
    "Testing 1",
    "Roman Empire",
    "Iron Age",
    "Mediterranean",
    "E",
    "F",
    "G",
    "H",
    "I"
  ];

  Offset _lastPosition = Offset.zero;

  void _onPanUpdate(DragUpdateDetails details, Offset center) {
    final touch = details.localPosition;

    final double dx = touch.dx - center.dx;
    final double dy = touch.dy - center.dy;

    final double currentAngle = atan2(dy, dx);

    final double dxLast = _lastPosition.dx - center.dx;
    final double dyLast = _lastPosition.dy - center.dy;
    final double lastAngle = atan2(dyLast, dxLast);

    final delta = currentAngle - lastAngle;

    setState(() {
      angle += delta;
    });

    _lastPosition = touch;
  }

  Node? secondaryNode;
  bool switchMain = false;

  @override
  Widget build(BuildContext context) {
    double totalWidth = showCenter ? 800 : 800;
    return Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{},
        child: Actions(
            actions: <Type, Action<Intent>>{},
            child: Scaffold(
                appBar: AppBar(
                  scrolledUnderElevation: 0,
                  toolbarHeight: 50,
                  titleSpacing: 0,
                  primary: false,

                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  // backgroundColor: const Color.fromARGB(255, 75, 185, 233),
                  title: Container(
                      color: Colors.white,
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
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              color: const Color.fromARGB(255, 255, 255, 255),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.rocket_launch_sharp),
                                  Spacer(),
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
                                        onPressed: () =>
                                            windowManager.minimize(),
                                        icon: const Icon(
                                            size: 14,
                                            Icons.horizontal_rule_sharp),
                                      )),
                                  const SizedBox(width: 15),
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
                                          onPressed: () => windowManager
                                                  .isMaximized()
                                                  .then((isMax) {
                                                if (isMax) {
                                                  windowManager.restore();
                                                } else {
                                                  windowManager.maximize();
                                                }
                                              }),
                                          icon: const Icon(
                                              size: 14,
                                              Icons.web_asset_sharp))),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: IconButton(
                                        style: IconButton.styleFrom(
                                          foregroundColor: const Color.fromARGB(
                                              255, 0, 0, 0),
                                        ),
                                        onPressed: () => windowManager.close(),
                                        icon: const Icon(
                                          Icons.close,
                                          size: 14,
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ))),
                ),
                body: loading
                    ? AnimatedOpacity(
                        opacity: _loadingVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 500),
                        child: Container(
                            child: Center(
                                child: LoadingAnimationWidget.halfTriangleDot(
                                    color: primary2, size: 50))))
                    : Container(
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(
                              251, 255, 255, 255), // Background color
                        ),
                        child: Container(
                            child: Column(children: [
                          Container(
                              // decoration: BoxDecoration(
                              //   border: Border.symmetric(
                              //       horizontal: BorderSide(
                              //           width: 1, color: Colors.black)),
                              // ),
                              padding:
                                  const EdgeInsets.only(left: 25, right: 25),
                              height: 60,
                              child: Row(
                                children: [
                                  Container(
                                      height: 40,
                                      width: 40,
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                            color: const Color.fromARGB(
                                                255, 0, 0, 0),
                                            width: 1,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20)),
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
                                  const SizedBox(width: 15),
                                  Container(
                                      height: 40,
                                      width: 90,
                                      decoration: BoxDecoration(
                                        color: editingMode
                                            ? primary3
                                            : Colors.white,
                                        border: Border.all(
                                            color: const Color.fromARGB(
                                                255, 0, 0, 0),
                                            width: 1),
                                      ),
                                      child: IconButton(
                                          padding: EdgeInsets.zero,
                                          style: const ButtonStyle(
                                              shape: WidgetStatePropertyAll(
                                                  ContinuousRectangleBorder())),
                                          onPressed: () {
                                            setState(() {
                                              if (nodeList.isNotEmpty) {
                                                editingMode = !editingMode;
                                              } else {
                                                return;
                                              }
                                              if (!editingMode) {
                                                editingModeCurrentNode = false;
                                              }
                                            });
                                          },
                                          icon: Icon(
                                              color: editingMode
                                                  ? Colors.white
                                                  : Colors.black,
                                              size: 20,
                                              Icons.edit))),
                                  Spacer(),
                                  Expanded(
                                      child: Container(
                                    margin: EdgeInsets.only(right: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    constraints: BoxConstraints(
                                      minHeight: 40,
                                      minWidth:
                                          MediaQuery.sizeOf(context).width > 600
                                              ? 480
                                              : 400,
                                    ),
                                    child: SearchAnchor(
                                        searchController: search,
                                        viewBackgroundColor: Colors.white,
                                        viewConstraints:
                                            BoxConstraints(maxHeight: 400),
                                        viewShape:
                                            const ContinuousRectangleBorder(
                                                side: BorderSide(
                                                    width: 3,
                                                    color: Colors.black)),
                                        builder: (BuildContext context,
                                            SearchController controller) {
                                          return SearchBar(
                                            shape: const WidgetStatePropertyAll(
                                                ContinuousRectangleBorder()),
                                            constraints: const BoxConstraints(
                                                maxHeight: 40),
                                            backgroundColor:
                                                const WidgetStatePropertyAll(
                                                    Colors.white),
                                            overlayColor:
                                                const WidgetStatePropertyAll(
                                                    Colors.white),
                                            surfaceTintColor:
                                                const WidgetStatePropertyAll(
                                                    Colors.white),
                                            shadowColor:
                                                const WidgetStatePropertyAll(
                                                    Colors.transparent),
                                            controller: controller,
                                            padding:
                                                const WidgetStatePropertyAll<
                                                        EdgeInsets>(
                                                    EdgeInsets.symmetric(
                                                        horizontal: 16.0)),
                                            onTap: () {
                                              controller.openView();
                                            },
                                            onChanged: (_) {
                                              controller.openView();
                                            },
                                            leading: const Icon(Icons.search),
                                          );
                                        },
                                        suggestionsBuilder:
                                            (BuildContext context,
                                                SearchController controller) {
                                          List<Node> suggestionList =
                                              nodeSearchSuggestion(controller);
                                          print(suggestionList.length);
                                          return suggestionList.map((e) {
                                            return Container(
                                                width: 400,
                                                child: ListTile(
                                                  tileColor: Colors.white,
                                                  title: Text(e.text),
                                                  onTap: () {
                                                    setState(() {
                                                      focusedNode = e;
                                                      controller.closeView("");
                                                    });
                                                  },
                                                ));
                                          });
                                        }),
                                  )),
                                ],
                              )),
                          editingMode
                              ?

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Submission Dashboard
// -------------------------------------------------------------------------------------------------------------------------------------

                              Container()
                              :
// -------------------------------------------------------------------------------------------------------------------------------------
// Node Flashcard Mode
// -------------------------------------------------------------------------------------------------------------------------------------

                              Expanded(
                                  //if main node does not have any auxiliary nodes
                                  child: Container(
                                      padding: EdgeInsets.all(20),
                                      alignment: Alignment.bottomCenter,
                                      decoration:
                                          BoxDecoration(color: backgroundColor),
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            nodeMap[focusedNode.id] == null
                                                ? MouseRegion(
                                                    onEnter: (details) =>
                                                        setState(() =>
                                                            mainNodeHover =
                                                                true),
                                                    onExit: (details) =>
                                                        setState(() {
                                                          mainNodeHover = false;
                                                        }),
                                                    child: Stack(
                                                        alignment:
                                                            Alignment.center,
                                                        children: [
                                                          Container(
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    bottom: 50),
                                                            child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Container(
                                                                      constraints: const BoxConstraints(
                                                                          maxWidth:
                                                                              500,
                                                                          minHeight:
                                                                              200),
                                                                      alignment:
                                                                          Alignment
                                                                              .center,
                                                                      padding: EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              10),
                                                                      decoration: BoxDecoration(
                                                                          borderRadius: BorderRadius.circular(
                                                                              20),
                                                                          border: Border.all(
                                                                              width:
                                                                                  1,
                                                                              color: Colors
                                                                                  .black),
                                                                          color: Colors
                                                                              .white),
                                                                      child: focusedNode.type ==
                                                                              1
                                                                          ? ClipRRect(
                                                                              borderRadius: BorderRadius.circular(8.0),
                                                                              child: Image.file(File(focusedNode.text)))
                                                                          : Text(
                                                                              style: TextStyle(
                                                                                  fontSize: focusedNode.text.length > 100
                                                                                      ? 18
                                                                                      : focusedNode.text.length > 20
                                                                                          ? 22
                                                                                          : 30),
                                                                              focusedNode.text)),
                                                                  Spacer(),
                                                                  Listener(
                                                                      onPointerSignal:
                                                                          (event) {
                                                                        if (event
                                                                            is PointerScrollEvent) {
                                                                          setState(
                                                                              () {
                                                                            angle +=
                                                                                event.scrollDelta.dy * -0.01; // scroll up = rotate clockwise
                                                                          });
                                                                        }
                                                                      },
                                                                      child: Container(
                                                                          decoration: BoxDecoration(border: Border.all(width: 1, color: Colors.black)),
                                                                          width: 500,
                                                                          height: 500,
                                                                          child: LayoutBuilder(
                                                                            builder:
                                                                                (context, constraints) {
                                                                              final Size size = constraints.biggest;
                                                                              final Offset center = size.center(Offset.zero);

                                                                              return ClipRect(
                                                                                  child: Align(
                                                                                      alignment: Alignment.centerLeft,
                                                                                      widthFactor: 0.5, // Show only the left half
                                                                                      child: GestureDetector(
                                                                                        onPanStart: (details) => _lastPosition = details.localPosition,
                                                                                        onPanUpdate: (details) => _onPanUpdate(details, center),
                                                                                        child: SizedBox(
                                                                                          width: size.width,
                                                                                          height: size.height,
                                                                                          child: Stack(
                                                                                            children: [
                                                                                              Positioned.fill(
                                                                                                child: Container(
                                                                                                  color: Colors.transparent, // ensures the area is hit-testable
                                                                                                ),
                                                                                              ),
                                                                                              // Items around circle
                                                                                              for (int i = 0; i < items.length; i++)
                                                                                                Positioned(
                                                                                                    left: center.dx + radius * cos(angle + i * 2 * pi / items.length) - 90,
                                                                                                    top: center.dy + radius * sin(angle + i * 2 * pi / items.length) - 90,
                                                                                                    child: Opacity(
                                                                                                      opacity: (-radius * cos(angle + i * 2 * pi / items.length) / center.dx).clamp(0.0, 1.0),
                                                                                                      child: Container(
                                                                                                        width: 300,
                                                                                                        height: 180,
                                                                                                        alignment: Alignment.center,
                                                                                                        decoration: BoxDecoration(
                                                                                                          borderRadius: BorderRadius.circular(20),
                                                                                                          color: Colors.blue,
                                                                                                        ),
                                                                                                        child: Text(items[i], style: TextStyle(color: Colors.white)),
                                                                                                      ),
                                                                                                    )),
                                                                                              // Center dot
                                                                                              Positioned(
                                                                                                left: center.dx - 5,
                                                                                                top: center.dy - 5,
                                                                                                child: Container(
                                                                                                  width: 200,
                                                                                                  height: 10,
                                                                                                  decoration: BoxDecoration(
                                                                                                    color: Colors.red,
                                                                                                  ),
                                                                                                ),
                                                                                              )
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      )));
                                                                            },
                                                                          )))
                                                                ]),
                                                          )
                                                        ]))
                                                : Stack(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    children: [
                                                        SizedBox(
                                                            width:
                                                                double.infinity,
                                                            child:
                                                                AnimatedAlign(
                                                                    duration: Duration(
                                                                        milliseconds:
                                                                            400),
                                                                    curve: Curves
                                                                        .easeInOut,
                                                                    alignment:
                                                                        Alignment
                                                                            .center,
                                                                    child: SizedBox(
                                                                        width: 1200,
                                                                        child: Row(children: [
                                                                          AnimatedSlide(
                                                                              offset: showSecond
                                                                                  ? Offset(0, 0)
                                                                                  : showCenter
                                                                                      ? Offset(0.25, 0)
                                                                                      : Offset(0.5, 0),
                                                                              duration: Duration(milliseconds: 600),
                                                                              curve: Curves.easeInOut,
                                                                              child: AnimatedAlign(
                                                                                duration: Duration(milliseconds: 400),
                                                                                curve: Curves.easeInOut,
                                                                                alignment: Alignment.center,
                                                                                child: SizedBox(
                                                                                    width: totalWidth,
                                                                                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                                                      AnimatedOpacity(
                                                                                          opacity: switchMain ? _fadeAnimation1.value : 1,
                                                                                          curve: Curves.easeInOut,
                                                                                          duration: Duration(milliseconds: 200),
                                                                                          child: AnimatedSlide(
                                                                                              offset: Offset(0, 0),
                                                                                              duration: Duration(milliseconds: 600),
                                                                                              curve: Curves.easeInOut,
                                                                                              child: Container(
                                                                                                  constraints: BoxConstraints(
                                                                                                    minHeight: 60,
                                                                                                    maxWidth: 400,
                                                                                                  ),
                                                                                                  padding: EdgeInsets.only(
                                                                                                    right: 20,
                                                                                                  ),
                                                                                                  child: GestureDetector(
                                                                                                    onTap: () async {
                                                                                                      print("testtttt");
                                                                                                      if (midTransition) {
                                                                                                        return;
                                                                                                      }

                                                                                                      setState(() {
                                                                                                        midTransition = true;
                                                                                                      });

                                                                                                      if (!showCenter) {
                                                                                                        // Showing center

                                                                                                        setState(() {
                                                                                                          showCenter = true;
                                                                                                          showCenter = true;
                                                                                                        });

                                                                                                        // First animate left container
                                                                                                        await Future.delayed(Duration(milliseconds: 400));

                                                                                                        // Then animate center
                                                                                                        _controller.forward();

                                                                                                        if (showSecond) {
                                                                                                          _controller1.forward();
                                                                                                        }
                                                                                                      } else {
                                                                                                        // Hiding center

                                                                                                        if (showSecond) {
                                                                                                          _controller1.reverse();
                                                                                                        }

                                                                                                        _controller.reverse();

                                                                                                        await Future.delayed(Duration(milliseconds: 350));

                                                                                                        setState(() {
                                                                                                          showCenter = false;
                                                                                                          showSecond = false;
                                                                                                        });
                                                                                                      }
                                                                                                      setState(() {
                                                                                                        midTransition = false;
                                                                                                      });
                                                                                                    },
                                                                                                    child:

                                                                                                        // Main node card

                                                                                                        Container(
                                                                                                            width: 400,
                                                                                                            decoration: BoxDecoration(
                                                                                                              borderRadius: BorderRadius.circular(20),
                                                                                                              border: Border.all(width: 1, color: Colors.black),
                                                                                                              color: Colors.white,
                                                                                                            ),
                                                                                                            alignment: Alignment.center,
                                                                                                            child: Container(padding: EdgeInsets.all(15), child: focusedNode.type == 1 ? Image.file(File(focusedNode.text)) : Text(focusedNode.text, style: TextStyle(fontSize: focusedNode.text.length > 100 ? 15 : 25)))),
                                                                                                  ))
                                                                                              // Top Gradient
                                                                                              )),
                                                                                      Expanded(
                                                                                          child: IgnorePointer(
                                                                                              ignoring: !showCenter,
                                                                                              child: ClipRect(
                                                                                                child: Container(
                                                                                                  // decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                                                                                                  width: 400, // Always reserve space
                                                                                                  child: AnimatedBuilder(
                                                                                                    animation: _controller,
                                                                                                    builder: (context, child) {
                                                                                                      return Opacity(
                                                                                                        opacity: _fadeAnimation.value,
                                                                                                        child: FractionalTranslation(
                                                                                                          translation: Offset(0, _slideAnimation.value),
                                                                                                          child: child,
                                                                                                        ),
                                                                                                      );
                                                                                                    },
                                                                                                    child: Container(
                                                                                                      constraints: BoxConstraints(maxWidth: 400),
                                                                                                      child: ReorderableListView(
                                                                                                        shrinkWrap: true,
                                                                                                        physics: ClampingScrollPhysics(),
                                                                                                        padding: const EdgeInsets.only(right: 10),
                                                                                                        proxyDecorator: auxiliaryDisplayProxyDecoratorTier1,
                                                                                                        onReorder: (int oldIndex, int newIndex) {
                                                                                                          setState(() {
                                                                                                            if (oldIndex < newIndex) newIndex -= 1;
                                                                                                            if (oldIndex != newIndex) {
                                                                                                              reorderableListNodeSwap(focusedNode.id, oldIndex, newIndex);
                                                                                                            }
                                                                                                          });
                                                                                                        },
                                                                                                        children: showCenter ? getNodeConnectionsParsed(focusedNode.id).map((e) => auxiliaryDisplay(e, 1)).toList() : [],
                                                                                                      ),
                                                                                                    ),
                                                                                                  ),
                                                                                                ),
                                                                                              )))
                                                                                    ])),
                                                                              )),
                                                                          ClipRect(
                                                                            child:
                                                                                SizedBox(
                                                                              width: 400, // Always reserve space
                                                                              child: AnimatedBuilder(
                                                                                animation: _controller1,
                                                                                builder: (context, child) {
                                                                                  return Opacity(
                                                                                    opacity: _fadeAnimation1.value,
                                                                                    child: FractionalTranslation(
                                                                                      translation: Offset(0, _slideAnimation1.value),
                                                                                      child: child,
                                                                                    ),
                                                                                  );
                                                                                },
                                                                                child: Container(
                                                                                  constraints: BoxConstraints(maxWidth: 400),
                                                                                  child: ReorderableListView(
                                                                                    shrinkWrap: true,
                                                                                    physics: ClampingScrollPhysics(),
                                                                                    padding: const EdgeInsets.only(right: 10),
                                                                                    proxyDecorator: auxiliaryDisplayProxyDecoratorTier2,
                                                                                    onReorder: (int oldIndex, int newIndex) {
                                                                                      setState(() {
                                                                                        if (secondaryNode == null) return;
                                                                                        if (oldIndex < newIndex) newIndex -= 1;
                                                                                        if (oldIndex != newIndex) {
                                                                                          reorderableListNodeSwap(secondaryNode!.id, oldIndex, newIndex);
                                                                                        }
                                                                                      });
                                                                                    },
                                                                                    children: secondaryNode == null ? [] : getNodeConnectionsParsed(secondaryNode!.id).map((e) => auxiliaryDisplay(e, 2)).toList(),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          )
                                                                        ]))))
                                                      ])
                                          ])))
                        ]))))));
  }
}
