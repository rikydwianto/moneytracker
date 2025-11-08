import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'wallet.g.dart';

@HiveType(typeId: 0)
class Wallet extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double balance;

  @HiveField(3)
  final String currency;

  @HiveField(4)
  final String icon;

  @HiveField(5)
  final String color;

  @HiveField(6)
  final String userId;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  @HiveField(9)
  final bool isShared;

  @HiveField(10)
  final List<String>? sharedWith;

  // Optional short alias for quick transfers (unique per user)
  @HiveField(11)
  final String? alias;

  // Is this the default wallet for new transactions
  @HiveField(12)
  final bool isDefault;

  // Exclude from total balance calculation
  @HiveField(13)
  final bool excludeFromTotal;

  const Wallet({
    required this.id,
    required this.name,
    required this.balance,
    this.currency = 'IDR',
    this.icon = '💳',
    this.color = '#1E88E5',
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.isShared = false,
    this.sharedWith,
    this.alias,
    this.isDefault = false,
    this.excludeFromTotal = false,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'balance': balance,
      'currency': currency,
      'icon': icon,
      'color': color,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isShared': isShared,
      'sharedWith': sharedWith ?? [],
      'alias': alias,
      'isDefault': isDefault,
      'excludeFromTotal': excludeFromTotal,
    };
  }

  // Convert to Realtime Database JSON
  Map<String, dynamic> toRtdbMap() {
    return {
      'name': name,
      'balance': balance,
      'currency': currency,
      'icon': icon,
      'color': color,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isShared': isShared,
      'sharedWith': sharedWith ?? [],
      'alias': alias,
      'isDefault': isDefault,
      'excludeFromTotal': excludeFromTotal,
    };
  }

  // Create from Firestore document
  factory Wallet.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Wallet(
      id: doc.id,
      name: data['name'] ?? '',
      balance: (data['balance'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'IDR',
      icon: data['icon'] ?? '💳',
      color: data['color'] ?? '#1E88E5',
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isShared: data['isShared'] ?? false,
      sharedWith: data['sharedWith'] != null
          ? List<String>.from(data['sharedWith'])
          : null,
      alias: data['alias'],
      isDefault: data['isDefault'] ?? false,
      excludeFromTotal: data['excludeFromTotal'] ?? false,
    );
  }

  // Create from JSON (for Hive)
  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'IDR',
      icon: json['icon'] ?? '💳',
      color: json['color'] ?? '#1E88E5',
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isShared: json['isShared'] ?? false,
      sharedWith: json['sharedWith'] != null
          ? List<String>.from(json['sharedWith'])
          : null,
      alias: json['alias'],
      isDefault: json['isDefault'] ?? false,
      excludeFromTotal: json['excludeFromTotal'] ?? false,
    );
  }

  // Create from Realtime Database snapshot value
  factory Wallet.fromRtdb(String id, Map<dynamic, dynamic> data) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Wallet(
      id: id,
      name: (data['name'] ?? '') as String,
      balance: ((data['balance'] ?? 0) as num).toDouble(),
      currency: (data['currency'] ?? 'IDR') as String,
      icon: (data['icon'] ?? '💳') as String,
      color: (data['color'] ?? '#1E88E5') as String,
      userId: (data['userId'] ?? '') as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        parseInt(data['createdAt']),
        isUtc: false,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        parseInt(data['updatedAt']),
        isUtc: false,
      ),
      isShared: (data['isShared'] ?? false) as bool,
      sharedWith: (data['sharedWith'] is List)
          ? List<String>.from(data['sharedWith'] as List)
          : null,
      alias: data['alias'] as String?,
      isDefault: (data['isDefault'] ?? false) as bool,
      excludeFromTotal: (data['excludeFromTotal'] ?? false) as bool,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'currency': currency,
      'icon': icon,
      'color': color,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isShared': isShared,
      'sharedWith': sharedWith,
      'alias': alias,
      'isDefault': isDefault,
      'excludeFromTotal': excludeFromTotal,
    };
  }

  // Create a copy with modified fields
  Wallet copyWith({
    String? id,
    String? name,
    double? balance,
    String? currency,
    String? icon,
    String? color,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isShared,
    List<String>? sharedWith,
    String? alias,
    bool? isDefault,
    bool? excludeFromTotal,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isShared: isShared ?? this.isShared,
      sharedWith: sharedWith ?? this.sharedWith,
      alias: alias ?? this.alias,
      isDefault: isDefault ?? this.isDefault,
      excludeFromTotal: excludeFromTotal ?? this.excludeFromTotal,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    balance,
    currency,
    icon,
    color,
    userId,
    createdAt,
    updatedAt,
    isShared,
    sharedWith,
    alias,
    isDefault,
    excludeFromTotal,
  ];
}
