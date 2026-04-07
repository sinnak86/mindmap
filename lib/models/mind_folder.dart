class MindFolder {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final int? colorValue; // null = default amber

  const MindFolder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    this.colorValue,
  });

  MindFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    DateTime? createdAt,
    int? colorValue,
    bool clearColor = false,
  }) {
    return MindFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'createdAt': createdAt.toIso8601String(),
        'colorValue': colorValue,
      };

  factory MindFolder.fromJson(Map<String, dynamic> json) => MindFolder(
        id: json['id'] as String,
        name: json['name'] as String,
        parentId: json['parentId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        colorValue: json['colorValue'] as int?,
      );
}
