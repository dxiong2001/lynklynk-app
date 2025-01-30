import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';
import 'package:lynklynk/test.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class DBFile {
  final int id;
  String fileDirectory;
  String fileName;
  final String createDate;
  String accessDate;
  String updateDate;
  List tags;
  int starred;

  DBFile({
    required this.id,
    required this.fileDirectory,
    required this.fileName,
    required this.createDate,
    required this.accessDate,
    required this.updateDate,
    required this.tags,
    required this.starred,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'fileDirectory': fileDirectory,
      'fileName': fileName,
      'createDate': createDate,
      'accessDate': accessDate,
      'updateDate': updateDate,
      'tags': tags.toString(),
      'starred': starred,
    };
  }

  @override
  String toString() {
    return 'DBFile(id: $id, fileDirectory: $fileDirectory, fileName: $fileName, createDate: $createDate, accessDate: $accessDate, updateDate: $updateDate, tags: ${tags.toString()}, starred: $starred)';
  }
}

class LabeledCheckbox extends StatelessWidget {
  const LabeledCheckbox({
    super.key,
    required this.label,
    required this.padding,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final EdgeInsets padding;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onChanged(!value);
      },
      child: Padding(
        padding: padding,
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Checkbox(
              value: value,
              onChanged: (bool? newValue) {
                onChanged(newValue!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class Loader extends StatefulWidget {
  const Loader({super.key});

  @override
  _Loader createState() => _Loader();
}

class _Loader extends State<Loader> {
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

  //currently selected set
  int currentlySelectedSet = -1;
  Color dashboardColor = const Color.fromRGBO(252, 231, 200, 1);
  Color primary1 = const Color.fromRGBO(177, 194, 158, 1);
  Color primary2 = const Color.fromRGBO(250, 218, 122, 1);
  Color primary3 = const Color.fromRGBO(240, 160, 75, 1);

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

  _asyncLoadDB() async {
    WidgetsFlutterBinding.ensureInitialized();

    database = openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await getDatabasesPath(), 'lynklynk_file_database.db'),
      // When the database is first created, create a table to store files.
      onCreate: (db, version) {
        // Run the CREATE TABLE statement on the database.
        return db.execute(
          'CREATE TABLE files(id INTEGER PRIMARY KEY, fileDirectory TEXT, fileName TEXT, createDate TEXT, accessDate TEXT, updateDate TEXT, tags TEXT)',
        );
      },
      onUpgrade: _onUpgrade,
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 2,
    );

    try {
      List<DBFile> queryResultsList = await getDBFileList();
      print(queryResultsList);
      setState(() {
        directoryFiles = queryResultsList;
        updateDirectoryFilesOrdering(directoryFiles);
        checkboxList = List<bool>.filled(queryResultsList.length, false);
        fileNameList = queryResultsList.map((e) => e.fileName).toList();
      });
    } catch (e) {
      print(e);
    }
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

  // UPGRADE DATABASE TABLES
  void _onUpgrade(Database db, int oldVersion, int newVersion) {
    if (oldVersion < 2) {
      db.execute(
          "ALTER TABLE files ADD COLUMN starred INTEGER NOT NULL DEFAULT (0);");
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
    final db = await database;
    await db.insert(
      'files',
      file.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    db.execute(
      'CREATE TABLE "${file.fileName}_${file.id.toString()}"(id INTEGER PRIMARY KEY, nodeTerm TEXT, auxiliaries TEXT, color TEXT, createDate TEXT, updateDate TEXT)',
    );

    updateFiles();
  }

  Future<List<DBFile>> getDBFileList() async {
    // Get a reference to the database.
    final db = await database;

    // Query the table for all the files.
    final List<Map<String, Object?>> fileMaps = await db.query('files');

    // Convert the list of each file's fields into a list of `file` objects.
    return [
      for (final {
            'id': id as int,
            'fileDirectory': fileDirectory as String,
            'fileName': fileName as String,
            'createDate': createDate as String,
            'accessDate': accessDate as String,
            'updateDate': updateDate as String,
            'tags': tags as String,
            'starred': starred as int,
          } in fileMaps)
        DBFile(
            id: id,
            fileDirectory: fileDirectory,
            fileName: fileName,
            createDate: createDate,
            accessDate: accessDate,
            updateDate: updateDate,
            tags: json.decode(tags),
            starred: starred),
    ];
  }

  Future<void> updateDBFile(DBFile file) async {
    // Get a reference to the database.
    final db = await database;

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
    final db = await database;

    // Remove the file from the database.
    await db.delete(
      'files',
      // Use a `where` clause to delete a specific file.
      where: 'id = ?',
      // Pass the file's id as a whereArg to prevent SQL injection.
      whereArgs: [id],
    );

    await db.execute('DROP TABLE IF EXISTS "${fileName}_$id"');
    updateFiles();
    currentlySelectedSet = -1;
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
    if (ret.length > 7) {
      ret = ret.sublist(0, 7);
    }
    return ret;
  }

  Widget dashboardConstellationCard(DBFile file, BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
              width: currentlySelectedSet == file.id ? 3 : 1,
              color: Colors.black),
          boxShadow: const [
            BoxShadow(
              color: const Color.fromARGB(255, 0, 0, 0),
              blurRadius: 0,
              offset: Offset(5, 5),
              spreadRadius: 1,
            )
          ],
        ),
        // decoration:
        //     BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
        child: TapRegion(
            onTapInside: (tap) {
              setState(() {
                if (currentlySelectedSet == file.id) {
                  currentlySelectedSet = -1;
                } else {
                  currentlySelectedSet = file.id;
                }
              });
            },
            onTapOutside: (tap) {
              print('On Tap Outside!!');
            },
            child: GestureDetector(
                onDoubleTap: () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => Test(
                                constellationName: file.fileName, id: file.id)
                            // Editor(
                            //       path: pathName,
                            //       isPath: true,
                            //       fileName: name.split(".")[0],
                            //     )
                            ),
                      )
                    },
                child: Card(
                    shape: const RoundedRectangleBorder(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(0),
                      ),
                    ),
                    color: Colors.white,
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
                                        color:
                                            Color.fromARGB(204, 235, 235, 235),
                                        borderRadius:
                                            BorderRadius.circular(20)),
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
                                    icon: Icon(
                                        file.starred == 0
                                            ? Icons.star_outline_rounded
                                            : Icons.star_rounded,
                                        size: 20,
                                        color:
                                            Color.fromARGB(255, 14, 14, 14))),
                                const SizedBox(
                                  width: 10,
                                ),
                                PopupMenuButton(
                                    shape: ContinuousRectangleBorder(
                                        side: BorderSide(
                                            width: 1, color: Colors.black)),
                                    color: Colors.white,
                                    itemBuilder: (BuildContext context) => [
                                          PopupMenuItem(
                                            onTap: () => {
                                              deleteDBFile(
                                                  file.id, file.fileName)
                                            },
                                            child: Text('Delete'),
                                          ),
                                        ],
                                    icon: const Icon(Icons.more_horiz,
                                        size: 20,
                                        color:
                                            Color.fromARGB(255, 14, 14, 14))),
                              ])),
                          ListTile(
                              title: Text(
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20),
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
                        ]))))));
  }

  String processDate(String date) {
    return DateFormat.yMEd().add_jm().format(DateTime.parse(date));
  }

  updateCheckBoxActive(int index, bool check) {
    setState(() {
      if (check) {
        checkboxList[index] = true;
        checkBoxActiveCount += 1;
      } else {
        checkboxList[index] = false;
        checkBoxActiveCount -= 1;
      }
    });
  }

  removeEntries() async {
    print(checkboxList);
    for (int i = 0; i < checkboxList.length; i++) {
      if (checkboxList[i]) {
        // await removeEntry(directoryFiles[i]["id"]);
        print("---------1");
        print(await database.rawQuery("SELECT * FROM loader_data_table"));
        setState(() {
          checkboxList.removeAt(i);
          print(fileNameList[i]);
          directoryFiles = List.from(directoryFiles)..removeAt(i);
          fileNameList.removeAt(i);
        });
        i--;
      }
    }
    _refreshLists();
    print(fileNameList);
  }

  removeEntry(int idNumber) async {
    await database.execute("DELETE FROM loader_data_table WHERE id=$idNumber");
    await database
        .execute("DELETE FROM constellation_table WHERE id=$idNumber");
    // List<Map> queryResultsList =
    //     await db.rawQuery("SELECT * FROM loader_data_table");
    // setState(() {
    //   directoryFiles = queryResultsList;
    //   fileNameList = directoryFiles.map((e) => e["name"].toString()).toList();
    // });

    print("deleted row $idNumber");
  }

  _refreshLists() async {
    List<Map> queryResultsList =
        await database.rawQuery("SELECT * FROM loader_data_table");
    setState(() {
      // directoryFiles = queryResultsList;
      print(directoryFiles);
      // fileNameList = directoryFiles.map((e) => e["name"].toString()).toList();
      checkboxList = List.generate(fileNameList.length, (e) {
        return false;
      });
    });
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

  Future<File> _createLevelFile(String name) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    var directory = await Directory('dir/subdir').create(recursive: true);
    File file = File('$appDocPath/LynkLynkApp/files/$name.txt');
    return await file.create();
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
    print(data[8]["terms"].length);
    print(dataTermList.length);
    print(dataLevelList.length);
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
          toolbarHeight: 40,
          titleSpacing: 0,
          primary: false,

          shape: const Border(
              bottom: BorderSide(
                  color: Color.fromARGB(255, 64, 70, 81), width: 0.5)),
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
                                  foregroundColor:
                                      const Color.fromARGB(255, 0, 0, 0),
                                ),
                                onPressed: () {
                                  WindowManager.instance.minimize();
                                  if (appMaximized) {
                                    appMaximized = !appMaximized;
                                  }
                                },
                                icon: const Icon(
                                    size: 12, Icons.horizontal_rule_sharp),
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
                                        const Color.fromARGB(255, 0, 0, 0),
                                  ),
                                  onPressed: () {
                                    if (appMaximized) {
                                      WindowManager.instance
                                          .setFullScreen(false);
                                    } else {
                                      WindowManager.instance
                                          .setFullScreen(true);
                                    }
                                    appMaximized = !appMaximized;
                                  },
                                  icon: const Icon(
                                      size: 12, Icons.web_asset_sharp))),
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
                                  foregroundColor:
                                      const Color.fromARGB(255, 0, 0, 0),
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
        body: Container(
            decoration: const BoxDecoration(
              color: Color.fromARGB(252, 231, 200, 255), // Background color
            ),
            child: Container(
                color: dashboardColor,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          decoration: BoxDecoration(
                              color: primary1,
                              border: Border(
                                  right: BorderSide(
                                      width: 1, color: Colors.black))),
                          constraints: BoxConstraints(maxWidth: 60)),
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(25),
                              child: ListView(
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                        child: const Row(
                                      children: [
                                        Text(
                                          "Dashboard",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 20),
                                        ),
                                      ],
                                    )),
                                    const SizedBox(height: 20),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Tooltip(
                                              textStyle: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.white),
                                              margin: const EdgeInsets.all(10),
                                              preferBelow: false,
                                              message:
                                                  'Create a new study file',
                                              padding: const EdgeInsets.only(
                                                  top: 6,
                                                  bottom: 8,
                                                  right: 20,
                                                  left: 20),
                                              decoration: BoxDecoration(
                                                  color: const Color.fromARGB(
                                                      255, 9, 42, 92),
                                                  border: Border.all(
                                                      color:
                                                          const Color.fromARGB(
                                                              255, 0, 0, 0),
                                                      width: 2),
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(2))),
                                              child: Container(
                                                  height: 100,
                                                  width: 100,
                                                  decoration: BoxDecoration(
                                                      color: primary1,
                                                      border: Border.all(
                                                          width: 1,
                                                          color: Colors.black),
                                                      boxShadow: const [
                                                        BoxShadow(
                                                          color: Color.fromARGB(
                                                              255, 0, 0, 0),
                                                          blurRadius: 0,
                                                          offset: Offset(5, 5),
                                                          spreadRadius: 1,
                                                        )
                                                      ]),
                                                  child: IconButton(
                                                      color: Colors.white,
                                                      icon: const Icon(Icons.add),
                                                      iconSize: 30,
                                                      style: IconButton.styleFrom(
                                                        shape:
                                                            const ContinuousRectangleBorder(),
                                                      ),
                                                      onPressed: () {
                                                        showModalBottomSheet<
                                                            void>(
                                                          context: context,
                                                          builder: (BuildContext
                                                              context) {
                                                            return SizedBox(
                                                              height: 200,
                                                              child: Center(
                                                                child: Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: <Widget>[
                                                                    FractionallySizedBox(
                                                                      widthFactor:
                                                                          0.75,
                                                                      child:
                                                                          Form(
                                                                        key:
                                                                            _formKey,
                                                                        child:
                                                                            Column(
                                                                          children: <Widget>[
                                                                            TextFormField(
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
                                                                            const SizedBox(height: 13),
                                                                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                                              TextButton(
                                                                                onPressed: () async {
                                                                                  // if (_formKey.currentState!.validate()) {
                                                                                  //   _formKey.currentState?.save();
                                                                                  //   String constellationName = newConstellationNameController.text;
                                                                                  //   print(constellationName);

                                                                                  //   _createLevelFile(constellationName);
                                                                                  //   setState(() {
                                                                                  //     fileNameList.add(constellationName);
                                                                                  //     newConstellationNameController = TextEditingController(text: _validFileName("Constellation"));
                                                                                  //   });

                                                                                  //   String currentDateTime = DateTime.now().toString();
                                                                                  //   await insertDBFile(DBFile(id: directoryFiles.isEmpty ? 0 : directoryFiles.last.id + 1, fileDirectory: directoryName, fileName: constellationName, createDate: currentDateTime, accessDate: currentDateTime, updateDate: currentDateTime, tags: [], starred: 0));

                                                                                  //   _refreshLists();
                                                                                  //   if (context.mounted) {
                                                                                  //     Navigator.pop(context);
                                                                                  //     Navigator.push(
                                                                                  //       context,
                                                                                  //       MaterialPageRoute(builder: (context) => Test(constellationName: constellationName)
                                                                                  //           // Editor(path: "$directoryName/$constellationName.txt", isPath: true, fileName: constellationName)
                                                                                  //           ),
                                                                                  //     );
                                                                                  //   }
                                                                                  // }
                                                                                },
                                                                                child: const Text('CREATE'),
                                                                              ),
                                                                              const SizedBox(width: 5),
                                                                              TextButton(
                                                                                child: const Text('CANCEL'),
                                                                                onPressed: () => Navigator.pop(context),
                                                                              ),
                                                                            ])
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      }))),
                                          const SizedBox(
                                            width: 20,
                                          ),
                                          Tooltip(
                                              textStyle: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.white),
                                              margin: const EdgeInsets.all(10),
                                              preferBelow: false,
                                              message:
                                                  'Create a new study file',
                                              padding: const EdgeInsets.only(
                                                  top: 6,
                                                  bottom: 8,
                                                  right: 20,
                                                  left: 20),
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                    255, 56, 99, 151),
                                                border: Border.all(
                                                    color: const Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    width: 2),
                                              ),
                                              child: Container(
                                                  height: 100,
                                                  width: 100,
                                                  decoration: BoxDecoration(
                                                    color: primary2,
                                                    border: Border.all(
                                                        width: 1,
                                                        color: Colors.black),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Color.fromARGB(
                                                            255, 0, 0, 0),
                                                        blurRadius: 0,
                                                        offset: Offset(5, 5),
                                                        spreadRadius: 1,
                                                      )
                                                    ],
                                                  ),
                                                  child: IconButton(
                                                      color: Colors.white,
                                                      icon: const Icon(Icons
                                                          .upload_file_sharp),
                                                      iconSize: 30,
                                                      style:
                                                          IconButton.styleFrom(
                                                        shape:
                                                            const ContinuousRectangleBorder(),
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
                                                        String
                                                            fileNameMaintain =
                                                            defaultFileName;
                                                        for (int i = 0;
                                                            i <
                                                                fileUploadResult
                                                                    .paths
                                                                    .length;
                                                            i++) {
                                                          String filePath =
                                                              fileUploadResult
                                                                          .paths[
                                                                      i] ??
                                                                  "./samples/test.txt";
                                                          String fileName =
                                                              (fileUploadResult
                                                                              .names[
                                                                          i] ??
                                                                      "test.txt")
                                                                  .split(
                                                                      ".")[0];
                                                          String dateTime =
                                                              DateTime.now()
                                                                  .toString()
                                                                  .split(
                                                                      ".")[0];

                                                          String validFileName =
                                                              _validFileName(
                                                                  fileName);
                                                          setState(() {
                                                            fileNameList.add(
                                                                validFileName);
                                                            newConstellationNameController =
                                                                TextEditingController(
                                                                    text: _validFileName(
                                                                        "Constellation"));
                                                          });
                                                          if (i == 0) {
                                                            fileNameMaintain =
                                                                validFileName;
                                                          }

                                                          String
                                                              currentDateTime =
                                                              DateTime.now()
                                                                  .toString();
                                                          await insertDBFile(DBFile(
                                                              id: directoryFiles.isEmpty
                                                                  ? 0
                                                                  : directoryFiles
                                                                          .last
                                                                          .id +
                                                                      1,
                                                              fileDirectory:
                                                                  directoryName,
                                                              fileName:
                                                                  validFileName,
                                                              createDate:
                                                                  currentDateTime,
                                                              accessDate:
                                                                  currentDateTime,
                                                              updateDate:
                                                                  currentDateTime,
                                                              tags: [],
                                                              starred: 0));
                                                        }

                                                        print(
                                                            "file upload result: $fileUploadResult");
                                                        // if (context.mounted) {
                                                        //   Navigator.push(
                                                        //     context,
                                                        //     MaterialPageRoute(
                                                        //         builder: (context) => Test(
                                                        //             path: fileUploadResult.paths[
                                                        //                     0] ??
                                                        //                 defaultFileName,
                                                        //             fileName:
                                                        //                 fileNameMaintain)

                                                        //         // Editor(
                                                        //         //     path: fileUploadResult.paths[
                                                        //         //             0] ??
                                                        //         //         defaultFileName,
                                                        //         //     isPath:
                                                        //         //         true,
                                                        //         //     fileName:
                                                        //         //         fileUploadResult.names[0] ??
                                                        //         //             "")

                                                        //         ),
                                                        //   );
                                                        // }
                                                      }))),
                                          // TextButton(
                                          //     onPressed: () {
                                          //       readJson();
                                          //     },
                                          //     child: Text("tesser1"))
                                          const SizedBox(
                                            width: 20,
                                          ),
                                          Container(
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color: primary3,
                                              border: Border.all(
                                                  width: 1,
                                                  color: Colors.black),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color.fromARGB(
                                                      255, 0, 0, 0),
                                                  blurRadius: 0,
                                                  offset: Offset(5, 5),
                                                  spreadRadius: 1,
                                                )
                                              ],
                                            ),
                                            child: TextButton.icon(
                                              onPressed: () => {},
                                              label: const Text(
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20),
                                                  "Continue from last set"),
                                              icon: const Icon(
                                                Icons.arrow_forward,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        ]),
                                    const SizedBox(height: 20),
                                    Row(children: [
                                      Expanded(
                                          child: Container(
                                        margin: EdgeInsets.only(top: 20),
                                        constraints: BoxConstraints(
                                          maxWidth: 480,
                                        ),
                                        child: SearchAnchor(
                                            viewBackgroundColor: Colors.white,
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
                                                    const WidgetStatePropertyAll(
                                                        Colors.white),
                                                overlayColor:
                                                    const WidgetStatePropertyAll(
                                                        Color.fromARGB(255, 255,
                                                            255, 255)),
                                                surfaceTintColor:
                                                    const WidgetStatePropertyAll(
                                                        Color.fromARGB(255, 255,
                                                            255, 255)),
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
                                                trailing: <Widget>[
                                                  Tooltip(
                                                    message:
                                                        'Change brightness mode',
                                                    child: IconButton(
                                                      isSelected: true,
                                                      onPressed: () {},
                                                      icon: const Icon(Icons
                                                          .wb_sunny_outlined),
                                                      selectedIcon: const Icon(Icons
                                                          .brightness_2_outlined),
                                                    ),
                                                  )
                                                ],
                                              );
                                            },
                                            suggestionsBuilder: (BuildContext
                                                    context,
                                                SearchController controller) {
                                              List<String> suggestionList =
                                                  fileNameSearchSuggestionList(
                                                      controller.text);

                                              return suggestionList.map((e) {
                                                return Container(
                                                    child: ListTile(
                                                  tileColor: Colors.white,
                                                  title: Text(e),
                                                  onTap: () {
                                                    setState(() {
                                                      controller.closeView(e);
                                                    });
                                                  },
                                                ));
                                              });
                                            }),
                                      )),
                                      SizedBox(width: 20),
                                      Container(
                                          margin: EdgeInsets.only(top: 20),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton2<String>(
                                              buttonStyleData: ButtonStyleData(
                                                height: 40,
                                                width: 160,
                                                padding: EdgeInsets.only(
                                                    left: 14, right: 14),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      width: 1,
                                                      color: Colors.black),
                                                  color: primary3,
                                                ),
                                              ),
                                              isExpanded: true,
                                              hint: Text(
                                                sortAttributeList[
                                                    sortAttribute],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Color.fromARGB(
                                                      255, 255, 255, 255),
                                                ),
                                              ),
                                              items: sortAttributeList
                                                  .map((String item) =>
                                                      DropdownMenuItem<String>(
                                                        value: item,
                                                        child: Text(
                                                          item,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ))
                                                  .toList(),

                                              onChanged: (String? value) {
                                                setState(() {
                                                  sortAttribute =
                                                      sortAttributeList.indexOf(
                                                          value ?? "access");
                                                  print("update");
                                                  updateDirectoryFilesOrdering(
                                                      directoryFiles);
                                                });
                                              },
                                              // buttonStyleData:
                                              //     const ButtonStyleData(
                                              //   overlayColor:
                                              //       WidgetStatePropertyAll(
                                              //           Colors.white),
                                              //   padding: EdgeInsets.symmetric(
                                              //       horizontal: 16),
                                              //   height: 40,
                                              //   width: 140,
                                              // ),
                                              iconStyleData:
                                                  const IconStyleData(
                                                icon: Icon(
                                                  Icons.arrow_drop_down,
                                                ),
                                                iconSize: 20,
                                                iconEnabledColor:
                                                    Color.fromARGB(
                                                        255, 255, 255, 255),
                                                iconDisabledColor: Colors.grey,
                                              ),
                                              menuItemStyleData:
                                                  const MenuItemStyleData(
                                                height: 40,
                                                overlayColor:
                                                    WidgetStatePropertyAll(
                                                        Colors.white),
                                              ),
                                              dropdownStyleData:
                                                  DropdownStyleData(
                                                maxHeight: 200,
                                                decoration: BoxDecoration(
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.grey
                                                          .withOpacity(0.5),
                                                      spreadRadius: 1,
                                                      blurRadius: 3,
                                                      offset: Offset(0,
                                                          2), // changes position of shadow
                                                    )
                                                  ],
                                                  color: Colors.white,
                                                ),
                                                offset: const Offset(0, -5),
                                                scrollbarTheme:
                                                    ScrollbarThemeData(
                                                  radius:
                                                      const Radius.circular(40),
                                                  thickness:
                                                      WidgetStateProperty.all(
                                                          6),
                                                  thumbVisibility:
                                                      WidgetStateProperty.all(
                                                          true),
                                                ),
                                              ),
                                            ),
                                          )),
                                      SizedBox(width: 20),
                                    ]),
                                    directoryFilesStarredOrdered.isNotEmpty
                                        ? const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                                SizedBox(height: 20),
                                                Text("Starred",
                                                    style: TextStyle(
                                                        fontSize: 25)),
                                                SizedBox(height: 5)
                                              ])
                                        : SizedBox(),
                                    directoryFilesStarredOrdered.isNotEmpty
                                        ? Container(
                                            margin: EdgeInsets.only(right: 30),
                                            child: GridView.builder(
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount:
                                                      MediaQuery.sizeOf(context)
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
                                                itemBuilder:
                                                    (BuildContext context,
                                                        int index) {
                                                  return dashboardConstellationCard(
                                                      directoryFilesStarredOrdered[
                                                          index],
                                                      context);
                                                }))
                                        : SizedBox(),
                                    const SizedBox(height: 30),
                                    const Row(children: [
                                      Text("Constellations",
                                          style: TextStyle(fontSize: 25)),
                                    ]),
                                    const SizedBox(height: 5),
                                    Container(
                                        margin: EdgeInsets.only(right: 30),
                                        child: GridView.builder(
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount:
                                                  MediaQuery.sizeOf(context)
                                                              .width >
                                                          800
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
                                            itemBuilder: (BuildContext context,
                                                int index) {
                                              return dashboardConstellationCard(
                                                  directoryFilesUnstarredOrdered[
                                                      index],
                                                  context);
                                            }))
                                  ]))),
                    ]))));
  }
}

class ViewLine extends StatefulWidget {
  const ViewLine(
      {this.lineNumber = 0,
      this.name = '',
      required this.pathName,
      this.idNumber = 0,
      required this.updateDelete,
      required this.date,
      required this.updateCheckBox,
      super.key});
  final int lineNumber;
  final String name;
  final String pathName;
  final String date;
  final int idNumber;
  final Function(int index) updateDelete;
  final Function(int index, bool check) updateCheckBox;

  @override
  State<ViewLine> createState() => _ViewLine();
}

class _ViewLine extends State<ViewLine> {
  bool? isChecked;
  int lineNumber = 0;
  String name = '';
  String pathName = '';
  int idNumber = 0;
  String date = "";

  @override
  void initState() {
    super.initState();
    lineNumber = widget.lineNumber;
    name = widget.name;
    pathName = widget.pathName;
    isChecked = false;
    idNumber = widget.idNumber;
    date = widget.date;
  }

  Future<void> deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Error in getting access to the file.
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color getColor(Set<WidgetState> states) {
      const Set<WidgetState> interactiveStates = <WidgetState>{
        WidgetState.pressed,
        WidgetState.hovered,
        WidgetState.focused,
      };
      // if (states.any(interactiveStates.contains)) {
      //   return Color.fromARGB(94, 255, 255, 255);
      // }
      return const Color.fromARGB(255, 255, 255, 255);
    }

    return Container(
        height: 65,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: isChecked ?? false
              ? const Color.fromARGB(255, 196, 209, 235)
              : Colors.transparent,
        ),
        child: Row(children: [
          Checkbox(
            side: const BorderSide(color: Colors.black, width: 1.3),
            shape: const ContinuousRectangleBorder(),
            fillColor: WidgetStateColor.resolveWith(getColor),
            checkColor: Colors.black,
            activeColor: Colors.black,
            value: isChecked,
            onChanged: (bool? value) {
              print(name);
              widget.updateCheckBox(lineNumber, value ?? false);
              setState(() {
                isChecked = value;
              });
            },
          ),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Container(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        child: Text(
                            style: const TextStyle(color: Colors.black),
                            textAlign: TextAlign.left,
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.fade),
                        onTap: () {
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //       builder: (context) =>
                          //           Test(constellationName: name.split(".")[0])
                          //       // Editor(
                          //       //       path: pathName,
                          //       //       isPath: true,
                          //       //       fileName: name.split(".")[0],
                          //       //     )
                          //       ),
                          // );
                          // print("pressed");
                        },
                      )))),
          isChecked ?? true
              ? Container(
                  child: Row(children: [
                  IconButton(
                      color: Colors.black,
                      onPressed: () async {},
                      icon: const Icon(Icons.edit)),
                  // IconButton(
                  //     color: Colors.black,
                  //     onPressed: () async {
                  //       await widget.updateDelete(idNumber);
                  //       if (!widget.external) {
                  //         await deleteFile(File(pathName));
                  //       }
                  //     },
                  //     icon: const Icon(Icons.delete_outline_sharp))
                ]))
              : const SizedBox.shrink(),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                date,
                style: const TextStyle(color: Colors.black),
              )),
        ]));
  }
}
