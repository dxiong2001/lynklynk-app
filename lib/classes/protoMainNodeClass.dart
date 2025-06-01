import 'package:flutter/material.dart';

class ProtoMainNode {
  TextEditingController controller;
  bool keyTerm;
  bool highlighted;

  ProtoMainNode(
      {required this.controller,
      this.keyTerm = false,
      this.highlighted = false});
  String toString() {
    return "{text: ${controller.text}, keyTerm: $keyTerm, highlighted: $highlighted}";
  }
}
