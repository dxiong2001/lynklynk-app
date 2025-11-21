class Node {
  int id;
  final int constellationID;
  String text;
  int type; //0: text, 1: image, 2: article (source -> url), 3: file (pdf, txt), 4: external (links between constellations)
  String source;
  final String createdAt;
  final String updatedAt;

  Node(
      {required this.id,
      required this.constellationID,
      required this.text,
      required this.type,
      required this.source,
      required this.createdAt,
      required this.updatedAt});
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'constellation_id': constellationID,
      'text': text,
      'type': type,
      'source': source,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
