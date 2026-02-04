class LibraryModel {
  final String id;
  final String name;
  final String collectionType;

  LibraryModel({
    required this.id,
    required this.name,
    required this.collectionType,
  });

  factory LibraryModel.fromJson(Map<String, dynamic> json) {
    return LibraryModel(
      id: json['Id'],
      name: json['Name'] ?? 'Unknown',
      collectionType: json['CollectionType'] ?? 'unknown',
    );
  }
}
