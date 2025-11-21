class Edge {
  final int id;
  final int constellationID;
  int fromNodeID;
  int toNodeID; //0: text, 1: image, 2: article (source -> url), 3: file (pdf, txt), 4: external (links between constellations)
  String relation;
  final String createdAt;
  final String updatedAt;

  Edge(
      {required this.id,
      required this.constellationID,
      required this.fromNodeID,
      required this.toNodeID,
      required this.relation,
      required this.createdAt,
      required this.updatedAt});
}
