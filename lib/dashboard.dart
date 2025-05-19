import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:lynklynk/highlighter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';
import 'package:lynklynk/constellation.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:pelaicons/pelaicons.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class Constellation {
  final int id;
  String name;
  String concept;
  List<String> keyWords;
  String directory;
  int starred;
  final String createdAt;
  String accessDate;
  String updateDate;

  Constellation({
    required this.id,
    required this.name,
    required this.concept,
    required this.keyWords,
    required this.directory,
    required this.starred,
    required this.createdAt,
    required this.accessDate,
    required this.updateDate,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'concept': concept,
      'key_words': jsonEncode(keyWords),
      'directory': directory,
      'starred': starred,
      'created_at': createdAt,
      'accessDate': accessDate,
      'updateDate': updateDate,
    };
  }

  @override
  String toString() {
    return 'Constellation(id: $id, name: $name, concept: $concept, key_words: ${keyWords.toString()}, directory: $directory, starred: $starred, created_at: $createdAt, accessDate: $accessDate, updateDate: $updateDate)';
  }
}

class Node {
  final int constellationID;
  String text;
  int type; //0: text, 1: image, 2: article (source -> url)
  String source;
  final String createdAt;
  final String updatedAt;

  Node(
      {required this.constellationID,
      required this.text,
      required this.type,
      required this.source,
      required this.createdAt,
      required this.updatedAt});
  Map<String, Object?> toMap() {
    return {
      'constellation_id': constellationID,
      'text': text,
      'type': type,
      'source': source,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _Dashboard createState() => _Dashboard();
}

class _Dashboard extends State<Dashboard> {
  //Page Scroller
  ScrollController? scroller;

  bool appMaximized = false;

  bool validNewConstellationName = true;

  //List of files in directory

  final _formKey = GlobalKey<FormState>();
  TextEditingController newConstellationNameController =
      TextEditingController();
  String directoryName = "";
  List<String> nameList = [];

  //list of all files retrieved from db
  List<Constellation> directoryFiles = [];

  //list of all files retrieved from db sorted by attribute (default accessed date)
  List directoryFilesStarredOrdered = [];
  List directoryFilesUnstarredOrdered = [];

  //string attribute by which directoryFilesOrdered is sorted by (most recent at top)
  int sortAttribute = 0;

  //list of attributes by which directoryFilesOrdered can be sorted by
  List<String> sortAttributeList = [
    "Access",
    "Create",
    "Update",
    "Alphabetical"
  ];
  bool loading = true;
  FontWeight loadingFontWeight = FontWeight.w100;
  Color loadingFontColor = const Color.fromRGBO(238, 165, 166, 1);
  bool loadingColor = false;
  bool visible = true;

  //currently selected set
  int currentlySelectedSet = -1;
  // Color dashboardColor = const Color.fromRGBO(252, 231, 200, 1);
  // Color primary1 = const Color.fromRGBO(177, 194, 158, 1);
  // Color primary2 = const Color.fromRGBO(250, 218, 122, 1);
  // Color primary3 = const Color.fromRGBO(240, 160, 75, 1);

  // Color dashboardColor = const Color.fromARGB(255, 78, 62, 110);
  Color dashboardColor = Colors.white;
  Color primary1 = const Color.fromARGB(255, 112, 103, 179);
  Color primary2 = const Color.fromRGBO(203, 128, 171, 1);
  Color primary3 = const Color.fromRGBO(238, 165, 166, 1);

  Color secondaryColor = const Color.fromARGB(255, 82, 72, 159);
  List<bool> checkboxList = [];
  int checkBoxActiveCount = 0;
  var database;
  int databaseID = 0;

  @override
  void initState() {
    scroller = ScrollController();
    if (Platform.isWindows || Platform.isLinux) {
      // Initialize FFI
      sqfliteFfiInit();
    }
    databaseFactory = databaseFactoryFfi;
    _loadDirectory();
    _asyncLoad();
    _asyncLoadDB();

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _asyncLoad() async {
    String databasesPath = await getDatabasesPath();

// Make sure the directory exists
    try {
      await Directory(databasesPath).create(recursive: true);
    } catch (_) {
      print("Error creating directory");
    }
  }

  Future<void> dropAllTables(Database db) async {
    // Step 1: Get all user-defined table names
    final tables = await db.rawQuery('''
    SELECT name FROM sqlite_master 
    WHERE type = 'table' AND name NOT LIKE 'sqlite_%';
  ''');

    // Step 2: Drop each table
    for (final table in tables) {
      final tableName = table['name'];
      await db.execute('DROP TABLE IF EXISTS $tableName');
    }
  }

  Future<void> deleteMyDatabase(String dbName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    // Delete the database file
    await deleteDatabase(path);
    print("Database deleted.");
  }

  _asyncLoadDB() async {
    WidgetsFlutterBinding.ensureInitialized();

    database = openDatabase(
      join(await getDatabasesPath(), 'lynklynk_database.db'),
      onCreate: (db, version) async {
        // Constellations table
        await db.execute(
          '''CREATE TABLE constellations(
              id INTEGER PRIMARY KEY, 
              name TEXT, 
              concept TEXT, 
              key_words TEXT, 
              directory TEXT,
              starred INTEGER,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
              accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
            )''',
        );

        // Nodes table
        await db.execute(
          '''CREATE TABLE nodes(
              id INTEGER PRIMARY KEY, 
              constellation_id INTEGER NOT NULL,
              text TEXT UNIQUE NOT NULL, 
              type INTEGER NOT NULL, 
              source TEXT, 
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (constellation_id) REFERENCES constellations(id) ON DELETE CASCADE
            )''',
        );

        // Edges table
        await db.execute(
          '''CREATE TABLE edges(
              id INTEGER PRIMARY KEY, 
              constellation_id INTEGER NOT NULL,
              from_node_id INTEGER NOT NULL,
              to_node_id INTEGER NOT NULL,
              relation TEXT, 
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (constellation_id) REFERENCES constellations(id) ON DELETE CASCADE,
              FOREIGN KEY (from_node_id) REFERENCES nodes(id),
              FOREIGN KEY (to_node_id) REFERENCES nodes(id)
            )''',
        );
      },
      onUpgrade: _onUpgrade,
      version: 1,
    );

    try {
      List<Constellation> queryResultsList = await getConstellationList();

      setState(() {
        directoryFiles = queryResultsList;
        updateDirectoryFilesOrdering(directoryFiles);
        checkboxList = List<bool>.filled(queryResultsList.length, false);
        nameList = queryResultsList.map((e) => e.name).toList();
      });
    } catch (e) {
      print(e);
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      loading = false;
    });
  }

  Future<int> createConstellation({
    required Database db,
    required String name,
    required String concept,
    required String directory,
    required keyWords,
    bool starred = false,
  }) async {
    final now = DateTime.now().toIso8601String();

    final data = {
      'name': name,
      'concept': concept,
      'key_words': jsonEncode(keyWords),
      'directory': directory,
      'created_at': now,
      'accessed_at': now,
      'updated_at': now,
      'starred': starred ? 1 : 0,
    };

    // Insert the constellation into the database and return its ID
    return await db.insert('constellations', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateConstellation({
    required Database db,
    required int constellationId,
    String? name,
    String? concept,
    String? keyWords,
    bool? starred,
    List<Map<String, dynamic>>?
        updatedNodes, // Includes node 'id' if updating, or omit 'id' to insert
    List<Map<String, dynamic>>?
        updatedEdges, // Includes edge 'id' if updating, or omit 'id' to insert
  }) async {
    await db.transaction((txn) async {
      // Update constellation metadata
      final updateFields = <String, Object?>{};
      if (name != null) updateFields['name'] = name;
      if (concept != null) updateFields['concept'] = concept;
      if (keyWords != null) updateFields['key_words'] = keyWords;
      if (starred != null) updateFields['starred'] = starred ? 1 : 0;
      if (updateFields.isNotEmpty) {
        updateFields['updated_at'] = DateTime.now().toIso8601String();
        await txn.update(
          'constellations',
          updateFields,
          where: 'id = ?',
          whereArgs: [constellationId],
        );
      }

      // Update or insert nodes
      if (updatedNodes != null) {
        for (var node in updatedNodes) {
          if (node.containsKey('id')) {
            // Update existing node
            final id = node['id'];
            await txn.update(
              'nodes',
              {
                'text': node['text'],
                'type': node['type'],
                'source': node['source'],
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ? AND constellation_id = ?',
              whereArgs: [id, constellationId],
            );
          } else {
            // Insert new node
            await txn.insert('nodes', {
              'text': node['text'],
              'type': node['type'],
              'source': node['source'],
              'constellation_id': constellationId,
            });
          }
        }
      }

      // Update or insert edges
      if (updatedEdges != null) {
        for (var edge in updatedEdges) {
          if (edge.containsKey('id')) {
            final id = edge['id'];
            await txn.update(
              'edges',
              {
                'text': edge['text'],
                'relation': edge['relation'],
                'from_node_id': edge['from_node_id'],
                'to_node_id': edge['to_node_id'],
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ? AND constellation_id = ?',
              whereArgs: [id, constellationId],
            );
          } else {
            await txn.insert('edges', {
              'text': edge['text'],
              'relation': edge['relation'],
              'from_node_id': edge['from_node_id'],
              'to_node_id': edge['to_node_id'],
              'constellation_id': constellationId,
            });
          }
        }
      }
    });
  }

  Future<void> deleteConstellation({
    required Database db,
    required int constellationId,
  }) async {
    await db.delete(
      'constellations',
      where: 'id = ?',
      whereArgs: [constellationId],
    );
    // Nodes and edges are automatically deleted due to ON DELETE CASCADE
  }

  void updateDirectoryFilesOrdering(
    List<Constellation> unordered,
  ) {
    List<Constellation> starred = [];
    List<Constellation> unstarred = [];

    for (int i = 0; i < unordered.length; i++) {
      if (unordered[i].starred == 0) {
        unstarred.add(unordered[i]);
      } else {
        starred.add(unordered[i]);
      }
    }

    if (sortAttribute == 0) {
      unstarred.sort((a, b) =>
          DateTime.parse(b.accessDate).compareTo(DateTime.parse(a.accessDate)));
      starred.sort((a, b) =>
          DateTime.parse(b.accessDate).compareTo(DateTime.parse(a.accessDate)));
    } else if (sortAttribute == 1) {
      unstarred.sort((a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));
      starred.sort((a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));
    } else if (sortAttribute == 1) {
      unstarred.sort((a, b) =>
          DateTime.parse(b.updateDate).compareTo(DateTime.parse(a.updateDate)));
      starred.sort((a, b) =>
          DateTime.parse(b.updateDate).compareTo(DateTime.parse(a.updateDate)));
    } else {
      unstarred.sort((a, b) => a.name.compareTo(b.name));
    }
    setState(() {
      directoryFilesStarredOrdered = starred;
      directoryFilesUnstarredOrdered = unstarred;
    });
  }

  Future<List<String>> getAllTableNames(Database db) async {
// you can use your initial name for dbClient

    List<Map> maps =
        await db.rawQuery('SELECT * FROM sqlite_master ORDER BY name;');

    List<String> tableNameList = [];
    if (maps.length > 0) {
      for (int i = 0; i < maps.length; i++) {
        try {
          tableNameList.add(maps[i]['name'].toString());
        } catch (e) {}
      }
    }
    return tableNameList;
  }

  // UPGRADE DATABASE TABLES
  void _onUpgrade(Database db, int oldVersion, int newVersion) {
    try {
      // if (oldVersion < 2) {
      //   db.execute(
      //       "ALTER TABLE files ADD COLUMN starred INTEGER NOT NULL DEFAULT (0);");
      // }

      // if (oldVersion < 3) {
      //   db.execute(
      //       "ALTER TABLE files ADD COLUMN existingFile INTEGER NOT NULL DEFAULT (0);");
      // }

      if (oldVersion < 4) {
        db.execute(
            'ALTER TABLE files RENAME COLUMN "fileDirectory" TO filePath');
      }
      print("Upgrade successful");
    } catch (e) {
      print("Upgrade failed: ");
      print(e);
    }
  }

  void _onUpgradeNodeDB(Database db, int oldVersion, int newVersion) async {
    try {
      List<String> tableNames = await getAllTableNames(db);
      print(tableNames);
      if (oldVersion < 6) {
        for (int i = 0; i < tableNames.length - 1; i++) {
          // await db.execute(
          //     'ALTER TABLE "${tableNames[i]}" ADD COLUMN image INTEGER NOT NULL DEFAULT (0);');
          await db.execute(
              'ALTER TABLE "${tableNames[i]}" ADD COLUMN tag TEXT NOT NULL DEFAULT "";');
        }
      }

      print("Upgrade successful");
    } catch (e) {
      print("Upgrade failed: ");
      print(e);
    }
  }

  Future<List<Constellation>> getConstellationList() async {
    // Get a reference to the database.
    final db = await database;

    // Query the table for all the files.
    final List<Map<String, Object?>> constellationMaps =
        await db.query('constellations');

    // Convert the list of each file's fields into a list of `file` objects.
    return [
      for (final {
            'id': id as int,
            'name': name as String,
            'concept': concept as String,
            'key_words': keyWords as String,
            'directory': directory as String,
            'starred': starred as int,
            'created_at': createdAt as String,
            'accessDate': accessDate as String,
            'updateDate': updateDate as String,
          } in constellationMaps)
        Constellation(
          id: id,
          name: name,
          concept: concept,
          keyWords: json.decode(keyWords).cast<String>().toList(),
          directory: directory,
          starred: starred,
          createdAt: createdAt,
          accessDate: accessDate,
          updateDate: updateDate,
        ),
    ];
  }

  String validateFileToTableName(String name) {
    return name.replaceAll(" ", "_");
  }

  List<String> nameSearchSuggestionList(String searchParam,
      {bool caseSensitive = true}) {
    List<String> ret = nameList
        .where((e) => caseSensitive
            ? e.startsWith(searchParam)
            : e.toLowerCase().startsWith(searchParam.toLowerCase()))
        .toList()
        .sorted((a, b) => a.compareTo(b));
    ret.removeWhere((e) => e.trim().isEmpty);
    if (ret.length > 7) {
      ret = ret.sublist(0, 7);
    }
    return ret;
  }

  Widget dashboardConstellationCard(
      Constellation constellation, BuildContext context) {
    return Container(

        // decoration:
        //     BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
        child: GestureDetector(
            onDoubleTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Test(
                        constellationName: constellation.name,
                        id: constellation.id)
                    // Editor(
                    //       path: pathName,
                    //       isPath: true,
                    //       name: name.split(".")[0],
                    //     )
                    ),
              );
            },
            child: Card(
                shape: const RoundedRectangleBorder(
                  side: BorderSide(width: 1),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(15),
                  ),
                ),
                color: Color.fromARGB(255, 255, 255, 255),
                shadowColor: Colors.transparent,
                child: Container(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      Container(
                          margin: EdgeInsets.only(
                              top: 10, left: 10, bottom: 10, right: 10),
                          child: Row(children: [
                            Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Color.fromARGB(204, 235, 235, 235),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Icon(Icons.gesture)),
                            Spacer(),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (constellation.starred == 0) {
                                    constellation.starred = 1;
                                  } else {
                                    constellation.starred = 0;
                                  }
                                });
                              },
                              icon: constellation.starred == 0
                                  ? const Icon(Icons.star_outline_rounded,
                                      size: 20,
                                      color: Color.fromARGB(255, 14, 14, 14))
                                  : Icon(Icons.star_rounded,
                                      size: 20, color: Colors.black),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            PopupMenuButton(
                                tooltip: "",
                                shape: ContinuousRectangleBorder(
                                    side: BorderSide(
                                        width: 1, color: Colors.black)),
                                color: Colors.white,
                                itemBuilder: (BuildContext context) => [
                                      PopupMenuItem(
                                        onTap: () => {
                                          deleteConstellation(
                                              db: database,
                                              constellationId: constellation.id)
                                        },
                                        child: Text('Delete'),
                                      ),
                                    ],
                                icon: const Icon(Icons.more_horiz,
                                    size: 20,
                                    color: Color.fromARGB(255, 14, 14, 14))),
                          ])),
                      ListTile(
                          title: Text(
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 20),
                              constellation.name),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  sortAttribute == 0
                                      ? const Text('Access Date:')
                                      : sortAttribute == 1
                                          ? const Text('Access Date')
                                          : const Text('Access Date:')
                                ]),
                                sortAttribute == 0
                                    ? Text(
                                        processDate(constellation.accessDate))
                                    : sortAttribute == 1
                                        ? Text(processDate(
                                            constellation.createdAt))
                                        : Text(processDate(
                                            constellation.updateDate))
                              ]))
                    ])))));
  }

  String processDate(String date) {
    return DateFormat.yMEd().add_jm().format(DateTime.parse(date));
  }

  void _loadDirectory() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    var directory = await Directory('$appDocPath/LynkLynkApp/files')
        .create(recursive: true);

    setState(() {
      directoryName = '$appDocPath/LynkLynkApp/files';
    });
  }

  bool _validatename(String name) {
    var existingItem = nameList.firstWhereOrNull((element) => element == name);
    print(nameList);
    return existingItem != null;
  }

  String _validname(String name) {
    int index = 0;
    String newname = name;
    while (nameList.firstWhereOrNull((element) => element == newname) != null) {
      index += 1;
      newname = "$name ($index)";
    }

    return newname;
  }

  Future<void> readJson() async {
    final String response =
        await rootBundle.loadString('assets/project-constellation.sets5.json');
    final data = await json.decode(response);
    Map dataMap = data[8]["terms"];
    List<int> dataLevelList = [];
    List<String> dataTermList = [];
    dataMap.forEach((key, value) {
      if (!dataTermList.contains(key.replaceAll('\n', ' '))) {
        dataTermList.add(key.replaceAll('\n', ' '));
        dataLevelList.add(0);
        List<String> auxiliaryList = List<String>.from(value["auxiliary"]
            .map((term) => term["title"].replaceAll('\n', ' ')));
        dataTermList += auxiliaryList;
        dataLevelList += List.generate(auxiliaryList.length, (e) => 1);
      } else {
        int termIndex = dataTermList.indexOf(key.replaceAll('\n', ' '));
        List<String> auxiliaryList = List<String>.from(value["auxiliary"]
            .map((term) => term["title"].replaceAll('\n', ' ')));
        dataTermList.insertAll(termIndex + 1, auxiliaryList);
        int termLevel = dataLevelList[termIndex];
        dataLevelList.insertAll(termIndex + 1,
            List.generate(auxiliaryList.length, (e) => termLevel + 1));
      }
    });

    File f = File(
        "C:/Users/David/lynklynk-app/assets/project-constellation-set.txt");
    String content = '';
    // await db.execute(
    //     "DELETE FROM constellation_table WHERE name=project-constellation-set");
    // await db.insert('constellation_table',
    //     {'name': "project-constellation-set", 'bullet_list': "$dataLevelList"});
    for (int i = 0; i < dataTermList.length; i++) {
      if (i < dataTermList.length - 1) {
        content += '${dataTermList[i]}\n';
      } else {
        content += dataTermList[i];
      }
    }
    f.writeAsString(content);
  }

  Widget addConstellationButton(BuildContext context) {
    return Tooltip(
        margin: const EdgeInsets.only(bottom: 40),
        preferBelow: false,
        message: 'Create a constellation',
        child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(width: 1, color: Colors.black),
            ),
            child: IconButton(
                color: Colors.white,
                icon: const Icon(Icons.add, color: Colors.black),
                iconSize: 30,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40)),
                ),
                onPressed: () {
                  validNewConstellationName = true;
                  newConstellationNameController.text = "";
                  showDialog(
                      context: context,
                      barrierDismissible: true, //

                      builder: (BuildContext context) {
                        return StatefulBuilder(
                          builder: (context, setState) {
                            return Transform.translate(
                                offset: Offset(0, -100),
                                child: Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: Form(
                                    key: _formKey,
                                    child: Stack(children: [
                                      Container(
                                        width: 480,
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(10),
                                          ),
                                          color: dashboardColor,
                                          border: Border.all(
                                              width: 1, color: Colors.black),
                                        ),
                                        child: Container(
                                          width: 460,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          child: TextFormField(
                                            onChanged: (value) => {
                                              setState(() {
                                                validNewConstellationName =
                                                    true;
                                              })
                                            },
                                            autofocus: true,
                                            controller:
                                                newConstellationNameController,
                                            decoration: const InputDecoration(
                                                hintText: "New Constellation",
                                                border: InputBorder.none,
                                                icon: Icon(Icons.add)),
                                            onFieldSubmitted: (value) async {
                                              _formKey.currentState?.save();

                                              if (value.isEmpty ||
                                                  _validatename(value)) {
                                                setState(() {
                                                  validNewConstellationName =
                                                      false;
                                                });
                                                return;
                                              }

                                              Directory appDocDir =
                                                  await getApplicationDocumentsDirectory();
                                              String appDocPath =
                                                  appDocDir.path;
                                              Directory directory = await Directory(
                                                      '$appDocPath/LynkLynkApp/resources/$value')
                                                  .create(recursive: true);

                                              await createConstellation(
                                                db: database,
                                                name: value,
                                                concept: value,
                                                directory: directory.toString(),
                                                keyWords: [],
                                              );

                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          Test(
                                                              id: 0,
                                                              constellationName:
                                                                  value)
                                                      // Editor(path: "$directoryName/$constellationName.txt", isPath: true, name: constellationName)
                                                      ),
                                                );
                                              }

                                              setState(() {
                                                newConstellationNameController =
                                                    TextEditingController();
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      Container(
                                          margin:
                                              EdgeInsets.only(top: 70, left: 5),
                                          child: Text(
                                              style: TextStyle(
                                                  color: Colors.white),
                                              validNewConstellationName
                                                  ? ""
                                                  : "Invalid constellation name"))
                                    ]),
                                  ),
                                ));
                          },
                        );
                      });
                })));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                  foregroundColor:
                                      const Color.fromARGB(255, 0, 0, 0),
                                ),
                                onPressed: () => windowManager.minimize(),
                                icon: const Icon(
                                    size: 14, Icons.horizontal_rule_sharp),
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
                                        const Color.fromARGB(255, 0, 0, 0),
                                  ),
                                  onPressed: () =>
                                      windowManager.isMaximized().then((isMax) {
                                        if (isMax) {
                                          windowManager.restore();
                                        } else {
                                          windowManager.maximize();
                                        }
                                      }),
                                  icon: const Icon(
                                      size: 14, Icons.web_asset_sharp))),
                          const SizedBox(width: 10),
                          SizedBox(
                              width: 30,
                              height: 30,
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  foregroundColor:
                                      const Color.fromARGB(255, 0, 0, 0),
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
        body: directoryFiles.isEmpty
            ? Container(
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Expanded(child: addConstellationButton(context)),
                  ],
                ))
            : AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(
                          251, 255, 255, 255), // Background color
                    ),
                    padding: EdgeInsets.only(bottom: 10, right: 10, left: 10),
                    child: Padding(
                        padding: const EdgeInsets.only(left: 25),
                        child: ListView(
                            // mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    addConstellationButton(context),
                                    const SizedBox(
                                      width: 25,
                                    ),
                                    Tooltip(
                                        margin: EdgeInsets.only(bottom: 20),
                                        preferBelow: false,
                                        message: 'Upload a study file',
                                        child: Container(
                                            height: 80,
                                            width: 80,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  width: 1,
                                                  color: Colors.black),
                                            ),
                                            child: IconButton(
                                                color: Colors.white,
                                                icon: const Icon(
                                                    color: Colors.black,
                                                    Icons.arrow_upward_sharp),
                                                iconSize: 30,
                                                style: IconButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              40)),
                                                ),
                                                onPressed: () async {
                                                  FilePickerResult?
                                                      fileUploadResult =
                                                      await FilePicker.platform
                                                          .pickFiles(
                                                    type: FileType.custom,
                                                    allowedExtensions: [
                                                      'txt',
                                                      'pdf',
                                                      'doc'
                                                    ],
                                                  );

                                                  if (fileUploadResult ==
                                                      null) {
                                                    return;
                                                  }
                                                  String defaultname =
                                                      './samples/test.txt';
                                                  String nameMaintain =
                                                      defaultname;
                                                  for (int i = 0;
                                                      i <
                                                          fileUploadResult
                                                              .paths.length;
                                                      i++) {
                                                    String filePath =
                                                        fileUploadResult
                                                                .paths[i] ??
                                                            "./samples/test.txt";
                                                    String name =
                                                        (fileUploadResult
                                                                    .names[i] ??
                                                                "test.txt")
                                                            .split(".")[0];

                                                    String validname =
                                                        _validname(name);
                                                    setState(() {
                                                      nameList.add(validname);
                                                      newConstellationNameController =
                                                          TextEditingController(
                                                              text: _validname(
                                                                  "Constellation"));
                                                    });
                                                    if (i == 0) {
                                                      nameMaintain = validname;
                                                    }

                                                    String currentDateTime =
                                                        DateTime.now()
                                                            .toString();
                                                    await createConstellation(
                                                      db: database,
                                                      name: "",
                                                      concept: "",
                                                      directory: "",
                                                      keyWords: [],
                                                    );
                                                  }

                                                  print(
                                                      "file upload result: $fileUploadResult");
                                                }))),
                                  ]),
                              Container(
                                  margin: EdgeInsets.only(top: 20),
                                  child: Row(children: [
                                    Text("Constellations",
                                        style: TextStyle(
                                            color: Colors.black, fontSize: 25)),
                                  ])),
                              directoryFilesStarredOrdered.isNotEmpty
                                  ? Container(
                                      margin: EdgeInsets.only(
                                          right: 30, bottom: 15, top: 10),
                                      child: GridView.builder(
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount:
                                                MediaQuery.sizeOf(context)
                                                            .width >
                                                        1200
                                                    ? 4
                                                    : MediaQuery.sizeOf(context)
                                                                .width >
                                                            800
                                                        ? 3
                                                        : 2,
                                            childAspectRatio: 1.0,
                                            crossAxisSpacing: 15,
                                            mainAxisSpacing: 15,
                                            mainAxisExtent: 300,
                                          ),
                                          shrinkWrap: true,
                                          itemCount:
                                              directoryFilesStarredOrdered
                                                  .length,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            return dashboardConstellationCard(
                                                directoryFilesStarredOrdered[
                                                    index],
                                                context);
                                          }))
                                  : const SizedBox(),
                              directoryFilesStarredOrdered.isNotEmpty
                                  ? Divider()
                                  : SizedBox(),
                              Container(
                                  margin: EdgeInsets.only(right: 30, top: 15),
                                  child: GridView.builder(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            MediaQuery.sizeOf(context).width >
                                                    1200
                                                ? 4
                                                : MediaQuery.sizeOf(context)
                                                            .width >
                                                        900
                                                    ? 3
                                                    : 2,
                                        childAspectRatio: 1.0,
                                        crossAxisSpacing: 15,
                                        mainAxisSpacing: 15,
                                        mainAxisExtent: 300,
                                      ),
                                      scrollDirection: Axis.vertical,
                                      shrinkWrap: true,
                                      controller: scroller,
                                      itemCount:
                                          directoryFilesUnstarredOrdered.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        return dashboardConstellationCard(
                                            directoryFilesUnstarredOrdered[
                                                index],
                                            context);
                                      })),
                              SizedBox(height: 20)
                            ]))),
              ));
  }
}
