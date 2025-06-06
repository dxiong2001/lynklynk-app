import 'package:flutter/material.dart';

class ProtoMainNode {
  TextEditingController controller;
  FocusNode focus;
  bool keyTerm;
  bool highlighted;
  int type;
  String? externalFileLoaded;

  ProtoMainNode(
      {required this.controller,
      required this.focus,
      this.keyTerm = false,
      this.highlighted = false,
      this.type = 0});
  String toString() {
    return "{text: ${controller.text}, keyTerm: $keyTerm, highlighted: $highlighted}";
  }
}
