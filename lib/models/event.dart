import 'package:hive/hive.dart';

part 'event.g.dart';

@HiveType(typeId: 3)
class Event extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isActive;

  @HiveField(3)
  DateTime? startDate;

  @HiveField(4)
  DateTime? endDate;

  @HiveField(5)
  double? budget;

  @HiveField(6)
  String? notes;

  @HiveField(7)
  String userId;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  Event({
    required this.id,
    required this.name,
    this.isActive = false,
    this.startDate,
    this.endDate,
    this.budget,
    this.notes,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to RTDB Map
  Map<String, dynamic> toRtdbMap() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'budget': budget,
      'notes': notes,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from RTDB
  factory Event.fromRtdb(Map<dynamic, dynamic> map, String id) {
    return Event(
      id: id,
      name: map['name'] as String,
      isActive: map['isActive'] as bool? ?? false,
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'] as String)
          : null,
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      budget: map['budget'] != null ? (map['budget'] as num).toDouble() : null,
      notes: map['notes'] as String?,
      userId: map['userId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  // CopyWith method
  Event copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    String? notes,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Event(id: $id, name: $name, isActive: $isActive, startDate: $startDate, endDate: $endDate, budget: $budget)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
