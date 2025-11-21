import 'package:flutter/cupertino.dart';

class Bullet {
  int level;
  Key uniqueKey;
  FocusNode focus;
  TextEditingController controller;

  Bullet(this.level, this.uniqueKey, this.focus, this.controller);
}
