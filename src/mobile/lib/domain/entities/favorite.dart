class Favorite {
  final String id;
  final String type;
  final String itemId;
  final DateTime addedAt;

  Favorite({
    required this.id,
    required this.type,
    required this.itemId,
    required this.addedAt,
  });

  factory Favorite.fromMap(Map<String, dynamic> map) {
    return Favorite(
      id: map['id'] as String,
      type: map['type'] as String,
      itemId: map['item_id'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'item_id': itemId,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }
}
