import 'package:flutter/material.dart';

class ProtoSecondaryNode {
  TextEditingController controller;
  TextEditingController modifierController;
  bool keyTerm;
  bool highlighted;

  ProtoSecondaryNode(
      {required this.controller,
      required this.modifierController,
      this.keyTerm = false,
      this.highlighted = false});
  String toString() {
    return "{text: ${controller.text}, modifier: ${modifierController.text}, keyTerm: $keyTerm, highlighted: $highlighted}";
  }
}
