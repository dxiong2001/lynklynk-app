import 'package:flutter/material.dart';

class Bullet extends StatefulWidget {
  const Bullet({
    super.key,
    required this.bulletLevel,
  });
  final int bulletLevel;
  @override
  BulletState createState() => BulletState();
}

class BulletState extends State<Bullet> {
  final TextEditingController bulletTextController =
      TextEditingController(text: "");
  String bulletText = "";
  bool focused = false;
  late int bulletLevel;
  bool editable = false;
  Color bulletColor = Color.fromARGB(255, 255, 255, 255);
  Color bulletFontColor = Colors.black;

  @override
  void initState() {
    bulletLevel = widget.bulletLevel;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void increaseLevel({int level = 1}) {
    if (bulletLevel + level > 7) {
      return;
    }
    setState(() {
      bulletLevel += level;
    });
  }

  void decreaseLevel({int level = 1}) {
    if (bulletLevel - level < 0) {
      return;
    }
    setState(() {
      bulletLevel -= level;
    });
  }

  int getLevel() {
    return bulletLevel;
  }

  String getBulletString() {
    return bulletText;
  }

  void setFocus(bool focus) {
    focused = focus;
  }

  bool getFocus() {
    return focused;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.only(
            left: (10 + 10 * bulletLevel.toDouble()),
            right: 10,
            top: 10,
            bottom: 10),
        child: Row(children: [
          Container(width: 6, height: 6, color: Colors.black),
          SizedBox(width: 10),
          GestureDetector(
              onTap: () {
                print("single press");
                setState(() {
                  focused = true;
                });
              },
              onDoubleTap: () {
                print("double press");
                print(editable);
                if (editable) return;
                setState(() {
                  editable = true;
                });
              },
              child: TapRegion(
                  onTapOutside: (tap) {
                    print("tap outside");
                    if (!focused && !editable) return;
                    setState(() {
                      editable = false;
                      focused = false;
                    });
                  },
                  child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                          border: Border.all(
                              width: focused ? 2 : 1, color: Colors.black),
                          borderRadius: BorderRadius.circular(5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: editable
                          ? TextField(
                              maxLines: null,
                              style: TextStyle(
                                color: bulletFontColor,
                                fontSize: 16,
                              ),
                              decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                  border: InputBorder.none),
                              controller: bulletTextController,
                            )
                          : Container(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                  style: const TextStyle(fontSize: 16),
                                  bulletTextController.text)))))
        ]));
  }
}
