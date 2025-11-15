// Statistics Page
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../models/transaction.dart';
import '../../services/transaction_service.dart';
import '../../utils/date_helpers.dart';
import '../../utils/idr.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {
  String _selectedPeriod = 'bulan_ini';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'bulan_ini':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case 'bulan_lalu':
        final lastMonth = DateTime(now.year, now.month - 1);
        return DateTimeRange(
          start: DateTime(lastMonth.year, lastMonth.month, 1),
          end: DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59),
        );
      case '7_hari':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: now,
        );
      case '30_hari':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 29),
          end: now,
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Silakan login terlebih dahulu'));
    }

    final dateRange = _getDateRange();

    return Column(
      children: [
        // Period Selector
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'bulan_ini',
                        child: Text('Bulan Ini'),
                      ),
                      DropdownMenuItem(
                        value: 'bulan_lalu',
                        child: Text('Bulan Lalu'),
                      ),
                      DropdownMenuItem(
                        value: '7_hari',
                        child: Text('7 Hari Terakhir'),
                      ),
                      DropdownMenuItem(
                        value: '30_hari',
                        child: Text('30 Hari Terakhir'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPeriod = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Ringkasan'),
              Tab(text: 'Per Kategori'),
            ],
          ),
        ),
        // Tab Views
        Expanded(
          child: StreamBuilder<List<TransactionModel>>(
            stream: TransactionService().streamTransactions(user.uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allTransactions = snapshot.data!;

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildSummaryTab(allTransactions, dateRange),
                  _buildCategoryTab(allTransactions, dateRange),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTab(
    List<TransactionModel> allTransactions,
    DateTimeRange dateRange,
  ) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Builder(
          builder: (context) {
            final filteredTransactions = allTransactions.where((tx) {
              return tx.date.isAfter(
                    dateRange.start.subtract(const Duration(days: 1)),
                  ) &&
                  tx.date.isBefore(dateRange.end.add(const Duration(days: 1)));
            }).toList();

            double totalIncome = 0;
            double totalExpense = 0;
            int incomeCount = 0;
            int expenseCount = 0;

            for (var tx in filteredTransactions) {
              if (tx.type == TransactionType.income) {
                totalIncome += tx.amount;
                incomeCount++;
              } else if (tx.type == TransactionType.expense) {
                totalExpense += tx.amount;
                expenseCount++;
              }
            }

            final balance = totalIncome - totalExpense;

            return Column(
              children: [
                // Balance Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: balance >= 0
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.red.shade400, Colors.red.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (balance >= 0 ? Colors.green : Colors.red)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Saldo Periode',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        IdrFormatters.format(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        balance >= 0 ? 'Surplus' : 'Defisit',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Income & Expense Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Pemasukan',
                        totalIncome,
                        incomeCount,
                        Icons.trending_up,
                        Colors.green,
                        onTap: () => _showTransactionList(
                          context,
                          'Pemasukan',
                          filteredTransactions
                              .where((t) => t.type == TransactionType.income)
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Pengeluaran',
                        totalExpense,
                        expenseCount,
                        Icons.trending_down,
                        Colors.red,
                        onTap: () => _showTransactionList(
                          context,
                          'Pengeluaran',
                          filteredTransactions
                              .where((t) => t.type == TransactionType.expense)
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Savings Rate
                if (totalIncome > 0)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.savings_outlined,
                                size: 20,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Tingkat Pemasukan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: (totalIncome - totalExpense) / totalIncome,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              balance >= 0 ? Colors.green : Colors.red,
                            ),
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${((totalIncome - totalExpense) / totalIncome * 100).toStringAsFixed(1)}% dari pemasukan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Daily Average
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Rata-rata Harian',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pemasukan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    IdrFormatters.format(
                                      dateRange.duration.inDays > 0
                                          ? totalIncome /
                                                dateRange.duration.inDays
                                          : totalIncome,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pengeluaran',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    IdrFormatters.format(
                                      dateRange.duration.inDays > 0
                                          ? totalExpense /
                                                dateRange.duration.inDays
                                          : totalExpense,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    double amount,
    int count,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              IdrFormatters.format(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count transaksi',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(
    List<TransactionModel> allTransactions,
    DateTimeRange dateRange,
  ) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: Builder(
        builder: (context) {
          final filteredTransactions = allTransactions.where((tx) {
            return tx.date.isAfter(
                  dateRange.start.subtract(const Duration(days: 1)),
                ) &&
                tx.date.isBefore(dateRange.end.add(const Duration(days: 1)));
          }).toList();

          // Group by category
          final Map<String, List<TransactionModel>> categoryGroups = {};
          for (var tx in filteredTransactions) {
            // Handle kategori kosong atau null
            String key = tx.categoryId;
            if (key.isEmpty) {
              // Jika kategori kosong, group berdasarkan type
              switch (tx.type) {
                case TransactionType.transfer:
                  key = 'no_category_transfer';
                  break;
                case TransactionType.debt:
                  key = 'no_category_debt';
                  break;
                case TransactionType.income:
                  key = 'no_category_income';
                  break;
                case TransactionType.expense:
                  key = 'no_category_expense';
                  break;
              }
            }
            categoryGroups.putIfAbsent(key, () => []).add(tx);
          }

          // Calculate totals per category
          final categoryStats = categoryGroups.entries.map((entry) {
            double total = 0;
            for (var tx in entry.value) {
              total += tx.amount;
            }
            return {
              'categoryId': entry.key,
              'transactions': entry.value,
              'total': total,
              'count': entry.value.length,
            };
          }).toList();

          // Sort by total
          categoryStats.sort(
            (a, b) => (b['total'] as double).compareTo(a['total'] as double),
          );

          final grandTotal = categoryStats.fold<double>(
            0,
            (sum, item) => sum + (item['total'] as double),
          );

          if (categoryStats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pie_chart_outline,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada data',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categoryStats.length,
            itemBuilder: (context, index) {
              final stat = categoryStats[index];
              final categoryId = stat['categoryId'] as String;
              final total = stat['total'] as double;
              final count = stat['count'] as int;
              final transactions =
                  stat['transactions'] as List<TransactionModel>;
              final percentage = (total / grandTotal * 100);

              return FutureBuilder<DatabaseEvent>(
                future: FirebaseDatabase.instance
                    .ref(
                      'users/${FirebaseAuth.instance.currentUser?.uid ?? ''}/categories/$categoryId',
                    )
                    .once(),
                builder: (context, categorySnap) {
                  String categoryName = 'Kategori Tidak Ditemukan';
                  String categoryIconString = '📂'; // Default emoji
                  Color categoryColor = Colors.grey;

                  // Handle special cases for no category
                  if (categoryId.startsWith('no_category_')) {
                    switch (categoryId) {
                      case 'no_category_transfer':
                        categoryName = 'Transfer (Tanpa Kategori)';
                        categoryIconString = '🔄';
                        categoryColor = Colors.blue;
                        break;
                      case 'no_category_debt':
                        categoryName = 'Utang/Piutang (Tanpa Kategori)';
                        categoryIconString = '💰';
                        categoryColor = Colors.orange;
                        break;
                      case 'no_category_income':
                        categoryName = 'Pemasukan (Tanpa Kategori)';
                        categoryIconString = '📈';
                        categoryColor = Colors.green;
                        break;
                      case 'no_category_expense':
                        categoryName = 'Pengeluaran (Tanpa Kategori)';
                        categoryIconString = '📉';
                        categoryColor = Colors.red;
                        break;
                    }
                  } else if (categorySnap.hasData &&
                      categorySnap.data!.snapshot.value != null) {
                    // Handle categories from Firebase
                    try {
                      final catData =
                          categorySnap.data!.snapshot.value
                              as Map<dynamic, dynamic>;
                      categoryName =
                          catData['name']?.toString() ?? categoryName;

                      // Ambil icon emoji dari Firebase
                      final iconString = catData['icon']?.toString();
                      if (iconString != null && iconString.isNotEmpty) {
                        categoryIconString = iconString;
                      }

                      final colorHex = catData['color']?.toString();
                      if (colorHex != null && colorHex.startsWith('#')) {
                        try {
                          categoryColor = Color(
                            int.parse(colorHex.substring(1), radix: 16) +
                                0xFF000000,
                          );
                        } catch (_) {}
                      }
                    } catch (e) {
                      // Jika parsing error, gunakan default
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showTransactionList(
                          context,
                          categoryName,
                          transactions,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: categoryColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        categoryIconString,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          categoryName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$count transaksi',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        IdrFormatters.format(total),
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: categoryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: categoryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: categoryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    categoryColor,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showTransactionList(
    BuildContext context,
    String title,
    List<TransactionModel> transactions,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${transactions.length} transaksi',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      IdrFormatters.format(
                        transactions.fold<double>(
                          0,
                          (sum, tx) => sum + tx.amount,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isIncome = tx.type == TransactionType.income;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isIncome
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        child: Icon(
                          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isIncome ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        tx.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        DateHelpers.dateOnly.format(tx.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: Text(
                        IdrFormatters.format(tx.amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isIncome ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
