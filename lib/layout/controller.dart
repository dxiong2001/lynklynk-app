import 'package:flutter/material.dart';
import 'package:lynklynk/layout/constellation.dart';
import 'package:lynklynk/view.dart';

class Controller extends StatelessWidget {
  final DocumentProvider doc;
  final Function update;
  const Controller({super.key, required this.doc, required this.update});

  void _onEnterSpecial(PointerEvent event, DocumentProvider doc) {
    print("entered special area");
    doc.doc.setDisableClick(true);
    // setState(() {
    //   doc.doc.setDisableClick(true);
    // });
  }

  void _onExitSpecial(PointerEvent event, DocumentProvider doc) {
    doc.doc.setDisableClick(false);
    // setState(() {
    //   doc.doc.setDisableClick(false);
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
              bottom:
                  BorderSide(color: Color.fromARGB(255, 64, 70, 81), width: 2),
              right: BorderSide(
                  color: Color.fromARGB(255, 181, 227, 247), width: 2),
              left: BorderSide(
                  color: Color.fromARGB(255, 181, 227, 247), width: 2),
              top: BorderSide(
                  color: Color.fromARGB(255, 181, 227, 247), width: 2)),
        ),
        child: Row(
          children: [
            MouseRegion(
              onEnter: (event) => _onEnterSpecial(event, doc),
              onExit: (event) => _onExitSpecial(event, doc),
              child: IconButton(
                color: Colors.white,
                iconSize: 20,
                icon: const Icon(Icons.format_list_bulleted_sharp),
                onPressed: () {
                  doc.doc.bulletMode();
                  update();
                },
              ),
            ),
            const SizedBox(width: 10),
            Container(
                height: 20,
                width: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  border: Border(
                      bottom: BorderSide(
                          color: Color.fromARGB(255, 64, 70, 81), width: 2),
                      right: BorderSide(
                          color: Color.fromARGB(255, 181, 227, 247), width: 2),
                      left: BorderSide(
                          color: Color.fromARGB(255, 181, 227, 247), width: 2),
                      top: BorderSide(
                          color: Color.fromARGB(255, 181, 227, 247), width: 2)),
                ),
                child: IconButton(
                    padding: const EdgeInsets.all(0.0),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                      backgroundColor: const Color.fromARGB(255, 75, 185, 233),
                      shape: const ContinuousRectangleBorder(),
                    ),
                    onPressed: () {
                      doc.doc.setFontSize(doc.doc.getFontSize() - 1);
                      update();
                      print("button pressed");
                    },
                    iconSize: 15,
                    icon: const Icon(
                      Icons.arrow_drop_down_sharp,
                    ))),
            const SizedBox(width: 4),
            Container(
                decoration: const BoxDecoration(),
                alignment: Alignment.center,
                width: 40,
                height: 40,
                child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text((doc.doc.getFontSize()).toStringAsFixed(0),
                        style: const TextStyle(
                            fontFamily: "PressStart2P",
                            color: Colors.white,
                            fontSize: 13)))),
            // child: Form(
            //     child: Row(children: <Widget>[
            //   Expanded(
            //       child: TextFormField(
            //           style: TextStyle(fontSize: 15),
            //           keyboardType: TextInputType.number,
            //           inputFormatters: <TextInputFormatter>[
            //             FilteringTextInputFormatter.digitsOnly
            //           ],
            //           decoration: const InputDecoration()))
            // ]))),
            const SizedBox(width: 4),
            Container(
                height: 20,
                width: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  border: Border(
                      bottom: BorderSide(
                          color: Color.fromARGB(255, 64, 70, 81), width: 2),
                      right: BorderSide(
                          color: Color.fromARGB(255, 181, 227, 247), width: 2),
                      left: BorderSide(
                          color: Color.fromARGB(255, 181, 227, 247), width: 2),
                      top: BorderSide(
                          color: Color.fromARGB(255, 181, 227, 247), width: 2)),
                ),
                child: IconButton(
                    padding: const EdgeInsets.all(0.0),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                      backgroundColor: const Color.fromARGB(255, 75, 185, 233),
                      shape: const ContinuousRectangleBorder(),
                    ),
                    onPressed: () {
                      doc.doc.setFontSize(doc.doc.getFontSize() + 1);
                      update();
                    },
                    iconSize: 15,
                    icon: const Icon(
                      Icons.arrow_drop_up_sharp,
                    ))),
            const SizedBox(width: 10),
            Container(
                height: 20,
                width: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  border: Border(
                      bottom: BorderSide(
                          color: Color.fromARGB(255, 64, 70, 81), width: 2),
                      right: BorderSide(
                          color: Color.fromARGB(255, 181, 227, 247), width: 2),
                      left: BorderSide(
                          color: Color.fromARGB(255, 181, 227, 247), width: 2),
                      top: BorderSide(
                          color: Color.fromARGB(255, 181, 227, 247), width: 2)),
                ),
                child: IconButton(
                    padding: const EdgeInsets.all(0.0),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                      backgroundColor: const Color.fromARGB(255, 75, 185, 233),
                      shape: const ContinuousRectangleBorder(),
                    ),
                    onPressed: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //       builder: (context) => const Constellation()),
                      // );
                      // print("button pressed");
                    },
                    iconSize: 15,
                    icon: const Icon(
                      Icons.arrow_right_sharp,
                    ))),
          ],
        ));
  }
}
