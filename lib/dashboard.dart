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

class DBFile {
  final int id;
  String filePath;
  String fileName;
  final String createDate;
  String accessDate;
  String updateDate;
  List tags;
  int starred;
  int existingFile; //boolean: 0 or 1

  DBFile({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.createDate,
    required this.accessDate,
    required this.updateDate,
    required this.tags,
    required this.starred,
    required this.existingFile,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'createDate': createDate,
      'accessDate': accessDate,
      'updateDate': updateDate,
      'tags': jsonEncode(tags),
      'starred': starred,
      'existingFile': existingFile
    };
  }

  @override
  String toString() {
    return 'DBFile(id: $id, filePath: $filePath, fileName: $fileName, createDate: $createDate, accessDate: $accessDate, updateDate: $updateDate, tags: ${tags.toString()}, starred: $starred, existingFile: $existingFile)';
  }
}

class Node {
  String nodeTerm;
  List<String> auxiliaries;
  String color;
  final String createDate;
  String updateDate;

  Node(
      {required this.nodeTerm,
      required this.auxiliaries,
      required this.color,
      required this.createDate,
      required this.updateDate});
  Map<String, Object?> toMap() {
    return {
      'nodeTerm': nodeTerm,
      'auxiliaries': jsonEncode(auxiliaries),
      'color': color,
      'createDate': createDate,
      'updateDate': updateDate,
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

  //List of files in directory

  final _formKey = GlobalKey<FormState>();
  TextEditingController newConstellationNameController =
      TextEditingController();
  String directoryName = "";
  List<String> fileNameList = [];

  //list of all files retrieved from db
  List<DBFile> directoryFiles = [];

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
  var fileDatabase;
  var nodeDatabase;
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

  _asyncLoadDB() async {
    WidgetsFlutterBinding.ensureInitialized();

    fileDatabase = openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await getDatabasesPath(), 'lynklynk_file_database.db'),
      // When the database is first created, create a table to store files.
      onCreate: (db, version) {
        // Run the CREATE TABLE statement on the database.
        return db.execute(
          'CREATE TABLE files(id INTEGER PRIMARY KEY, filePath TEXT, fileName TEXT, createDate TEXT, accessDate TEXT, updateDate TEXT, tags TEXT, starred INTEGER, existingFile INTEGER)',
        );
      },
      onUpgrade: _onUpgrade,
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 4,
    );

    nodeDatabase = await openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await getDatabasesPath(), 'lynklynk_node_database.db'),
      // When the database is first created, create a table to store files.
      onUpgrade: _onUpgradeNodeDB,
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 6,
    );

    try {
      List<DBFile> queryResultsList = await getDBFileList();

      setState(() {
        directoryFiles = queryResultsList;
        updateDirectoryFilesOrdering(directoryFiles);
        checkboxList = List<bool>.filled(queryResultsList.length, false);
        fileNameList = queryResultsList.map((e) => e.fileName).toList();
      });
    } catch (e) {
      print(e);
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      loading = false;
    });
  }

  void updateDirectoryFilesOrdering(
    List<DBFile> unordered,
  ) {
    List<DBFile> starred = [];
    List<DBFile> unstarred = [];

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
          DateTime.parse(b.createDate).compareTo(DateTime.parse(a.createDate)));
      starred.sort((a, b) =>
          DateTime.parse(b.createDate).compareTo(DateTime.parse(a.createDate)));
    } else if (sortAttribute == 1) {
      unstarred.sort((a, b) =>
          DateTime.parse(b.updateDate).compareTo(DateTime.parse(a.updateDate)));
      starred.sort((a, b) =>
          DateTime.parse(b.updateDate).compareTo(DateTime.parse(a.updateDate)));
    } else {
      unstarred.sort((a, b) => a.fileName.compareTo(b.fileName));
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

  Future<void> updateFiles() async {
    try {
      List<DBFile> queryResultsList = await getDBFileList();
      print(queryResultsList);
      setState(() {
        directoryFiles = queryResultsList;
        updateDirectoryFilesOrdering(directoryFiles);
        fileNameList = queryResultsList.map((e) => e.fileName).toList();
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> insertDBFile(DBFile file) async {
    final db = await fileDatabase;
    await db.insert(
      'files',
      file.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    var nodeDB = await nodeDatabase;
    await nodeDB.execute(
      'CREATE TABLE "${file.fileName}_${file.id.toString()}"(id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, nodeTerm TEXT, auxiliaries TEXT, color TEXT, createDate TEXT, updateDate TEXT, image INTEGER NOT NULL DEFAULT (0), tag TEXT NOT NULL DEFAULT "")',
    );
    if (file.existingFile == 1) {
      insertNodes(file);
    }
    updateFiles();
  }

  Future<void> insertNodes(DBFile file) async {
    String filePath = file.filePath;
    File readFile = File(filePath);
    final contents = await readFile.readAsString();
    List<String> fileArray = contents.split("\n");
    fileArray.removeWhere((e) => e.trim().isEmpty);
    var nodeDB = await nodeDatabase;
    String currentDateTime = DateTime.now().toString();
    for (int i = 0; i < fileArray.length; i++) {
      await nodeDB.insert(
        '"${file.fileName}_${file.id.toString()}"',
        Node(
                nodeTerm: fileArray[i],
                auxiliaries: [],
                color: Color.fromARGB(255, 224, 224, 224).toString(),
                createDate: currentDateTime,
                updateDate: currentDateTime)
            .toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<DBFile>> getDBFileList() async {
    // Get a reference to the database.
    final db = await fileDatabase;

    // Query the table for all the files.
    final List<Map<String, Object?>> fileMaps = await db.query('files');

    // Convert the list of each file's fields into a list of `file` objects.
    return [
      for (final {
            'id': id as int,
            'filePath': filePath as String,
            'fileName': fileName as String,
            'createDate': createDate as String,
            'accessDate': accessDate as String,
            'updateDate': updateDate as String,
            'tags': tags as String,
            'starred': starred as int,
            'existingFile': existingFile as int,
          } in fileMaps)
        DBFile(
            id: id,
            filePath: filePath,
            fileName: fileName,
            createDate: createDate,
            accessDate: accessDate,
            updateDate: updateDate,
            tags: json.decode(tags),
            starred: starred,
            existingFile: existingFile),
    ];
  }

  Future<void> updateDBFile(DBFile file) async {
    // Get a reference to the database.
    final db = await fileDatabase;

    // Update the given Dfile.
    await db.update(
      'files',
      file.toMap(),
      // Ensure that the file has a matching id.
      where: 'id = ?',
      // Pass the file's id as a whereArg to prevent SQL injection.
      whereArgs: [file.id],
    );

    updateFiles();
  }

  Future<void> deleteDBFile(int id, String fileName) async {
    // Get a reference to the database.
    final db = await fileDatabase;
    final nodeDB = await nodeDatabase;

    // Remove the file from the database.
    await db.delete(
      'files',
      // Use a `where` clause to delete a specific file.
      where: 'id = ?',
      // Pass the file's id as a whereArg to prevent SQL injection.
      whereArgs: [id],
    );

    await nodeDB.execute('DROP TABLE IF EXISTS "${fileName}_$id"');
    updateFiles();
    currentlySelectedSet = -1;
  }

  void createFile(String fileName) {
    new File('path/to/file').create(recursive: true);
  }

  String validateFileToTableName(String fileName) {
    return fileName.replaceAll(" ", "_");
  }

  List<String> fileNameSearchSuggestionList(String searchParam,
      {bool caseSensitive = true}) {
    List<String> ret = fileNameList
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

  Widget dashboardConstellationCard(DBFile file, BuildContext context) {
    return Container(

        // decoration:
        //     BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
        child: GestureDetector(
            onDoubleTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        Test(constellationName: file.fileName, id: file.id)
                    // Editor(
                    //       path: pathName,
                    //       isPath: true,
                    //       fileName: name.split(".")[0],
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
                                  if (file.starred == 0) {
                                    file.starred = 1;
                                  } else {
                                    file.starred = 0;
                                  }
                                  updateDBFile(file);
                                });
                              },
                              icon: file.starred == 0
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
                                          deleteDBFile(file.id, file.fileName)
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
                              file.fileName),
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
                                    ? Text(processDate(file.accessDate))
                                    : sortAttribute == 1
                                        ? Text(processDate(file.createDate))
                                        : Text(processDate(file.updateDate))
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

  bool _validateFileName(String name) {
    var existingItem =
        fileNameList.firstWhereOrNull((element) => element == name);
    print(fileNameList);
    return existingItem != null;
  }

  String _validFileName(String name) {
    int index = 0;
    String newFileName = name;
    while (fileNameList.firstWhereOrNull((element) => element == newFileName) !=
        null) {
      index += 1;
      newFileName = "$name ($index)";
    }

    return newFileName;
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
        body: loading
            ? Container(
                color: dashboardColor,
                child: Center(
                    child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Lynk',
                      style: TextStyle(
                          fontSize: 50.0,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 50.0,
                        fontWeight: FontWeight.w200,
                      ),
                      child: AnimatedTextKit(
                        isRepeatingAnimation: false,
                        animatedTexts: [
                          RotateAnimatedText('Lynk ',
                              duration: const Duration(milliseconds: 1000),
                              rotateOut: false),
                        ],
                      ),
                    ),
                  ],
                )))
            : AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  decoration: const BoxDecoration(
                    color:
                        Color.fromARGB(251, 255, 255, 255), // Background color
                  ),
                  padding: EdgeInsets.only(bottom: 10, right: 10, left: 10),
                  child: Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(left: 25),
                          child: ListView(
                              // mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Tooltip(
                                          margin:
                                              const EdgeInsets.only(bottom: 20),
                                          preferBelow: false,
                                          message: 'Create a study file',
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
                                                  icon: const Icon(Icons.add,
                                                      color: Colors.black),
                                                  iconSize: 30,
                                                  style: IconButton.styleFrom(
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        40)),
                                                  ),
                                                  onPressed: () {
                                                    showModalBottomSheet<void>(
                                                      isScrollControlled: true,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      context: context,
                                                      enableDrag: true,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10)),
                                                      builder: (BuildContext
                                                          context) {
                                                        return Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: <Widget>[
                                                            FractionallySizedBox(
                                                              widthFactor: 1,
                                                              child: Form(
                                                                key: _formKey,
                                                                child: Stack(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  children: <Widget>[
                                                                    Container(
                                                                        height:
                                                                            400,
                                                                        margin: EdgeInsets.only(
                                                                            bottom:
                                                                                150),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.only(
                                                                            bottomRight:
                                                                                Radius.circular(40),
                                                                          ),
                                                                          color:
                                                                              dashboardColor,
                                                                          border: Border.all(
                                                                              width: 2,
                                                                              color: Colors.black),
                                                                        ),
                                                                        child:
                                                                            Column(
                                                                          children: [
                                                                            Container(
                                                                                decoration: BoxDecoration(color: primary2, border: Border(bottom: BorderSide(width: 2, color: Colors.black))),
                                                                                constraints: BoxConstraints(maxHeight: 40),
                                                                                child: Row(
                                                                                  children: [
                                                                                    Spacer(),
                                                                                    Container(
                                                                                      alignment: Alignment.center,
                                                                                      height: 24,
                                                                                      width: 24,
                                                                                      margin: EdgeInsets.all(8),
                                                                                      decoration: BoxDecoration(color: const Color.fromARGB(255, 240, 159, 154), border: Border.all(width: 2, color: Colors.black), shape: BoxShape.circle),
                                                                                      child: IconButton(
                                                                                        padding: EdgeInsets.zero,
                                                                                        color: Colors.white,
                                                                                        icon: Icon(size: 14, Icons.clear),
                                                                                        onPressed: () => Navigator.pop(context),
                                                                                      ),
                                                                                    )
                                                                                  ],
                                                                                )),
                                                                            SizedBox(height: 50),
                                                                            Container(
                                                                              padding: EdgeInsets.all(20),
                                                                              child: TextFormField(
                                                                                controller: newConstellationNameController,

                                                                                // The validator receives the text that the user has entered.
                                                                                validator: (value) {
                                                                                  if ((value == null || value.isEmpty)) {
                                                                                    return 'Please enter some text';
                                                                                  }
                                                                                  if (_validateFileName(value)) {
                                                                                    return 'File name already exists';
                                                                                  }
                                                                                  return null;
                                                                                },
                                                                              ),
                                                                            ),
                                                                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                                              TextButton(
                                                                                onPressed: () async {
                                                                                  if (_formKey.currentState!.validate()) {
                                                                                    _formKey.currentState?.save();
                                                                                    String constellationName = newConstellationNameController.text;
                                                                                    print(constellationName);

                                                                                    setState(() {
                                                                                      newConstellationNameController = TextEditingController();
                                                                                    });

                                                                                    String currentDateTime = DateTime.now().toString();
                                                                                    int id = directoryFiles.isEmpty ? 0 : directoryFiles.last.id + 1;
                                                                                    await insertDBFile(DBFile(id: id, filePath: "$directoryName/$constellationName.txt", fileName: constellationName, createDate: currentDateTime, accessDate: currentDateTime, updateDate: currentDateTime, tags: [], starred: 0, existingFile: 0));

                                                                                    if (context.mounted) {
                                                                                      Navigator.pop(context);
                                                                                      Navigator.push(
                                                                                        context,
                                                                                        MaterialPageRoute(builder: (context) => Test(id: id, constellationName: constellationName)
                                                                                            // Editor(path: "$directoryName/$constellationName.txt", isPath: true, fileName: constellationName)
                                                                                            ),
                                                                                      );
                                                                                    }
                                                                                  }
                                                                                },
                                                                                child: const Text('Create'),
                                                                              ),
                                                                              const SizedBox(width: 5),
                                                                            ]),
                                                                          ],
                                                                        )),
                                                                    Container(
                                                                      decoration: BoxDecoration(
                                                                          color: Colors
                                                                              .white,
                                                                          border: Border.all(
                                                                              width: 2.5,
                                                                              color: Colors.black),
                                                                          borderRadius: BorderRadius.all(Radius.circular(50))),
                                                                      margin: EdgeInsets.only(
                                                                          bottom:
                                                                              470),
                                                                      child: Icon(
                                                                          size:
                                                                              50,
                                                                          Pelaicons
                                                                              .upload1LightOutline),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  }))),
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
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        40)),
                                                  ),
                                                  onPressed: () async {
                                                    FilePickerResult?
                                                        fileUploadResult =
                                                        await FilePicker
                                                            .platform
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
                                                    String defaultFileName =
                                                        './samples/test.txt';
                                                    String fileNameMaintain =
                                                        defaultFileName;
                                                    for (int i = 0;
                                                        i <
                                                            fileUploadResult
                                                                .paths.length;
                                                        i++) {
                                                      String filePath =
                                                          fileUploadResult
                                                                  .paths[i] ??
                                                              "./samples/test.txt";
                                                      String fileName =
                                                          (fileUploadResult
                                                                          .names[
                                                                      i] ??
                                                                  "test.txt")
                                                              .split(".")[0];

                                                      String validFileName =
                                                          _validFileName(
                                                              fileName);
                                                      setState(() {
                                                        fileNameList
                                                            .add(validFileName);
                                                        newConstellationNameController =
                                                            TextEditingController(
                                                                text: _validFileName(
                                                                    "Constellation"));
                                                      });
                                                      if (i == 0) {
                                                        fileNameMaintain =
                                                            validFileName;
                                                      }

                                                      String currentDateTime =
                                                          DateTime.now()
                                                              .toString();
                                                      await insertDBFile(DBFile(
                                                          id:
                                                              directoryFiles
                                                                      .isEmpty
                                                                  ? 0
                                                                  : directoryFiles
                                                                          .last
                                                                          .id +
                                                                      1,
                                                          filePath: filePath,
                                                          fileName:
                                                              validFileName,
                                                          createDate:
                                                              currentDateTime,
                                                          accessDate:
                                                              currentDateTime,
                                                          updateDate:
                                                              currentDateTime,
                                                          tags: [],
                                                          starred: 0,
                                                          existingFile: 1));
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
                                              color: Colors.black,
                                              fontSize: 25)),
                                    ])),
                                directoryFilesStarredOrdered.isNotEmpty
                                    ? Container(
                                        margin: EdgeInsets.only(
                                            right: 30, bottom: 15, top: 10),
                                        child: GridView.builder(
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: MediaQuery.sizeOf(
                                                              context)
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
                                            directoryFilesUnstarredOrdered
                                                .length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          return dashboardConstellationCard(
                                              directoryFilesUnstarredOrdered[
                                                  index],
                                              context);
                                        })),
                                SizedBox(height: 20)
                              ]))),
                )));
  }
}
