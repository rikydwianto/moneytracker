import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'transaction.g.dart';

enum TransactionType { income, expense, transfer, debt }

@HiveType(typeId: 1)
class TransactionModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final TransactionType type;

  @HiveField(4)
  final String categoryId;

  @HiveField(5)
  final String walletId;

  @HiveField(6)
  final String? toWalletId; // For transfers

  @HiveField(7)
  final DateTime date;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final String? photoUrl;

  @HiveField(10)
  final String userId;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final DateTime updatedAt;

  @HiveField(13)
  final bool isSynced;

  // Debt-specific fields (optional)
  // counterpartyName: who borrowed (hutang) or who was lent to (piutang)
  @HiveField(14)
  final String? counterpartyName;

  // 'hutang' (you owe) or 'piutang' (they owe you)
  @HiveField(15)
  final String? debtDirection;

  // Event association (optional)
  @HiveField(16)
  final String? eventId;

  // Debt payment tracking
  @HiveField(17)
  final DateTime? dueDate; // Tanggal jatuh tempo

  @HiveField(18)
  final double? paidAmount; // Jumlah yang sudah dibayar

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    this.toWalletId,
    required this.date,
    this.notes,
    this.photoUrl,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.counterpartyName,
    this.debtDirection,
    this.eventId,
    this.dueDate,
    this.paidAmount,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'type': type.toString().split('.').last,
      'categoryId': categoryId,
      'walletId': walletId,
      'toWalletId': toWalletId,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'photoUrl': photoUrl,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'counterpartyName': counterpartyName,
      'debtDirection': debtDirection,
      'eventId': eventId,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'paidAmount': paidAmount,
    };
  }

  // Convert to Realtime Database JSON
  Map<String, dynamic> toRtdbMap() {
    return {
      'title': title,
      'amount': amount,
      'type': type.toString().split('.').last,
      'categoryId': categoryId,
      'walletId': walletId,
      'toWalletId': toWalletId,
      'date': date.millisecondsSinceEpoch,
      'notes': notes,
      'photoUrl': photoUrl,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'counterpartyName': counterpartyName,
      'debtDirection': debtDirection,
      'eventId': eventId,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'paidAmount': paidAmount,
    };
  }

  // Create from Firestore document
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => TransactionType.expense,
      ),
      categoryId: data['categoryId'] ?? '',
      walletId: data['walletId'] ?? '',
      toWalletId: data['toWalletId'],
      date: (data['date'] as Timestamp).toDate(),
      notes: data['notes'],
      photoUrl: data['photoUrl'],
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isSynced: true,
      counterpartyName: data['counterpartyName'] as String?,
      debtDirection: data['debtDirection'] as String?,
      eventId: data['eventId'] as String?,
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      paidAmount: data['paidAmount'] != null
          ? (data['paidAmount'] as num).toDouble()
          : null,
    );
  }

  // Create from Realtime Database snapshot value
  factory TransactionModel.fromRtdb(String id, Map<dynamic, dynamic> data) {
    return TransactionModel(
      id: id,
      title: (data['title'] ?? '') as String,
      amount: ((data['amount'] ?? 0) as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == (data['type'] ?? 'expense'),
        orElse: () => TransactionType.expense,
      ),
      categoryId: (data['categoryId'] ?? '') as String,
      walletId: (data['walletId'] ?? '') as String,
      toWalletId: data['toWalletId'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch((data['date'] ?? 0) as int),
      notes: data['notes'] as String?,
      photoUrl: data['photoUrl'] as String?,
      userId: (data['userId'] ?? '') as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['createdAt'] ?? 0) as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (data['updatedAt'] ?? 0) as int,
      ),
      isSynced: true,
      counterpartyName: data['counterpartyName'] as String?,
      debtDirection: data['debtDirection'] as String?,
      eventId: data['eventId'] as String?,
      dueDate: data['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['dueDate'] as int)
          : null,
      paidAmount: data['paidAmount'] != null
          ? (data['paidAmount'] as num).toDouble()
          : null,
    );
  }

  // Convert to JSON (for Hive)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.toString().split('.').last,
      'categoryId': categoryId,
      'walletId': walletId,
      'toWalletId': toWalletId,
      'date': date.toIso8601String(),
      'notes': notes,
      'photoUrl': photoUrl,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced,
      'counterpartyName': counterpartyName,
      'debtDirection': debtDirection,
      'eventId': eventId,
      'dueDate': dueDate?.toIso8601String(),
      'paidAmount': paidAmount,
    };
  }

  // Create from JSON
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => TransactionType.expense,
      ),
      categoryId: json['categoryId'] ?? '',
      walletId: json['walletId'] ?? '',
      toWalletId: json['toWalletId'],
      date: DateTime.parse(json['date']),
      notes: json['notes'],
      photoUrl: json['photoUrl'],
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isSynced: json['isSynced'] ?? false,
      counterpartyName: json['counterpartyName'],
      debtDirection: json['debtDirection'],
      eventId: json['eventId'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      paidAmount: json['paidAmount'] != null
          ? (json['paidAmount'] as num).toDouble()
          : null,
    );
  }

  // Create a copy with modified fields
  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? walletId,
    String? toWalletId,
    DateTime? date,
    String? notes,
    String? photoUrl,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? counterpartyName,
    String? debtDirection,
    String? eventId,
    DateTime? dueDate,
    double? paidAmount,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      toWalletId: toWalletId ?? this.toWalletId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      debtDirection: debtDirection ?? this.debtDirection,
      eventId: eventId ?? this.eventId,
      dueDate: dueDate ?? this.dueDate,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    amount,
    type,
    categoryId,
    walletId,
    toWalletId,
    date,
    notes,
    photoUrl,
    userId,
    createdAt,
    updatedAt,
    isSynced,
    counterpartyName,
    debtDirection,
    eventId,
    dueDate,
    paidAmount,
  ];
}
