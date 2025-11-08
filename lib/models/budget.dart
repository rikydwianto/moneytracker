import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'budget.g.dart';

enum BudgetPeriod { weekly, monthly, yearly, custom }

@HiveType(typeId: 2)
class Budget extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double limit;

  @HiveField(3)
  final double spent;

  @HiveField(4)
  final String categoryId;

  @HiveField(5)
  final String? walletId;

  @HiveField(6)
  final BudgetPeriod period;

  @HiveField(7)
  final DateTime startDate;

  @HiveField(8)
  final DateTime endDate;

  @HiveField(9)
  final String userId;

  @HiveField(10)
  final bool alertAt80Percent;

  @HiveField(11)
  final bool alertAtExceeded;

  @HiveField(12)
  final DateTime createdAt;

  const Budget({
    required this.id,
    required this.name,
    required this.limit,
    this.spent = 0,
    required this.categoryId,
    this.walletId,
    this.period = BudgetPeriod.monthly,
    required this.startDate,
    required this.endDate,
    required this.userId,
    this.alertAt80Percent = true,
    this.alertAtExceeded = true,
    required this.createdAt,
  });

  double get progress => spent / limit;
  double get remaining => limit - spent;
  bool get isExceeded => spent > limit;
  bool get isNear80Percent => progress >= 0.8 && progress < 1.0;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'limit': limit,
      'spent': spent,
      'categoryId': categoryId,
      'walletId': walletId,
      'period': period.toString().split('.').last,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'userId': userId,
      'alertAt80Percent': alertAt80Percent,
      'alertAtExceeded': alertAtExceeded,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Budget.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Budget(
      id: doc.id,
      name: data['name'] ?? '',
      limit: (data['limit'] ?? 0).toDouble(),
      spent: (data['spent'] ?? 0).toDouble(),
      categoryId: data['categoryId'] ?? '',
      walletId: data['walletId'],
      period: BudgetPeriod.values.firstWhere(
        (e) => e.toString().split('.').last == data['period'],
        orElse: () => BudgetPeriod.monthly,
      ),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
      alertAt80Percent: data['alertAt80Percent'] ?? true,
      alertAtExceeded: data['alertAtExceeded'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Budget copyWith({
    String? id,
    String? name,
    double? limit,
    double? spent,
    String? categoryId,
    String? walletId,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    bool? alertAt80Percent,
    bool? alertAtExceeded,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      userId: userId ?? this.userId,
      alertAt80Percent: alertAt80Percent ?? this.alertAt80Percent,
      alertAtExceeded: alertAtExceeded ?? this.alertAtExceeded,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    limit,
    spent,
    categoryId,
    walletId,
    period,
    startDate,
    endDate,
    userId,
    alertAt80Percent,
    alertAtExceeded,
    createdAt,
  ];
}
