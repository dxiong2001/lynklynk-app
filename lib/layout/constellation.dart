import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lynklynk/utils/stack.dart' as Stack;
import 'package:flip_card/flip_card.dart';
import 'package:auto_size_text/auto_size_text.dart';

class Constellation extends StatefulWidget {
  const Constellation(
      {super.key,
      required this.bulletList,
      required this.textList,
      required this.line});
  final List<int> bulletList;
  final List<String> textList;
  final String line;

  @override
  _Constellation createState() => _Constellation();
}

class _Constellation extends State<Constellation> {
  bool maximized = false;
  Map mappingTable = <String, List<String>>{};
  var currentTerm = "";
  List<String> currentTermChildren = <String>[];
  var db;
  Map auxiliaryTable = <String, bool>{};
  @override
  void initState() {
    _initProcess();

    super.initState();
  }

  void setTerm(String term) {
    currentTerm = term;
    currentTermChildren = mappingTable[term];
  }

  void _initProcess() {
    if (widget.bulletList.isEmpty || widget.textList.isEmpty) {
      print("Error: Exited early due to bulletList and textList issue");
      return;
    }

    // for (int i = 0; i < widget.bulletList.length; i++) {
    //   if (widget.textList[i].isEmpty) {
    //     widget.textList.removeAt(i);
    //     widget.bulletList.removeAt(i);
    //     i--;
    //   }
    // }

    if (widget.bulletList.length != widget.textList.length) {
      if (widget.bulletList.length > widget.textList.length) {
        print(
            "Error: Exited early due to bulletList and textList length issue");
        return;
      }
    }
    Stack.Stack s = Stack.Stack();
    for (int i = 0; i < widget.bulletList.length; i++) {
      // print(s);
      String line = widget.textList[i];
      int index = widget.bulletList[i];
      if (i == 0) {
        s.push({"index": index, "line": line});
        mappingTable[widget.textList[i]] = <String>[];
        continue;
      }
      mappingTable.putIfAbsent(line, () => <String>[]);
      // if outside
      if (widget.bulletList[i] <= s.peek["index"]) {
        while (s.isNotEmpty && s.peek["index"] >= index) {
          s.pop();
        }
        if (index != 0) {
          mappingTable[line].add(s.peek["line"]);
          mappingTable[s.peek["line"]].add(line);
        }
      }
      // if inside
      else {
        mappingTable[line].add(s.peek["line"]);
        mappingTable[s.peek["line"]].add(line);
      }
      s.push({"index": index, "line": line});
    }
    // print(mappingTable);
    setTerm(widget.line);
  }

  Widget auxiliary(String term, int index, String ledger, Map record) {
    bool showSubNodes = false;
    if (index > 5) {
      return const SizedBox();
    }

    if (record[term] != null) {
      return const SizedBox();
    }

    if (auxiliaryTable[ledger + term] == null) {
      auxiliaryTable[ledger + term] = false;
    }
    print(record);
    record[term] = true;
    print(record);
    return term.isEmpty
        ? const SizedBox()
        : Container(
            child: Column(children: [
            Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  border: Border.all(color: Colors.black, width: 1),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                margin: EdgeInsets.only(top: 5, bottom: 5, left: index * 15),
                child: Row(children: [
                  ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 36),
                      child: Container(
                          alignment: Alignment.centerLeft,
                          width: 570 - index * 15,
                          padding: const EdgeInsets.only(right: 18),
                          decoration: const BoxDecoration(
                              border: Border(
                                  right: BorderSide(
                                      width: 0.5, color: Colors.black))),
                          child: GestureDetector(
                              onTap: () {
                                setTerm(term);
                                setState(() {});
                              },
                              child: AutoSizeText(
                                term,
                              )))),
                  const Spacer(),
                  index < 5
                      ? IconButton(
                          onPressed: () {
                            auxiliaryTable[ledger + term] =
                                !auxiliaryTable[ledger + term];
                            setState(() {});
                            print(showSubNodes);
                          },
                          icon: !auxiliaryTable[ledger + term]
                              ? const Icon(Icons.arrow_drop_down_sharp)
                              : const Icon(Icons.arrow_drop_up_sharp))
                      : const SizedBox()
                ])),
            auxiliaryTable[ledger + term]
                ? Container(
                    child: Column(
                        children: mappingTable[term]
                            .map<Widget>((item) => auxiliary(
                                item, index + 1, "$ledger-$term", record))
                            .toList()))
                : const SizedBox()
          ]));
  }

  @override
  void dispose() {
    super.dispose();
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
        drawer: Drawer(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          child: ListView(
            children: <Widget>[
              SizedBox(
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
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () {
                  // Handle menu item tap
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  // Handle menu item tap
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Logout'),
                onTap: () {
                  // Handle menu item tap
                },
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
            child: Container(
                color: const Color.fromARGB(255, 233, 237, 246),
                width: 800,
                child: Column(children: [
                  Row(children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_left_sharp),
                        onPressed: () {
                          Navigator.pop(context);
                        })
                  ]),
                  Center(
                      child: Column(children: [
                    Card(
                      elevation: 0.0,
                      margin: const EdgeInsets.only(
                          left: 32.0, right: 32.0, top: 20.0, bottom: 0.0),
                      color: Colors.black,
                      child: FlipCard(
                        direction: FlipDirection.HORIZONTAL,
                        side: CardSide.FRONT,
                        speed: 680,
                        onFlipDone: (status) {
                          print(status);
                        },
                        front: Container(
                          height: 300,
                          width: 650,
                          decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 255, 255, 255),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(8.0)),
                              border:
                                  Border.all(color: Colors.black, width: 1)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 5, horizontal: 25),
                                  child: AutoSizeText(
                                    currentTerm,
                                    maxLines: 9,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  )),
                            ],
                          ),
                        ),
                        back: Container(
                          height: 300,
                          width: 650,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8.0)),
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: currentTermChildren
                                  .map((item) => Text(item))
                                  .toList()),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: 650,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            child: ExpansionTile(
                              shape: const Border(),
                              title: const Text('Auxiliaries'),
                              children: currentTermChildren
                                      .map((item) => auxiliary(item, 0, "", {}))
                                      .toList() +
                                  [Container(height: 10)],
                            ))),
                  ]))
                ]))));
  }
}

// Container(
//                       alignment: Alignment.center,
//                       height: 300,
//                       width: 700,
//                       color: Colors.white,
//                       child: Text(
//                         currentTerm,
//                         style: const TextStyle(
//                             fontSize: 20, fontWeight: FontWeight.bold),
//                       ))

class Auxiliary extends StatefulWidget {
  const Auxiliary(
      {required this.term,
      required this.mappingTable,
      required this.index,
      super.key});
  final String term;
  final Map mappingTable;
  final int index;

  @override
  State<Auxiliary> createState() => _Auxiliary();
}

class _Auxiliary extends State<Auxiliary> {
  bool showAuxiliary = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(children: [
      Row(
        children: [
          Container(child: Text(widget.term)),
          Container(
              child: IconButton(
                  onPressed: () {
                    setState(() {
                      showAuxiliary = !showAuxiliary;
                    });
                  },
                  icon: const Icon(Icons.arrow_drop_down_sharp)))
        ],
      )
    ]));
  }
}
