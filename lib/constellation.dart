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

  final FocusNode _focusNode = FocusNode();
  final GlobalKey<fleather.EditorState> _editorKey = GlobalKey();
  fleather.FleatherController? _editorController;

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
    _editorController = fleather.FleatherController();

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

    constellationDashboardSceneOffset = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, -1.5), // slide up off screen
    ).animate(CurvedAnimation(
      parent: _sceneController,
      curve: Curves.easeInOut,
    ));

    addNodeSceneOffset = Tween<Offset>(
      begin: Offset(0, 1.4), // start below
      end: Offset(0, 0), // end at center
    ).animate(CurvedAnimation(
      parent: _sceneController,
      curve: Curves.easeInOut,
    ));

    addNodeSceneControllerOffset = Tween<Offset>(
      begin: Offset(0, -2), // start below
      end: Offset(0, 0), // end at center
    ).animate(CurvedAnimation(
      parent: _sceneController,
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

    connectionList = [
      newConnection(list: [
        ProtoSecondaryNode(
            controller: TextEditingController(),
            modifierController: TextEditingController(text: "")),
        ProtoSecondaryNode(
            controller: TextEditingController(),
            modifierController: TextEditingController(text: ""))
      ])
    ];

    _asyncLoadDB();
    setState(() {});
  }

  @override
  void dispose() {
    _controller1.dispose();
    search.dispose();
    // _editorFocusNode.dispose();
    super.dispose();
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

      constellation = await getConstellation(constellationID);

      print(constellation.toString());

      setState(() {
        nodeList = queryResultsList;
        nodeMap = {for (Node n in queryResultsList) n.id: n};

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

  Future<Constellation> getConstellation(int id) async {
    // Get a reference to the database.
    Database db = await database;

    // Query the table for all the files.
    final List<Map<String, Object?>> constellationMaps =
        await db.query('constellations', where: 'id = ?', whereArgs: [id]);
    print(constellationMaps);
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

  Color primary1 = const Color.fromARGB(255, 108, 99, 255);
  Color primary2 = const Color.fromARGB(255, 63, 61, 86);
  Color primary3 = const Color.fromARGB(255, 255, 101, 132);
  Color selectedColor = const Color.fromARGB(127, 255, 255, 255);

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
        mainNode:
            ProtoMainNode(controller: TextEditingController(text: mainNode)),
        secondaryNodeList: [
          ProtoSecondaryNode(
              controller: TextEditingController(),
              modifierController: TextEditingController(text: modifier))
        ],
      );
    } else {
      return Connection(
        mainNode:
            ProtoMainNode(controller: TextEditingController(text: mainNode)),
        secondaryNodeList: list,
      );
    }
  }

  void addConnection(
      {int index = -1, String mainNode = "", String modifier = ""}) {
    setState(() {
      if (index > -1) {
        connectionList.insert(
            index + 1, newConnection(mainNode: mainNode, modifier: modifier));
      } else {
        connectionList
            .add(newConnection(mainNode: mainNode, modifier: modifier));
      }
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

  void _onPlusPressed() {
    _sceneColorController.forward(from: 0);
    setState(() {
      scene = 1;
    });
    _sceneController.forward(); // animate transition
  }

  void _onBackPressed() {
    _sceneColorController.forward(from: 0);
    _sceneController.reverse().then((_) {
      setState(() {
        scene = 0;
      });
    });
  }

  int scene = 0;
  late AnimationController _sceneController;
  late Animation<Offset> constellationDashboardSceneOffset;
  late Animation<Offset> addNodeSceneOffset;
  late Animation<Offset> addNodeSceneControllerOffset;
  late AnimationController _sceneColorController;
  late Animation<Color?> _borderColor;
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
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        width: 180,
        height: 50,
        child: TextField(
          style: TextStyle(fontSize: 14),
          controller: controller,
          cursorColor: Colors.black,
          decoration: InputDecoration(
            hintText: "Modifier",
            hintStyle: TextStyle(
                fontSize: 14,
                color: const Color.fromARGB(255, 193, 193, 193),
                fontWeight: FontWeight.bold),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ));
  }

  Widget nodeTypeWidget(TextEditingController controller,
      {String? type, bool selected = false}) {
    Widget nodeTypeSelect = TextField(
      controller: controller,
      cursorColor: Colors.black,
      maxLines: null, // 👈 Allow unlimited lines
      expands: false, // 👈 Don't force fill parent
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        hintText: "Node Term",
        hintStyle: TextStyle(
            color: const Color.fromARGB(255, 193, 193, 193),
            fontWeight: FontWeight.bold),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
    return Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        width: 240,
        constraints: BoxConstraints(minHeight: 100),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(padding: EdgeInsets.all(18), child: nodeTypeSelect),
            Positioned(top: 5, right: 5, child: Icon(Pelaicons.textBold))
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
              modifierController: TextEditingController(text: modifier)));
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
            margin: EdgeInsets.only(bottom: 20),
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
                    child: nodeTypeWidget(p.controller, selected: selected)),
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
              if (currentMainProtoNode != index) {
                currentMainProtoNode = index;
              } else {
                currentMainProtoNode = -1;
              }
              currentSecondaryProtoNode = -1;
              print("test");
              outerClicked = false;
            }
          });
        },
        child: Container(
            margin: EdgeInsets.only(bottom: 20),
            padding: EdgeInsets.only(top: 20, left: 20, right: 20),
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
                        child: nodeTypeWidget(c.mainNode.controller))
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
                    IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.add),
                        color: Colors.white,
                        constraints: BoxConstraints(
                          minWidth: 80,
                        ),
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
                                                            fontSize: 20,
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
                SizedBox(height: 10),
                Expanded(
                  child: Container(
                      decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          borderRadius: BorderRadius.circular(20)),
                      width: 300,
                      padding: EdgeInsets.all(18),
                      child: SingleChildScrollView(
                        child: Column(children: [
                          Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(10),
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
                                  Spacer(),
                                  Container(
                                      padding: EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                          color: Color.fromARGB(41, 63, 61, 86),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Icon(
                                        Pelaicons.penBold,
                                        color: primary2,
                                      ))
                                ],
                              )),
                          Divider(color: Colors.white),
                          Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      const Color.fromARGB(255, 248, 248, 248),
                                  borderRadius: BorderRadius.circular(5)),
                              child: Text(
                                firstSentence,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: const Color.fromARGB(255, 0, 0, 0)),
                              )),
                          Divider(color: Colors.white),
                          Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      const Color.fromARGB(255, 248, 248, 248),
                                  borderRadius: BorderRadius.circular(5)),
                              child: Text(
                                rest,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: const Color.fromARGB(255, 0, 0, 0)),
                              )),
                        ]),
                      )),
                )
              ]))
        ]);
  }

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
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                            child: Center(
                                child: LoadingAnimationWidget.halfTriangleDot(
                                    color: primary2, size: 50))))
                    : Scaffold(
                        body: LayoutBuilder(builder: (context, constraints) {
                        return Stack(alignment: Alignment.center, children: [
                          SingleChildScrollView(
                              controller: mainScrollController,
                              scrollDirection: Axis.vertical,
                              child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints
                                        .maxHeight, // 👈 Fill full height
                                  ),
                                  child: AnimatedBuilder(
                                      animation: _sceneColorController,
                                      builder: (_, __) => Container(
                                          padding: EdgeInsets.all(20),
                                          decoration: const BoxDecoration(
                                            color: Color.fromARGB(255, 218, 218,
                                                234), // Background color
                                          ),
                                          child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color: _borderColor.value ??
                                                        Colors.black),
                                              ),
                                              child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Stack(
                                                      alignment:
                                                          Alignment.center,
                                                      children: [
                                                        editingMode
                                                            ?

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Submission Dashboard
// -------------------------------------------------------------------------------------------------------------------------------------

                                                            Container(
                                                                padding:
                                                                    EdgeInsets
                                                                        .all(
                                                                            20),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: const Color
                                                                      .fromARGB(
                                                                      255,
                                                                      218,
                                                                      218,
                                                                      234),
                                                                ),
                                                                child:
                                                                    sceneController(
                                                                        context),
                                                              )
                                                            :
// -------------------------------------------------------------------------------------------------------------------------------------
// Node Flashcard Mode
// -------------------------------------------------------------------------------------------------------------------------------------

                                                            Expanded(
                                                                //if main node does not have any auxiliary nodes
                                                                child:
                                                                    Container(
                                                                        padding: EdgeInsets.all(
                                                                            20),
                                                                        alignment: Alignment
                                                                            .bottomCenter,
                                                                        decoration: BoxDecoration(
                                                                            color:
                                                                                backgroundColor),
                                                                        child: Column(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.center,
                                                                            children: [
                                                                              nodeMap[focusedNode.id] == null
                                                                                  ? MouseRegion(
                                                                                      onEnter: (details) => setState(() => mainNodeHover = true),
                                                                                      onExit: (details) => setState(() {
                                                                                            mainNodeHover = false;
                                                                                          }),
                                                                                      child: Stack(alignment: Alignment.center, children: [
                                                                                        Container(
                                                                                          margin: const EdgeInsets.only(bottom: 50),
                                                                                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                                                            Container(
                                                                                                constraints: const BoxConstraints(maxWidth: 500, minHeight: 200),
                                                                                                alignment: Alignment.center,
                                                                                                padding: EdgeInsets.symmetric(horizontal: 10),
                                                                                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(width: 1, color: Colors.black), color: Colors.white),
                                                                                                child: focusedNode.type == 1
                                                                                                    ? ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.file(File(focusedNode.text)))
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
                                                                                                onPointerSignal: (event) {
                                                                                                  if (event is PointerScrollEvent) {
                                                                                                    setState(() {
                                                                                                      angle += event.scrollDelta.dy * -0.01; // scroll up = rotate clockwise
                                                                                                    });
                                                                                                  }
                                                                                                },
                                                                                                child: Container(
                                                                                                    decoration: BoxDecoration(border: Border.all(width: 1, color: Colors.black)),
                                                                                                    width: 500,
                                                                                                    height: 500,
                                                                                                    child: LayoutBuilder(
                                                                                                      builder: (context, constraints) {
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
                                                                                  : Stack(alignment: Alignment.centerLeft, children: [
                                                                                      SizedBox(
                                                                                          width: double.infinity,
                                                                                          child: AnimatedAlign(
                                                                                              duration: Duration(milliseconds: 400),
                                                                                              curve: Curves.easeInOut,
                                                                                              alignment: Alignment.center,
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
                                                                                                      child: SizedBox(
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
                                                                                                  ])))),
                                                                                    ])
                                                                            ]))),
                                                      ]))))))),
                          Positioned(
                              top: 30,
                              child: SlideTransition(
                                position: addNodeSceneControllerOffset,
                                child: addNodeSceneController(),
                              )),
                          Positioned(
                              top: 20,
                              left: 20,
                              child: Container(
                                  // decoration: BoxDecoration(
                                  //   borderRadius: BorderRadius.circular(10),
                                  //   border:
                                  //       Border.all(width: 1, color: Colors.black),
                                  // ),
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
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
                                            icon: Icon(
                                                size: 24,
                                                scene == 1
                                                    ? Icons.arrow_upward_rounded
                                                    : Icons.arrow_left_rounded),
                                            onPressed: () {
                                              if (scene == 0) {
                                                Navigator.pop(context);
                                              } else if (scene == 1) {
                                                mainScrollController.animateTo(
                                                  0, // Scroll to top (offset 0)
                                                  duration: Duration(
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
                        ]);
                      })))));
  }
}
