import 'dart:convert';

class Constellation {
  int id;
  String name;
  String concept;
  String summary;
  String image;
  List<String> keyWords;
  String directory;
  int starred;
  final String createdAt;
  String accessedAt;
  String updatedAt;

  Constellation({
    required this.id,
    required this.name,
    required this.concept,
    required this.summary,
    required this.image,
    required this.keyWords,
    required this.directory,
    required this.starred,
    required this.createdAt,
    required this.accessedAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'concept': concept,
      'summary': summary,
      'image': image,
      'key_words': jsonEncode(keyWords),
      'directory': directory,
      'starred': starred,
      'created_at': createdAt,
      'accessed_at': accessedAt,
      'updated_at': updatedAt,
    };
  }

  @override
  String toString() {
    return 'Constellation(id: $id, name: $name, concept: $concept, summary: $summary, image: $image, key_words: ${keyWords.toString()}, directory: $directory, starred: $starred, created_at: $createdAt, accessed_at: $accessedAt, updated_at: $updatedAt)';
  }
}
