import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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
  List<String> fileNameList = [];
  Color secondaryColor = const Color.fromARGB(255, 82, 72, 159);
  List<bool> checkBoxActiveList = [];
  int checkBoxActiveCount = 0;
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
          'CREATE TABLE IF NOT EXISTS loader_data_table (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, file_path TEXT, access_date TEXT, external INTEGER)');
      // await db.execute(
      //     'ALTER TABLE loader_data_table ADD COLUMN external INTEGER DEFAULT 0');
      // int recordId = await db.insert('constellation_table',
      //     {'name': 'file1', 'lines': 'my_type', 'bullet': 'bullets'});
      // List<Map> queryResults =
      //     await db.rawQuery("SELECT count(*) FROM constellation_table");
      List<Map> queryResultsList =
          await db.rawQuery("SELECT * FROM loader_data_table");
      print(await db.rawQuery("SELECT * FROM constellation_table"));
      print(queryResultsList);

      setState(() {
        directoryFiles = queryResultsList;
        fileNameList = directoryFiles.map((e) => e["name"].toString()).toList();
        newConstellationNameController =
            TextEditingController(text: _validFileName("Constellation"));
        checkBoxActiveList = List.generate(fileNameList.length, (e) {
          return false;
        });
        db = retrievedDB;
      });
    } catch (e) {
      print(e);
    }
  }

  updateCheckBoxActive(int index, bool check) {
    setState(() {
      if (check) {
        checkBoxActiveList[index] = true;
        checkBoxActiveCount += 1;
      } else {
        checkBoxActiveList[index] = false;
        checkBoxActiveCount -= 1;
      }
    });
  }

  removeEntries() async {
    print(checkBoxActiveList);
    for (int i = 0; i < checkBoxActiveList.length; i++) {
      if (checkBoxActiveList[i]) {
        await removeEntry(directoryFiles[i]["id"]);
        print("---------1");
        print(await db.rawQuery("SELECT * FROM loader_data_table"));
        setState(() {
          checkBoxActiveList.removeAt(i);
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
    await db.execute("DELETE FROM loader_data_table WHERE id=$idNumber");
    await db.execute("DELETE FROM constellation_table WHERE id=$idNumber");
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
        await db.rawQuery("SELECT * FROM loader_data_table");
    setState(() {
      directoryFiles = queryResultsList;
      print(directoryFiles);
      fileNameList = directoryFiles.map((e) => e["name"].toString()).toList();
      checkBoxActiveList = List.generate(fileNameList.length, (e) {
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
    int index = 1;
    String newFileName = "$name ($index)";
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
                                  if (maximized) {
                                    maximized = !maximized;
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
              color: Color.fromARGB(255, 255, 255, 255), // Background color
            ),
            child: Container(
                color: const Color.fromARGB(255, 215, 222, 235),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(25),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                        child: const Row(
                                      children: [
                                        Text(
                                          "Overview",
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
                                                  color: Color.fromARGB(
                                                      255, 9, 42, 92),
                                                  border: Border.all(
                                                      color: const Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      width: 2),
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(2))),
                                              child: Container(
                                                  height: 100,
                                                  width: 100,
                                                  decoration: const BoxDecoration(
                                                      color: Color.fromARGB(
                                                          255, 9, 42, 92),
                                                      borderRadius:
                                                          const BorderRadius.all(
                                                              Radius.circular(10))),
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
                                                                                  if (_formKey.currentState!.validate()) {
                                                                                    _formKey.currentState?.save();
                                                                                    String constellationName = newConstellationNameController.text;
                                                                                    print(constellationName);

                                                                                    _createLevelFile(constellationName);
                                                                                    setState(() {
                                                                                      fileNameList.add(constellationName);
                                                                                      newConstellationNameController = TextEditingController(text: _validFileName("Constellation"));
                                                                                    });

                                                                                    await db.insert('loader_data_table', {
                                                                                      'name': constellationName,
                                                                                      'file_path': "$directoryName/$constellationName.txt",
                                                                                      'access_date': DateTime.now().toString().split(".")[0]
                                                                                    });
                                                                                    await db.insert('constellation_table', {
                                                                                      'name': constellationName,
                                                                                      'bullet_list': "[]"
                                                                                    });
                                                                                    _refreshLists();
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
                                                  color: Color.fromARGB(
                                                      255, 56, 99, 151),
                                                  border: Border.all(
                                                      color: const Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      width: 2),
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(10))),
                                              child: Container(
                                                  height: 100,
                                                  width: 100,
                                                  decoration: const BoxDecoration(
                                                      color: Color.fromARGB(
                                                          255, 56, 99, 151),
                                                      borderRadius: const BorderRadius.all(
                                                          Radius.circular(10))),
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
                                                          int recordId =
                                                              await db.insert(
                                                                  'loader_data_table',
                                                                  {
                                                                'name':
                                                                    validFileName,
                                                                'file_path':
                                                                    filePath,
                                                                'access_date':
                                                                    dateTime,
                                                                'external': 1
                                                              });
                                                          await db.insert(
                                                              'constellation_table',
                                                              {
                                                                'name':
                                                                    validFileName,
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
                                                        print(
                                                            "file upload result: $fileUploadResult");
                                                        if (context.mounted) {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                                builder: (context) => Test(
                                                                    path: fileUploadResult.paths[
                                                                            0] ??
                                                                        defaultFileName,
                                                                    fileName:
                                                                        fileNameMaintain)

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
                                                color: Color.fromARGB(
                                                    225, 204, 41, 54),
                                                borderRadius:
                                                    BorderRadius.circular(10)),
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
                                    Expanded(
                                        child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: const BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(10))),
                                            child: Column(children: [
                                              Container(
                                                color: const Color.fromARGB(
                                                    255, 255, 255, 255),
                                                height: 50,
                                                child: Row(children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 62),
                                                    child: Text("Constellation",
                                                        style: TextStyle(
                                                            color:
                                                                secondaryColor,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                  Spacer(),
                                                  checkBoxActiveCount > 0
                                                      ? Container(
                                                          margin:
                                                              EdgeInsets.only(
                                                                  right: 115),
                                                          child: IconButton(
                                                              style: const ButtonStyle(
                                                                  backgroundColor:
                                                                      WidgetStatePropertyAll(
                                                                          Colors
                                                                              .transparent)),
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              onPressed: () {
                                                                removeEntries();
                                                              },
                                                              icon: const Icon(
                                                                  Icons
                                                                      .delete_forever_sharp,
                                                                  color: Colors
                                                                      .black)))
                                                      : SizedBox(
                                                          width: 20,
                                                          height: 20),
                                                  Container(
                                                    margin: EdgeInsets.only(
                                                        right: 30),
                                                    child: Text("Date",
                                                        style: TextStyle(
                                                            color:
                                                                secondaryColor,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                ]),
                                              ),
                                              const SizedBox(height: 10),
                                              Expanded(
                                                  child: Container(
                                                      decoration: const BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          20)),
                                                          color: Colors.white,
                                                          border: Border.symmetric(
                                                              horizontal: BorderSide(
                                                                  color: Colors
                                                                      .white,
                                                                  width: 4))),
                                                      child: ListView.builder(
                                                          scrollDirection:
                                                              Axis.vertical,
                                                          shrinkWrap: true,
                                                          controller: scroller,
                                                          itemCount:
                                                              directoryFiles
                                                                  .length,
                                                          itemBuilder:
                                                              (BuildContext
                                                                      context,
                                                                  int index) {
                                                            return ViewLine(
                                                                updateCheckBox:
                                                                    updateCheckBoxActive,
                                                                updateDelete:
                                                                    removeEntry,
                                                                lineNumber:
                                                                    index,
                                                                name: directoryFiles[
                                                                        index]
                                                                    ["name"],
                                                                pathName: directoryFiles[
                                                                        index][
                                                                    "file_path"],
                                                                idNumber:
                                                                    directoryFiles[
                                                                            index]
                                                                        ['id'],
                                                                date: directoryFiles[
                                                                        index][
                                                                    'access_date'],
                                                                external: directoryFiles[
                                                                            index]
                                                                        [
                                                                        "external"] ==
                                                                    1);
                                                          })))
                                            ])))
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
      required this.external,
      required this.updateCheckBox,
      super.key});
  final int lineNumber;
  final String name;
  final String pathName;
  final String date;
  final int idNumber;
  final bool external;
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
      return Color.fromARGB(255, 255, 255, 255);
    }

    return Container(
        height: 65,
        margin: EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: isChecked ?? false
              ? Color.fromARGB(255, 196, 209, 235)
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
