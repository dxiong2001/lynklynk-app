import 'package:flutter/material.dart';
import 'package:lynklynk/classes/protoMainNodeClass.dart';
import 'package:lynklynk/classes/protoSecondaryNodeClass.dart';

class Connection {
  ProtoMainNode mainNode;
  List<ProtoSecondaryNode> secondaryNodeList;

  Connection({
    required this.mainNode,
    required this.secondaryNodeList,
  });
  String tostring() {
    return "{node1: ${mainNode.toString()}, node2: ${secondaryNodeList.toString()}}";
  }
}
