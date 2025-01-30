class DBFile {
  final int id;
  String fileDirectory;
  String fileName;
  final String createDate;
  String accessDate;
  String updateDate;
  List tags;
  int starred;

  DBFile({
    required this.id,
    required this.fileDirectory,
    required this.fileName,
    required this.createDate,
    required this.accessDate,
    required this.updateDate,
    required this.tags,
    required this.starred,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'fileDirectory': fileDirectory,
      'fileName': fileName,
      'createDate': createDate,
      'accessDate': accessDate,
      'updateDate': updateDate,
      'tags': tags.toString(),
      'starred': starred,
    };
  }
}

class Node {
  final int id;
  String nodeTerm;
  List<String> auxiliaries;
  String color;
  final String createDate;
  String updateDate;

  Node(
      {required this.id,
      required this.nodeTerm,
      required this.auxiliaries,
      required this.color,
      required this.createDate,
      required this.updateDate});
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nodeTerm': nodeTerm,
      'auxiliaries': auxiliaries.toString(),
      'color': color,
      'createDate': createDate,
      'updateDate': updateDate,
    };
  }
}
