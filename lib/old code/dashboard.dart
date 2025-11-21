// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/widgets.dart';
// import 'package:lynklynk/highlighter.dart';
// import 'package:window_manager/window_manager.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:collection/collection.dart';
// import 'package:lynklynk/constellation.dart';
// import 'package:path/path.dart';
// import 'package:intl/intl.dart';
// import 'package:dropdown_button2/dropdown_button2.dart';
// import 'package:pelaicons/pelaicons.dart';
// import 'package:animated_text_kit/animated_text_kit.dart';

// class Constellation {
//   final int id;
//   String filePath;
//   String fileName;
//   final String createDate;
//   String accessDate;
//   String updateDate;
//   List tags;
//   int starred;
//   int existingFile; //boolean: 0 or 1

//   Constellation({
//     required this.id,
//     required this.filePath,
//     required this.fileName,
//     required this.createDate,
//     required this.accessDate,
//     required this.updateDate,
//     required this.tags,
//     required this.starred,
//     required this.existingFile,
//   });

//   Map<String, Object?> toMap() {
//     return {
//       'id': id,
//       'filePath': filePath,
//       'fileName': fileName,
//       'createDate': createDate,
//       'accessDate': accessDate,
//       'updateDate': updateDate,
//       'tags': jsonEncode(tags),
//       'starred': starred,
//       'existingFile': existingFile
//     };
//   }

//   @override
//   String toString() {
//     return 'Constellation(id: $id, filePath: $filePath, fileName: $fileName, createDate: $createDate, accessDate: $accessDate, updateDate: $updateDate, tags: ${tags.toString()}, starred: $starred, existingFile: $existingFile)';
//   }
// }

// class Node {
//   String nodeTerm;
//   List<String> auxiliaries;
//   String color;
//   final String createDate;
//   String updateDate;

//   Node(
//       {required this.nodeTerm,
//       required this.auxiliaries,
//       required this.color,
//       required this.createDate,
//       required this.updateDate});
//   Map<String, Object?> toMap() {
//     return {
//       'nodeTerm': nodeTerm,
//       'auxiliaries': jsonEncode(auxiliaries),
//       'color': color,
//       'createDate': createDate,
//       'updateDate': updateDate,
//     };
//   }
// }

// class Dashboard extends StatefulWidget {
//   const Dashboard({super.key});

//   @override
//   _Dashboard createState() => _Dashboard();
// }

// class _Dashboard extends State<Dashboard> {
//   //Page Scroller
//   ScrollController? scroller;

//   bool appMaximized = false;

//   bool validNewConstellationName = true;

//   //List of files in directory

//   final _formKey = GlobalKey<FormState>();
//   TextEditingController newConstellationNameController =
//       TextEditingController();
//   String directoryName = "";
//   List<String> fileNameList = [];

//   //list of all files retrieved from db
//   List<Constellation> directoryFiles = [];

//   //list of all files retrieved from db sorted by attribute (default accessed date)
//   List directoryFilesStarredOrdered = [];
//   List directoryFilesUnstarredOrdered = [];

//   //string attribute by which directoryFilesOrdered is sorted by (most recent at top)
//   int sortAttribute = 0;

//   //list of attributes by which directoryFilesOrdered can be sorted by
//   List<String> sortAttributeList = [
//     "Access",
//     "Create",
//     "Update",
//     "Alphabetical"
//   ];
//   bool loading = true;
//   FontWeight loadingFontWeight = FontWeight.w100;
//   Color loadingFontColor = const Color.fromRGBO(238, 165, 166, 1);
//   bool loadingColor = false;
//   bool visible = true;

//   //currently selected set
//   int currentlySelectedSet = -1;
//   // Color dashboardColor = const Color.fromRGBO(252, 231, 200, 1);
//   // Color primary1 = const Color.fromRGBO(177, 194, 158, 1);
//   // Color primary2 = const Color.fromRGBO(250, 218, 122, 1);
//   // Color primary3 = const Color.fromRGBO(240, 160, 75, 1);

//   // Color dashboardColor = const Color.fromARGB(255, 78, 62, 110);
//   Color dashboardColor = Colors.white;
//   Color primary1 = const Color.fromARGB(255, 112, 103, 179);
//   Color primary2 = const Color.fromRGBO(203, 128, 171, 1);
//   Color primary3 = const Color.fromRGBO(238, 165, 166, 1);

//   Color secondaryColor = const Color.fromARGB(255, 82, 72, 159);
//   List<bool> checkboxList = [];
//   int checkBoxActiveCount = 0;
//   var fileDatabase;
//   int databaseID = 0;

//   @override
//   void initState() {
//     scroller = ScrollController();
//     if (Platform.isWindows || Platform.isLinux) {
//       // Initialize FFI
//       sqfliteFfiInit();
//     }
//     databaseFactory = databaseFactoryFfi;
//     _loadDirectory();
//     _asyncLoad();
//     _asyncLoadDB();

//     super.initState();
//   }

//   @override
//   void dispose() {
//     super.dispose();
//   }

//   _asyncLoad() async {
//     String databasesPath = await getDatabasesPath();

// // Make sure the directory exists
//     try {
//       await Directory(databasesPath).create(recursive: true);
//     } catch (_) {
//       print("Error creating directory");
//     }
//   }

//   Future<void> dropAllTables(Database db) async {
//     // Step 1: Get all user-defined table names
//     final tables = await db.rawQuery('''
//     SELECT name FROM sqlite_master 
//     WHERE type = 'table' AND name NOT LIKE 'sqlite_%';
//   ''');

//     // Step 2: Drop each table
//     for (final table in tables) {
//       final tableName = table['name'];
//       await db.execute('DROP TABLE IF EXISTS $tableName');
//     }
//   }

//   Future<void> deleteMyDatabase(String dbName) async {
//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, dbName);

//     // Delete the database file
//     await deleteDatabase(path);
//     print("Database deleted.");
//   }

//   _asyncLoadDB() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     deleteMyDatabase('lynklynk_file_database.db');
//     fileDatabase = openDatabase(
//       join(await getDatabasesPath(), 'lynklynk_database.db'),
//       onCreate: (db, version) async {
//         // Constellations table
//         await db.execute(
//           '''CREATE TABLE constellations(
//               id INTEGER PRIMARY KEY, 
//               name TEXT, 
//               concept TEXT, 
//               key_words TEXT, 
//               directory TEXT,
//               starred INTEGER,
//               created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
//               accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
//               updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
//             )''',
//         );

//         // Nodes table
//         await db.execute(
//           '''CREATE TABLE nodes(
//               id INTEGER PRIMARY KEY, 
//               constellation_id INTEGER NOT NULL,
//               text TEXT UNIQUE NOT NULL, 
//               type INTEGER NOT NULL, 
//               source TEXT, 
//               created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
//               updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
//               FOREIGN KEY (constellation_id) REFERENCES constellations(id) ON DELETE CASCADE
//             )''',
//         );

//         // Edges table
//         await db.execute(
//           '''CREATE TABLE edges(
//               id INTEGER PRIMARY KEY, 
//               constellation_id INTEGER NOT NULL,
//               from_node_id INTEGER NOT NULL,
//               to_node_id INTEGER NOT NULL,
//               relation TEXT, 
//               created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
//               updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
//               FOREIGN KEY (constellation_id) REFERENCES constellations(id) ON DELETE CASCADE,
//               FOREIGN KEY (from_node_id) REFERENCES nodes(id),
//               FOREIGN KEY (to_node_id) REFERENCES nodes(id)
//             )''',
//         );
//       },
//       onUpgrade: _onUpgrade,
//       version: 1,
//     );

//     try {
//       List<Constellation> queryResultsList = await getConstellationList();

//       setState(() {
//         directoryFiles = queryResultsList;
//         updateDirectoryFilesOrdering(directoryFiles);
//         checkboxList = List<bool>.filled(queryResultsList.length, false);
//         fileNameList = queryResultsList.map((e) => e.fileName).toList();
//       });
//     } catch (e) {
//       print(e);
//     }

//     await Future.delayed(const Duration(milliseconds: 1500));
//     setState(() {
//       loading = false;
//     });
//   }

//   Future<void> createConstellation({
//     required Database db,
//     required String name,
//     required String concept,
//     required String keyWords,
//     required List<Map<String, dynamic>>
//         nodes, // Each with 'text', 'type', 'source'
//     required List<Map<String, dynamic>>
//         edges, // Each with 'from_text', 'to_text', 'relation'
//     bool starred = false,
//   }) async {
//     await db.transaction((txn) async {
//       // 1. Insert the constellation
//       final constellationId = await txn.insert('constellations', {
//         'name': name,
//         'concept': concept,
//         'key_words': keyWords,
//         'starred': starred ? 1 : 0,
//       });

//       // 2. Insert the nodes and keep track of inserted IDs by their text
//       Map<String, int> nodeTextToId = {};

//       for (final node in nodes) {
//         final nodeId = await txn.insert('nodes', {
//           'constellation_id': constellationId,
//           'text': node['text'],
//           'type': node['type'],
//           'source': node['source'],
//         });
//         nodeTextToId[node['text']] = nodeId;
//       }

//       // 3. Insert the edges using node text references
//       for (final edge in edges) {
//         final fromId = nodeTextToId[edge['from_text']];
//         final toId = nodeTextToId[edge['to_text']];

//         if (fromId != null && toId != null) {
//           await txn.insert('edges', {
//             'constellation_id': constellationId,
//             'from_node_id': fromId,
//             'to_node_id': toId,
//             'text': edge['text'],
//             'relation': edge['relation'],
//           });
//         } else {
//           throw Exception(
//               'Edge references unknown node text: ${edge['from_text']} or ${edge['to_text']}');
//         }
//       }
//     });
//   }

//   void updateDirectoryFilesOrdering(
//     List<Constellation> unordered,
//   ) {
//     List<Constellation> starred = [];
//     List<Constellation> unstarred = [];

//     for (int i = 0; i < unordered.length; i++) {
//       if (unordered[i].starred == 0) {
//         unstarred.add(unordered[i]);
//       } else {
//         starred.add(unordered[i]);
//       }
//     }

//     if (sortAttribute == 0) {
//       unstarred.sort((a, b) =>
//           DateTime.parse(b.accessDate).compareTo(DateTime.parse(a.accessDate)));
//       starred.sort((a, b) =>
//           DateTime.parse(b.accessDate).compareTo(DateTime.parse(a.accessDate)));
//     } else if (sortAttribute == 1) {
//       unstarred.sort((a, b) =>
//           DateTime.parse(b.createDate).compareTo(DateTime.parse(a.createDate)));
//       starred.sort((a, b) =>
//           DateTime.parse(b.createDate).compareTo(DateTime.parse(a.createDate)));
//     } else if (sortAttribute == 1) {
//       unstarred.sort((a, b) =>
//           DateTime.parse(b.updateDate).compareTo(DateTime.parse(a.updateDate)));
//       starred.sort((a, b) =>
//           DateTime.parse(b.updateDate).compareTo(DateTime.parse(a.updateDate)));
//     } else {
//       unstarred.sort((a, b) => a.fileName.compareTo(b.fileName));
//     }
//     setState(() {
//       directoryFilesStarredOrdered = starred;
//       directoryFilesUnstarredOrdered = unstarred;
//     });
//   }

//   Future<List<String>> getAllTableNames(Database db) async {
// // you can use your initial name for dbClient

//     List<Map> maps =
//         await db.rawQuery('SELECT * FROM sqlite_master ORDER BY name;');

//     List<String> tableNameList = [];
//     if (maps.length > 0) {
//       for (int i = 0; i < maps.length; i++) {
//         try {
//           tableNameList.add(maps[i]['name'].toString());
//         } catch (e) {}
//       }
//     }
//     return tableNameList;
//   }

//   // UPGRADE DATABASE TABLES
//   void _onUpgrade(Database db, int oldVersion, int newVersion) {
//     try {
//       // if (oldVersion < 2) {
//       //   db.execute(
//       //       "ALTER TABLE files ADD COLUMN starred INTEGER NOT NULL DEFAULT (0);");
//       // }

//       // if (oldVersion < 3) {
//       //   db.execute(
//       //       "ALTER TABLE files ADD COLUMN existingFile INTEGER NOT NULL DEFAULT (0);");
//       // }

//       if (oldVersion < 4) {
//         db.execute(
//             'ALTER TABLE files RENAME COLUMN "fileDirectory" TO filePath');
//       }
//       print("Upgrade successful");
//     } catch (e) {
//       print("Upgrade failed: ");
//       print(e);
//     }
//   }

//   void _onUpgradeNodeDB(Database db, int oldVersion, int newVersion) async {
//     try {
//       List<String> tableNames = await getAllTableNames(db);
//       print(tableNames);
//       if (oldVersion < 6) {
//         for (int i = 0; i < tableNames.length - 1; i++) {
//           // await db.execute(
//           //     'ALTER TABLE "${tableNames[i]}" ADD COLUMN image INTEGER NOT NULL DEFAULT (0);');
//           await db.execute(
//               'ALTER TABLE "${tableNames[i]}" ADD COLUMN tag TEXT NOT NULL DEFAULT "";');
//         }
//       }

//       print("Upgrade successful");
//     } catch (e) {
//       print("Upgrade failed: ");
//       print(e);
//     }
//   }

//   Future<void> updateFiles() async {
//     try {
//       List<Constellation> queryResultsList = await getConstellationList();
//       print(queryResultsList);
//       setState(() {
//         directoryFiles = queryResultsList;
//         updateDirectoryFilesOrdering(directoryFiles);
//         fileNameList = queryResultsList.map((e) => e.fileName).toList();
//       });
//     } catch (e) {
//       print(e);
//     }
//   }

//   Future<void> insertConstellation(Constellation file) async {
//     final db = await fileDatabase;
//     await db.insert(
//       'files',
//       file.toMap(),
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );

//     var nodeDB = await nodeDatabase;
//     await nodeDB.execute(
//       'CREATE TABLE "${file.fileName}_${file.id.toString()}"(id INTEGER PRIMARY KEY, text TEXT UNIQUE NOT NULL, type INTEGER NOT NULL, source TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP , updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, )',
//     );
//     if (file.existingFile == 1) {
//       insertNodes(file);
//     }
//     updateFiles();
//   }

//   Future<void> insertNodes(Constellation file) async {
//     String filePath = file.filePath;
//     File readFile = File(filePath);
//     final contents = await readFile.readAsString();
//     List<String> fileArray = contents.split("\n");
//     fileArray.removeWhere((e) => e.trim().isEmpty);
//     var nodeDB = await nodeDatabase;
//     String currentDateTime = DateTime.now().toString();
//     for (int i = 0; i < fileArray.length; i++) {
//       await nodeDB.insert(
//         '"${file.fileName}_${file.id.toString()}"',
//         Node(
//                 nodeTerm: fileArray[i],
//                 auxiliaries: [],
//                 color: Color.fromARGB(255, 224, 224, 224).toString(),
//                 createDate: currentDateTime,
//                 updateDate: currentDateTime)
//             .toMap(),
//         conflictAlgorithm: ConflictAlgorithm.replace,
//       );
//     }
//   }

//   Future<List<Constellation>> getConstellationList() async {
//     // Get a reference to the database.
//     final db = await fileDatabase;

//     // Query the table for all the files.
//     final List<Map<String, Object?>> fileMaps = await db.query('files');

//     // Convert the list of each file's fields into a list of `file` objects.
//     return [
//       for (final {
//             'id': id as int,
//             'filePath': filePath as String,
//             'fileName': fileName as String,
//             'createDate': createDate as String,
//             'accessDate': accessDate as String,
//             'updateDate': updateDate as String,
//             'tags': tags as String,
//             'starred': starred as int,
//             'existingFile': existingFile as int,
//           } in fileMaps)
//         Constellation(
//             id: id,
//             filePath: filePath,
//             fileName: fileName,
//             createDate: createDate,
//             accessDate: accessDate,
//             updateDate: updateDate,
//             tags: json.decode(tags),
//             starred: starred,
//             existingFile: existingFile),
//     ];
//   }

//   Future<void> updateConstellation(Constellation file) async {
//     // Get a reference to the database.
//     final db = await fileDatabase;

//     // Update the given Dfile.
//     await db.update(
//       'files',
//       file.toMap(),
//       // Ensure that the file has a matching id.
//       where: 'id = ?',
//       // Pass the file's id as a whereArg to prevent SQL injection.
//       whereArgs: [file.id],
//     );

//     updateFiles();
//   }

//   Future<void> deleteConstellation(int id, String fileName) async {
//     // Get a reference to the database.
//     final db = await fileDatabase;
//     final nodeDB = await nodeDatabase;

//     // Remove the file from the database.
//     await db.delete(
//       'files',
//       // Use a `where` clause to delete a specific file.
//       where: 'id = ?',
//       // Pass the file's id as a whereArg to prevent SQL injection.
//       whereArgs: [id],
//     );

//     await nodeDB.execute('DROP TABLE IF EXISTS "${fileName}_$id"');
//     updateFiles();
//     currentlySelectedSet = -1;
//   }

//   void createFile(String fileName) {
//     new File('path/to/file').create(recursive: true);
//   }

//   String validateFileToTableName(String fileName) {
//     return fileName.replaceAll(" ", "_");
//   }

//   List<String> fileNameSearchSuggestionList(String searchParam,
//       {bool caseSensitive = true}) {
//     List<String> ret = fileNameList
//         .where((e) => caseSensitive
//             ? e.startsWith(searchParam)
//             : e.toLowerCase().startsWith(searchParam.toLowerCase()))
//         .toList()
//         .sorted((a, b) => a.compareTo(b));
//     ret.removeWhere((e) => e.trim().isEmpty);
//     if (ret.length > 7) {
//       ret = ret.sublist(0, 7);
//     }
//     return ret;
//   }

//   Widget dashboardConstellationCard(Constellation file, BuildContext context) {
//     return Container(

//         // decoration:
//         //     BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
//         child: GestureDetector(
//             onDoubleTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                     builder: (context) =>
//                         Test(constellationName: file.fileName, id: file.id)
//                     // Editor(
//                     //       path: pathName,
//                     //       isPath: true,
//                     //       fileName: name.split(".")[0],
//                     //     )
//                     ),
//               );
//             },
//             child: Card(
//                 shape: const RoundedRectangleBorder(
//                   side: BorderSide(width: 1),
//                   borderRadius: const BorderRadius.all(
//                     Radius.circular(15),
//                   ),
//                 ),
//                 color: Color.fromARGB(255, 255, 255, 255),
//                 shadowColor: Colors.transparent,
//                 child: Container(
//                     child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                       Container(
//                           margin: EdgeInsets.only(
//                               top: 10, left: 10, bottom: 10, right: 10),
//                           child: Row(children: [
//                             Container(
//                                 padding: const EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                     color: Color.fromARGB(204, 235, 235, 235),
//                                     borderRadius: BorderRadius.circular(20)),
//                                 child: Icon(Icons.gesture)),
//                             Spacer(),
//                             IconButton(
//                               onPressed: () {
//                                 setState(() {
//                                   if (file.starred == 0) {
//                                     file.starred = 1;
//                                   } else {
//                                     file.starred = 0;
//                                   }
//                                   updateConstellation(file);
//                                 });
//                               },
//                               icon: file.starred == 0
//                                   ? const Icon(Icons.star_outline_rounded,
//                                       size: 20,
//                                       color: Color.fromARGB(255, 14, 14, 14))
//                                   : Icon(Icons.star_rounded,
//                                       size: 20, color: Colors.black),
//                             ),
//                             const SizedBox(
//                               width: 10,
//                             ),
//                             PopupMenuButton(
//                                 tooltip: "",
//                                 shape: ContinuousRectangleBorder(
//                                     side: BorderSide(
//                                         width: 1, color: Colors.black)),
//                                 color: Colors.white,
//                                 itemBuilder: (BuildContext context) => [
//                                       PopupMenuItem(
//                                         onTap: () => {
//                                           deleteConstellation(
//                                               file.id, file.fileName)
//                                         },
//                                         child: Text('Delete'),
//                                       ),
//                                     ],
//                                 icon: const Icon(Icons.more_horiz,
//                                     size: 20,
//                                     color: Color.fromARGB(255, 14, 14, 14))),
//                           ])),
//                       ListTile(
//                           title: Text(
//                               style: const TextStyle(
//                                   fontWeight: FontWeight.bold, fontSize: 20),
//                               file.fileName),
//                           subtitle: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(children: [
//                                   sortAttribute == 0
//                                       ? const Text('Access Date:')
//                                       : sortAttribute == 1
//                                           ? const Text('Access Date')
//                                           : const Text('Access Date:')
//                                 ]),
//                                 sortAttribute == 0
//                                     ? Text(processDate(file.accessDate))
//                                     : sortAttribute == 1
//                                         ? Text(processDate(file.createDate))
//                                         : Text(processDate(file.updateDate))
//                               ]))
//                     ])))));
//   }

//   String processDate(String date) {
//     return DateFormat.yMEd().add_jm().format(DateTime.parse(date));
//   }

//   void _loadDirectory() async {
//     Directory appDocDir = await getApplicationDocumentsDirectory();
//     String appDocPath = appDocDir.path;
//     var directory = await Directory('$appDocPath/LynkLynkApp/files')
//         .create(recursive: true);

//     setState(() {
//       directoryName = '$appDocPath/LynkLynkApp/files';
//     });
//   }

//   bool _validateFileName(String name) {
//     var existingItem =
//         fileNameList.firstWhereOrNull((element) => element == name);
//     print(fileNameList);
//     return existingItem != null;
//   }

//   String _validFileName(String name) {
//     int index = 0;
//     String newFileName = name;
//     while (fileNameList.firstWhereOrNull((element) => element == newFileName) !=
//         null) {
//       index += 1;
//       newFileName = "$name ($index)";
//     }

//     return newFileName;
//   }

//   Future<void> readJson() async {
//     final String response =
//         await rootBundle.loadString('assets/project-constellation.sets5.json');
//     final data = await json.decode(response);
//     Map dataMap = data[8]["terms"];
//     List<int> dataLevelList = [];
//     List<String> dataTermList = [];
//     dataMap.forEach((key, value) {
//       if (!dataTermList.contains(key.replaceAll('\n', ' '))) {
//         dataTermList.add(key.replaceAll('\n', ' '));
//         dataLevelList.add(0);
//         List<String> auxiliaryList = List<String>.from(value["auxiliary"]
//             .map((term) => term["title"].replaceAll('\n', ' ')));
//         dataTermList += auxiliaryList;
//         dataLevelList += List.generate(auxiliaryList.length, (e) => 1);
//       } else {
//         int termIndex = dataTermList.indexOf(key.replaceAll('\n', ' '));
//         List<String> auxiliaryList = List<String>.from(value["auxiliary"]
//             .map((term) => term["title"].replaceAll('\n', ' ')));
//         dataTermList.insertAll(termIndex + 1, auxiliaryList);
//         int termLevel = dataLevelList[termIndex];
//         dataLevelList.insertAll(termIndex + 1,
//             List.generate(auxiliaryList.length, (e) => termLevel + 1));
//       }
//     });

//     File f = File(
//         "C:/Users/David/lynklynk-app/assets/project-constellation-set.txt");
//     String content = '';
//     // await db.execute(
//     //     "DELETE FROM constellation_table WHERE name=project-constellation-set");
//     // await db.insert('constellation_table',
//     //     {'name': "project-constellation-set", 'bullet_list': "$dataLevelList"});
//     for (int i = 0; i < dataTermList.length; i++) {
//       if (i < dataTermList.length - 1) {
//         content += '${dataTermList[i]}\n';
//       } else {
//         content += dataTermList[i];
//       }
//     }
//     f.writeAsString(content);
//   }

//   Widget addConstellationButton(BuildContext context) {
//     return Tooltip(
//         margin: const EdgeInsets.only(bottom: 20),
//         preferBelow: false,
//         message: 'Create a study file',
//         child: Container(
//             height: 80,
//             width: 80,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               border: Border.all(width: 1, color: Colors.black),
//             ),
//             child: IconButton(
//                 color: Colors.white,
//                 icon: const Icon(Icons.add, color: Colors.black),
//                 iconSize: 30,
//                 style: IconButton.styleFrom(
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(40)),
//                 ),
//                 onPressed: () {
//                   validNewConstellationName = true;
//                   newConstellationNameController.text = "";
//                   showDialog(
//                       context: context,
//                       barrierDismissible: true, //

//                       builder: (BuildContext context) {
//                         return StatefulBuilder(
//                           builder: (context, setState) {
//                             return Transform.translate(
//                                 offset: Offset(0, -100),
//                                 child: Dialog(
//                                   backgroundColor: Colors.transparent,
//                                   child: Form(
//                                     key: _formKey,
//                                     child: Stack(children: [
//                                       Container(
//                                         width: 480,
//                                         decoration: BoxDecoration(
//                                           borderRadius: const BorderRadius.all(
//                                             Radius.circular(10),
//                                           ),
//                                           color: dashboardColor,
//                                           border: Border.all(
//                                               width: 1, color: Colors.black),
//                                         ),
//                                         child: Container(
//                                           width: 460,
//                                           padding: const EdgeInsets.symmetric(
//                                               horizontal: 10, vertical: 5),
//                                           child: TextFormField(
//                                             onChanged: (value) => {
//                                               setState(() {
//                                                 validNewConstellationName =
//                                                     true;
//                                               })
//                                             },
//                                             autofocus: true,
//                                             controller:
//                                                 newConstellationNameController,
//                                             decoration: const InputDecoration(
//                                                 hintText: "New Constellation",
//                                                 border: InputBorder.none,
//                                                 icon: Icon(Icons.add)),
//                                             onFieldSubmitted: (value) async {
//                                               _formKey.currentState?.save();

//                                               if (value.isEmpty ||
//                                                   _validateFileName(value)) {
//                                                 setState(() {
//                                                   validNewConstellationName =
//                                                       false;
//                                                 });
//                                                 return;
//                                               }
//                                               String constellationName = value;

//                                               setState(() {
//                                                 newConstellationNameController =
//                                                     TextEditingController();
//                                               });

//                                               String currentDateTime =
//                                                   DateTime.now().toString();
//                                               int id = directoryFiles.isEmpty
//                                                   ? 0
//                                                   : directoryFiles.last.id + 1;
//                                               await insertConstellation(
//                                                   Constellation(
//                                                       id: id,
//                                                       filePath:
//                                                           "$directoryName/$constellationName.txt",
//                                                       fileName:
//                                                           constellationName,
//                                                       createDate:
//                                                           currentDateTime,
//                                                       accessDate:
//                                                           currentDateTime,
//                                                       updateDate:
//                                                           currentDateTime,
//                                                       tags: [],
//                                                       starred: 0,
//                                                       existingFile: 0));

//                                               if (context.mounted) {
//                                                 Navigator.pop(context);
//                                                 Navigator.push(
//                                                   context,
//                                                   MaterialPageRoute(
//                                                       builder: (context) => Test(
//                                                           id: id,
//                                                           constellationName:
//                                                               constellationName)
//                                                       // Editor(path: "$directoryName/$constellationName.txt", isPath: true, fileName: constellationName)
//                                                       ),
//                                                 );
//                                               }
//                                             },
//                                           ),
//                                         ),
//                                       ),
//                                       Container(
//                                           margin:
//                                               EdgeInsets.only(top: 70, left: 5),
//                                           child: Text(
//                                               style: TextStyle(
//                                                   color: Colors.white),
//                                               validNewConstellationName
//                                                   ? ""
//                                                   : "Invalid constellation name"))
//                                     ]),
//                                   ),
//                                 ));
//                           },
//                         );
//                       });
//                 })));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           scrolledUnderElevation: 0,
//           toolbarHeight: 50,
//           titleSpacing: 0,
//           primary: false,

//           backgroundColor: const Color.fromARGB(255, 255, 255, 255),
//           // backgroundColor: const Color.fromARGB(255, 75, 185, 233),
//           title: Container(
//               color: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 5),
//               child: GestureDetector(
//                   onHorizontalDragStart: (e) {
//                     WindowManager.instance.startDragging();
//                   },
//                   onVerticalDragStart: (e) {
//                     WindowManager.instance.startDragging();
//                   },
//                   child: Container(
//                     color: const Color.fromARGB(255, 233, 237, 246),
//                     // Color.fromARGB(255, 75, 185, 233),

//                     child: Container(
//                       padding: EdgeInsets.symmetric(horizontal: 10),
//                       color: const Color.fromARGB(255, 255, 255, 255),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [
//                           Icon(Icons.rocket_launch_sharp),
//                           Spacer(),
//                           Container(
//                               width: 30,
//                               height: 30,
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(30),
//                               ),
//                               child: IconButton(
//                                 padding: EdgeInsets.zero,
//                                 style: IconButton.styleFrom(
//                                   foregroundColor:
//                                       const Color.fromARGB(255, 0, 0, 0),
//                                 ),
//                                 onPressed: () => windowManager.minimize(),
//                                 icon: const Icon(
//                                     size: 14, Icons.horizontal_rule_sharp),
//                               )),
//                           const SizedBox(width: 15),
//                           Container(
//                               width: 30,
//                               height: 30,
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(30),
//                               ),
//                               child: IconButton(
//                                   style: IconButton.styleFrom(
//                                     foregroundColor:
//                                         const Color.fromARGB(255, 0, 0, 0),
//                                   ),
//                                   onPressed: () =>
//                                       windowManager.isMaximized().then((isMax) {
//                                         if (isMax) {
//                                           windowManager.restore();
//                                         } else {
//                                           windowManager.maximize();
//                                         }
//                                       }),
//                                   icon: const Icon(
//                                       size: 14, Icons.web_asset_sharp))),
//                           const SizedBox(width: 10),
//                           SizedBox(
//                               width: 30,
//                               height: 30,
//                               child: IconButton(
//                                 style: IconButton.styleFrom(
//                                   foregroundColor:
//                                       const Color.fromARGB(255, 0, 0, 0),
//                                 ),
//                                 onPressed: () => windowManager.close(),
//                                 icon: const Icon(
//                                   Icons.close,
//                                   size: 14,
//                                 ),
//                               )),
//                         ],
//                       ),
//                     ),
//                   ))),
//         ),
//         body: directoryFiles.isEmpty
//             ? Container(
//                 alignment: Alignment.center,
//                 child: Row(
//                   children: [
//                     Expanded(child: addConstellationButton(context)),
//                   ],
//                 ))
//             : AnimatedOpacity(
//                 opacity: visible ? 1.0 : 0.0,
//                 duration: const Duration(milliseconds: 500),
//                 child: Container(
//                     decoration: const BoxDecoration(
//                       color: Color.fromARGB(
//                           251, 255, 255, 255), // Background color
//                     ),
//                     padding: EdgeInsets.only(bottom: 10, right: 10, left: 10),
//                     child: Padding(
//                         padding: const EdgeInsets.only(left: 25),
//                         child: ListView(
//                             // mainAxisAlignment: MainAxisAlignment.start,
//                             children: [
//                               const SizedBox(height: 20),
//                               Row(
//                                   mainAxisAlignment: MainAxisAlignment.start,
//                                   children: [
//                                     addConstellationButton(context),
//                                     const SizedBox(
//                                       width: 25,
//                                     ),
//                                     Tooltip(
//                                         margin: EdgeInsets.only(bottom: 20),
//                                         preferBelow: false,
//                                         message: 'Upload a study file',
//                                         child: Container(
//                                             height: 80,
//                                             width: 80,
//                                             decoration: BoxDecoration(
//                                               shape: BoxShape.circle,
//                                               border: Border.all(
//                                                   width: 1,
//                                                   color: Colors.black),
//                                             ),
//                                             child: IconButton(
//                                                 color: Colors.white,
//                                                 icon: const Icon(
//                                                     color: Colors.black,
//                                                     Icons.arrow_upward_sharp),
//                                                 iconSize: 30,
//                                                 style: IconButton.styleFrom(
//                                                   shape: RoundedRectangleBorder(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                               40)),
//                                                 ),
//                                                 onPressed: () async {
//                                                   FilePickerResult?
//                                                       fileUploadResult =
//                                                       await FilePicker.platform
//                                                           .pickFiles(
//                                                     type: FileType.custom,
//                                                     allowedExtensions: [
//                                                       'txt',
//                                                       'pdf',
//                                                       'doc'
//                                                     ],
//                                                   );

//                                                   if (fileUploadResult ==
//                                                       null) {
//                                                     return;
//                                                   }
//                                                   String defaultFileName =
//                                                       './samples/test.txt';
//                                                   String fileNameMaintain =
//                                                       defaultFileName;
//                                                   for (int i = 0;
//                                                       i <
//                                                           fileUploadResult
//                                                               .paths.length;
//                                                       i++) {
//                                                     String filePath =
//                                                         fileUploadResult
//                                                                 .paths[i] ??
//                                                             "./samples/test.txt";
//                                                     String fileName =
//                                                         (fileUploadResult
//                                                                     .names[i] ??
//                                                                 "test.txt")
//                                                             .split(".")[0];

//                                                     String validFileName =
//                                                         _validFileName(
//                                                             fileName);
//                                                     setState(() {
//                                                       fileNameList
//                                                           .add(validFileName);
//                                                       newConstellationNameController =
//                                                           TextEditingController(
//                                                               text: _validFileName(
//                                                                   "Constellation"));
//                                                     });
//                                                     if (i == 0) {
//                                                       fileNameMaintain =
//                                                           validFileName;
//                                                     }

//                                                     String currentDateTime =
//                                                         DateTime.now()
//                                                             .toString();
//                                                     await insertConstellation(Constellation(
//                                                         id: directoryFiles
//                                                                 .isEmpty
//                                                             ? 0
//                                                             : directoryFiles.last
//                                                                     .id +
//                                                                 1,
//                                                         filePath: filePath,
//                                                         fileName: validFileName,
//                                                         createDate:
//                                                             currentDateTime,
//                                                         accessDate:
//                                                             currentDateTime,
//                                                         updateDate:
//                                                             currentDateTime,
//                                                         tags: [],
//                                                         starred: 0,
//                                                         existingFile: 1));
//                                                   }

//                                                   print(
//                                                       "file upload result: $fileUploadResult");
//                                                 }))),
//                                   ]),
//                               Container(
//                                   margin: EdgeInsets.only(top: 20),
//                                   child: Row(children: [
//                                     Text("Constellations",
//                                         style: TextStyle(
//                                             color: Colors.black, fontSize: 25)),
//                                   ])),
//                               directoryFilesStarredOrdered.isNotEmpty
//                                   ? Container(
//                                       margin: EdgeInsets.only(
//                                           right: 30, bottom: 15, top: 10),
//                                       child: GridView.builder(
//                                           gridDelegate:
//                                               SliverGridDelegateWithFixedCrossAxisCount(
//                                             crossAxisCount:
//                                                 MediaQuery.sizeOf(context)
//                                                             .width >
//                                                         1200
//                                                     ? 4
//                                                     : MediaQuery.sizeOf(context)
//                                                                 .width >
//                                                             800
//                                                         ? 3
//                                                         : 2,
//                                             childAspectRatio: 1.0,
//                                             crossAxisSpacing: 15,
//                                             mainAxisSpacing: 15,
//                                             mainAxisExtent: 300,
//                                           ),
//                                           shrinkWrap: true,
//                                           itemCount:
//                                               directoryFilesStarredOrdered
//                                                   .length,
//                                           itemBuilder: (BuildContext context,
//                                               int index) {
//                                             return dashboardConstellationCard(
//                                                 directoryFilesStarredOrdered[
//                                                     index],
//                                                 context);
//                                           }))
//                                   : const SizedBox(),
//                               directoryFilesStarredOrdered.isNotEmpty
//                                   ? Divider()
//                                   : SizedBox(),
//                               Container(
//                                   margin: EdgeInsets.only(right: 30, top: 15),
//                                   child: GridView.builder(
//                                       gridDelegate:
//                                           SliverGridDelegateWithFixedCrossAxisCount(
//                                         crossAxisCount:
//                                             MediaQuery.sizeOf(context).width >
//                                                     1200
//                                                 ? 4
//                                                 : MediaQuery.sizeOf(context)
//                                                             .width >
//                                                         900
//                                                     ? 3
//                                                     : 2,
//                                         childAspectRatio: 1.0,
//                                         crossAxisSpacing: 15,
//                                         mainAxisSpacing: 15,
//                                         mainAxisExtent: 300,
//                                       ),
//                                       scrollDirection: Axis.vertical,
//                                       shrinkWrap: true,
//                                       controller: scroller,
//                                       itemCount:
//                                           directoryFilesUnstarredOrdered.length,
//                                       itemBuilder:
//                                           (BuildContext context, int index) {
//                                         return dashboardConstellationCard(
//                                             directoryFilesUnstarredOrdered[
//                                                 index],
//                                             context);
//                                       })),
//                               SizedBox(height: 20)
//                             ]))),
//               ));
//   }
// }
