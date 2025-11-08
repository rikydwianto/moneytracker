import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'bill.g.dart';

enum BillRecurrence { once, daily, weekly, monthly, yearly, custom }

enum BillStatus { unpaid, paid, overdue }

@HiveType(typeId: 3)
class Bill extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String categoryId;

  @HiveField(4)
  final String walletId;

  @HiveField(5)
  final DateTime dueDate;

  @HiveField(6)
  final BillRecurrence recurrence;

  @HiveField(7)
  final BillStatus status;

  @HiveField(8)
  final bool reminderEnabled;

  @HiveField(9)
  final int reminderDaysBefore;

  @HiveField(10)
  final String? notes;

  @HiveField(11)
  final String userId;

  @HiveField(12)
  final DateTime? paidDate;

  @HiveField(13)
  final DateTime createdAt;

  const Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.walletId,
    required this.dueDate,
    this.recurrence = BillRecurrence.monthly,
    this.status = BillStatus.unpaid,
    this.reminderEnabled = true,
    this.reminderDaysBefore = 3,
    this.notes,
    required this.userId,
    this.paidDate,
    required this.createdAt,
  });

  bool get isOverdue {
    if (status == BillStatus.paid) return false;
    return DateTime.now().isAfter(dueDate);
  }

  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  int get daysUntilDue {
    return dueDate.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'categoryId': categoryId,
      'walletId': walletId,
      'dueDate': Timestamp.fromDate(dueDate),
      'recurrence': recurrence.toString().split('.').last,
      'status': status.toString().split('.').last,
      'reminderEnabled': reminderEnabled,
      'reminderDaysBefore': reminderDaysBefore,
      'notes': notes,
      'userId': userId,
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Bill.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Bill(
      id: doc.id,
      name: data['name'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      categoryId: data['categoryId'] ?? '',
      walletId: data['walletId'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      recurrence: BillRecurrence.values.firstWhere(
        (e) => e.toString().split('.').last == data['recurrence'],
        orElse: () => BillRecurrence.monthly,
      ),
      status: BillStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => BillStatus.unpaid,
      ),
      reminderEnabled: data['reminderEnabled'] ?? true,
      reminderDaysBefore: data['reminderDaysBefore'] ?? 3,
      notes: data['notes'],
      userId: data['userId'] ?? '',
      paidDate: data['paidDate'] != null
          ? (data['paidDate'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Bill copyWith({
    String? id,
    String? name,
    double? amount,
    String? categoryId,
    String? walletId,
    DateTime? dueDate,
    BillRecurrence? recurrence,
    BillStatus? status,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    String? notes,
    String? userId,
    DateTime? paidDate,
    DateTime? createdAt,
  }) {
    return Bill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      dueDate: dueDate ?? this.dueDate,
      recurrence: recurrence ?? this.recurrence,
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      paidDate: paidDate ?? this.paidDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    amount,
    categoryId,
    walletId,
    dueDate,
    recurrence,
    status,
    reminderEnabled,
    reminderDaysBefore,
    notes,
    userId,
    paidDate,
    createdAt,
  ];
}
