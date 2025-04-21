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
  String tag;
  List<String> auxiliaries;
  String color;
  final int image;
  final String createDate;
  String updateDate;

  Node(
      {required this.id,
      required this.nodeTerm,
      required this.tag,
      required this.auxiliaries,
      required this.color,
      required this.image,
      required this.createDate,
      required this.updateDate});
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nodeTerm': nodeTerm,
      'tag': tag,
      'auxiliaries': jsonEncode(auxiliaries),
      'color': color,
      'image': image,
      'createDate': createDate,
      'updateDate': updateDate,
    };
  }
}

class AuxiliaryEntry {
  TextEditingController controller;
  int imageMode;
  bool selected;

  AuxiliaryEntry(
      {required this.controller,
      required this.imageMode,
      required this.selected});
}

class Test extends StatefulWidget {
  const Test({super.key, required this.constellationName, required this.id});

  final String constellationName;
  final int id;

  @override
  State<Test> createState() => _Test();
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
  Map<int, int> nodeIdMap = {};

  //bool for editing mode
  bool editingMode = true;
  bool editingModeCurrentNode = false;
  bool editingModeTextUpload = true;
  bool editingModePhotoUploaded = false;
  bool bottomDisplayOpen = false;

  //main node with default set
  Node mainNode = Node(
      id: -1,
      nodeTerm: "",
      tag: "",
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
  List<AuxiliaryEntry> auxiliaryEntryList = List.generate(
    3,
    (e) => AuxiliaryEntry(
        controller: TextEditingController(), imageMode: -1, selected: false),
  );

  List<String> auxiliaryNodePriorEditList = [];
  Node editingNode = Node(
      id: 0,
      nodeTerm: "",
      tag: "",
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
        nodeIdMap =
            nodeList.asMap().map((i, element) => MapEntry(element.id, i));
        print(nodeIdMap);
        print(nodeList);
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
            'tag': tag as String,
            'auxiliaries': auxiliaries as String,
            'color': color as String,
            'image': image as int,
            'createDate': createDate as String,
            'updateDate': updateDate as String,
          } in fileMaps)
        Node(
          id: id,
          nodeTerm: nodeTerm,
          tag: tag,
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

//Fix node update with image => null check !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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
      where: 'id = ?',
      // Pass the file's id as a whereArg to prevent SQL injection.
      whereArgs: [node.id],
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
      if (insertIndex < auxiliaryEntryList.length &&
          auxiliaryEntryList[insertIndex].controller.text.isEmpty) {
        auxiliaryEntryList[insertIndex].controller.text = listText[i];
      } else {
        auxiliaryEntryList.insert(
            insertIndex,
            AuxiliaryEntry(
                controller: TextEditingController(text: listText[i]),
                imageMode: -1,
                selected: false));
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
                      auxiliaryEntryList[index].selected
                          ? Icons.circle
                          : Icons.circle_outlined),
                  onPressed: () {
                    setState(() {
                      auxiliaryEntryList[index].selected =
                          !auxiliaryEntryList[index].selected;
                    });
                  },
                )),
                IconButton(
                    onPressed: () {
                      setState(() {
                        auxiliaryEntryList[index].imageMode = max(
                            -1, (auxiliaryEntryList[index].imageMode * -1) - 1);
                        if (auxiliaryEntryList[index].imageMode == -1) {
                          auxiliaryEntryList[index].controller.text = "";
                        }
                      });
                    },
                    icon: auxiliaryEntryList[index].imageMode >= 0
                        ? Icon(Icons.photo)
                        : Icon(Icons.text_fields_sharp)),
                Expanded(
                  child: Card(
                      // decoration: BoxDecoration(
                      //     border: Border.all(width: 1, color: Colors.black)),
                      child: Row(children: [
                    Expanded(
                        child: Container(
                            padding: EdgeInsets.only(right: 32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                            child: Container(
                                constraints: BoxConstraints(
                                    minHeight: 50, maxHeight: 400),
                                child: auxiliaryEntryList[index].imageMode >= 0
                                    ? auxiliaryEntryList[index].imageMode > 0
                                        ? Container(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 15, horizontal: 15),
                                            child: Stack(children: [
                                              Center(
                                                  child: Image.file(File(
                                                      auxiliaryEntryList[index]
                                                          .controller
                                                          .text))),
                                              Row(children: [
                                                Container(
                                                    padding: EdgeInsets.all(8),
                                                    child: TextButton(
                                                        style: const ButtonStyle(
                                                            backgroundColor:
                                                                WidgetStatePropertyAll(
                                                                    Color.fromARGB(
                                                                        223,
                                                                        255,
                                                                        255,
                                                                        255))),
                                                        onPressed: () async {
                                                          FilePickerResult?
                                                              fileUploadResult =
                                                              await FilePicker
                                                                  .platform
                                                                  .pickFiles(
                                                            allowedExtensions: [
                                                              'jpg',
                                                              'png',
                                                            ],
                                                          );

                                                          if (fileUploadResult ==
                                                              null) {
                                                            return;
                                                          }

                                                          setState(() {
                                                            auxiliaryEntryList[
                                                                        index]
                                                                    .controller
                                                                    .text =
                                                                fileUploadResult
                                                                    .files
                                                                    .single
                                                                    .path!;
                                                            auxiliaryEntryList[
                                                                    index]
                                                                .imageMode = 1;
                                                          });
                                                        },
                                                        child: Text("Reselect",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 12))))
                                              ])
                                            ]))
                                        : IconButton(
                                            style: const ButtonStyle(
                                                shape: WidgetStatePropertyAll(
                                                    ContinuousRectangleBorder())),
                                            onPressed: () async {
                                              FilePickerResult?
                                                  fileUploadResult =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                allowedExtensions: [
                                                  'jpg',
                                                  'png',
                                                ],
                                              );

                                              if (fileUploadResult == null) {
                                                return;
                                              }

                                              setState(() {
                                                auxiliaryEntryList[index]
                                                        .controller
                                                        .text =
                                                    fileUploadResult
                                                        .files.single.path!;
                                                auxiliaryEntryList[index]
                                                    .imageMode = 1;
                                              });
                                            },
                                            icon: const Icon(Icons
                                                .add_photo_alternate_outlined))
                                    : TextField(
                                        controller: auxiliaryEntryList[index]
                                            .controller,
                                        keyboardType: TextInputType.multiline,
                                        textInputAction:
                                            TextInputAction.newline,
                                        maxLines: null,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.all(10.0),
                                        ),
                                      ))))
                  ])),
                )
              ],
            )));
  }

  void removeAuxiliaryNodeInput() {
    List<AuxiliaryEntry> auxiliaryEntryListTemp = auxiliaryEntryList;

    for (int i = 0; i < auxiliaryEntryListTemp.length; i++) {
      if (auxiliaryEntryListTemp[i].selected) {
        auxiliaryEntryListTemp.removeAt(i);
        i--;
      }
    }
    setState(() {
      auxiliaryEntryList = auxiliaryEntryListTemp;
    });
  }

  void resetSubmission() {
    setState(() {
      mainNodeTextController.text = "";
      auxiliaryEntryList = List.generate(
        3,
        (e) => AuxiliaryEntry(
            controller: TextEditingController(),
            imageMode: -1,
            selected: false),
      );
      editingModePhotoUploaded = false;
    });
  }

  List<AuxiliaryEntry> processList(List<AuxiliaryEntry> l, String mainNode) {
    l.removeWhere((e) => e.controller.text.isEmpty);
    l.removeWhere((e) => e.controller.text == mainNode);

    Set<String> seen = {};
    List<AuxiliaryEntry> uniqueAuxiliary =
        l.where((entry) => seen.add(entry.controller.text)).toList();

    print(uniqueAuxiliary.map((e) => e.controller.text));
    return uniqueAuxiliary;
  }

  void createNode() async {
    // final int id;
    // String nodeTerm;
    // List<String> auxiliaries;
    // String color;
    // final String createDate;
    // String updateDate;

    String nodeTerm = mainNodeTextController.text;
    print(nodeTerm);
    if (nodeTerm.isEmpty) {
      print("Term cannot be empty");
      return;
    }

    if (editingModePhotoUploaded) {
      nodeTerm = await copyFile(File(nodeTerm));
    }

    List<AuxiliaryEntry> auxiliaries =
        processList(auxiliaryEntryList, nodeTerm);

    //add auxiliaries
    List<String> auxProcessedList =
        await createAuxiliaries(auxiliaries, nodeTerm);

    if (nodeMap[nodeTerm] != null) {
      //term already exists - update
      print("already exists");
      Node currentNode = nodeMap[nodeTerm]!;
      Set<String> currentNodeAux = currentNode.auxiliaries.toSet();
      currentNode.updateDate = DateTime.now().toString();
      print(auxProcessedList);
      currentNode.auxiliaries =
          currentNodeAux.union(auxProcessedList.toSet()).toList();

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
      print(editingModePhotoUploaded);
      Node newNode = Node(
          id: nodeList.isEmpty ? 1 : nodeList[nodeList.length - 1].id + 1,
          nodeTerm: nodeTerm,
          tag: "",
          auxiliaries: auxProcessedList,
          color: color,
          image: (editingModePhotoUploaded) ? 1 : 0,
          createDate: createDate,
          updateDate: updateDate);

      insertNode(newNode);
      setState(() {
        addNodeLocally(newNode);

        mainNode = newNode;
      });
    }

    setState(() {
      editingMode = !editingMode;
    });

    resetSubmission();
  }

  void addNodeLocally(Node newNode) {
    nodeIdMap[newNode.id] = nodeList.isNotEmpty ? nodeIdMap.values.last + 1 : 0;
    nodeList.add(newNode);
    nodeMap[newNode.nodeTerm] = newNode;
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
      returnList = nodeList
          .where((e) => e.nodeTerm.startsWith(controller.text))
          .toList();
    } else {
      returnList = nodeList
          .where((e) => e.nodeTerm.startsWith(controller.text))
          .toList();
    }
    print(returnList.map((e) => e.nodeTerm));
    if (returnList.isEmpty) {
      return [];
    } else {
      returnList =
          returnList.getRange(0, min(returnList.length, searchLimit)).toList();

      return returnList;
    }
  }

  Future<List<String>> createAuxiliaries(
      List<AuxiliaryEntry> auxiliaries, String mainNode) async {
    List<String> auxiliaryReturn = [];
    for (int i = 0; i < auxiliaries.length; i++) {
      String auxTerm = auxiliaries[i].controller.text;

      // node already exists
      if (nodeMap.containsKey(auxTerm)) {
        List<String> existingAux = nodeMap[auxTerm]!.auxiliaries;
        if (!existingAux.contains(mainNode)) {
          nodeMap[auxTerm]!.auxiliaries.add(mainNode);
        }
        auxiliaryReturn.add(auxTerm);
      }
      // node does not already exist
      else {
        if (auxiliaries[i].imageMode == 1) {
          auxTerm = await copyFile(File(auxiliaryEntryList[i].controller.text));
        }

        auxiliaryReturn.add(auxTerm);

        Node newNode = Node(
            id: nodeList.isEmpty ? 1 : nodeList[nodeList.length - 1].id + 1,
            nodeTerm: auxTerm,
            tag: "",
            auxiliaries: [mainNode],
            color: Color.fromARGB(255, 224, 224, 224).toString(),
            image: auxiliaries[i].imageMode == 1 ? 1 : 0,
            createDate: DateTime.now().toString(),
            updateDate: DateTime.now().toString());
        insertNode(newNode);
        setState(() {
          addNodeLocally(newNode);
        });
      }
    }

    return auxiliaryReturn;
  }

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Edit Functions
// 1. updateNodeTerm: updates a node (and any relevant auxiliaries) with a new node term
// 2. removeAuxiliaries: disconnects a node from its auxiliaries
// 3. editNode: wrapper functions that uses all the above functions to update a node to its most recently edited version
// 4. removeNode: deletes a node and uncouples all auxiliaries
// -------------------------------------------------------------------------------------------------------------------------------------

  Node updateNodeTerm(Node node, String newNodeTerm) {
    Node newNode = Node(
        id: node.id,
        nodeTerm: newNodeTerm,
        tag: node.tag,
        auxiliaries: node.auxiliaries,
        color: node.color,
        image: 0,
        createDate: node.createDate,
        updateDate: node.updateDate);

    //Update node locally
    nodeList[nodeIdMap[node.id]!] = newNode;
    nodeMap[node.nodeTerm] = newNode;

    updateNode(newNode);

    for (int i = 0; i < node.auxiliaries.length; i++) {
      Node auxiliaryNode = nodeMap[node.auxiliaries[i]]!;
      auxiliaryNode
              .auxiliaries[auxiliaryNode.auxiliaries.indexOf(node.nodeTerm)] =
          newNodeTerm;
      nodeList[nodeIdMap[auxiliaryNode.id]!] = auxiliaryNode;
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
      nodeList[nodeIdMap[auxiliaryNode.id]!] = auxiliaryNode;
      nodeMap[auxiliaryNode.nodeTerm] = auxiliaryNode;
      updateNode(auxiliaryNode);
    }
  }

  void editNode() async {
    Node updatedNode = editingNode;
    if (mainNodeTextController.text != editingNode.nodeTerm) {
      updatedNode = updateNodeTerm(editingNode, mainNodeTextController.text);
      print(mainNodeTextController.text);
    }
    List<AuxiliaryEntry> auxiliaryControllerTextList =
        processList(auxiliaryEntryList, mainNodeTextController.text);
    List<String> auxTextList =
        auxiliaryControllerTextList.map((e) => e.controller.text).toList();
    List<String> currentAuxiliaryList = updatedNode.auxiliaries;

    Set<String> currentSet = currentAuxiliaryList.toSet();
    Set<String> updateSet = auxTextList.toSet();

    Set<String> auxiliaryUnion = updateSet.intersection(currentSet);
    Set<String> auxiliaryToRemove = currentSet.difference(auxiliaryUnion);
    print(auxiliaryToRemove);

    print("----------------------------1");

    List<String> auxProcessedList = await createAuxiliaries(
        auxiliaryControllerTextList, mainNodeTextController.text);
    print("----------------------------2");
    removeAuxiliaries(auxiliaryToRemove, mainNodeTextController.text);
    updatedNode.auxiliaries = auxProcessedList;
    setState(() {
      updateNode(updatedNode);
      nodeList[nodeIdMap[updatedNode.id]!] = updatedNode;
      nodeMap[updatedNode.nodeTerm] = updatedNode;
      mainNode = updatedNode;
    });
  }

  void removeNode() {
    Node nodeToRemove = mainNode;
    int nodeIndex = nodeIdMap[nodeToRemove.id]!;
    print(nodeToRemove.auxiliaries);
    for (int i = 0; i < nodeToRemove.auxiliaries.length; i++) {
      Node newNode = nodeMap[nodeToRemove.auxiliaries[i]]!;
      newNode.auxiliaries
          .removeWhere((element) => element == nodeToRemove.nodeTerm);
      updateNode(newNode);
      nodeList[nodeIdMap[newNode.id]!] = newNode;
      nodeMap[newNode.nodeTerm] = newNode;
    }

    nodeList.removeAt(nodeIndex);
    nodeMap.remove(nodeToRemove.nodeTerm);
    nodeIdMap.remove(nodeToRemove.id);

    List<int> nodeIdList = nodeIdMap.values.toList();
    for (int i = nodeIdList.length - 1; i >= 0; i--) {
      if (nodeIdList[i] <= nodeIndex) {
        break;
      }
      nodeIdList[i]--;
    }
    print(nodeIdList);

    setState(() {
      nodeIdMap = Map.fromIterables(nodeIdMap.keys, nodeIdList);
    });

    if (nodeList.isEmpty) {
      editingMode = true;
      setState(() {
        mainNode = Node(
            id: -1,
            nodeTerm: "",
            tag: "",
            auxiliaries: [],
            color: Colors.black.toString(),
            image: 0,
            updateDate: DateTime.now().toString(),
            createDate: DateTime.now().toString());
      });
    } else {
      setState(() {
        if (nodeIndex >= nodeList.length) {
          nodeIndex--;
        }
        mainNode = nodeList[nodeIndex];
      });
    }

    deleteNode(nodeToRemove);
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

// -------------------------------------------------------------------------------------------------------------------------------------
// nodeMasterySelectButton method
// parameters:
// return: Widget | returns a widgt that comprises of a dropdown button that is used to select the node mastery for a node
// -------------------------------------------------------------------------------------------------------------------------------------

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

// -------------------------------------------------------------------------------------------------------------------------------------
// auxiliaryDisplayProxyDecorator method
// - used for the ReorderableListView that displays the auxiliary nodes
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

// -------------------------------------------------------------------------------------------------------------------------------------
// auxiliaryDisplay method
// - parameters: String term [the nodeTerm of the node whose auxiliary nodes are to be displayed]
// - return: Widget | returns a widget that displays a card with auxiliary node information (term and color)
// -------------------------------------------------------------------------------------------------------------------------------------

  Widget auxiliaryDisplay(String term) {
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
                                        color:
                                            colorFromString(auxNode.color)))),
                            margin: EdgeInsets.only(right: 20),
                            padding: EdgeInsets.all(10),
                            child: auxNode.image == 1
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

  Future<String> copyFile(File file) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    Directory directory = await Directory(
            '$appDocPath/LynkLynkApp/images/${constellationName}_$constellationID')
        .create(recursive: true);

    mainNodeTextController.text = file.path;
    var rng = Random();
    var identifier = rng.nextInt(900000) + 100000;

    File copyFile = await file.copy(
        "$appDocPath/LynkLynkApp/images/${constellationName}_$constellationID/${constellationName}_${constellationID}_${identifier}_${Path.basename(file.path)}");
    return copyFile.path;
  }

// -------------------------------------------------------------------------------------------------------------------------------------
// Node Submission Component
// -------------------------------------------------------------------------------------------------------------------------------------

  Widget nodeSubmissionComponent() {
    return Expanded(
        child: Container(
            margin: EdgeInsets.only(top: 20),
            decoration: BoxDecoration(color: Colors.white),
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              controller: addNodeController,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                        decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(width: 3, color: Colors.black),
                                left: BorderSide(width: 3, color: Colors.black),
                                right:
                                    BorderSide(width: 3, color: Colors.black))),
                        child: TextButton(
                            style: ButtonStyle(
                                padding:
                                    WidgetStatePropertyAll(EdgeInsets.all(2)),
                                backgroundColor: WidgetStatePropertyAll(
                                    editingModeTextUpload
                                        ? primary2
                                        : primary1),
                                shape: WidgetStatePropertyAll(
                                    ContinuousRectangleBorder())),
                            onPressed: () {
                              setState(() {
                                editingModeTextUpload = true;
                                mainNodeTextController.text = "";
                                editingModePhotoUploaded = false;
                              });
                            },
                            child: const Text("Text",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)))),
                    Container(
                        decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(width: 3, color: Colors.black),
                                right:
                                    BorderSide(width: 3, color: Colors.black))),
                        child: TextButton(
                            style: ButtonStyle(
                                padding:
                                    WidgetStatePropertyAll(EdgeInsets.all(2)),
                                backgroundColor: WidgetStatePropertyAll(
                                    !editingModeTextUpload
                                        ? primary2
                                        : primary1),
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
                              editingModeTextUpload = true;
                              resetSubmission();
                            },
                            child: Text("Update Node"))
                        : TextButton(
                            onPressed: () {
                              if (mainNodeTextController.text.isEmpty) return;
                              editingModeTextUpload = true;
                              createNode();
                            },
                            child: Text("Create +"))
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                  decoration: BoxDecoration(
                      color: primary1,
                      border: const Border(
                          left: BorderSide(width: 3, color: Colors.black),
                          right: BorderSide(width: 3, color: Colors.black),
                          top: BorderSide(width: 3, color: Colors.black))),
                  child: Row(
                    children: [
                      const Text(
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.white),
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
                              padding: EdgeInsets.all(10),
                              constraints: BoxConstraints(
                                  minHeight: 200,
                                  maxHeight:
                                      editingModePhotoUploaded ? 450 : 200),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border:
                                    Border.all(width: 3, color: Colors.black),
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
                                      textInputAction: TextInputAction.newline,
                                      maxLines: 8,
                                    )
                                  : Center(
                                      child: editingModePhotoUploaded
                                          ? Container(
                                              child: Stack(children: [
                                              Center(
                                                  child: Image.file(File(
                                                      mainNodeTextController
                                                          .text))),
                                              Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    TextButton(
                                                        onPressed: () async {
                                                          FilePickerResult?
                                                              fileUploadResult =
                                                              await FilePicker
                                                                  .platform
                                                                  .pickFiles(
                                                            allowedExtensions: [
                                                              'jpg',
                                                              'png',
                                                            ],
                                                          );

                                                          if (fileUploadResult ==
                                                              null) {
                                                            return;
                                                          }

                                                          setState(() {
                                                            mainNodeTextController
                                                                    .text =
                                                                fileUploadResult
                                                                    .files
                                                                    .single
                                                                    .path!;
                                                            editingModePhotoUploaded =
                                                                true;
                                                          });
                                                        },
                                                        child: Text(
                                                            "Reselect Image"))
                                                  ])
                                            ]))
                                          : Container(
                                              height: 50,
                                              width: 50,
                                              child: IconButton(
                                                  onPressed: () async {
                                                    FilePickerResult?
                                                        fileUploadResult =
                                                        await FilePicker
                                                            .platform
                                                            .pickFiles(
                                                      allowedExtensions: [
                                                        'jpg',
                                                        'png',
                                                      ],
                                                    );

                                                    if (fileUploadResult ==
                                                        null) {
                                                      return;
                                                    }

                                                    setState(() {
                                                      mainNodeTextController
                                                              .text =
                                                          fileUploadResult.files
                                                              .single.path!;
                                                      editingModePhotoUploaded =
                                                          true;
                                                    });
                                                  },
                                                  icon: Icon(Icons.add)))))),
                    ],
                  ),
                ),
                // Container(
                //     margin: EdgeInsets.all(10),
                //     decoration: BoxDecoration(
                //         border: Border.all(width: 3, color: Colors.black)),
                //     padding: EdgeInsets.all(10),
                //     child: IconButton(
                //         onPressed: () {
                //           formatMainNodeText();
                //         },
                //         icon: Icon(Icons.rebase_edit))),
                SizedBox(height: 10),
                Row(children: [
                  Text(style: TextStyle(fontSize: 18), "Auxiliary Nodes"),
                  Spacer(),
                  Container(
                      height: 30,
                      width: 30,
                      child:
                          auxiliaryEntryList.where((e) => e.selected).isNotEmpty
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
                      final AuxiliaryEntry item =
                          auxiliaryEntryList.removeAt(oldIndex);

                      auxiliaryEntryList.insert(newIndex, item);
                      selectedAuxiliaryNodeInput = newIndex;
                    });
                  },
                  children: auxiliaryEntryList
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
                      auxiliaryEntryList.add(AuxiliaryEntry(
                          controller: TextEditingController(),
                          imageMode: -1,
                          selected: false));
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
      nodeTrack = List.filled(nodeList.length, 1, growable: true);
    } else {
      int row = (nodeIdMap[mainNode.id]!) ~/ numRow;

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
                      child: nodeListSlice[index].image == 1
                          ? Container(
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5)),
                              child: Image.file(
                                  File(nodeListSlice[index].nodeTerm)))
                          : Text(nodeListSlice[index].nodeTerm,
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
      if (nodeList.length <= 36) {
        int divide = MediaQuery.sizeOf(context).width > 820 ? 4 : 3;
        int offset = (nodeIdMap[mainNode.id]!) ~/ divide * (120 + 15);
        bottomDisplayScrollController1 =
            ScrollController(initialScrollOffset: offset.toDouble());
      } else {
        bottomDisplayScrollController1 = ScrollController(
            initialScrollOffset:
                MediaQuery.sizeOf(context).width > 820 ? 540 : 660);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{},
        child: Actions(
            actions: <Type, Action<Intent>>{},
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
                              border: Border.all(width: 3, color: Colors.black),
                            ),
                            child: Column(children: [
                              Container(
                                  decoration: BoxDecoration(
                                    color: primary1,
                                    border: const Border(
                                        bottom: BorderSide(
                                            width: 3, color: Colors.black)),
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
                                                width: 2),
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
                                                width: 2),
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

                                                  resetSubmission();
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
                                              MediaQuery.sizeOf(context).width >
                                                      600
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
                                                constraints:
                                                    const BoxConstraints(
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
                                              print(suggestionList.length);
                                              return suggestionList.map((e) {
                                                return Container(
                                                    width: 400,
                                                    child: ListTile(
                                                      tileColor: Colors.white,
                                                      title: Text(e.nodeTerm),
                                                      onTap: () {
                                                        setState(() {
                                                          mainNode = e;
                                                          controller
                                                              .closeView("");
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

                                  nodeSubmissionComponent()
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
                                                                                  3,
                                                                              color: Colors
                                                                                  .black),
                                                                          color: Colors
                                                                              .white),
                                                                      child: mainNode.image ==
                                                                              1
                                                                          ? ClipRRect(
                                                                              borderRadius: BorderRadius.circular(8.0),
                                                                              child: Image.file(File(mainNode.nodeTerm)))
                                                                          : Text(style: TextStyle(fontSize: mainNode.nodeTerm.length > 100 ? 24 : 30), mainNode.nodeTerm))),
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
                                                                                  IconButton(
                                                                                      onPressed: () {
                                                                                        removeNode();
                                                                                      },
                                                                                      icon: Icon(Icons.delete)),
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
                                                                                        editingModeTextUpload = mainNode.image == 0;
                                                                                        editingModePhotoUploaded = mainNode.image == 1;
                                                                                        auxiliaryEntryList = mainNode.auxiliaries.map((e) => AuxiliaryEntry(controller: TextEditingController(text: e), imageMode: nodeMap[e]?.image == 1 ? 1 : -1, selected: false)).toList();
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
                                                                                  border: Border.all(width: 3, color: Colors.black),
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
                                                                                child: Container(padding: EdgeInsets.all(15), child: mainNode.image == 1 ? Image.file(File(mainNode.nodeTerm)) : Text(mainNode.nodeTerm, style: TextStyle(fontSize: mainNode.nodeTerm.length > 100 ? 15 : 25))))),
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
                                                                                        IconButton(
                                                                                            onPressed: () {
                                                                                              removeNode();
                                                                                            },
                                                                                            icon: Icon(Icons.delete)),
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
                                                                                              editingModeTextUpload = mainNode.image == 0;
                                                                                              editingModePhotoUploaded = mainNode.image == 1;
                                                                                              auxiliaryEntryList = mainNode.auxiliaries.map((e) => AuxiliaryEntry(controller: TextEditingController(text: e), imageMode: nodeMap[e]?.image == 1 ? 1 : -1, selected: false)).toList();
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
                                                                    width: 3,
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
                                                    setState(() {
                                                      bottomDisplayOpen = value;
                                                    });
                                                    if (value) {
                                                      setBottomDisplayScrollPosition();
                                                    }
                                                  },
                                                  title: Row(
                                                    children: [
                                                      SizedBox(width: 46),
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
                                                                    nodeIdMap[
                                                                        mainNode
                                                                            .id]!;
                                                                if (setIndex ==
                                                                    0) {
                                                                  setIndex =
                                                                      nodeIdMap
                                                                          .values
                                                                          .last;
                                                                } else {
                                                                  setIndex--;
                                                                }
                                                                setState(() {
                                                                  mainNode =
                                                                      nodeList[
                                                                          setIndex];
                                                                });

                                                                if (!bottomDisplayOpen) {
                                                                  return;
                                                                }

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
                                                                } else {
                                                                  int divide =
                                                                      MediaQuery.sizeOf(context).width >
                                                                              820
                                                                          ? 4
                                                                          : 3;
                                                                  int offset = (nodeIdMap[
                                                                          mainNode
                                                                              .id]!) ~/
                                                                      divide *
                                                                      (120 +
                                                                          15);
                                                                  bottomDisplayScrollController1
                                                                      .animateTo(
                                                                    offset
                                                                        .toDouble(),
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
                                                          "${nodeIdMap[mainNode.id]! + 1}/${nodeList.length}"),
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
                                                                    nodeIdMap[
                                                                        mainNode
                                                                            .id]!;
                                                                print(setIndex);
                                                                if (setIndex ==
                                                                    nodeIdMap
                                                                        .values
                                                                        .last) {
                                                                  setIndex = 0;
                                                                } else {
                                                                  setIndex++;
                                                                }
                                                                print(setIndex);
                                                                setState(() {
                                                                  mainNode =
                                                                      nodeList[
                                                                          setIndex];
                                                                  // print(mainNode
                                                                  //     .auxiliaries);
                                                                  // print(mainNode
                                                                  //     .nodeTerm);
                                                                });
                                                                if (!bottomDisplayOpen) {
                                                                  return;
                                                                }

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
                                                                } else {
                                                                  int divide =
                                                                      MediaQuery.sizeOf(context).width >
                                                                              820
                                                                          ? 4
                                                                          : 3;
                                                                  int offset =
                                                                      (nodeIdMap[mainNode.id]! -
                                                                              1) ~/
                                                                          divide *
                                                                          (120 +
                                                                              15);
                                                                  bottomDisplayScrollController1
                                                                      .animateTo(
                                                                    offset
                                                                        .toDouble(),
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
