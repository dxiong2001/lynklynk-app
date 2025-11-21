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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lynklynk/utils/bullet.dart' as Bullet;
import 'package:path/path.dart' as Path;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:lynklynk/classes/constellationClass.dart';
import 'package:lynklynk/classes/nodeClass.dart';
import 'package:fleather/fleather.dart' as fleather;
import 'package:lynklynk/functions/keywordExtractor.dart';
import 'package:lynklynk/functions/keywordSearcher.dart';
import 'package:pelaicons/pelaicons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lynklynk/classes/connectionClass.dart';
import 'package:lynklynk/classes/protoMainNodeClass.dart';
import 'package:lynklynk/classes/protoSecondaryNodeClass.dart';
import 'package:lynklynk/classes/edgeClass.dart';
import 'package:lynklynk/classes/ResponsiveGrid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lynklynk/classes/searchbarClass.dart';
import 'package:collection/collection.dart';
import 'package:lynklynk/utils/editableText.dart';

class AddIntent extends Intent {
  const AddIntent();
}

class Test extends StatefulWidget {
  const Test({
    super.key,
    required this.constellationID,
    required this.constellationName,
    required this.constellationConcept,
  });

  final int constellationID;
  final String constellationConcept;
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
  late String constellationConcept;
  late Constellation constellation;
  Map<(String, String), String> relationMap = {};
  Map<String, List<String>> generalToDetail = {};
  Map<String, List<String>> detailToGeneral = {};

  //list of all nodes in the constellation
  late Map<int, Node> nodeMapID;
  late Map<String, Node> nodeMapText;
  Map<String, Node> topLevelMap = {};

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
    constellationConcept = widget.constellationConcept;

    nodeMasteryColorMap = {
      "New": nodeMasteryColorDefault,
      "Know Well": nodeMasteryColorKnown,
      "Need to Practice": nodeMasteryColorPractice,
      "Difficult": nodeMasteryColorDifficult,
      "Just Learned": nodeMasteryColorLearned
    };

    super.initState();

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

    _sceneController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _primarySceneOffset = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(-1.5, 0), // slide up off screen
    ).animate(CurvedAnimation(
      parent: _sceneController,
      curve: Curves.easeInOut,
    ));
    _secondarySceneOffset = Tween<Offset>(
      begin: Offset(1.5, 0),
      end: Offset(0, 0), // slide up off screen
    ).animate(CurvedAnimation(
      parent: _sceneController,
      curve: Curves.easeInOut,
    ));

    _primarySceneController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    constellationDashboardSceneOffset = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, -1.5), // slide up off screen
    ).animate(CurvedAnimation(
      parent: _primarySceneController,
      curve: Curves.easeInOut,
    ));

    addNodeSceneOffset = Tween<Offset>(
      begin: Offset(0, 1.4), // start below
      end: Offset(0, 0), // end at center
    ).animate(CurvedAnimation(
      parent: _primarySceneController,
      curve: Curves.easeInOut,
    ));

    addNodeSceneControllerOffset = Tween<Offset>(
      begin: Offset(0, -2), // start below
      end: Offset(0, 0), // end at center
    ).animate(CurvedAnimation(
      parent: _primarySceneController,
      curve: Curves.easeInOut,
    ));

    _sceneColorController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );

    _borderColor = TweenSequence<Color?>(
      [
        TweenSequenceItem(
          tween: ColorTween(
              begin: const Color.fromARGB(255, 0, 0, 0),
              end: Colors.transparent),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: ColorTween(
              begin: Colors.transparent,
              end: const Color.fromARGB(255, 0, 0, 0)),
          weight: 50,
        ),
      ],
    ).animate(CurvedAnimation(
        parent: _sceneColorController, curve: Curves.slowMiddle));

    _secondarySceneController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    directorySceneOffset = Tween<Offset>(
      begin: Offset(0, 0), // start below
      end: Offset(0, -1.5), // end at center
    ).animate(CurvedAnimation(
      parent: _secondarySceneController,
      curve: Curves.easeInOut,
    ));

    expandedViewOffset = Tween<Offset>(
      begin: Offset(0, 2), // start below
      end: Offset(0, 0), // end at center
    ).animate(CurvedAnimation(
      parent: _secondarySceneController,
      curve: Curves.easeInOut,
    ));

    connectionList = [
      newConnection(list: [
        ProtoSecondaryNode(
            controller: TextEditingController(),
            modifierController: TextEditingController(text: ""),
            focus: FocusNode()),
        ProtoSecondaryNode(
            controller: TextEditingController(),
            modifierController: TextEditingController(text: ""),
            focus: FocusNode())
      ])
    ];

    _asyncLoadDB();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _controller1.dispose();
    _sceneController.dispose();
    _primarySceneController.dispose();
    _sceneColorController.dispose();
    _secondarySceneController.dispose();
    search.dispose();
    // _editorFocusNode.dispose();
    super.dispose();
  }

  _asyncLoadDB() async {
    print("load db");

    //loading screen animation
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _loadingVisible = true;
    });

    database = await openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      Path.join(await getDatabasesPath(), 'lynklynk_database.db'),
      // When the database is first created, create a table to store files.
      onConfigure: (db) async {
        // 🔑 Enable foreign key support
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: _onUpgrade,
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 1,
    );
    final List<Map<String, dynamic>> rows = await database.query("edges");
    print("----------");

    for (final row in rows) {
      print("----------");
      print(row);
    }
    print("----------");

    try {
      List<Node> queryResultsList = await getNodeList(constellationID);
      List<Edge> edgeList = await getEdgeList(constellationID);
      if (queryResultsList.isNotEmpty) {
        editingMode = false;
        focusedNode = queryResultsList[0];
      } else {}

      constellation = await getConstellation(constellationID);
      print("got constellation");
      setState(() {
        nodeMapID = {for (Node n in queryResultsList) n.id: n};
        nodeMapText = {for (Node n in queryResultsList) n.text: n};
        print(edgeList);
        getEdgeMappings(edgeList);
        for (String n in nodeMapText.keys) {
          if (detailToGeneral[n] == null) {
            topLevelMap[n] = nodeMapText[n]!;
          }
        }
      });
    } catch (e) {
      print(e);
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      loading = false;
    });
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<List<Node>> getNodeList(int constellationId) async {
    // Get a reference to the database.
    final db = await database;
    // Query the table for all the files.
    print(constellationId);
    final List<Map<String, Object?>> nodeMaps = await db.query(
      'nodes',
      where: 'constellation_id = ?',
      whereArgs: [constellationId],
    );
    print(nodeMaps);
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

  Future<List<Edge>> getEdgeList(int constellationId) async {
    // Get a reference to the database.
    final db = await database;
    // Query the table for all the files.
    final List<Map<String, Object?>> nodeMaps = await db.query(
      'edges',
      where: 'constellation_id = ?',
      whereArgs: [constellationId],
    );
    // Convert the list of each file's fields into a list of `file` objects.
    return [
      for (final {
            'id': id as int,
            'constellation_id': constellationID as int,
            'from_node_id': fromNodeID as int,
            'to_node_id': toNodeID as int,
            'relation': relation as String,
            'created_at': createdAt as String,
            'updated_at': updatedAt as String,
          } in nodeMaps)
        Edge(
          id: id,
          constellationID: constellationID,
          fromNodeID: fromNodeID,
          toNodeID: toNodeID,
          relation: relation,
          createdAt: createdAt,
          updatedAt: updatedAt,
        )
    ];
  }

  Future<Constellation> getConstellation(int id) async {
    // Get a reference to the database.
    Database db = await database;

    // Query the table for all the files.
    final List<Map<String, Object?>> constellationMaps =
        await db.query('constellations', where: 'id = ?', whereArgs: [id]);
    print("get constellation: " + constellationMaps.toString());
    // Convert the list of each file's fields into a list of `file` objects.
    return [
      for (final {
            'id': id as int,
            'name': name as String,
            'concept': concept as String,
            'summary': summary as String,
            'image': image as String,
            'key_words': keyWords as String,
            'directory': directory as String,
            'starred': starred as int,
            'created_at': createdAt as String,
            'accessed_at': accessedAt as String,
            'updated_at': updatedAt as String,
          } in constellationMaps)
        Constellation(
          id: id,
          name: name,
          concept: concept,
          summary: summary,
          image: image,
          keyWords: json.decode(keyWords).cast<String>().toList(),
          directory: directory,
          starred: starred,
          createdAt: createdAt,
          accessedAt: accessedAt,
          updatedAt: updatedAt,
        ),
    ][0];
  }

  Future<void> updateConstellation({
    required int constellationId,
    String? name,
    String? concept,
    String? summary,
    String? image,
    List<String>? keyWords,
    int? starred,
  }) async {
    Database db = await database;
    await db.transaction((txn) async {
      // Update constellation metadata
      String now = DateTime.now().toIso8601String();
      final updateFields = <String, Object?>{};
      if (name != null) {
        updateFields['name'] = name;
      }
      if (concept != null) {
        updateFields['concept'] = concept;
      }
      if (summary != null) {
        updateFields['summary'] = concept;
      }
      if (image != null) {
        updateFields['image'] = image;
      }
      if (keyWords != null) {
        updateFields['key_words'] = keyWords.toString();
      }
      if (starred != null) {
        updateFields['starred'] = starred;
      }

      if (updateFields.isNotEmpty) {
        print("updated in db");
        updateFields['updated_at'] = now;
        await txn.update(
          'constellations',
          updateFields,
          where: 'id = ?',
          whereArgs: [constellationId],
        );
      }
    });

    print("constellationUpdated");
  }

  List<Node> getNodeConnections(String node) {
    return (generalToDetail[node]!
        .map((e) => nodeMapText[e])
        .whereType<Node>()
        .toList());
  }

  void addToMap(String key, String value, Map map) {
    // Get the list or create a new one if the key doesn't exist
    List<String> list = map[key] ?? [];

    // Add the value only if it’s not already in the list
    if (!list.contains(value)) {
      list.add(value);
    }

    // Assign the updated list back to the map
    setState(() {
      map[key] = list;
    });
  }

  void getEdgeMappings(List<Edge> edges) {
    print(edges);
    for (Edge e in edges) {
      String fromNode = nodeMapID[e.fromNodeID]!.text;
      String toNode = nodeMapID[e.toNodeID]!.text;
      print(e);
      addToMap(fromNode, toNode, generalToDetail);
      addToMap(toNode, fromNode, detailToGeneral);
      relationMap[(fromNode, toNode)] = e.relation;
    }

    setState(() {});
  }

  List<String> getNodeConnectionsParsed(String nodeText) {
    return getNodeConnections(nodeText).map((e) => e.text).toList();
  }

  void insertNodeConnectionLocal(String node1, String node2,
      {int index = -1, String relation = ""}) {
    if (index == -1) {
      generalToDetail[node1]!.add(node2);
    } else {
      generalToDetail[node1]!.insert(index, node2);
    }
  }

  deleteNode(String node) {}

  deleteNodeConnectionLocal(String node1, String node2,
      {String relation = ""}) {
    generalToDetail[node1]!.removeWhere((item) => item == node2);
    detailToGeneral[node2]!.removeWhere((item) => item == node1);
  }

  reorderableListNodeSwap(String node, int oldIndex, int newIndex) {
    setState(() {
      String term = generalToDetail[node]!.removeAt(oldIndex);
      generalToDetail[node]!.insert(newIndex, term);
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
      returnList = nodeMapID.values
          .where((e) => e.text.startsWith(controller.text))
          .toList();
    } else {
      returnList = nodeMapID.values
          .where((e) => e.text.startsWith(controller.text))
          .toList();
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
              getNodeConnectionsParsed(focusedNode.text)[index], 1),
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
              getNodeConnectionsParsed(secondaryNode!.text)[index], 2),
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
    if (!nodeMapID.containsKey(term)) {
      return Container(
        key: UniqueKey(),
      );
    }
    print("term: $term");
    Node auxNode = nodeMapText[term]!;
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
                        focusedNode = nodeMapID[term]!;
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

  Node? secondaryNode;
  bool switchMain = false;

  final List<String> tabs = ["Editor", "Blank Page"];

  bool isUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  // Widget textEditor() {
  //   return SizedBox(
  //       height: 500,
  //       width: 800,
  //       child: Column(
  //         children: [
  //           fleather.FleatherToolbar.basic(
  //             controller: _editorController!,
  //             hideAlignment: true,
  //             hideDirection: true,
  //             hideCodeBlock: true,
  //             hideListChecks: true,
  //           ),
  //           Expanded(
  //             child: fleather.FleatherEditor(controller: _editorController!),
  //           ),
  //           //or
  //         ],
  //       ));
  // }

  List<T> mergeUniqueBy<T, K>(
    List<T> listA,
    List<T> listB,
    K Function(T) keySelector,
  ) {
    final seen = <K>{};
    return [...listA, ...listB]
        .where((item) => seen.add(keySelector(item)))
        .toList();
  }

  Future<void> createNode(Connection c) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    List<Node> newNodeList = [];
    String mainNodeText = c.mainNode.controller.text;
    await db.transaction((txn) async {
      final batch = txn.batch();

      //Check if node exists
      int? nodeID;
      Node? firstWhere = nodeMapText[mainNodeText];

      if (firstWhere != null) {
        //if node exists
        nodeID = firstWhere.id;
      } else {
        //if node does not exist
        var n = {
          'constellation_id': constellation.id,
          'text': mainNodeText,
          'type': c.mainNode.type,
          'source': c.mainNode.externalFileLoaded ?? "",
          'created_at': now,
          'updated_at': now,
        };
        batch.insert('nodes', n);
        newNodeList.add(Node(
            id: -1,
            constellationID: constellation.id,
            text: mainNodeText,
            type: c.mainNode.type,
            source: c.mainNode.externalFileLoaded ?? "",
            createdAt: now,
            updatedAt: now));
      }

      for (final s in c.secondaryNodeList) {
        if (nodeMapText[s.controller.text] == null) {
          if (s.controller.text.trim().isEmpty) continue;

          batch.insert(
            'nodes',
            {
              'constellation_id': constellation.id,
              'text': s.controller.text,
              'type': s.type,
              'source': s.externalFileLoaded ?? '',
              'created_at': now,
              'updated_at': now,
            },
          );
          newNodeList.add(Node(
              id: -1,
              constellationID: constellation.id,
              text: s.controller.text,
              type: s.type,
              source: s.externalFileLoaded ?? '',
              createdAt: now,
              updatedAt: now));
        }
      }

      final List<int> results1 = (await batch.commit())
          .whereType<int>()
          .toList(); // This returns a list of inserted row IDs
      for (int i = 0; i < newNodeList.length; i++) {
        newNodeList[i].id = results1[i];
      }

      final Map<int, Node> toInsert = Map.fromIterables(results1, newNodeList);
      nodeMapID = {...nodeMapID, ...toInsert};
      nodeMapText = {
        ...nodeMapText,
        ...Map.fromIterables(
            newNodeList.map(
              (e) => e.text,
            ),
            newNodeList)
      };
      print("---------------");
      final dependentBatch = txn.batch();
      int mainID = nodeID ?? results1.removeAt(0);

      generalToDetail[mainNodeText] = {
        ...(generalToDetail[mainNodeText] ?? []),
        ...c.secondaryNodeList.map(
          (e) => e.controller.text,
        )
      }.toList();
      for (int i = 0; i < c.secondaryNodeList.length; i++) {
        String secondaryText = c.secondaryNodeList[i].controller.text;
        detailToGeneral[secondaryText] = {
          ...(detailToGeneral[secondaryText] ?? []),
          ...[mainNodeText]
        }.toList();
        relationMap[(mainNodeText, secondaryText)] = secondaryText;
      }
      for (int s = 0; s < c.secondaryNodeList.length; s++) {
        String secondaryText = c.secondaryNodeList[s].controller.text.trim();
        if (secondaryText.isEmpty) continue;
        print("secondary text: $secondaryText");
        print("id: ${nodeMapText[secondaryText]!.id}");
        dependentBatch.insert("edges", {
          "constellation_id": constellation.id,
          "from_node_id": mainID,
          "to_node_id": nodeMapText[secondaryText]!.id,
          "relation": c.secondaryNodeList[s].modifierController.text,
          "created_at": now,
          "updated_at": now,
        });
      }
      (await dependentBatch.commit());

      if (detailToGeneral[mainNodeText] == null && nodeMapID[mainID] != null) {
        topLevelMap[mainNodeText] = nodeMapID[mainID]!;
      }
      return topLevelMap;
    });
    print(nodeMapText);
    setState(() {
      print("--------------------updated after create");
    });

    switchScene(true);
  }

  Color primary1 = const Color.fromARGB(255, 108, 99, 255);
  Color primary2 = const Color.fromARGB(255, 63, 61, 86);
  Color primary3 = const Color.fromARGB(255, 255, 101, 132);
  Color selectedColor = const Color.fromARGB(127, 255, 255, 255);
  Color backgroundColor = const Color.fromARGB(255, 218, 218, 234);

  late List<Connection> connectionList;

  ScrollController mainScrollController = ScrollController();

  int currentMainProtoNode = -1;
  int currentSecondaryProtoNode = -1;
  bool innerClicked = false;
  bool outerClicked = false;

  Connection newConnection({
    List<ProtoSecondaryNode>? list,
    String mainNode = "",
    String modifier = "",
  }) {
    if (list == null) {
      return Connection(
        mainNode: ProtoMainNode(
            controller: TextEditingController(text: mainNode),
            focus: FocusNode()),
        secondaryNodeList: [
          ProtoSecondaryNode(
              controller: TextEditingController(),
              modifierController: TextEditingController(text: modifier),
              focus: FocusNode())
        ],
      );
    } else {
      return Connection(
        mainNode: ProtoMainNode(
            controller: TextEditingController(text: mainNode),
            focus: FocusNode()),
        secondaryNodeList: list,
      );
    }
  }

  void resetConnections() {
    setState(() {
      connectionList = [
        newConnection(list: [
          ProtoSecondaryNode(
              controller: TextEditingController(),
              modifierController: TextEditingController(text: ""),
              focus: FocusNode()),
          ProtoSecondaryNode(
              controller: TextEditingController(),
              modifierController: TextEditingController(text: ""),
              focus: FocusNode())
        ])
      ];
    });
  }

  void addConnection(
      {int index = -1, String mainNode = "", String modifier = ""}) {
    int addIndex = connectionList.length;
    setState(() {
      if (index > -1) {
        connectionList.insert(
            index + 1, newConnection(mainNode: mainNode, modifier: modifier));
        addIndex = index + 1;
      } else {
        connectionList
            .add(newConnection(mainNode: mainNode, modifier: modifier));
      }
      connectionList[addIndex].mainNode.focus.requestFocus();
      currentMainProtoNode = addIndex;
    });
  }

  void removeConnection() {
    setState(() {
      if (connectionList.length == 1) {
        return;
      }

      connectionList.removeAt(currentMainProtoNode);
      if (currentMainProtoNode >= connectionList.length) {
        currentMainProtoNode = connectionList.length - 1;
      }
    });
  }

  String formatDate(String input) {
    final dateTime = DateTime.parse(input); // e.g. "2025-05-30T15:42:00Z"
    final formatter = DateFormat('MMM d*yyyy  |  h:mm a'); // customize format
    return formatter
        .format(dateTime.toLocal()); // convert to local time if needed
  }

  void switchScene(bool forward) {
    if (forward) {
      setState(() {
        scene = 3;
      });
      _sceneController.forward();
    } else {
      _sceneController.reverse().then((_) {
        setState(() {
          scene = 1;
        });
      });
    }
  }

  void switchSecondaryScene(bool forward) {
    if (forward) {
      setState(() {
        scene = 4;
      });
      _secondarySceneController.forward(); // animate transition
    } else {
      _secondarySceneController.reverse().then((_) {
        setState(() {
          scene = 3;
        });
      });
    }
  }

  void _onPlusPressed() {
    _sceneColorController.forward(from: 0);
    setState(() {
      scene = 1;
    });
    _primarySceneController.forward(); // animate transition
  }

  void _onBackPressed() {
    _sceneColorController.forward(from: 0);
    _primarySceneController.reverse().then((_) {
      setState(() {
        scene = 0;
      });
    });
  }

  int scene = 0; // 0: dashboard, 1: new node, 2: directory 3: expanded view
  late AnimationController _sceneController;
  late Animation<Offset> _primarySceneOffset;
  late Animation<Offset> _secondarySceneOffset;
  late AnimationController _primarySceneController;
  late Animation<Offset> constellationDashboardSceneOffset;
  late Animation<Offset> addNodeSceneOffset;
  late Animation<Offset> addNodeSceneControllerOffset;
  late AnimationController _sceneColorController;
  late Animation<Color?> _borderColor;
  late AnimationController _secondarySceneController;
  late Animation<Offset> directorySceneOffset;
  late Animation<Offset> expandedViewOffset;

  Widget sceneController(BuildContext context) {
    return Stack(
      children: [
        SlideTransition(
            position: constellationDashboardSceneOffset,
            child: constellationDashboardScene()),
        SlideTransition(
          position: addNodeSceneOffset,
          child: addNodeScene(),
        )
      ],
    );
  }

  Widget nodeModifierInput(TextEditingController controller, bool selected) {
    return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        width: 180,
        height: 50,
        child: TextField(
          style: const TextStyle(fontSize: 14),
          controller: controller,
          cursorColor: Colors.black,
          decoration: const InputDecoration(
            hintText: "Modifier",
            hintStyle: TextStyle(
                fontSize: 14,
                color: Color.fromARGB(255, 193, 193, 193),
                fontWeight: FontWeight.bold),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ));
  }

  final List<IconData> nodeTypeList = [Pelaicons.textBold, Pelaicons.imageBold];

  IconData iconFromValue(int type) {
    if (type == 0) {
      return Pelaicons.textBold;
    } else if (type == 1) {
      return Pelaicons.imageBold;
    } else {
      return Pelaicons.addBold;
    }
  }

  int typeFromIcon(IconData data) {
    if (data == Pelaicons.textBold) {
      return 0;
    } else if (data == Pelaicons.imageBold) {
      return 1;
    } else {
      return 2;
    }
  }

  Widget nodeTypeWidget(
      TextEditingController controller, FocusNode focus, int type,
      {bool selected = false, int? mainNodeIndex, int? secondaryNodeIndex}) {
    IconData? selectedValue = iconFromValue(type);

    Widget nodeTypeSelect = Container(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: TextField(
          focusNode: focus,
          controller: controller,
          cursorColor: Colors.black,
          maxLines: null,
          expands: false,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: "Node Term",
            hintStyle: TextStyle(
                color: Color.fromARGB(255, 193, 193, 193),
                fontWeight: FontWeight.bold),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ));
    if (type == 1) {
      nodeTypeSelect = Container(
          child: ((secondaryNodeIndex == null)
                  ? connectionList[mainNodeIndex ?? 0]
                          .mainNode
                          .externalFileLoaded ==
                      null
                  : connectionList[mainNodeIndex ?? 0]
                          .secondaryNodeList[secondaryNodeIndex]
                          .externalFileLoaded ==
                      null)
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        onPressed: () async {
                          final picker = ImagePicker();
                          XFile? image = await picker.pickImage(
                              source: ImageSource.gallery);

                          if (image != null) {
                            setState(() {
                              if (secondaryNodeIndex == null) {
                                connectionList[mainNodeIndex ?? 0]
                                    .mainNode
                                    .externalFileLoaded = image.path;
                              } else {
                                connectionList[mainNodeIndex ?? 0]
                                    .secondaryNodeList[secondaryNodeIndex]
                                    .externalFileLoaded = image.path;
                              }
                            });
                          }
                        },
                        icon: Icon(Icons.add_rounded))
                  ],
                )
              : Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File((secondaryNodeIndex == null)
                                ? connectionList[mainNodeIndex ?? 0]
                                    .mainNode
                                    .externalFileLoaded!
                                : connectionList[mainNodeIndex ?? 0]
                                    .secondaryNodeList[secondaryNodeIndex]
                                    .externalFileLoaded!)))),
                    Positioned(
                        child: Container(
                            margin: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                                color: const Color.fromARGB(197, 255, 255, 255),
                                borderRadius: BorderRadius.circular(10)),
                            child: TextField(
                              style: TextStyle(fontWeight: FontWeight.bold),
                              focusNode: focus,
                              controller: controller,
                              cursorColor: Colors.black,
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                hintText: "Image label",
                                hintStyle: TextStyle(
                                    color: Color.fromARGB(255, 91, 91, 91),
                                    fontWeight: FontWeight.bold),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            )))
                  ],
                ));
    }
    return Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        width: 240,
        constraints: BoxConstraints(minHeight: 100),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
                child: Column(
              children: [nodeTypeSelect],
            )),
            type == 1
                ? ((secondaryNodeIndex == null)
                        ? connectionList[mainNodeIndex ?? 0]
                                .mainNode
                                .externalFileLoaded !=
                            null
                        : connectionList[mainNodeIndex ?? 0]
                                .secondaryNodeList[secondaryNodeIndex]
                                .externalFileLoaded !=
                            null)
                    ? Positioned(
                        top: 3,
                        left: 3,
                        child: Container(
                            decoration: BoxDecoration(
                                color: Color.fromARGB(179, 255, 255, 255),
                                borderRadius: BorderRadius.circular(20)),
                            child: IconButton(
                                iconSize: 20,
                                padding: EdgeInsets.all(2),
                                constraints: BoxConstraints(),
                                hoverColor: Colors.transparent,
                                onPressed: () {
                                  setState(() {
                                    ((secondaryNodeIndex == null)
                                        ? connectionList[mainNodeIndex ?? 0]
                                            .mainNode
                                            .externalFileLoaded = null
                                        : connectionList[mainNodeIndex ?? 0]
                                            .secondaryNodeList[
                                                secondaryNodeIndex]
                                            .externalFileLoaded = null);
                                  });
                                },
                                icon: Icon(Icons.clear_rounded))))
                    : SizedBox.shrink()
                : SizedBox.shrink(),
            Positioned(
                top: 3,
                right: 3,
                child: DropdownButtonHideUnderline(
                    child: DropdownButton2<IconData>(
                        value: selectedValue,
                        onChanged: (IconData? value) {
                          setState(() {
                            selectedValue = value;
                            if (mainNodeIndex != null) {
                              if (secondaryNodeIndex == null) {
                                connectionList[mainNodeIndex].mainNode.type =
                                    typeFromIcon(value ?? Pelaicons.textBold);
                              } else {
                                connectionList[mainNodeIndex]
                                        .secondaryNodeList[secondaryNodeIndex]
                                        .type =
                                    typeFromIcon(value ?? Pelaicons.textBold);
                              }
                            }
                          });
                        },
                        iconStyleData: IconStyleData(
                            icon: Icon(
                          Icons.arrow_drop_down_rounded,
                        )),
                        buttonStyleData: ButtonStyleData(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Color.fromARGB(179, 255, 255, 255)),
                          padding: EdgeInsets.all(0),
                          height: 24,
                          width: 50,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          width: 30,
                          padding: EdgeInsets.all(0),
                          decoration: BoxDecoration(
                            boxShadow: [],
                            border: Border.all(),
                            borderRadius: BorderRadius.circular(5),
                            color: const Color.fromARGB(255, 255, 255, 255),
                          ),
                          offset: const Offset(-3, -8),
                          scrollbarTheme: ScrollbarThemeData(
                            radius: const Radius.circular(2),
                            thickness: WidgetStateProperty.all(6),
                            thumbVisibility: WidgetStateProperty.all(true),
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 34,
                          padding: EdgeInsets.all(3),
                        ),
                        items: nodeTypeList
                            .map((IconData item) => DropdownMenuItem<IconData>(
                                value: item, child: Icon(item)))
                            .toList())))
          ],
        ));
  }

  void addConnectionWidget({String modifier = ""}) {
    setState(() {
      currentSecondaryProtoNode += 1;
      connectionList[currentMainProtoNode].secondaryNodeList.insert(
          currentSecondaryProtoNode,
          ProtoSecondaryNode(
              controller: TextEditingController(),
              modifierController: TextEditingController(text: modifier),
              focus: FocusNode()));

      connectionList[currentMainProtoNode]
          .secondaryNodeList[currentSecondaryProtoNode]
          .focus
          .requestFocus();
    });
  }

  void removeConnectionWidget() {
    setState(() {
      int len = connectionList[currentMainProtoNode].secondaryNodeList.length;
      if (len == 1) {
        removeConnection();
        return;
      }
      connectionList[currentMainProtoNode]
          .secondaryNodeList
          .removeAt(currentSecondaryProtoNode);
      if (currentSecondaryProtoNode >= len - 1) {
        currentSecondaryProtoNode = len - 2;
      }
    });
  }

  Widget connectionWidget(ProtoSecondaryNode p, int index, int parent) {
    bool selected =
        currentMainProtoNode == parent && currentSecondaryProtoNode == index;
    return Listener(
        onPointerDown: (event) {
          if (currentMainProtoNode == parent) {
            setState(() {
              innerClicked = true;
            });
          }
          Future.delayed(Duration.zero, () {
            setState(() {
              currentSecondaryProtoNode = index;
              innerClicked = false;
            });
          });
        },
        child: Container(
            margin: EdgeInsets.only(
                bottom:
                    connectionList[parent].secondaryNodeList.length - 1 != index
                        ? 20
                        : 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    margin: EdgeInsets.only(top: 26),
                    child: Row(
                      children: [
                        SizedBox(width: 30),
                        Icon(
                          selected ? Icons.circle : Icons.trip_origin,
                          color: Colors.white,
                          size: 10,
                        ),
                        SizedBox(width: 30),
                        nodeModifierInput(p.modifierController, selected),
                        Container(
                            color: Colors.white,
                            height: selected ? 4 : 4,
                            width: 50),
                      ],
                    )),
                Container(
                    width: 300,
                    child: nodeTypeWidget(
                        p.controller,
                        selected: selected,
                        p.focus,
                        p.type,
                        mainNodeIndex: parent,
                        secondaryNodeIndex: index)),
              ],
            )));
  }

  Widget nodeConnection(Connection c, int index) {
    return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          Future.microtask(() => outerClicked = true);
          setState(() {
            if (!innerClicked) {
              currentMainProtoNode = index;

              currentSecondaryProtoNode = -1;
              outerClicked = false;
            }
          });
        },
        child: Container(
            padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
            decoration: BoxDecoration(
                color: index == currentMainProtoNode
                    ? primary1
                    : const Color.fromARGB(255, 243, 243, 248),
                borderRadius: BorderRadius.circular(20)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                        width: 300,
                        child: nodeTypeWidget(c.mainNode.controller,
                            c.mainNode.focus, c.mainNode.type,
                            mainNodeIndex: index))
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...c.secondaryNodeList.asMap().entries.map((entry) {
                      int indexKey = entry.key;
                      ProtoSecondaryNode p = entry.value;

                      return connectionWidget(p, indexKey, index);
                    }),
                  ],
                )
              ],
            )));
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget addNodeSceneController() {
    return ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color.fromARGB(69, 255, 255, 255),
                    borderRadius: BorderRadius.circular(40)),
                child: Row(
                  children: [
                    IconButton(
                        onPressed: () {
                          if (currentSecondaryProtoNode >= 0) {
                            print("test");
                            addConnectionWidget();
                          } else if (currentMainProtoNode >= 0) {
                            addConnection(index: currentMainProtoNode);
                          } else {
                            addConnection();
                          }
                        },
                        icon: Icon(Icons.add),
                        color: Colors.white,
                        style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(primary1),
                            shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadiusGeometry.circular(20))))),
                    SizedBox(width: 20),
                    IconButton(
                        onPressed: () {
                          if (currentSecondaryProtoNode >= 0) {
                            removeConnectionWidget();
                          } else if (currentMainProtoNode >= 0) {
                            removeConnection();
                          } else {}
                        },
                        icon: Icon(Icons.delete_forever_rounded),
                        color: Colors.white,
                        style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(primary2),
                            shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadiusGeometry.circular(20))))),
                    SizedBox(width: 250),
                    TextButton(
                        onPressed: () async {
                          for (Connection c in connectionList) {
                            if ((c.mainNode.externalFileLoaded != null &&
                                    c.mainNode.controller.text.isEmpty) ||
                                (c.secondaryNodeList.any((c) =>
                                    (c.externalFileLoaded != null &&
                                        c.controller.text.isEmpty)))) {
                              showErrorDialog(
                                  context, 'Images must have a label');
                              return;
                            }
                            if (c.mainNode.controller.text.isEmpty &&
                                c.secondaryNodeList.any((c) =>
                                    c.controller.text.trim().isNotEmpty)) {
                              showErrorDialog(context,
                                  'Primary nodes cannot be empty when making secondary connections');
                              return;
                            }
                          }

                          for (Connection c in connectionList) {
                            print("-create-----------------");
                            await createNode(c);
                          }
                          Future.delayed(const Duration(milliseconds: 600), () {
                            // Your function here
                            resetConnections();
                          });
                        },
                        child: Container(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              "Create",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            )),
                        style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(primary3),
                            shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadiusGeometry.circular(20)))))
                  ],
                ))));
  }

  Widget addNodeScene() {
    return scene == 1
        ? GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() {
                if (outerClicked) {
                  outerClicked = false;
                  return;
                }
                ;
                currentSecondaryProtoNode = -1;
                currentMainProtoNode = -1;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                    constraints: BoxConstraints(minHeight: 500),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            SizedBox(height: 60),
                            ...connectionList.asMap().entries.map((entry) {
                              int index = entry.key;
                              Connection c = entry.value;

                              return nodeConnection(c, index);
                            })
                          ],
                        ),
                      ],
                    ))
              ],
            ))
        : SizedBox.shrink();
  }

  Widget constellationDashboardScene() {
    String imagePath = constellation.image;
    List<String> sentences = constellation.summary.split(".");
    String firstSentence = sentences.isNotEmpty ? sentences[0] + '.' : '';
    String rest =
        sentences.length > 1 ? sentences.sublist(1).join('.').trim() : '';

    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
              child: Column(
            children: [
              Container(
                  height: 80,
                  width: 80,
                  child: IconButton.filled(
                      color: primary2,
                      style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Colors.white),
                          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadiusGeometry.circular(20)))),
                      onPressed: () {
                        _onPlusPressed();
                      },
                      icon: Icon(Icons.add_rounded))),
              SizedBox(height: 10),
              Container(
                  height: 80,
                  width: 80,
                  child: IconButton.filled(
                      color: Colors.white,
                      style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(primary1),
                          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadiusGeometry.circular(20)))),
                      onPressed: () {
                        switchScene(true);
                      },
                      icon: Icon(Icons.list))),
              SizedBox(height: 10),
              Container(
                  height: 80,
                  width: 80,
                  child: IconButton.filled(
                      color: Colors.white,
                      style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(primary1),
                          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadiusGeometry.circular(20)))),
                      onPressed: () {},
                      icon: Icon(Icons.search)))
            ],
          )),
          SizedBox(width: 10),
          Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: const Color.fromARGB(255, 255, 255, 255),
                borderRadius: BorderRadius.circular(25)),
            width: 300,
            height: 480,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Media Types",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: 12),
                Expanded(
                    child: GridView.count(
                        crossAxisCount: 2, // 2 columns
                        childAspectRatio: 1.0, // width:height = 1:1 (square)
                        mainAxisSpacing: 12, // vertical spacing between rows
                        crossAxisSpacing:
                            12, // horizontal spacing between columns
                        children: [
                      Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Pelaicons.folder1Bold, size: 30),
                              Text("Files")
                            ],
                          )),
                      Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Pelaicons.textBold, size: 30),
                              Text("Texts")
                            ],
                          )),
                      Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Pelaicons.webBrowserBold, size: 30),
                              Text("Media")
                            ],
                          )),
                      Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Pelaicons.imageBold, size: 30),
                              Text("Images")
                            ],
                          )),
                      Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Pelaicons.linkBold, size: 30),
                              Text("Internal Link")
                            ],
                          )),
                      Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Pelaicons.websiteBold, size: 30),
                              Text("External Link")
                            ],
                          ))
                    ])),
              ],
            ),
          ),
          SizedBox(width: 10),
          Container(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 400,
                        height: 110,
                        padding: EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            borderRadius: BorderRadius.circular(25)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Text("Concept",
                                    style: TextStyle(
                                        color: const Color.fromARGB(
                                            255, 181, 181, 181),
                                        fontWeight: FontWeight.w700)),
                                Spacer(),
                                Icon(Pelaicons.menuBold, color: primary3)
                              ],
                            ),
                            SizedBox(height: 5),
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  constellationConcept,
                                  style: const TextStyle(
                                      color: Color.fromARGB(255, 21, 19, 19),
                                      fontWeight: FontWeight.w100,
                                      fontSize: 30),
                                )),
                          ],
                        ),
                      ),
                    ]),
                SizedBox(height: 10),
                Container(
                    decoration: BoxDecoration(
                        color: primary1,
                        borderRadius: BorderRadius.circular(25)),
                    width: 400,
                    padding: EdgeInsets.all(18),
                    child: SingleChildScrollView(
                      child: Column(children: [
                        Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5)),
                            child: const Text(
                              "Key Words",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Color.fromARGB(255, 255, 255, 255)),
                            )),
                        SizedBox(height: 20),
                        Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.white),
                                borderRadius: BorderRadius.circular(10)),
                            child: TextButton(
                              style: ButtonStyle(
                                  shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadiusGeometry.circular(
                                                  10)))),
                              child: Row(
                                children: [
                                  Text("Add new key word",
                                      style: TextStyle(color: primary1)),
                                  Spacer(),
                                  Icon(Icons.add_rounded, color: primary1)
                                ],
                              ),
                              onPressed: () {},
                            )),
                      ]),
                    )),
                SizedBox(height: 10),
                Container(
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        borderRadius: BorderRadius.circular(25)),
                    width: 400,
                    padding: EdgeInsets.all(18),
                    child: SingleChildScrollView(
                      child: Column(children: [
                        Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(
                              "Highlighted",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: primary1),
                            )),
                        Container(
                          padding: EdgeInsets.all(16),
                          child: SvgPicture.asset(
                            'images/highlighted_alternative.svg',
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Text("Add and highlight nodes to see them here")
                      ]),
                    )),
              ])),
          SizedBox(width: 10),
          Container(
              height: 480,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 300,
                  constraints: BoxConstraints(maxHeight: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: AspectRatio(
                                  aspectRatio: 1, // width : height = 1:1
                                  child: Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                            255, 255, 255, 255),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text('Last Updated',
                                            style: TextStyle(
                                              fontSize: 10,
                                            )),
                                        Divider(),
                                        SizedBox(height: 5),
                                        Container(
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                        style:
                                                            GoogleFonts.roboto(
                                                                color: primary3,
                                                                fontSize: 40,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                        formatDate(constellation
                                                                .updatedAt)
                                                            .split('*')[0]
                                                            .toUpperCase())),
                                                FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                        formatDate(constellation
                                                                .updatedAt)
                                                            .split('*')[1]
                                                            .toUpperCase()))
                                              ],
                                            ))
                                      ],
                                    ),
                                  ))),
                          SizedBox(width: 10),
                          Expanded(
                              child: AspectRatio(
                                  aspectRatio: 1, // width : height = 1:1
                                  child: Container(
                                      decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                              255, 255, 255, 255),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Icon(Pelaicons.userBold))))
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                      decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          borderRadius: BorderRadius.circular(20)),
                      width: 300,
                      padding: const EdgeInsets.all(18),
                      child: SingleChildScrollView(
                        child: Column(children: [
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      const Color.fromARGB(255, 255, 255, 255),
                                  borderRadius: BorderRadius.circular(5)),
                              child: Row(
                                children: [
                                  const Text(
                                    "Notes",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Color.fromARGB(255, 0, 0, 0)),
                                  ),
                                  const Spacer(),
                                  Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                              41, 63, 61, 86),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Icon(
                                        Pelaicons.penBold,
                                        color: primary2,
                                      ))
                                ],
                              )),
                          const Divider(color: Colors.white),
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      const Color.fromARGB(255, 248, 248, 248),
                                  borderRadius: BorderRadius.circular(5)),
                              child: Text(
                                firstSentence,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color.fromARGB(255, 0, 0, 0)),
                              )),
                          const Divider(color: Colors.white),
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      const Color.fromARGB(255, 248, 248, 248),
                                  borderRadius: BorderRadius.circular(5)),
                              child: Text(
                                rest,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color.fromARGB(255, 0, 0, 0)),
                              )),
                        ]),
                      )),
                )
              ]))
        ]);
  }

  List<Node> getTopLevelNodes() {
    return topLevelMap.values.toList();
  }

  double directoryEntryWidth = 580;

  Widget directoryEntryTop(Node? n, {int index = -1}) {
    Widget entry = Container(
        margin: const EdgeInsets.only(bottom: 45),
        width: directoryEntryWidth,
        padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: n == null
            ? const SizedBox.shrink()
            : Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      child: Row(children: [
                    Column(
                      children: [
                        n.type == 1
                            ? Container(
                                margin: EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                    border:
                                        Border.all(color: primary1, width: 3),
                                    borderRadius: BorderRadius.circular(10)),
                                constraints: BoxConstraints(
                                    maxWidth: directoryEntryWidth),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.file(File(n.source),
                                        fit: BoxFit.fitWidth)))
                            : const SizedBox.shrink(),
                        Container(
                          width: directoryEntryWidth,
                          decoration: BoxDecoration(
                              color: primary1,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Container(
                                  decoration: BoxDecoration(
                                      color: primary1,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Container(
                                      margin: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      child: SizedBox(
                                        width: 560,
                                        child: DoubleTapEditableText(
                                          textColor: Colors.white,
                                          fontSize: 25,
                                          backgroundColor: primary1,
                                          initialText: n.text,
                                          onSubmitted: (newText) {
                                            setState(() {
                                              if (newText.isNotEmpty) {
                                                n.text = newText;
                                              } else {} // update state when user finishes editing
                                            });
                                          },
                                        ),
                                      ))),
                              Spacer(),
                              PopupMenuButton(
                                  tooltip: "",
                                  shape: ContinuousRectangleBorder(
                                      side: BorderSide(
                                          width: 1, color: Colors.black)),
                                  color: Colors.white,
                                  itemBuilder: (BuildContext context) => [
                                        PopupMenuItem(
                                          onTap: () => {},
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          onTap: () => {},
                                          child: Text('Delete'),
                                        ),
                                      ],
                                  icon: const Icon(Icons.more_horiz,
                                      size: 20,
                                      color:
                                          Color.fromARGB(255, 255, 255, 255)))
                            ],
                          ),
                        )
                      ],
                    )
                  ])),
                  generalToDetail[n.text] != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(children: [
                            ListView.separated(
                              shrinkWrap:
                                  true, // use this if inside another scrollable
                              itemCount: generalToDetail[n.text]!.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return Container(
                                  child: directoryEntry(
                                      nodeMapText[
                                          generalToDetail[n.text]![index]],
                                      1,
                                      index: index),
                                );
                              },
                            ),
                          ]))
                      : const SizedBox.shrink()
                ],
              ));
    return SizedBox(child: entry);
  }

  Widget directoryEntry(Node? n, int level, {int index = -1}) {
    // print(level);
    // print("text: ${n.text}");
    print(n);
    Widget entry = Container(
        width: directoryEntryWidth,
        padding: (level == 1 ? EdgeInsets.symmetric(vertical: 0) : null),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: n == null
            ? SizedBox.shrink()
            : level < 6
                ? Container(
                    padding: (level == 1 && generalToDetail[n.text] != null)
                        ? EdgeInsets.only(right: 10, top: 10, bottom: 10)
                        : EdgeInsets.all(0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            child: Row(children: [
                          Column(
                            children: [
                              n.type == 1
                                  ? Container(
                                      margin: EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: primary1, width: 3),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      constraints: BoxConstraints(
                                          maxWidth: directoryEntryWidth),
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          child: Image.file(File(n.source),
                                              fit: BoxFit.fitWidth)))
                                  : const SizedBox.shrink(),
                              Row(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        margin: EdgeInsets.only(top: 15),
                                        child: Container(
                                          // decoration: BoxDecoration(
                                          //     border: Border.all()),
                                          width: 30,
                                          child: level % 2 == 0
                                              ? Icon(
                                                  Icons.circle,
                                                  size: 9,
                                                  color: primary1,
                                                )
                                              : Icon(
                                                  Icons.square,
                                                  size: 9,
                                                  color: primary1,
                                                ),
                                        )),
                                    SizedBox(
                                        width: level == 1
                                            ? 522
                                            : (500 - ((level - 1) * 30))
                                                .toDouble(),
                                        child: Container(
                                            padding: EdgeInsets.all(
                                                level == 1 ? 10 : 0),
                                            decoration: (level == 1 &&
                                                    generalToDetail[n.text] !=
                                                        null)
                                                ? BoxDecoration(
                                                    border: Border.all(
                                                        color: const Color
                                                            .fromARGB(255, 147,
                                                            147, 147)),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10))
                                                : null,
                                            child: Column(children: [
                                              DoubleTapEditableText(
                                                initialText: n.text,
                                                onSubmitted: (newText) {
                                                  setState(() {
                                                    if (newText.isNotEmpty) {
                                                      n.text = newText;
                                                    } // update state when user finishes editing
                                                  });
                                                },
                                              ),
                                              generalToDetail[n.text] != null
                                                  ? Column(children: [
                                                      SizedBox(height: 10),
                                                      ListView.separated(
                                                        shrinkWrap:
                                                            true, // use this if inside another scrollable
                                                        itemCount:
                                                            generalToDetail[
                                                                    n.text]!
                                                                .length,
                                                        separatorBuilder:
                                                            (context, index) =>
                                                                const SizedBox(
                                                                    height: 10),
                                                        itemBuilder:
                                                            (context, index) {
                                                          return Container(
                                                            child: directoryEntry(
                                                                nodeMapText[
                                                                    generalToDetail[
                                                                            n.text]![
                                                                        index]],
                                                                level + 1,
                                                                index: index),
                                                          );
                                                        },
                                                      ),
                                                    ])
                                                  : const SizedBox.shrink()
                                            ])))
                                  ])
                            ],
                          )
                        ])),
                      ],
                    ))
                : const SizedBox.shrink());
    return SizedBox(child: entry);
  }

  Widget directoryView() {
    List<Node> topLevelNodes = topLevelMap.values.toList();
    topLevelNodes.removeWhere(
      (element) => element.text == constellationConcept,
    );
    print(detailToGeneral);
    print(topLevelNodes.map((e) => e.text));
    // print(topLevelNodes.map((e) => e.text));
    return Center(
        child: Stack(children: [
      SingleChildScrollView(
          child: Container(
              width: double.infinity,
              child: Align(
                  alignment: Alignment.center,
                  child: Container(
                      width: 600,
                      margin: EdgeInsets.only(top: 40, left: 10, right: 10),
                      child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            scrollbars: false, // disables the scrollbar
                          ),
                          child: ReorderableListView.builder(
                              physics:
                                  const NeverScrollableScrollPhysics(), // disables scrolling
                              shrinkWrap: true,
                              itemBuilder: (BuildContext context, int index) {
                                return Container(
                                    key: UniqueKey(),
                                    width: 600,
                                    child: directoryEntryTop(
                                        topLevelNodes[index],
                                        index: index));
                              },
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  Node newIndexNode = topLevelNodes[newIndex];
                                  topLevelNodes[newIndex] =
                                      topLevelNodes[oldIndex];
                                  topLevelNodes[oldIndex] = newIndexNode;
                                });
                              },
                              itemCount: topLevelNodes.length)))))),
    ]));
  }

  Widget expandedView() {
    return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(color: backgroundColor),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          nodeMapID[focusedNode.id] == null
              ? MouseRegion(
                  onEnter: (details) => setState(() => mainNodeHover = true),
                  onExit: (details) => setState(() {
                        mainNodeHover = false;
                      }),
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 50),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                                constraints: const BoxConstraints(
                                    maxWidth: 500, minHeight: 200),
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(width: 1, color: Colors.black),
                                ),
                                child: focusedNode.type == 1
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child:
                                            Image.file(File(focusedNode.text)))
                                    : Text(
                                        style: TextStyle(
                                            fontSize: focusedNode.text.length >
                                                    100
                                                ? 18
                                                : focusedNode.text.length > 20
                                                    ? 22
                                                    : 30),
                                        focusedNode.text)),
                          ]),
                    )
                  ]))
              : Stack(alignment: Alignment.centerLeft, children: [
                  SizedBox(
                      width: double.infinity,
                      child: AnimatedAlign(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          alignment: Alignment.center,
                          child: SizedBox(
                              width: 1200,
                              child: Row(children: [
                                AnimatedSlide(
                                    offset: showSecond
                                        ? const Offset(0, 0)
                                        : showCenter
                                            ? const Offset(0.25, 0)
                                            : const Offset(0.5, 0),
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeInOut,
                                    child: AnimatedAlign(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                          width: 800,
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                AnimatedOpacity(
                                                    opacity: switchMain
                                                        ? _fadeAnimation1.value
                                                        : 1,
                                                    curve: Curves.easeInOut,
                                                    duration: const Duration(
                                                        milliseconds: 200),
                                                    child: AnimatedSlide(
                                                        offset:
                                                            const Offset(0, 0),
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    600),
                                                        curve: Curves.easeInOut,
                                                        child: Container(
                                                            constraints:
                                                                const BoxConstraints(
                                                              minHeight: 60,
                                                              maxWidth: 400,
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                              right: 20,
                                                            ),
                                                            child:
                                                                GestureDetector(
                                                              onTap: () async {
                                                                print(
                                                                    "testtttt");
                                                                if (midTransition) {
                                                                  return;
                                                                }

                                                                setState(() {
                                                                  midTransition =
                                                                      true;
                                                                });

                                                                if (!showCenter) {
                                                                  // Showing center

                                                                  setState(() {
                                                                    showCenter =
                                                                        true;
                                                                    showCenter =
                                                                        true;
                                                                  });

                                                                  // First animate left container
                                                                  await Future.delayed(
                                                                      const Duration(
                                                                          milliseconds:
                                                                              400));

                                                                  // Then animate center
                                                                  _controller
                                                                      .forward();

                                                                  if (showSecond) {
                                                                    _controller1
                                                                        .forward();
                                                                  }
                                                                } else {
                                                                  // Hiding center

                                                                  if (showSecond) {
                                                                    _controller1
                                                                        .reverse();
                                                                  }

                                                                  _controller
                                                                      .reverse();

                                                                  await Future.delayed(
                                                                      const Duration(
                                                                          milliseconds:
                                                                              350));

                                                                  setState(() {
                                                                    showCenter =
                                                                        false;
                                                                    showSecond =
                                                                        false;
                                                                  });
                                                                }
                                                                setState(() {
                                                                  midTransition =
                                                                      false;
                                                                });
                                                              },
                                                              child:

                                                                  // Main node card

                                                                  Container(
                                                                      width:
                                                                          400,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        borderRadius:
                                                                            BorderRadius.circular(20),
                                                                        border: Border.all(
                                                                            width:
                                                                                1,
                                                                            color:
                                                                                Colors.black),
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                      alignment:
                                                                          Alignment
                                                                              .center,
                                                                      child: Container(
                                                                          padding: const EdgeInsets
                                                                              .all(
                                                                              15),
                                                                          child: focusedNode.type == 1
                                                                              ? Image.file(File(focusedNode.text))
                                                                              : Text(focusedNode.text, style: TextStyle(fontSize: focusedNode.text.length > 100 ? 15 : 25)))),
                                                            ))
                                                        // Top Gradient
                                                        )),
                                                Expanded(
                                                    child: IgnorePointer(
                                                        ignoring: !showCenter,
                                                        child: ClipRect(
                                                          child: SizedBox(
                                                            // decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                                                            width:
                                                                400, // Always reserve space
                                                            child:
                                                                AnimatedBuilder(
                                                              animation:
                                                                  _controller,
                                                              builder: (context,
                                                                  child) {
                                                                return Opacity(
                                                                  opacity:
                                                                      _fadeAnimation
                                                                          .value,
                                                                  child:
                                                                      FractionalTranslation(
                                                                    translation:
                                                                        Offset(
                                                                            0,
                                                                            _slideAnimation.value),
                                                                    child:
                                                                        child,
                                                                  ),
                                                                );
                                                              },
                                                              child: Container(
                                                                constraints:
                                                                    const BoxConstraints(
                                                                        maxWidth:
                                                                            400),
                                                                child:
                                                                    ReorderableListView(
                                                                  shrinkWrap:
                                                                      true,
                                                                  physics:
                                                                      const ClampingScrollPhysics(),
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          right:
                                                                              10),
                                                                  proxyDecorator:
                                                                      auxiliaryDisplayProxyDecoratorTier1,
                                                                  onReorder: (int
                                                                          oldIndex,
                                                                      int newIndex) {
                                                                    setState(
                                                                        () {
                                                                      if (oldIndex <
                                                                          newIndex) {
                                                                        newIndex -=
                                                                            1;
                                                                      }
                                                                      if (oldIndex !=
                                                                          newIndex) {
                                                                        reorderableListNodeSwap(
                                                                            focusedNode.text,
                                                                            oldIndex,
                                                                            newIndex);
                                                                      }
                                                                    });
                                                                  },
                                                                  children: showCenter
                                                                      ? getNodeConnectionsParsed(focusedNode
                                                                              .text)
                                                                          .map((e) => auxiliaryDisplay(
                                                                              e,
                                                                              1))
                                                                          .toList()
                                                                      : [],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        )))
                                              ])),
                                    )),
                                ClipRect(
                                  child: SizedBox(
                                    width: 400, // Always reserve space
                                    child: AnimatedBuilder(
                                      animation: _controller1,
                                      builder: (context, child) {
                                        return Opacity(
                                          opacity: _fadeAnimation1.value,
                                          child: FractionalTranslation(
                                            translation: Offset(
                                                0, _slideAnimation1.value),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 400),
                                        child: ReorderableListView(
                                          shrinkWrap: true,
                                          physics:
                                              const ClampingScrollPhysics(),
                                          padding:
                                              const EdgeInsets.only(right: 10),
                                          proxyDecorator:
                                              auxiliaryDisplayProxyDecoratorTier2,
                                          onReorder:
                                              (int oldIndex, int newIndex) {
                                            setState(() {
                                              if (secondaryNode == null) return;
                                              if (oldIndex < newIndex) {
                                                newIndex -= 1;
                                              }
                                              if (oldIndex != newIndex) {
                                                reorderableListNodeSwap(
                                                    secondaryNode!.text,
                                                    oldIndex,
                                                    newIndex);
                                              }
                                            });
                                          },
                                          children: secondaryNode == null
                                              ? []
                                              : getNodeConnectionsParsed(
                                                      secondaryNode!.text)
                                                  .map((e) =>
                                                      auxiliaryDisplay(e, 2))
                                                  .toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              ])))),
                ])
        ]));
  }

  void addConnectionEnter() {
    if (currentSecondaryProtoNode >= 0) {
      addConnectionWidget();
    } else if (currentMainProtoNode >= 0) {
      addConnection(index: currentMainProtoNode);
    } else {
      addConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{},
        child: Actions(
            actions: const <Type, Action<Intent>>{},
            child: Scaffold(
                appBar: AppBar(
                  scrolledUnderElevation: 0,
                  toolbarHeight: 50,
                  titleSpacing: 0,
                  primary: false,
                  automaticallyImplyLeading: false,
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              color: const Color.fromARGB(255, 255, 255, 255),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(Icons.rocket_launch_sharp),
                                  const Spacer(),
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
                        duration: const Duration(milliseconds: 200),
                        child: Center(
                            child: LoadingAnimationWidget.halfTriangleDot(
                                color: primary2, size: 50)))
                    : Shortcuts(
                        shortcuts: <LogicalKeySet, Intent>{
                            LogicalKeySet(LogicalKeyboardKey.enter,
                                LogicalKeyboardKey.shift): const AddIntent(),
                          },
                        child: Actions(
                            actions: <Type, Action<Intent>>{
                              AddIntent: CallbackAction<AddIntent>(
                                onInvoke: (AddIntent intent) => setState(() {
                                  addConnectionEnter();
                                }),
                              ),
                            },
                            child: Scaffold(
                                backgroundColor: backgroundColor,
                                body: LayoutBuilder(
                                    builder: (context, constraints) {
                                  return Stack(children: [
                                    SlideTransition(
                                        position: _primarySceneOffset,
                                        child: (Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SingleChildScrollView(
                                                  controller:
                                                      mainScrollController,
                                                  scrollDirection:
                                                      Axis.vertical,
                                                  child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                        minHeight: constraints
                                                            .maxHeight, // 👈 Fill full height
                                                      ),
                                                      child: AnimatedBuilder(
                                                          animation:
                                                              _sceneColorController,
                                                          builder: (_, __) =>
                                                              Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          20),
                                                                  decoration:
                                                                      const BoxDecoration(
                                                                    color: Color
                                                                        .fromARGB(
                                                                            255,
                                                                            218,
                                                                            218,
                                                                            234), // Background color
                                                                  ),
                                                                  child: Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius:
                                                                            BorderRadius.circular(10),
                                                                        border: Border.all(
                                                                            color:
                                                                                _borderColor.value ?? Colors.black),
                                                                      ),
                                                                      child: ClipRRect(
                                                                          borderRadius: BorderRadius.circular(10),
                                                                          child: Stack(alignment: Alignment.center, children: [
// -------------------------------------------------------------------------------------------------------------------------------------
// Node Submission Dashboard
// -------------------------------------------------------------------------------------------------------------------------------------

                                                                            Container(
                                                                              padding: const EdgeInsets.all(20),
                                                                              decoration: const BoxDecoration(
                                                                                color: Color.fromARGB(255, 218, 218, 234),
                                                                              ),
                                                                              child: sceneController(context),
                                                                            )

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Flashcard Mode
// -------------------------------------------------------------------------------------------------------------------------------------
                                                                          ]))))))),
                                              Positioned(
                                                  top: 30,
                                                  child: SlideTransition(
                                                    position:
                                                        addNodeSceneControllerOffset,
                                                    child:
                                                        addNodeSceneController(),
                                                  )),
                                              Positioned(
                                                  top: 20,
                                                  left: 70,
                                                  child: Container(
                                                      // decoration: BoxDecoration(
                                                      //   borderRadius: BorderRadius.circular(10),
                                                      //   border:
                                                      //       Border.all(width: 1, color: Colors.black),
                                                      // ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              10),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Container(
                                                              height: 40,
                                                              width: 40,
                                                              decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              20)),
                                                              child: IconButton(
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                style: const ButtonStyle(
                                                                    shape: WidgetStatePropertyAll(
                                                                        RoundedRectangleBorder())),
                                                                icon: Icon(
                                                                    size: 24,
                                                                    scene == 1
                                                                        ? Icons
                                                                            .arrow_upward_rounded
                                                                        : Icons
                                                                            .arrow_downward_rounded),
                                                                onPressed: () {
                                                                  if (scene ==
                                                                      0) {
                                                                    _onPlusPressed();
                                                                  } else if (scene ==
                                                                      1) {
                                                                    mainScrollController
                                                                        .animateTo(
                                                                      0, // Scroll to top (offset 0)
                                                                      duration: const Duration(
                                                                          milliseconds:
                                                                              400), // Adjust speed here
                                                                      curve: Curves
                                                                          .easeOut, // Smooth animation
                                                                    );
                                                                    _onBackPressed();
                                                                  }
                                                                },
                                                              )),
                                                        ],
                                                      ))),
                                            ]))),
                                    SlideTransition(
                                      position: _secondarySceneOffset,
                                      child: Stack(
                                        children: [
                                          SlideTransition(
                                              position: directorySceneOffset,
                                              child: directoryView()),
                                          SlideTransition(
                                              position: expandedViewOffset,
                                              child: expandedView()),
                                          Positioned(
                                              top: 30,
                                              left: 130,
                                              child: Container(
                                                  height: 40,
                                                  width: 40,
                                                  decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20)),
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    style: const ButtonStyle(
                                                        shape: WidgetStatePropertyAll(
                                                            RoundedRectangleBorder())),
                                                    icon: const Icon(Pelaicons
                                                        .downArrow1Bold),
                                                    onPressed: () {
                                                      if (scene == 3) {
                                                        switchSecondaryScene(
                                                            true);
                                                      } else {
                                                        switchSecondaryScene(
                                                            false);
                                                      }
                                                    },
                                                  )))
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                        top: 30,
                                        left: 30,
                                        child: Container(
                                            height: 40,
                                            width: 40,
                                            decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              style: const ButtonStyle(
                                                  shape: WidgetStatePropertyAll(
                                                      RoundedRectangleBorder())),
                                              icon: const Icon(
                                                  Pelaicons.homeBold),
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                            ))),
                                    scene > 2
                                        ? Positioned(
                                            top: 30,
                                            left: 80,
                                            child: Container(
                                                height: 40,
                                                width: 40,
                                                decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20)),
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  style: const ButtonStyle(
                                                      shape: WidgetStatePropertyAll(
                                                          RoundedRectangleBorder())),
                                                  icon: const Icon(Icons.undo),
                                                  onPressed: () {
                                                    switchScene(false);
                                                  },
                                                )))
                                        : const SizedBox.shrink()
                                  ]);
                                })))))));
  }
}
