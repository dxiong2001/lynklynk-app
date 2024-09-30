import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:lynklynk/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';
import 'package:lynklynk/test.dart';

class Loader extends StatefulWidget {
  const Loader({super.key});

  @override
  _Loader createState() => _Loader();
}

class _Loader extends State<Loader> {
  ScrollController? scroller;
  bool maximized = false;
  List directoryFiles = List.generate(0, (index) => "");
  final _formKey = GlobalKey<FormState>();
  TextEditingController newConstellationNameController =
      TextEditingController();
  String directoryName = "";
  var db;
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
    } catch (_) {}
  }

  _asyncLoadDB() async {
    Database retrievedDB = db = await openDatabase('constellation_db.db');
    try {
      // await db.execute('DELETE FROM constellation_table');
      // await db.execute('DELETE FROM loader_data_table');
      // await db.execute('DROP TABLE IF EXISTS constellation_table');
      // await db.execute('DROP TABLE IF EXISTS loader_data_table');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS constellation_table (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, bullet_list TEXT)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS loader_data_table (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, file_path TEXT, access_date TEXT)');

      // int recordId = await db.insert('constellation_table',
      //     {'name': 'file1', 'lines': 'my_type', 'bullet': 'bullets'});
      // List<Map> queryResults =
      //     await db.rawQuery("SELECT count(*) FROM constellation_table");
      List<Map> queryResultsList =
          await db.rawQuery("SELECT * FROM loader_data_table");

      setState(() {
        directoryFiles = queryResultsList;
        newConstellationNameController = TextEditingController(
            text: "Constellation #${directoryFiles.length + 1}");
        db = retrievedDB;
      });
    } catch (e) {
      print(e);
    }
  }

  removeEntry(int idNumber) async {
    await db.execute("DELETE FROM loader_data_table WHERE id=$idNumber");
    await db.execute("DELETE FROM constellation_table WHERE id=$idNumber");
    List<Map> queryResultsList =
        await db.rawQuery("SELECT * FROM loader_data_table");
    setState(() {
      directoryFiles = queryResultsList;
    });

    print("deleted row $idNumber");
  }

  _refreshDirectoryList() async {
    List<Map> queryResultsList =
        await db.rawQuery("SELECT * FROM loader_data_table");
    setState(() {
      directoryFiles = queryResultsList;
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
        directoryFiles.firstWhereOrNull((element) => element["name"] == name);

    return existingItem != null;
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
        ;
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
        content += dataTermList[i] + '\n';
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
          shape: const Border(
              bottom:
                  BorderSide(color: Color.fromARGB(255, 64, 70, 81), width: 3),
              right: BorderSide(
                  color: Color.fromARGB(255, 205, 209, 218), width: 3),
              left: BorderSide(
                  color: Color.fromARGB(255, 205, 209, 218), width: 3),
              top: BorderSide(
                  color: Color.fromARGB(255, 205, 209, 218), width: 3)),
          titleSpacing: 0,
          primary: false,
          backgroundColor: const Color.fromARGB(255, 75, 185, 233),
          title: GestureDetector(
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
                    color: const Color.fromARGB(255, 50, 73, 126),
                    child: Container(
                      color: const Color.fromARGB(255, 75, 185, 233),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(width: 10),
                          Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color.fromARGB(255, 64, 70, 81),
                                        width: 2),
                                    right: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2),
                                    left: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2),
                                    top: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2)),
                              ),
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  foregroundColor:
                                      const Color.fromARGB(255, 255, 255, 255),
                                  backgroundColor:
                                      const Color.fromARGB(255, 75, 185, 233),
                                  shape: const ContinuousRectangleBorder(),
                                ),
                                onPressed: () {
                                  WindowManager.instance.setFullScreen(false);
                                  WindowManager.instance.minimize();
                                  if (maximized) {
                                    maximized = !maximized;
                                  }
                                },
                                icon: const Icon(Icons.minimize_sharp),
                              )),
                          const SizedBox(width: 10),
                          Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color.fromARGB(255, 64, 70, 81),
                                        width: 2),
                                    right: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2),
                                    left: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2),
                                    top: BorderSide(
                                        color:
                                            Color.fromARGB(255, 181, 227, 247),
                                        width: 2)),
                              ),
                              child: IconButton(
                                  style: IconButton.styleFrom(
                                    foregroundColor: const Color.fromARGB(
                                        255, 255, 255, 255),
                                    backgroundColor:
                                        const Color.fromARGB(255, 75, 185, 233),
                                    shape: const ContinuousRectangleBorder(),
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
                                  icon: const Icon(Icons.web_asset_sharp))),
                          const SizedBox(width: 10),
                          Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color.fromARGB(255, 64, 70, 81),
                                        width: 2),
                                    right: BorderSide(
                                        color:
                                            Color.fromARGB(255, 253, 165, 171),
                                        width: 2),
                                    left: BorderSide(
                                        color:
                                            Color.fromARGB(255, 253, 165, 171),
                                        width: 2),
                                    top: BorderSide(
                                        color:
                                            Color.fromARGB(255, 253, 165, 171),
                                        width: 2)),
                              ),
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  foregroundColor:
                                      const Color.fromARGB(255, 255, 255, 255),
                                  backgroundColor:
                                      const Color.fromARGB(255, 216, 31, 81),
                                  shape: const ContinuousRectangleBorder(),
                                ),
                                onPressed: () {
                                  WindowManager.instance.close();
                                },
                                icon: const Icon(Icons.clear),
                              )),
                          const SizedBox(width: 10),
                        ],
                      ),
                    )),
              )),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: Color.fromARGB(255, 255, 255, 255),
          child: ListView(
            children: <Widget>[
              Container(
                  height: 120,
                  child: DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                    child: Container(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Menu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                          ),
                        )),
                  )),
              ListTile(
                leading: Icon(Icons.home),
                title: Text('Home'),
                onTap: () {
                  // Handle menu item tap
                },
              ),
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                onTap: () {
                  // Handle menu item tap
                },
              ),
              ListTile(
                leading: Icon(Icons.exit_to_app),
                title: Text('Logout'),
                onTap: () {
                  // Handle menu item tap
                },
              ),
            ],
          ),
        ),
        body: Container(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 233, 237, 246), // Background color
              border: Border(
                bottom: BorderSide(
                    color: Color.fromARGB(255, 64, 70, 81), width: 3),
                right: BorderSide(
                    color: Color.fromARGB(255, 205, 209, 218), width: 3),
                left: BorderSide(
                    color: Color.fromARGB(255, 205, 209, 218), width: 3),
              ),
            ),
            child: Container(
                color: Color.fromARGB(255, 0, 4, 12),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Padding(
                              padding: EdgeInsets.all(30),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 40),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Tooltip(
                                              textStyle: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.white),
                                              margin: EdgeInsets.all(10),
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
                                                      173, 224, 56, 146),
                                                  border: Border.all(
                                                      color: const Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      width: 2),
                                                  borderRadius: const BorderRadius.all(
                                                      Radius.circular(2))),
                                              child: Container(
                                                  height: 50,
                                                  width: 120,
                                                  decoration: const BoxDecoration(
                                                      color: Color.fromARGB(
                                                          255, 224, 56, 146),
                                                      border: Border(
                                                          bottom: BorderSide(color: Color.fromARGB(255, 64, 70, 81), width: 3),
                                                          right: BorderSide(color: Color.fromARGB(255, 251, 182, 219), width: 3),
                                                          left: BorderSide(color: Color.fromARGB(255, 251, 182, 219), width: 3),
                                                          top: BorderSide(color: Color.fromARGB(255, 251, 182, 219), width: 3))),
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
                                                                            SizedBox(height: 13),
                                                                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                                              TextButton(
                                                                                onPressed: () async {
                                                                                  if (_formKey.currentState!.validate()) {
                                                                                    _formKey.currentState?.save();
                                                                                    String constellationName = newConstellationNameController.text;
                                                                                    print(constellationName);

                                                                                    _createLevelFile(constellationName);

                                                                                    await db.insert('loader_data_table', {
                                                                                      'name': constellationName,
                                                                                      'file_path': "$directoryName/$constellationName.txt",
                                                                                      'access_date': DateTime.now().toString().split(".")[0]
                                                                                    });
                                                                                    await db.insert('constellation_table', {
                                                                                      'name': constellationName,
                                                                                      'bullet_list': "[]"
                                                                                    });
                                                                                    _refreshDirectoryList();
                                                                                    if (context.mounted) {
                                                                                      Navigator.pop(context);
                                                                                      Navigator.push(
                                                                                        context,
                                                                                        MaterialPageRoute(builder: (context) => Test(path: "$directoryName/$constellationName.txt", fileName: constellationName)
                                                                                            // Editor(path: "$directoryName/$constellationName.txt", isPath: true, fileName: constellationName)
                                                                                            ),
                                                                                      );
                                                                                    }
                                                                                  }
                                                                                },
                                                                                child: const Text('CREATE'),
                                                                              ),
                                                                              SizedBox(width: 5),
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
                                              margin: EdgeInsets.all(10),
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
                                                      173, 224, 56, 146),
                                                  border: Border.all(
                                                      color: const Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      width: 2),
                                                  borderRadius: const BorderRadius.all(
                                                      Radius.circular(2))),
                                              child: Container(
                                                  height: 50,
                                                  width: 120,
                                                  decoration: const BoxDecoration(
                                                      color: Color.fromARGB(
                                                          255, 224, 56, 146),
                                                      border: Border(
                                                          bottom: BorderSide(color: Color.fromARGB(255, 64, 70, 81), width: 3),
                                                          right: BorderSide(color: Color.fromARGB(255, 251, 182, 219), width: 3),
                                                          left: BorderSide(color: Color.fromARGB(255, 251, 182, 219), width: 3),
                                                          top: BorderSide(color: Color.fromARGB(255, 251, 182, 219), width: 3))),
                                                  child: IconButton(
                                                      color: Colors.white,
                                                      icon: const Icon(Icons.upload_file_sharp),
                                                      iconSize: 30,
                                                      style: IconButton.styleFrom(
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
                                                              fileUploadResult
                                                                          .names[
                                                                      i] ??
                                                                  "test.txt";
                                                          String dateTime =
                                                              DateTime.now()
                                                                  .toString()
                                                                  .split(
                                                                      ".")[0];
                                                          int recordId =
                                                              await db.insert(
                                                                  'loader_data_table',
                                                                  {
                                                                'name':
                                                                    fileName,
                                                                'file_path':
                                                                    filePath,
                                                                'access_date':
                                                                    dateTime
                                                              });
                                                          await db.insert(
                                                              'constellation_table',
                                                              {
                                                                'name':
                                                                    fileName,
                                                                'bullet_list':
                                                                    "[]"
                                                              });
                                                        }
                                                        List<Map>
                                                            queryResultsList =
                                                            await db.rawQuery(
                                                                "SELECT * FROM loader_data_table");
                                                        setState(() {
                                                          directoryFiles =
                                                              queryResultsList;
                                                        });
                                                        if (context.mounted) {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                                builder: (context) => Test(
                                                                    path: fileUploadResult.paths[
                                                                            0] ??
                                                                        defaultFileName,
                                                                    fileName:
                                                                        fileUploadResult.names[0] ??
                                                                            "")

                                                                // Editor(
                                                                //     path: fileUploadResult.paths[
                                                                //             0] ??
                                                                //         defaultFileName,
                                                                //     isPath:
                                                                //         true,
                                                                //     fileName:
                                                                //         fileUploadResult.names[0] ??
                                                                //             "")

                                                                ),
                                                          );
                                                        }
                                                      }))),
                                          TextButton(
                                              onPressed: () {
                                                readJson();
                                              },
                                              child: Text("tesser1"))
                                        ]),
                                    SizedBox(height: 20),
                                    const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.only(left: 62),
                                            child: Text("Constellation",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsets.only(right: 110),
                                            child: Text("Date",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ]),
                                    SizedBox(height: 10),
                                    Container(
                                        decoration: const BoxDecoration(
                                            border: Border.symmetric(
                                                horizontal: BorderSide(
                                                    color: Colors.white,
                                                    width: 1))),
                                        child: ListView.separated(
                                            separatorBuilder: (context,
                                                    index) =>
                                                Container(
                                                  color: const Color.fromARGB(
                                                      255, 255, 255, 255),
                                                  height: 1,
                                                ),
                                            scrollDirection: Axis.vertical,
                                            shrinkWrap: true,
                                            controller: scroller,
                                            itemCount: directoryFiles.length,
                                            itemBuilder: (BuildContext context,
                                                int index) {
                                              return ViewLine(
                                                  updateDelete: removeEntry,
                                                  lineNumber: index,
                                                  name: directoryFiles[index]
                                                      ["name"],
                                                  pathName:
                                                      directoryFiles[index]
                                                          ["file_path"],
                                                  idNumber:
                                                      directoryFiles[index]
                                                          ['id'],
                                                  date: directoryFiles[index]
                                                      ['access_date']);
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
      super.key});
  final int lineNumber;
  final String name;
  final String pathName;
  final String date;
  final int idNumber;
  final Function(int index) updateDelete;

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
      return const Color.fromARGB(255, 5, 14, 32);
    }

    return Container(
        height: 70,
        color: isChecked ?? false
            ? const Color.fromARGB(255, 5, 14, 32)
            : Colors.transparent,
        child: Row(children: [
          Checkbox(
            side: const BorderSide(color: Colors.white, width: 1.3),
            shape: ContinuousRectangleBorder(),
            fillColor: WidgetStateColor.resolveWith(getColor),
            activeColor: Colors.white,
            value: isChecked,
            onChanged: (bool? value) {
              print(name);
              setState(() {
                isChecked = value;
              });
            },
          ),
          Expanded(
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Container(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        child: Text(
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.left,
                            name.split(".")[0],
                            maxLines: 1,
                            overflow: TextOverflow.fade),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => Test(
                                    path: pathName,
                                    fileName: name.split(".")[0])
                                // Editor(
                                //       path: pathName,
                                //       isPath: true,
                                //       fileName: name.split(".")[0],
                                //     )
                                ),
                          );
                          print("pressed");
                        },
                      )))),
          isChecked ?? true
              ? Container(
                  child: Row(children: [
                  IconButton(
                      color: Colors.white,
                      onPressed: () async {
                        await widget.updateDelete(idNumber);
                        await deleteFile(File(pathName));
                      },
                      icon: const Icon(Icons.delete_outline_sharp))
                ]))
              : SizedBox.shrink(),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                date,
                style: TextStyle(color: Colors.white),
              )),
        ]));
  }
}
