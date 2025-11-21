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
import 'classes/constellationClass.dart';
import 'package:lynklynk/functions/keywordSearcher.dart';

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
  List<Constellation> constellations = [];

  //list of all files retrieved from db sorted by attribute (default accessed date)
  List constellationsStarredOrdered = [];
  List constellationsUnstarredOrdered = [];

  //string attribute by which constellationsOrdered is sorted by (most recent at top)
  int sortAttribute = 0;

  //list of attributes by which constellationsOrdered can be sorted by
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
  late Database database;
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

  Future<void> deleteDatabase(String dbName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    // Delete the database file
    await deleteDatabase(path);
    print("Database deleted.");
  }

  _asyncLoadDB() async {
    WidgetsFlutterBinding.ensureInitialized();
    database = await openDatabase(
      join(await getDatabasesPath(), 'lynklynk_database.db'),
      onConfigure: (db) async {
        // 🔑 Enable foreign key support
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // Constellations table
        await db.execute(
          '''CREATE TABLE constellations(
              id INTEGER PRIMARY KEY, 
              name TEXT, 
              concept TEXT, 
              summary TEXT,
              image TEXT,
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
              text TEXT NOT NULL, 
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
      version: 4,
    );

    try {
      List<Constellation> queryResultsList = await getConstellationList();
      print(queryResultsList.map((e) => e.name));
      setState(() {
        constellations = queryResultsList;
        updateConstellationsOrdering(constellations);
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

  // UPGRADE DATABASE TABLES
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      try {
        await db.execute(
            "ALTER TABLE constellations ADD COLUMN image TEXT NOT NULL DEFAULT ''");
      } catch (e) {
        print("Column already exists or error adding summary column: $e");
      }
    }
  }

  Future<int> createConstellation({
    required Database db,
    required String name,
    required String concept,
    required String directory,
    required List<String> keyWords,
    bool starred = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    var fetchedData = await fetchSummary(concept);
    String? summary;
    String? image;
    if (fetchedData != null) {
      summary = fetchedData.$1;
      image = fetchedData.$2;
    }
    Constellation newConstellation = Constellation(
      id: 0,
      name: name,
      concept: concept,
      summary: summary ?? "",
      image: image ?? "",
      keyWords: keyWords,
      directory: directory,
      starred: starred ? 1 : 0,
      createdAt: now,
      accessedAt: now,
      updatedAt: now,
    );

    //Add constellation locally
    setState(() {
      constellations.add(newConstellation);
      updateConstellationsOrdering(constellations);
    });

    int newConstellationId = -1;

    await db.transaction((txn) async {
      final batch = txn.batch();

      batch.insert(
          'constellations',
          {
            'name': name,
            'concept': concept,
            'summary': summary ?? "",
            'image': image ?? "",
            'key_words': jsonEncode(keyWords),
            'directory': directory,
            'starred': starred ? 1 : 0,
            'created_at': now,
            'accessed_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      final int newID = (await batch.commit()).whereType<int>().toList()[0];
      newConstellationId = newID;
      print("test");
      constellations[constellations.length - 1].id = newID;
      final dependentBatch = txn.batch();
      var n = {
        'constellation_id': newID,
        'text': concept,
        'type': 0,
        'source': '',
        'created_at': now,
        'updated_at': now,
      };
      dependentBatch.insert('nodes', n);
      await dependentBatch.commit();
    });
    final List<Map<String, dynamic>> rows = await database.query("nodes");

    for (final row in rows) {
      print(row);
    }
    return newConstellationId;
  }

  Future<void> updateConstellation({
    required Database db,
    required int constellationId,
    String? name,
    String? concept,
    String? summary,
    String? image,
    List<String>? keyWords,
    int? starred,
  }) async {
    await db.transaction((txn) async {
      // Update constellation metadata
      String now = DateTime.now().toIso8601String();
      bool updated = false;
      final updateFields = <String, Object?>{};
      if (name != null) {
        updated = true;
        updateFields['name'] = name;
        setState(() {
          constellations[
                  constellations.indexWhere((e) => e.id == constellationId)]
              .name = name;
        });
      }
      if (concept != null) {
        updated = true;

        updateFields['concept'] = concept;
        setState(() {
          constellations[
                  constellations.indexWhere((e) => e.id == constellationId)]
              .concept = concept;
        });
      }
      if (summary != null) {
        updated = true;

        updateFields['summary'] = concept;
        setState(() {
          constellations[
                  constellations.indexWhere((e) => e.id == constellationId)]
              .summary = summary;
        });
      }
      if (image != null) {
        updated = true;

        updateFields['image'] = image;
        setState(() {
          constellations[
                  constellations.indexWhere((e) => e.id == constellationId)]
              .image = image;
        });
      }
      if (keyWords != null) {
        updated = true;

        updateFields['key_words'] = keyWords.toString();
        setState(() {
          constellations[
                  constellations.indexWhere((e) => e.id == constellationId)]
              .keyWords = keyWords;
        });
      }
      if (starred != null) {
        updated = true;

        updateFields['starred'] = starred;
        setState(() {
          constellations[
                  constellations.indexWhere((e) => e.id == constellationId)]
              .starred = starred;
        });
      }
      if (updated) {
        print("updated locally");
        setState(() {
          constellations[
                  constellations.indexWhere((e) => e.id == constellationId)]
              .updatedAt = now;
          updateConstellationsOrdering(constellations);
        });
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

    setState(() {
      constellations.removeWhere((e) => e.id == constellationId);
      updateConstellationsOrdering(constellations);
    });
  }

  void updateConstellationsOrdering(
    List<Constellation> unordered,
  ) {
    List<Constellation> starred = [];
    List<Constellation> unstarred = [];

    print("unordered");

    for (int i = 0; i < unordered.length; i++) {
      if (unordered[i].starred == 0) {
        unstarred.add(unordered[i]);
      } else {
        starred.add(unordered[i]);
      }
    }

    if (sortAttribute == 0) {
      unstarred.sort((a, b) =>
          DateTime.parse(b.accessedAt).compareTo(DateTime.parse(a.accessedAt)));
      starred.sort((a, b) =>
          DateTime.parse(b.accessedAt).compareTo(DateTime.parse(a.accessedAt)));
    } else if (sortAttribute == 1) {
      unstarred.sort((a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));
      starred.sort((a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));
    } else if (sortAttribute == 2) {
      unstarred.sort((a, b) =>
          DateTime.parse(b.updatedAt).compareTo(DateTime.parse(a.updatedAt)));
      starred.sort((a, b) =>
          DateTime.parse(b.updatedAt).compareTo(DateTime.parse(a.updatedAt)));
    } else {
      unstarred.sort((a, b) => a.name.compareTo(b.name));
    }
    setState(() {
      constellationsStarredOrdered = starred;
      constellationsUnstarredOrdered = unstarred;
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

  Future<List<Constellation>> getConstellationList() async {
    // Get a reference to the database.
    Database db = await database;

    // Query the table for all the files.
    final List<Map<String, Object?>> constellationMaps =
        await db.query('constellations');
    print("test");
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
                          constellationID: constellation.id,
                          constellationName: constellation.name,
                          constellationConcept: constellation.concept,
                        )
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
                                updateConstellation(
                                    db: database,
                                    constellationId: constellation.id,
                                    starred:
                                        (constellation.starred == 0 ? 1 : 0));
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
                                          editConstellationDialog(
                                              context, constellation)
                                        },
                                        child: Text('Edit'),
                                      ),
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
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              constellation.name == constellation.concept
                                  ? SizedBox()
                                  : Text(
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Color.fromARGB(
                                              255, 147, 147, 147)),
                                      constellation.concept),
                              Text(
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22),
                                  constellation.name)
                            ],
                          ),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  sortAttribute == 0
                                      ? const Text('Access Date:')
                                      : sortAttribute == 1
                                          ? const Text('Create Date')
                                          : const Text('Update Date:')
                                ]),
                                sortAttribute == 0
                                    ? Text(
                                        processDate(constellation.accessedAt))
                                    : sortAttribute == 1
                                        ? Text(processDate(
                                            constellation.createdAt))
                                        : Text(processDate(
                                            constellation.updatedAt))
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
    var existingItem =
        constellations.firstWhereOrNull((element) => element.name == name);

    return existingItem != null;
  }

  String _validname(String name) {
    int index = 0;
    String newname = name;
    while (
        constellations.firstWhereOrNull((element) => element.name == newname) !=
            null) {
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

                                              int constellationID =
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
                                                      builder: (context) => Test(
                                                          constellationID:
                                                              constellationID,
                                                          constellationName:
                                                              value,
                                                          constellationConcept:
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

  void editConstellationDialog(
      BuildContext context, Constellation constellation) {
    int starred = constellation.starred;
    TextEditingController nameController = TextEditingController(
        text: constellation.name == constellation.concept
            ? null
            : constellation.name);
    TextEditingController conceptController =
        TextEditingController(text: constellation.concept);
    List<int> keyWords = [];

    showDialog(
        context: context,
        barrierDismissible: true, //

        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Transform.translate(
                  offset: Offset(0, 0),
                  child: Dialog(
                      backgroundColor: Colors.transparent,
                      child: Container(
                          // height:MediaQuery.sizeOf(context).height,
                          child:
                              Stack(alignment: Alignment.topCenter, children: [
                        Card(
                            shape: const RoundedRectangleBorder(
                              side: BorderSide(width: 1),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(15),
                              ),
                            ),
                            color: Color.fromARGB(255, 255, 255, 255),
                            shadowColor: Colors.transparent,
                            child: Container(
                                width: 480,
                                height: 300,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                          margin: EdgeInsets.only(
                                              top: 10,
                                              left: 10,
                                              bottom: 10,
                                              right: 10),
                                          child: Row(children: [
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                    color: Color.fromARGB(
                                                        204, 235, 235, 235),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20)),
                                                child: Icon(Icons.gesture)),
                                            Spacer(),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  starred =
                                                      starred == 1 ? 0 : 1;
                                                });
                                              },
                                              icon: starred == 0
                                                  ? const Icon(
                                                      Icons
                                                          .star_outline_rounded,
                                                      size: 20,
                                                      color: Color.fromARGB(
                                                          255, 14, 14, 14))
                                                  : Icon(Icons.star_rounded,
                                                      size: 20,
                                                      color: Colors.black),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  starred =
                                                      starred == 1 ? 0 : 1;
                                                });
                                              },
                                              icon: Icon(
                                                  Icons.delete_outline_outlined,
                                                  size: 17,
                                                  color: Colors.black),
                                            ),
                                            Container(
                                                margin: EdgeInsets.all(10),
                                                child: OutlinedButton(
                                                    onPressed: () {
                                                      print(nameController
                                                          .text.isEmpty);
                                                      print(conceptController
                                                              .text ==
                                                          constellation
                                                              .concept);

                                                      updateConstellation(
                                                        db: database,
                                                        constellationId:
                                                            constellation.id,
                                                        name: ((nameController
                                                                    .text
                                                                    .isEmpty ||
                                                                nameController
                                                                        .text ==
                                                                    conceptController
                                                                        .text)
                                                            ? (conceptController
                                                                        .text ==
                                                                    nameController
                                                                        .text
                                                                ? null
                                                                : conceptController
                                                                    .text)
                                                            : nameController
                                                                        .text ==
                                                                    constellation
                                                                        .name
                                                                ? null
                                                                : nameController
                                                                    .text),
                                                        concept: conceptController
                                                                    .text ==
                                                                constellation
                                                                    .concept
                                                            ? null
                                                            : conceptController
                                                                .text,
                                                        starred: starred ==
                                                                constellation
                                                                    .starred
                                                            ? null
                                                            : starred,
                                                      );
                                                      Navigator.pop(context);
                                                    },
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      side: BorderSide(
                                                          color: const Color
                                                              .fromARGB(
                                                              255, 0, 0, 0),
                                                          width:
                                                              1), // border color and width
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(40),
                                                      ),
                                                    ),
                                                    child: Text("Save"))),
                                          ])),
                                      ListTile(
                                          title: Column(children: [
                                            Tooltip(
                                                margin: const EdgeInsets.only(
                                                    bottom: 10),
                                                preferBelow: false,
                                                message:
                                                    'Constellation concept',
                                                child: TextField(
                                                  controller: conceptController,
                                                  decoration: InputDecoration(
                                                    hintText: 'Enter text',
                                                    fillColor: Colors.grey[
                                                        200], // Background color
                                                    filled: true,
                                                    border: InputBorder
                                                        .none, // No underline
                                                    enabledBorder:
                                                        InputBorder.none,
                                                    focusedBorder:
                                                        InputBorder.none,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 10),
                                                  ),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20),
                                                )),
                                            SizedBox(height: 5),
                                            Tooltip(
                                                margin: const EdgeInsets.only(
                                                    top: 10),
                                                preferBelow: true,
                                                message: constellation.name ==
                                                        constellation.concept
                                                    ? 'By default this is the same as the concept'
                                                    : 'Constellation name',
                                                child: TextField(
                                                  controller: nameController,
                                                  decoration: InputDecoration(
                                                    hintStyle: TextStyle(
                                                        color: const Color
                                                            .fromARGB(255, 128,
                                                            128, 128)),
                                                    hintText: 'Enter name',
                                                    fillColor: Colors.grey[
                                                        200], // Background color
                                                    filled: true,
                                                    border: InputBorder
                                                        .none, // No underline
                                                    enabledBorder:
                                                        InputBorder.none,
                                                    focusedBorder:
                                                        InputBorder.none,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 10),
                                                  ),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 25),
                                                )),
                                            SizedBox(height: 10),
                                          ]),
                                          subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(children: [
                                                  Text('Update Date')
                                                ]),
                                                Text(processDate(DateTime.now()
                                                    .toIso8601String()))
                                              ]))
                                    ]))),
                        Transform.translate(
                          offset: Offset(0, 0),
                          child: Container(
                            margin: EdgeInsets.only(top: 340),
                            width: 480,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                              color: dashboardColor,
                              border: Border.all(width: 1, color: Colors.black),
                            ),
                            child: Container(
                              width: 480,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: TextFormField(
                                onChanged: (value) => {
                                  setState(() {
                                    validNewConstellationName = true;
                                  })
                                },
                                autofocus: true,
                                controller: newConstellationNameController,
                                decoration: const InputDecoration(
                                    hintText: "Add key term",
                                    border: InputBorder.none,
                                    icon: Icon(Icons.add)),
                                onFieldSubmitted: (value) async {
                                  _formKey.currentState?.save();

                                  if (value.isEmpty) {
                                    setState(() {
                                      validNewConstellationName = false;
                                    });
                                    return;
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ]))));
            },
          );
        });
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
        body: constellations.isEmpty
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
                                    Spacer(),
                                    Container(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 8),
                                        child: DropdownButton<String>(
                                          elevation: 0,
                                          underline:
                                              SizedBox(), // Removes underline
                                          dropdownColor: Colors
                                              .white, // White background for dropdown
                                          style: TextStyle(
                                              color:
                                                  Colors.black), // Text color
                                          iconEnabledColor: Colors
                                              .black, // Dropdown arrow color
                                          value:
                                              sortAttributeList[sortAttribute],
                                          items: sortAttributeList
                                              .map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value.toString()),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            setState(() {
                                              if (newValue != null) {
                                                sortAttribute =
                                                    sortAttributeList
                                                        .indexOf(newValue);
                                              }
                                              updateConstellationsOrdering(
                                                  constellations);
                                            });
                                          },
                                        )),
                                    SizedBox(width: 26)
                                  ])),
                              constellationsStarredOrdered.isNotEmpty
                                  ? Container(
                                      margin: EdgeInsets.only(
                                          right: 30, bottom: 15, top: 15),
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
                                              constellationsStarredOrdered
                                                  .length,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            return dashboardConstellationCard(
                                                constellationsStarredOrdered[
                                                    index],
                                                context);
                                          }))
                                  : const SizedBox(),
                              (constellationsStarredOrdered.isNotEmpty &&
                                      constellationsUnstarredOrdered.isNotEmpty)
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
                                          constellationsUnstarredOrdered.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        return dashboardConstellationCard(
                                            constellationsUnstarredOrdered[
                                                index],
                                            context);
                                      })),
                              SizedBox(height: 20)
                            ]))),
              ));
  }
}
