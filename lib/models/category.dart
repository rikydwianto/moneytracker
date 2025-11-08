import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'transaction.dart';

part 'category.g.dart';

@HiveType(typeId: 4)
class Category extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String icon;

  @HiveField(3)
  final String color;

  @HiveField(4)
  final TransactionType type;

  @HiveField(5)
  final bool isDefault;

  @HiveField(6)
  final String? userId; // null for default categories

  // New: where this category applies: 'income' | 'expense' | 'both'
  @HiveField(7)
  final String applies;

  // Optional parent category id (for one-level subcategories)
  @HiveField(8)
  final String? parentId;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.isDefault = false,
    this.userId,
    this.parentId,
    String? applies,
  }) : applies =
           applies ?? (type == TransactionType.income ? 'income' : 'expense');

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'color': color,
      'type': type.toString().split('.').last,
      'applies': applies,
      'isDefault': isDefault,
      'userId': userId,
      'parentId': parentId,
    };
  }

  factory Category.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '',
      color: data['color'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => TransactionType.expense,
      ),
      applies: (data['applies'] as String?) ?? data['type'],
      isDefault: data['isDefault'] ?? false,
      userId: data['userId'],
      parentId: data['parentId'],
    );
  }

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
      color: map['color'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => TransactionType.expense,
      ),
      applies: (map['applies'] as String?) ?? map['type'],
      isDefault: map['isDefault'] ?? false,
      userId: map['userId'],
      parentId: map['parentId'],
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    TransactionType? type,
    bool? isDefault,
    String? userId,
    String? applies,
    String? parentId,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      userId: userId ?? this.userId,
      applies: applies ?? this.applies,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    icon,
    color,
    type,
    isDefault,
    userId,
    applies,
    parentId,
  ];
}

// Default categories
class DefaultCategories {
  static final List<Category> expenseCategories = [
    const Category(
      id: 'food',
      name: 'Makanan & Minuman',
      icon: '🍔',
      color: '#FF5722',
      type: TransactionType.expense,
      isDefault: true,
    ),
    // Subcategories of food
    const Category(
      id: 'food_meal',
      name: 'Makanan',
      icon: '🍛',
      color: '#FF7043',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'food',
    ),
    const Category(
      id: 'food_drink',
      name: 'Minuman',
      icon: '🥤',
      color: '#FF8A65',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'food',
    ),
    const Category(
      id: 'food_restaurant',
      name: 'Restoran',
      icon: '🍽️',
      color: '#FF7043',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'food',
    ),
    const Category(
      id: 'transport',
      name: 'Transportasi',
      icon: '🚗',
      color: '#2196F3',
      type: TransactionType.expense,
      isDefault: true,
    ),
    // Subcategories of transport
    const Category(
      id: 'transport_fuel',
      name: 'Bahan Bakar',
      icon: '⛽',
      color: '#42A5F5',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'transport',
    ),
    const Category(
      id: 'transport_public',
      name: 'Transportasi Umum',
      icon: '🚌',
      color: '#64B5F6',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'transport',
    ),
    const Category(
      id: 'transport_parking',
      name: 'Parkir',
      icon: '🅿️',
      color: '#90CAF9',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'transport',
    ),
    const Category(
      id: 'transport_toll',
      name: 'Tol',
      icon: '🛣️',
      color: '#BBDEFB',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'transport',
    ),
    const Category(
      id: 'shopping',
      name: 'Belanja',
      icon: '🛍️',
      color: '#E91E63',
      type: TransactionType.expense,
      isDefault: true,
    ),
    // Subcategories of shopping
    const Category(
      id: 'shopping_groceries',
      name: 'Belanja Harian',
      icon: '🧺',
      color: '#F06292',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'shopping',
    ),
    const Category(
      id: 'shopping_clothing',
      name: 'Pakaian',
      icon: '👕',
      color: '#EC407A',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'shopping',
    ),
    const Category(
      id: 'shopping_electronics',
      name: 'Elektronik',
      icon: '📱',
      color: '#D81B60',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'shopping',
    ),
    const Category(
      id: 'shopping_household',
      name: 'Rumah Tangga',
      icon: '🏠',
      color: '#C2185B',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'shopping',
    ),
    const Category(
      id: 'entertainment',
      name: 'Hiburan',
      icon: '🎮',
      color: '#9C27B0',
      type: TransactionType.expense,
      isDefault: true,
    ),
    // Subcategories of entertainment
    const Category(
      id: 'entertainment_movies',
      name: 'Bioskop',
      icon: '🎬',
      color: '#AB47BC',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'entertainment',
    ),
    const Category(
      id: 'entertainment_games',
      name: 'Game',
      icon: '🕹️',
      color: '#BA68C8',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'entertainment',
    ),
    const Category(
      id: 'entertainment_subscriptions',
      name: 'Langganan',
      icon: '📺',
      color: '#CE93D8',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'entertainment',
    ),
    const Category(
      id: 'entertainment_travel',
      name: 'Wisata',
      icon: '✈️',
      color: '#E1BEE7',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'entertainment',
    ),
    const Category(
      id: 'bills',
      name: 'Tagihan & Utilitas',
      icon: '💡',
      color: '#FFC107',
      type: TransactionType.expense,
      isDefault: true,
    ),
    // Subcategories of bills
    const Category(
      id: 'bills_electricity',
      name: 'Listrik',
      icon: '🔌',
      color: '#FFD54F',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'bills',
    ),
    const Category(
      id: 'bills_water',
      name: 'Air',
      icon: '🚰',
      color: '#FFE082',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'bills',
    ),
    const Category(
      id: 'bills_internet',
      name: 'Internet',
      icon: '🌐',
      color: '#FFCA28',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'bills',
    ),
    const Category(
      id: 'bills_phone',
      name: 'Telepon',
      icon: '📞',
      color: '#FFC107',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'bills',
    ),
    const Category(
      id: 'health',
      name: 'Kesehatan',
      icon: '💊',
      color: '#4CAF50',
      type: TransactionType.expense,
      isDefault: true,
    ),
    // Subcategories of health
    const Category(
      id: 'health_medicine',
      name: 'Obat',
      icon: '🧪',
      color: '#66BB6A',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'health',
    ),
    const Category(
      id: 'health_doctor',
      name: 'Dokter',
      icon: '🩺',
      color: '#81C784',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'health',
    ),
    const Category(
      id: 'health_insurance',
      name: 'Asuransi',
      icon: '🛡️',
      color: '#A5D6A7',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'health',
    ),
    const Category(
      id: 'health_fitness',
      name: 'Kebugaran',
      icon: '🏋️',
      color: '#C8E6C9',
      type: TransactionType.expense,
      isDefault: true,
      parentId: 'health',
    ),
    // System categories
    Category(
      id: 'transfer',
      name: 'Transfer',
      icon: '🔁',
      color: '#607D8B',
      type: TransactionType.transfer,
      isDefault: true,
      // Make it available for both income and expense flows
      applies: 'both',
    ),
    Category(
      id: 'adjustment',
      name: 'Penyesuaian',
      icon: '🧮',
      color: '#795548',
      type: TransactionType.expense,
      isDefault: true,
      applies: 'both',
    ),
    Category(
      id: 'debt',
      name: 'Hutang/Piutang',
      icon: '📝',
      color: '#455A64',
      type: TransactionType.debt,
      isDefault: true,
      applies: 'both',
    ),
  ];

  static final List<Category> incomeCategories = [
    const Category(
      id: 'salary',
      name: 'Gaji',
      icon: '💰',
      color: '#4CAF50',
      type: TransactionType.income,
      isDefault: true,
    ),
    // Subcategories of salary
    const Category(
      id: 'salary_base',
      name: 'Gaji Pokok',
      icon: '💵',
      color: '#66BB6A',
      type: TransactionType.income,
      isDefault: true,
      parentId: 'salary',
    ),
    const Category(
      id: 'salary_bonus',
      name: 'Bonus',
      icon: '🎉',
      color: '#81C784',
      type: TransactionType.income,
      isDefault: true,
      parentId: 'salary',
    ),
    const Category(
      id: 'business',
      name: 'Usaha',
      icon: '💼',
      color: '#1E88E5',
      type: TransactionType.income,
      isDefault: true,
    ),
    // Subcategories of business
    const Category(
      id: 'business_sales',
      name: 'Penjualan',
      icon: '🧾',
      color: '#42A5F5',
      type: TransactionType.income,
      isDefault: true,
      parentId: 'business',
    ),
    const Category(
      id: 'business_services',
      name: 'Jasa',
      icon: '🛠️',
      color: '#64B5F6',
      type: TransactionType.income,
      isDefault: true,
      parentId: 'business',
    ),
    const Category(
      id: 'investment',
      name: 'Investasi',
      icon: '📈',
      color: '#00BCD4',
      type: TransactionType.income,
      isDefault: true,
    ),
    // Subcategories of investment
    const Category(
      id: 'investment_dividend',
      name: 'Dividen',
      icon: '🏦',
      color: '#26C6DA',
      type: TransactionType.income,
      isDefault: true,
      parentId: 'investment',
    ),
    const Category(
      id: 'investment_gain',
      name: 'Capital Gain',
      icon: '📊',
      color: '#4DD0E1',
      type: TransactionType.income,
      isDefault: true,
      parentId: 'investment',
    ),
    const Category(
      id: 'gift',
      name: 'Hadiah',
      icon: '🎁',
      color: '#E91E63',
      type: TransactionType.income,
      isDefault: true,
    ),
    // Subcategories of gift
    const Category(
      id: 'gift_cash',
      name: 'Uang',
      icon: '💸',
      color: '#F06292',
      type: TransactionType.income,
      isDefault: true,
      parentId: 'gift',
    ),
    const Category(
      id: 'gift_goods',
      name: 'Barang',
      icon: '📦',
      color: '#EC407A',
      type: TransactionType.income,
      isDefault: true,
      parentId: 'gift',
    ),
  ];

  static List<Category> get allCategories => [
    ...expenseCategories,
    ...incomeCategories,
  ];
}
