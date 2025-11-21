import 'package:flutter/material.dart';

class ProtoSecondaryNode {
  TextEditingController controller;
  TextEditingController modifierController;
  FocusNode focus;
  bool keyTerm;
  bool highlighted;
  int type;
  String? externalFileLoaded;

  ProtoSecondaryNode(
      {required this.controller,
      required this.modifierController,
      required this.focus,
      this.keyTerm = false,
      this.highlighted = false,
      this.type = 0});
  String toString() {
    return "{text: ${controller.text}, modifier: ${modifierController.text}, keyTerm: $keyTerm, highlighted: $highlighted}";
  }
}
