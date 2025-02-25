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
import 'package:lynklynk/test.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:pelaicons/pelaicons.dart';
import 'package:lynklynk/dashboard.dart';

class Loader extends StatefulWidget {
  const Loader({super.key});

  @override
  _Loader createState() => _Loader();
}

class _Loader extends State<Loader> {
  //Page Scroller
  ScrollController? scroller;

  bool appMaximized = false;

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
    return Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          toolbarHeight: 40,
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
        body: Container(child: Center(child: Text("LynkLynk"))));
  }
}
