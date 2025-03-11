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
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:collection/collection.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class Node {
  final int id;
  String nodeTerm;
  List<String> auxiliaries;
  String color;
  final int image;
  final String createDate;
  String updateDate;

  Node(
      {required this.id,
      required this.nodeTerm,
      required this.auxiliaries,
      required this.color,
      required this.image,
      required this.createDate,
      required this.updateDate});
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nodeTerm': nodeTerm,
      'auxiliaries': jsonEncode(auxiliaries),
      'color': color,
      'image': image,
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
  List<String> validSearch = [];
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
  Map<String, Node> nodeMap = {};

  //bool for editing mode
  bool editingMode = true;
  bool editingModeCurrentNode = false;
  bool editingModeTextUpload = true;

  //main node with default set
  Node mainNode = Node(
      id: -1,
      nodeTerm: "",
      auxiliaries: [],
      color: Colors.black.toString(),
      image: 0,
      updateDate: DateTime.now().toString(),
      createDate: DateTime.now().toString());

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

  //Auxilary node input TextEditingController list
  List<TextEditingController> auxiliaryNodeTextControllerList = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController()
  ];

  List<bool> auxiliaryNodeSelectedList = [false, false, false];
  List<String> auxiliaryNodePriorEditList = [];
  Node editingNode = Node(
      id: 0,
      nodeTerm: "",
      auxiliaries: [],
      color: "",
      image: 0,
      createDate: "",
      updateDate: "");

  //Int index for selected auxiliary node input
  int selectedAuxiliaryNodeInput = -1;

  ScrollController addNodeController = ScrollController();

  //display loading screen boolean
  bool loading = true;

  bool _loadingVisible = false;

  Color backgroundColor = const Color.fromRGBO(252, 231, 200, 1);
  Color primary1 = const Color.fromRGBO(177, 194, 158, 1);
  Color primary2 = const Color.fromRGBO(250, 218, 122, 1);
  Color primary3 = const Color.fromRGBO(240, 160, 75, 1);

  // Color backgroundColor = const Color.fromARGB(255, 78, 62, 110);
  // Color primary1 = const Color.fromRGBO(137, 103, 179, 1);
  // Color primary2 = const Color.fromRGBO(203, 128, 171, 1);
  // Color primary3 = const Color.fromRGBO(238, 165, 166, 1);

  ScrollController bottomDisplayScrollController1 = ScrollController();
  ScrollController bottomDisplayScrollController2 = ScrollController();

  var database;

  double suggestionHeight = 100;
  @override
  void initState() {
    constellationID = widget.id;
    constellationName = widget.constellationName;
    nodeMasteryColorMap = {
      "New": nodeMasteryColorDefault,
      "Know Well": nodeMasteryColorKnown,
      "Need to Practice": nodeMasteryColorPractice,
      "Difficult": nodeMasteryColorDifficult,
      "Just Learned": nodeMasteryColorLearned
    };
    print("---------------------");

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
      Path.join(await getDatabasesPath(), 'lynklynk_node_database.db'),
      // When the database is first created, create a table to store files.

      onUpgrade: _onUpgrade,
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 2,
    );

    try {
      List<Node> queryResultsList = await getNodeList();
      if (queryResultsList.isNotEmpty) {
        editingMode = false;
        mainNode = queryResultsList[0];
      }

      print(queryResultsList.map((e) => e.id).toList());
      setState(() {
        nodeList = queryResultsList;
        nodeMap = <String, Node>{
          for (Node n in queryResultsList) n.nodeTerm: n
        };
        loading = false;
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
            'image': image as int,
            'createDate': createDate as String,
            'updateDate': updateDate as String,
          } in fileMaps)
        Node(
          id: id,
          nodeTerm: nodeTerm,
          auxiliaries: json.decode(auxiliaries).cast<String>().toList(),
          color: color,
          image: image,
          createDate: createDate,
          updateDate: updateDate,
        )
    ];
  }

  Future<void> insertNode(Node node) async {
    final db = await database;
    print(constellationName);
    await db.insert(
      '"${constellationName}_$constellationID"',
      node.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNode(Node node) async {
    // Get a reference to the database.
    final db = await database;

    // Update the given Dfile.
    await db.update(
      '"${constellationName}_$constellationID"',
      node.toMap(),
      // Ensure that the file has a matching id.
      where: 'id = ?',
      // Pass the file's id as a whereArg to prevent SQL injection.
      whereArgs: [node.id],
    );

    updateNodes();
  }

  Future<void> deleteNode(Node node) async {
    // Get a reference to the database.
    final db = await database;

    // Remove the file from the database.
    await db.delete(
      '"${constellationName}_$constellationID"',
      // Use a `where` clause to delete a specific file.
      where: 'nodeTerm = ?',
      // Pass the file's id as a whereArg to prevent SQL injection.
      whereArgs: [node.nodeTerm],
    );

    updateNodes();
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) {
    if (oldVersion < 2) {
      // db.execute(
      //     "ALTER TABLE files ADD COLUMN starred INTEGER NOT NULL DEFAULT (0);");
    }
  }

  Future<void> updateNodes() async {
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

  void formatMainNodeText() {
    List<String> listText = mainNodeTextController.text.split('\n');
    listText.removeWhere((e) => e.trim().isEmpty);
    setState(() {
      mainNodeTextController.text = listText[0];
    });
    int insertIndex = 0;
    for (int i = 1; i < listText.length; i++) {
      if (insertIndex < auxiliaryNodeTextControllerList.length &&
          auxiliaryNodeTextControllerList[insertIndex].text.isEmpty) {
        auxiliaryNodeTextControllerList[insertIndex].text = listText[i];
      } else {
        auxiliaryNodeTextControllerList.insert(
            insertIndex, TextEditingController(text: listText[i]));
        auxiliaryNodeSelectedList.insert(insertIndex, false);
      }
      insertIndex++;
    }
    print(listText);
  }

  Widget proxyDecorator(Widget child, int index, Animation<double> animation) {
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
          child: auxiliaryNodeInput(index),
        );
      },
      child: child,
    );
  }

  Widget auxiliaryNodeInput(int index) {
    TextEditingController controller = auxiliaryNodeTextControllerList[index];
    return Container(
        key: UniqueKey(),
        child: Container(
            margin: EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Container(
                    child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                      size: 10,
                      auxiliaryNodeSelectedList[index]
                          ? Icons.circle
                          : Icons.circle_outlined),
                  onPressed: () {
                    setState(() {
                      auxiliaryNodeSelectedList[index] =
                          !auxiliaryNodeSelectedList[index];
                    });
                  },
                )),
                Expanded(
                  child: Card(
                      // decoration: BoxDecoration(
                      //     border: Border.all(width: 1, color: Colors.black)),
                      child: Row(children: [
                    Expanded(
                        child: Container(
                            padding: EdgeInsets.only(right: 18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.multiline,
                              maxLines: null,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.all(10.0),
                              ),
                            )))
                  ])),
                )
              ],
            )));
  }

  void removeAuxiliaryNodeInput() {
    List<TextEditingController> controllerListTemp =
        auxiliaryNodeTextControllerList;
    List<bool> boolListTemp = auxiliaryNodeSelectedList;
    for (int i = 0; i < boolListTemp.length; i++) {
      if (boolListTemp[i]) {
        boolListTemp.removeAt(i);
        controllerListTemp.removeAt(i);
        i--;
      }
    }
    setState(() {
      auxiliaryNodeSelectedList = boolListTemp;
      auxiliaryNodeTextControllerList = controllerListTemp;
    });
  }

  void resetSubmission() {
    setState(() {
      mainNodeTextController.text = "";
      auxiliaryNodeTextControllerList = [
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ];
      auxiliaryNodeSelectedList = [false, false, false];
    });
  }

  void createNode() {
    // final int id;
    // String nodeTerm;
    // List<String> auxiliaries;
    // String color;
    // final String createDate;
    // String updateDate;

    String nodeTerm = mainNodeTextController.text;
    if (nodeTerm.isEmpty) {
      print("Term cannot be empty");
      return;
    }
    Set<String> auxiliaries =
        auxiliaryNodeTextControllerList.map((e) => e.text).toList().toSet();
    auxiliaries.removeWhere((e) => e.isEmpty);
    auxiliaries.removeWhere((e) => e == nodeTerm);
    print("1");
    if (nodeMap[nodeTerm] != null) {
      //term already exists - update
      print("already exists");
      Node currentNode = nodeMap[nodeTerm]!;
      Set<String> currentNodeAux = currentNode.auxiliaries.toSet();
      currentNode.updateDate = DateTime.now().toString();
      currentNode.auxiliaries = currentNodeAux.union(auxiliaries).toList();
      setState(() {
        nodeMap[nodeTerm] = currentNode;
      });
      updateNode(currentNode);
    } else {
      print("does not already exists");
      //term does not exist - create
      String color = Color.fromARGB(255, 224, 224, 224).toString();
      String createDate = DateTime.now().toString();
      String updateDate = DateTime.now().toString();

      Node newNode = Node(
          id: nodeList.isEmpty ? 1 : nodeList[nodeList.length - 1].id + 1,
          nodeTerm: nodeTerm,
          auxiliaries: auxiliaries.toList(),
          color: color,
          image: 0,
          createDate: createDate,
          updateDate: updateDate);
      insertNode(newNode);

      setState(() {
        addNodeLocally(newNode);
        mainNode = newNode;
      });
    }

    //add auxiliaries
    createAuxiliaries(auxiliaries, nodeTerm);
    setState(() {
      editingMode = !editingMode;
    });
  }

  void addNodeLocally(Node newNode) {
    nodeList.add(newNode);
    nodeMap[newNode.nodeTerm] = newNode;
  }

  List<Node> nodeSearchSuggestion(TextEditingController controller,
      {bool matchCase = false, bool matchStart = true}) {
    if (controller.text.isEmpty) {
      return [];
    }

    if (!matchCase) {
      return nodeList
          .where((e) => e.nodeTerm.startsWith(controller.text))
          .toList();
    } else {
      return nodeList
          .where((e) => e.nodeTerm.startsWith(controller.text))
          .toList();
    }
  }

  void createAuxiliaries(Set<String> auxiliaries, String mainNode) {
    for (int i = 0; i < auxiliaries.length; i++) {
      String auxTerm = auxiliaries.elementAt(i);

      // node already exists
      if (nodeMap.containsKey(auxTerm)) {
        nodeMap[auxTerm]?.auxiliaries.add(mainNode);
      }
      // node does not already exist
      else {
        Node newNode = Node(
            id: nodeList[nodeList.length - 1].id + 1,
            nodeTerm: auxTerm,
            auxiliaries: [mainNode],
            color: Color.fromARGB(255, 224, 224, 224).toString(),
            image: 0,
            createDate: DateTime.now().toString(),
            updateDate: DateTime.now().toString());
        insertNode(newNode);
        setState(() {
          addNodeLocally(newNode);
        });
      }
    }
  }

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Edit Functions
// 1. updateNodeTerm: updates a node (and any relevant auxiliaries) with a new node term
// 2. removeAuxiliaries: disconnects a node from its auxiliaries
// 3. editNode: wrapper functions that uses all the above functions to update a node to its most recently edited version
// -------------------------------------------------------------------------------------------------------------------------------------

  Node updateNodeTerm(Node node, String newNodeTerm) {
    Node newNode = Node(
        id: node.id,
        nodeTerm: newNodeTerm,
        auxiliaries: node.auxiliaries,
        color: node.color,
        image: 0,
        createDate: node.createDate,
        updateDate: node.updateDate);

    //Update node locally
    nodeList[node.id - 1] = newNode;
    nodeMap[node.nodeTerm] = newNode;

    updateNode(newNode);

    for (int i = 0; i < node.auxiliaries.length; i++) {
      Node auxiliaryNode = nodeMap[node.auxiliaries[i]]!;
      auxiliaryNode
              .auxiliaries[auxiliaryNode.auxiliaries.indexOf(node.nodeTerm)] =
          newNodeTerm;
      nodeList[auxiliaryNode.id - 1] = auxiliaryNode;
      nodeMap[auxiliaryNode.nodeTerm] = auxiliaryNode;
      updateNode(auxiliaryNode);
    }

    return newNode;
  }

  void removeAuxiliaries(Set<String> auxiliariesToRemove, String nodeTerm) {
    for (int i = 0; i < auxiliariesToRemove.length; i++) {
      String auxiliary = auxiliariesToRemove.elementAt(i);

      Node auxiliaryNode = nodeMap[auxiliary]!;
      auxiliaryNode.auxiliaries.removeWhere((e) => e == nodeTerm);
      nodeList[auxiliaryNode.id - 1] = auxiliaryNode;
      nodeMap[auxiliaryNode.nodeTerm] = auxiliaryNode;
      updateNode(auxiliaryNode);
    }
  }

  void editNode() {
    Node updatedNode = editingNode;
    if (mainNodeTextController.text != editingNode.nodeTerm) {
      updatedNode = updateNodeTerm(editingNode, mainNodeTextController.text);
      print(mainNodeTextController.text);
    }
    List<String> auxiliaryControllerTextList =
        auxiliaryNodeTextControllerList.map((e) => e.text).toList();
    List<String> currentAuxiliaryList = updatedNode.auxiliaries;

    Set<String> currentSet = currentAuxiliaryList.toSet();
    Set<String> updateSet = auxiliaryControllerTextList.toSet();

    Set<String> auxiliaryUnion = updateSet.intersection(currentSet);

    Set<String> auxiliaryToAdd = updateSet.difference(auxiliaryUnion);
    Set<String> auxiliaryToRemove = currentSet.difference(auxiliaryUnion);

    updatedNode.auxiliaries = auxiliaryControllerTextList;
    createAuxiliaries(auxiliaryToAdd, mainNodeTextController.text);
    removeAuxiliaries(auxiliaryToRemove, mainNodeTextController.text);

    setState(() {
      updateNode(updatedNode);
      nodeList[updatedNode.id - 1] = updatedNode;
      nodeMap[updatedNode.nodeTerm] = updatedNode;
      mainNode = updatedNode;
    });
  }

// -------------------------------------------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Mastery Color Functions
// 1. compareColor: compare two colors
// 2. colorFromString: get the Color from a color string
// 3. getNodeMasteryText: get the text for the respective node mastery color
// -------------------------------------------------------------------------------------------------------------------------------------

  bool compareColor(Color color1, Color color2) {
    return color1.value == color2.value;
  }

  Color colorFromString(String color) {
    return Color(int.parse(color.split('(0x')[1].split(')')[0], radix: 16));
  }

  String getNodeMasteryText(Color nodeColor) {
    if (compareColor(nodeMasteryColorDifficult, nodeColor)) {
      return "Difficult";
    } else if (compareColor(nodeMasteryColorPractice, nodeColor)) {
      return "Need to Practice";
    } else if (compareColor(nodeMasteryColorLearned, nodeColor)) {
      return "Just Learned";
    } else if (compareColor(nodeMasteryColorKnown, nodeColor)) {
      return "Know Well";
    } else {
      return "New";
    }
  }

  Widget nodeMasterySelectButton() {
    final List<String> dropDownList = nodeMasteryColorMap.keys.toList();
    String mainNodeMasteryText =
        getNodeMasteryText(colorFromString(mainNode.color));

    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        customButton: Container(
            width: 150,
            padding: EdgeInsets.only(
                right: max(0, 90 - mainNodeMasteryText.length * 6)),
            child: Container(
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  border: Border.all(width: 1, color: Colors.black),
                  borderRadius: BorderRadius.circular(20),
                ),
                width: 50 + mainNodeMasteryText.length * 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      color: colorFromString(mainNode.color),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(mainNodeMasteryText,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ))),
        items: dropDownList
            .map((String item) => DropdownMenuItem<String>(
                value: item,
                child: Container(
                    child: Row(children: [
                  Icon(Icons.circle, color: nodeMasteryColorMap[item]),
                  const SizedBox(width: 10),
                  Text(
                    item,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ]))))
            .toList(),
        value: mainNodeMasteryText,
        onChanged: (String? value) {
          setState(() {
            mainNode.color = nodeMasteryColorMap[value].toString();
            nodeList[mainNode.id] = mainNode;
            nodeMap[mainNode.nodeTerm] = mainNode;
          });
          updateNode(mainNode);
        },
        buttonStyleData: const ButtonStyleData(
          padding: EdgeInsets.symmetric(horizontal: 10),
          height: 40,
          width: 160,
        ),
        menuItemStyleData: const MenuItemStyleData(
          padding: EdgeInsets.symmetric(horizontal: 8),
          height: 40,
        ),
      ),
    );
  }

// -------------------------------------------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------------------------------------------

  Widget auxiliaryDisplayProxyDecorator(
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
          child: auxiliaryDisplay(mainNode.auxiliaries[index]),
        );
      },
      child: child,
    );
  }

  Widget auxiliaryDisplay(String term) {
    return Container(
        key: UniqueKey(),
        child: Row(
          children: [
            Expanded(
                child: GestureDetector(
                    onDoubleTap: () {
                      setState(() {
                        mainNode = nodeMap[term]!;
                      });
                    },
                    child: Card(
                        shape: ContinuousRectangleBorder(),
                        color: Colors.white,
                        child: Container(
                            decoration: BoxDecoration(
                                border: Border(
                                    left: BorderSide(
                                        width: 5,
                                        color: colorFromString(
                                            nodeMap[term]!.color)))),
                            margin: EdgeInsets.only(right: 20),
                            padding: EdgeInsets.all(10),
                            child: Text(term)))))
          ],
        ));
  }

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Submission Component
// -------------------------------------------------------------------------------------------------------------------------------------

  Widget constellationSubmissionComponent() {
    return Expanded(
        child: Container(
            decoration: BoxDecoration(color: backgroundColor),
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              controller: addNodeController,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                        height: 20,
                        decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(width: 1, color: Colors.black),
                                left: BorderSide(width: 1, color: Colors.black),
                                right:
                                    BorderSide(width: 1, color: Colors.black))),
                        child: TextButton(
                            style: ButtonStyle(
                                padding:
                                    WidgetStatePropertyAll(EdgeInsets.all(2)),
                                backgroundColor: WidgetStatePropertyAll(
                                    editingModeTextUpload
                                        ? Colors.blue
                                        : Colors.blue.shade800),
                                shape: WidgetStatePropertyAll(
                                    ContinuousRectangleBorder())),
                            onPressed: () {
                              setState(() {
                                editingModeTextUpload = true;
                              });
                            },
                            child: const Text("Text",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)))),
                    Container(
                        height: 20,
                        decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(width: 1, color: Colors.black),
                                right:
                                    BorderSide(width: 1, color: Colors.black))),
                        child: TextButton(
                            style: ButtonStyle(
                                padding:
                                    WidgetStatePropertyAll(EdgeInsets.all(2)),
                                backgroundColor: WidgetStatePropertyAll(
                                    !editingModeTextUpload
                                        ? Colors.blue
                                        : Colors.blue.shade800),
                                shape: WidgetStatePropertyAll(
                                    ContinuousRectangleBorder())),
                            onPressed: () {
                              setState(() {
                                editingModeTextUpload = false;
                              });
                            },
                            child: const Text("Image",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)))),
                    Spacer(),
                    editingModeCurrentNode
                        ? TextButton(
                            onPressed: () {
                              editNode();
                              editingMode = false;
                            },
                            child: Text("Update Constellation"))
                        : TextButton(
                            onPressed: () {
                              createNode();
                            },
                            child: Text("Create Constellation"))
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                  decoration: const BoxDecoration(
                      color: Colors.blue,
                      border: Border(
                          left: BorderSide(width: 1, color: Colors.black),
                          right: BorderSide(width: 1, color: Colors.black),
                          top: BorderSide(width: 1, color: Colors.black))),
                  child: Row(
                    children: [
                      const Text(
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                          "Main Node"),
                      Spacer(),
                      IconButton(
                          onPressed: () {
                            resetSubmission();
                          },
                          icon: Icon(Icons.undo)),
                    ],
                  ),
                ),
                Container(
                  child: Row(
                    children: [
                      Expanded(
                          child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border:
                                    Border.all(width: 1, color: Colors.black),
                              ),
                              child: editingModeTextUpload
                                  ? TextField(
                                      controller: mainNodeTextController,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Ex: The Senate under the Roman Empire',
                                        contentPadding: EdgeInsets.all(10.0),
                                      ),
                                      minLines: 8,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.next,
                                      maxLines: 8,
                                    )
                                  : Container(
                                      child: IconButton(
                                          onPressed: () async {
                                            FilePickerResult? fileUploadResult =
                                                await FilePicker.platform
                                                    .pickFiles(
                                              allowedExtensions: [
                                                'jpg',
                                                'png',
                                              ],
                                            );
                                            Directory appDocDir =
                                                await getApplicationDocumentsDirectory();
                                            String appDocPath = appDocDir.path;
                                            Directory directory = await Directory(
                                                    '$appDocPath/LynkLynkApp/images/${constellationName}_$constellationID')
                                                .create(recursive: true);

                                            if (fileUploadResult == null) {
                                              return;
                                            }
                                          },
                                          icon: Icon(Icons.add))))),
                    ],
                  ),
                ),
                Container(
                    margin: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        border: Border.all(width: 1, color: Colors.black)),
                    padding: EdgeInsets.all(10),
                    child: IconButton(
                        onPressed: () {
                          formatMainNodeText();
                        },
                        icon: Icon(Icons.rebase_edit))),
                SizedBox(height: 10),
                Row(children: [
                  Text(style: TextStyle(fontSize: 18), "Auxiliary Nodes"),
                  Spacer(),
                  Container(
                      height: 30,
                      width: 30,
                      child:
                          auxiliaryNodeSelectedList.where((e) => e).isNotEmpty
                              ? IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    removeAuxiliaryNodeInput();
                                  },
                                  icon: Icon(Icons.delete))
                              : SizedBox())
                ]),
                SizedBox(height: 5),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 10),
                  proxyDecorator: proxyDecorator,
                  onReorder: (int oldIndex, int newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final TextEditingController item =
                          auxiliaryNodeTextControllerList.removeAt(oldIndex);
                      final bool item1 =
                          auxiliaryNodeSelectedList.removeAt(oldIndex);

                      auxiliaryNodeTextControllerList.insert(newIndex, item);
                      auxiliaryNodeSelectedList.insert(newIndex, item1);
                      selectedAuxiliaryNodeInput = newIndex;
                    });
                  },
                  children: auxiliaryNodeTextControllerList
                      .asMap()
                      .map((i, e) => MapEntry(i, auxiliaryNodeInput(i)))
                      .values
                      .toList(),
                ),
                IconButton(
                  style: const ButtonStyle(
                      shape:
                          WidgetStatePropertyAll(ContinuousRectangleBorder())),
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      auxiliaryNodeTextControllerList
                          .add(TextEditingController());
                      auxiliaryNodeSelectedList.add(false);
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],
            )));
  }

  Widget bottomScrollDisplay(
      BuildContext context, ScrollController controller) {
    bool screenWidthLarger = MediaQuery.sizeOf(context).width > 820;
    int numRow = screenWidthLarger ? 4 : 3;

    List<Node> nodeListSlice = [];
    List<int> nodeTrack = [];

    if (nodeList.length <= 36) {
      nodeListSlice = nodeList;
      nodeTrack = List.filled(nodeList.length, 1);
    } else {
      int row = (mainNode.id - 1) ~/ numRow;

      int startIndex = (row - (screenWidthLarger ? 4 : 5)) * numRow;
      int endIndex = (row + (screenWidthLarger ? 4 : 6)) * numRow;

      for (int i = startIndex; i < endIndex; i++) {
        nodeListSlice.add(nodeList[i % nodeList.length]);
        if (i < 0 || i >= nodeList.length) {
          nodeTrack.add(-1);
        } else {
          nodeTrack.add(1);
        }
      }
    }

    return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: screenWidthLarger ? 4 : 3,
          childAspectRatio: 1.0,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          mainAxisExtent: 120,
        ),
        itemCount: nodeListSlice.length,
        shrinkWrap: true,
        controller: bottomDisplayScrollController1,
        itemBuilder: (BuildContext context, int index) {
          return Stack(children: [
            GestureDetector(
                onTap: () {
                  setState(() {
                    if (nodeTrack[index] == 0) return;
                    mainNode = nodeListSlice[index];
                    if (nodeListSlice.length >= 36) {
                      bottomDisplayScrollController1.animateTo(
                        MediaQuery.sizeOf(context).width > 820 ? 540 : 660,
                        duration: Duration(seconds: 1),
                        curve: Curves.fastOutSlowIn,
                      );
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: const Color.fromARGB(255, 255, 255, 255),
                      border: Border.all(
                          width: nodeListSlice[index].id == mainNode.id ? 3 : 1,
                          color: Colors.black)),
                  padding: EdgeInsets.all(10),
                  child: Center(
                      child: Text(nodeListSlice[index].nodeTerm,
                          style: TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2)),
                )),
            nodeTrack[index] >= 0
                ? SizedBox()
                : Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: Color.fromARGB(80, 0, 0, 0)),
                  ),
          ]);
        });
  }

  void setBottomDisplayScrollPosition() {
    setState(() {
      bottomDisplayScrollController1 = ScrollController(
          initialScrollOffset:
              MediaQuery.sizeOf(context).width > 820 ? 540 : 660);
    });
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

                  // shape: const Border(
                  //     bottom: BorderSide(
                  //         color: Color.fromARGB(255, 0, 0, 0), width: 1)),
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
                        padding: const EdgeInsets.only(
                            bottom: 10, right: 10, left: 10),
                        child: Container(
                            decoration: BoxDecoration(
                              border:
                                  Border.all(width: 0.8, color: Colors.black),
                            ),
                            child: Column(children: [
                              Container(
                                  decoration: BoxDecoration(
                                    color: primary1,
                                    border: const Border(
                                        bottom: BorderSide(
                                            width: 1, color: Colors.black)),
                                  ),
                                  padding: const EdgeInsets.only(
                                      left: 25, right: 25),
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
                                                width: 1),
                                          ),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            style: const ButtonStyle(
                                                shape: WidgetStatePropertyAll(
                                                    ContinuousRectangleBorder())),
                                            icon: const Icon(
                                                size: 24,
                                                Icons.arrow_left_rounded),
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
                                                    editingModeCurrentNode =
                                                        false;
                                                  }
                                                  mainNodeTextController =
                                                      TextEditingController();

                                                  auxiliaryNodeTextControllerList =
                                                      [
                                                    TextEditingController(),
                                                    TextEditingController(),
                                                    TextEditingController()
                                                  ];

                                                  auxiliaryNodeSelectedList = [
                                                    false,
                                                    false,
                                                    false
                                                  ];
                                                });
                                              },
                                              icon: Icon(
                                                  color: editingMode
                                                      ? Colors.white
                                                      : Colors.black,
                                                  size: 20,
                                                  Icons.edit))),
                                      const Spacer(),
                                      Container(
                                        margin: EdgeInsets.only(right: 5),
                                        constraints:
                                            BoxConstraints(maxWidth: 60),
                                        child: SearchAnchor(
                                            viewBackgroundColor: primary1,
                                            viewShape:
                                                const ContinuousRectangleBorder(
                                                    side: BorderSide(
                                                        width: 1,
                                                        color: Colors.black)),
                                            builder: (BuildContext context,
                                                SearchController controller) {
                                              return SearchBar(
                                                shape: const WidgetStatePropertyAll(
                                                    ContinuousRectangleBorder()),
                                                constraints:
                                                    const BoxConstraints(
                                                        maxHeight: 40),
                                                backgroundColor:
                                                    WidgetStatePropertyAll(
                                                        primary1),
                                                overlayColor:
                                                    WidgetStatePropertyAll(
                                                        primary1),
                                                surfaceTintColor:
                                                    const WidgetStatePropertyAll(
                                                        Colors.transparent),
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
                                                leading:
                                                    const Icon(Icons.search),
                                              );
                                            },
                                            suggestionsBuilder: (BuildContext
                                                    context,
                                                SearchController controller) {
                                              List<Node> suggestionList =
                                                  nodeSearchSuggestion(
                                                      controller);

                                              return suggestionList.map((e) {
                                                return Container(
                                                    child: ListTile(
                                                  tileColor: Colors.white,
                                                  title: Text(e.nodeTerm),
                                                  onTap: () {
                                                    setState(() {
                                                      mainNode = e;
                                                      controller.closeView("");
                                                    });
                                                  },
                                                ));
                                              });
                                            }),
                                      ),
                                    ],
                                  )),
                              editingMode
                                  ?

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Submission Dashboard
// -------------------------------------------------------------------------------------------------------------------------------------

                                  constellationSubmissionComponent()
                                  :
// -------------------------------------------------------------------------------------------------------------------------------------
// Node Flashcard Mode
// -------------------------------------------------------------------------------------------------------------------------------------

                                  Expanded(
                                      //if main node does not have any auxiliary nodes
                                      child: Container(
                                          padding: EdgeInsets.all(20),
                                          alignment: Alignment.bottomCenter,
                                          decoration: BoxDecoration(
                                              color: backgroundColor),
                                          child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                mainNode.auxiliaries.isEmpty
                                                    ? Expanded(
                                                        child: MouseRegion(
                                                            onEnter: (details) =>
                                                                setState(() =>
                                                                    mainNodeHover =
                                                                        true),
                                                            onExit: (details) =>
                                                                setState(() {
                                                                  mainNodeHover =
                                                                      false;
                                                                }),
                                                            child: Stack(
                                                                children: [
                                                                  (Container(
                                                                      alignment:
                                                                          Alignment
                                                                              .center,
                                                                      padding:
                                                                          EdgeInsets.all(
                                                                              40),
                                                                      decoration: BoxDecoration(
                                                                          border: Border.all(
                                                                              width:
                                                                                  1,
                                                                              color: Colors
                                                                                  .black),
                                                                          color: Colors
                                                                              .white),
                                                                      child: Text(
                                                                          style:
                                                                              TextStyle(fontSize: mainNode.nodeTerm.length > 100 ? 24 : 30),
                                                                          mainNode.nodeTerm))),
                                                                  Container(
                                                                      color: Colors
                                                                          .transparent,
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          vertical:
                                                                              8,
                                                                          horizontal:
                                                                              12),
                                                                      child:
                                                                          Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.end,
                                                                        children: [
                                                                          nodeMasterySelectButton(),
                                                                          Spacer(),
                                                                          mainNodeHover
                                                                              ? Row(children: [
                                                                                  IconButton(onPressed: () {}, icon: Icon(Icons.delete)),
                                                                                  SizedBox(width: 10),
                                                                                  IconButton(
                                                                                    icon: Icon(Icons.edit),
                                                                                    onPressed: () {
                                                                                      setState(() {
                                                                                        editingMode = true;
                                                                                        editingModeCurrentNode = true;
                                                                                        editingNode = mainNode;
                                                                                        auxiliaryNodePriorEditList = mainNode.auxiliaries;
                                                                                        mainNodeTextController = TextEditingController(text: mainNode.nodeTerm);
                                                                                        auxiliaryNodeTextControllerList = mainNode.auxiliaries.map((e) => TextEditingController(text: e)).toList();
                                                                                        auxiliaryNodeSelectedList = List.filled(auxiliaryNodeTextControllerList.length, false, growable: true);
                                                                                      });
                                                                                    },
                                                                                  )
                                                                                ])
                                                                              : SizedBox(height: 40),
                                                                        ],
                                                                      )),
                                                                ])))
                                                    : Expanded(
                                                        child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Column(children: [
                                                            Expanded(
                                                                child:
                                                                    MouseRegion(
                                                              onEnter: (details) =>
                                                                  setState(() =>
                                                                      mainNodeHover =
                                                                          true),
                                                              onExit:
                                                                  (details) =>
                                                                      setState(
                                                                          () {
                                                                mainNodeHover =
                                                                    false;
                                                              }),
                                                              child: Container(
                                                                  constraints: BoxConstraints(
                                                                      minWidth: MediaQuery.sizeOf(context).width <
                                                                              900
                                                                          ? MediaQuery.sizeOf(context).width /
                                                                              2
                                                                          : MediaQuery.sizeOf(context).width /
                                                                              2.5,
                                                                      maxWidth: MediaQuery.sizeOf(context).width <
                                                                              900
                                                                          ? MediaQuery.sizeOf(context).width /
                                                                              2
                                                                          : MediaQuery.sizeOf(context).width /
                                                                              2.5),
                                                                  padding:
                                                                      EdgeInsets
                                                                          .only(
                                                                    right: 20,
                                                                  ),
                                                                  child: Stack(
                                                                      children: [
                                                                        (
                                                                            // Main node card
                                                                            Container(
                                                                                decoration: BoxDecoration(
                                                                                  border: Border.all(width: 1, color: Colors.black),
                                                                                  color: Colors.white,
                                                                                  boxShadow: const [
                                                                                    BoxShadow(
                                                                                      color: const Color.fromARGB(255, 0, 0, 0),
                                                                                      blurRadius: 0,
                                                                                      offset: Offset(6, 6),
                                                                                      spreadRadius: 1,
                                                                                    )
                                                                                  ],
                                                                                ),
                                                                                alignment: Alignment.center,
                                                                                child: Container(padding: EdgeInsets.all(15), child: Text(mainNode.nodeTerm, style: TextStyle(fontSize: mainNode.nodeTerm.length > 100 ? 15 : 25))))),
                                                                        Container(
                                                                            color: Color.fromARGB(
                                                                                0,
                                                                                0,
                                                                                0,
                                                                                0),
                                                                            padding:
                                                                                const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                                            child: Row(
                                                                              mainAxisAlignment: MainAxisAlignment.end,
                                                                              children: [
                                                                                nodeMasterySelectButton(),
                                                                                Spacer(),
                                                                                mainNodeHover
                                                                                    ? Row(children: [
                                                                                        IconButton(onPressed: () {}, icon: Icon(Icons.delete)),
                                                                                        SizedBox(width: 10),
                                                                                        IconButton(
                                                                                          icon: Icon(Icons.edit),
                                                                                          onPressed: () {
                                                                                            setState(() {
                                                                                              editingMode = true;
                                                                                              editingModeCurrentNode = true;
                                                                                              editingNode = mainNode;
                                                                                              auxiliaryNodePriorEditList = mainNode.auxiliaries;
                                                                                              mainNodeTextController = TextEditingController(text: mainNode.nodeTerm);
                                                                                              auxiliaryNodeTextControllerList = mainNode.auxiliaries.map((e) => TextEditingController(text: e)).toList();
                                                                                              auxiliaryNodeSelectedList = List.filled(auxiliaryNodeTextControllerList.length, false, growable: true);
                                                                                            });
                                                                                          },
                                                                                        )
                                                                                      ])
                                                                                    : SizedBox(height: 40)
                                                                              ],
                                                                            )),
                                                                      ])),
                                                            ))
                                                          ]),
                                                          Expanded(
                                                              child: Container(
                                                            decoration: BoxDecoration(
                                                                border: Border.all(
                                                                    width: 1,
                                                                    color: Colors
                                                                        .black)),
                                                            padding:
                                                                EdgeInsets.only(
                                                                    left: 10,
                                                                    top: 10,
                                                                    bottom: 10),
                                                            child:
                                                                ReorderableListView(
                                                                    shrinkWrap:
                                                                        true,
                                                                    physics:
                                                                        ClampingScrollPhysics(),
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        right:
                                                                            10),
                                                                    proxyDecorator:
                                                                        auxiliaryDisplayProxyDecorator,
                                                                    onReorder: (int
                                                                            oldIndex,
                                                                        int
                                                                            newIndex) {
                                                                      setState(
                                                                          () {
                                                                        if (oldIndex <
                                                                            newIndex) {
                                                                          newIndex -=
                                                                              1;
                                                                        }

                                                                        if (oldIndex !=
                                                                            newIndex) {
                                                                          String
                                                                              term =
                                                                              mainNode.auxiliaries[oldIndex];

                                                                          mainNode.auxiliaries[oldIndex] =
                                                                              mainNode.auxiliaries[newIndex];
                                                                          mainNode.auxiliaries[newIndex] =
                                                                              term;
                                                                        }
                                                                      });
                                                                    },
                                                                    children: mainNode
                                                                        .auxiliaries
                                                                        .map((e) =>
                                                                            auxiliaryDisplay(e))
                                                                        .toList()),
                                                          ))
                                                        ],
                                                      )),
                                                SizedBox(height: 20),
                                                ExpansionTileCard(
                                                  onExpansionChanged: (value) {
                                                    setBottomDisplayScrollPosition();
                                                  },
                                                  title: Row(
                                                    children: [
                                                      Container(
                                                          decoration: BoxDecoration(
                                                              border: Border.all(
                                                                  width: 1,
                                                                  color: Colors
                                                                      .black),
                                                              shape: BoxShape
                                                                  .circle,
                                                              color:
                                                                  Colors.white),
                                                          child: IconButton(
                                                              color:
                                                                  Colors.white,
                                                              onPressed: () {
                                                                int setIndex =
                                                                    mainNode.id;
                                                                if (setIndex ==
                                                                    1) {
                                                                  setIndex =
                                                                      nodeList
                                                                          .last
                                                                          .id;
                                                                } else {
                                                                  setIndex--;
                                                                }
                                                                setState(() {
                                                                  mainNode =
                                                                      nodeList[
                                                                          setIndex -
                                                                              1];
                                                                });

                                                                if (nodeList
                                                                        .length >=
                                                                    36) {
                                                                  bottomDisplayScrollController1
                                                                      .animateTo(
                                                                    MediaQuery.sizeOf(context).width >
                                                                            820
                                                                        ? 540
                                                                        : 660,
                                                                    duration: Duration(
                                                                        seconds:
                                                                            2),
                                                                    curve: Curves
                                                                        .fastOutSlowIn,
                                                                  );
                                                                }
                                                              },
                                                              icon: const Icon(
                                                                  color: Colors
                                                                      .black,
                                                                  Icons
                                                                      .arrow_left))),
                                                      Spacer(),
                                                      Text(
                                                          "${mainNode.id}/${nodeList.length}"),
                                                      Spacer(),
                                                      Container(
                                                          decoration: BoxDecoration(
                                                              border: Border.all(
                                                                  width: 1,
                                                                  color: Colors
                                                                      .black),
                                                              shape: BoxShape
                                                                  .circle,
                                                              color:
                                                                  Colors.white),
                                                          child: IconButton(
                                                              color:
                                                                  Colors.white,
                                                              onPressed: () {
                                                                int setIndex =
                                                                    mainNode.id;
                                                                if (setIndex ==
                                                                    nodeList
                                                                        .last
                                                                        .id) {
                                                                  setIndex = 1;
                                                                } else {
                                                                  setIndex++;
                                                                }
                                                                setState(() {
                                                                  mainNode =
                                                                      nodeList[
                                                                          setIndex -
                                                                              1];
                                                                });
                                                                if (nodeList
                                                                        .length >=
                                                                    36) {
                                                                  bottomDisplayScrollController1
                                                                      .animateTo(
                                                                    MediaQuery.sizeOf(context).width >
                                                                            820
                                                                        ? 540
                                                                        : 660,
                                                                    duration: Duration(
                                                                        seconds:
                                                                            2),
                                                                    curve: Curves
                                                                        .fastOutSlowIn,
                                                                  );
                                                                }
                                                              },
                                                              icon: const Icon(
                                                                  color: Colors
                                                                      .black,
                                                                  Icons
                                                                      .arrow_right)))
                                                    ],
                                                  ),
                                                  children: [
                                                    Container(
                                                        padding:
                                                            EdgeInsets.all(20),
                                                        height:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .height -
                                                                395,
                                                        child: bottomScrollDisplay(
                                                            context,
                                                            bottomDisplayScrollController1))
                                                  ],
                                                ),
                                              ])))
                            ]))))));
  }
}
