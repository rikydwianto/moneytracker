import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../services/export_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _exportService = ExportService();
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  Map<String, String> _categoryNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Load summary
      final summary = await _exportService.getTransactionsSummary(user.uid);

      // Load category names
      final categoriesSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/categories')
          .get();

      final Map<String, String> categoryNames = {};
      if (categoriesSnapshot.exists) {
        final categories = (categoriesSnapshot.value as Map)
            .cast<String, dynamic>();
        for (final entry in categories.entries) {
          categoryNames[entry.key] = entry.value['name'] ?? 'Kategori';
        }
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _categoryNames = categoryNames;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisis Mendalam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary Cards
                  _buildSummaryCard(
                    'Total Pemasukan',
                    formatRupiah(_summary['totalIncome'] ?? 0),
                    Colors.green,
                    Icons.arrow_upward,
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryCard(
                    'Total Pengeluaran',
                    formatRupiah(_summary['totalExpense'] ?? 0),
                    Colors.red,
                    Icons.arrow_downward,
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryCard(
                    'Saldo Bersih',
                    formatRupiah(_summary['balance'] ?? 0),
                    (_summary['balance'] ?? 0) >= 0
                        ? Colors.blue
                        : Colors.orange,
                    Icons.account_balance_wallet,
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryCard(
                    'Total Transaksi',
                    '${_summary['transactionCount'] ?? 0} transaksi',
                    Colors.purple,
                    Icons.receipt_long,
                  ),

                  const SizedBox(height: 24),

                  // Category Breakdown
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart, color: Colors.orange),
                              const SizedBox(width: 12),
                              Text(
                                'Pengeluaran per Kategori',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if ((_summary['categoryBreakdown'] as Map? ?? {})
                              .isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Belum ada data pengeluaran'),
                              ),
                            )
                          else
                            ..._buildCategoryBreakdown(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Monthly Trend
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.trending_up, color: Colors.blue),
                              const SizedBox(width: 12),
                              Text(
                                'Tren Bulanan',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if ((_summary['monthlyTrend'] as Map? ?? {}).isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Belum ada data tren'),
                              ),
                            )
                          else
                            ..._buildMonthlyTrend(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Insights
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Insight Keuangan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._buildInsights(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 24,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategoryBreakdown() {
    final breakdown = (_summary['categoryBreakdown'] as Map)
        .cast<String, double>();
    final total = breakdown.values.fold<double>(0, (sum, val) => sum + val);

    // Sort by amount
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.take(10).map((entry) {
      final categoryId = entry.key;
      final amount = entry.value;
      final percentage = (amount / total * 100);
      final categoryName = _categoryNames[categoryId] ?? 'Kategori';

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    categoryName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  formatRupiah(amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.primaries[sortedEntries.indexOf(entry) %
                            Colors.primaries.length],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildMonthlyTrend() {
    final trend = (_summary['monthlyTrend'] as Map).cast<String, double>();

    // Sort by month
    final sortedEntries = trend.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Take last 6 entries
    final last6 = sortedEntries.length > 6
        ? sortedEntries.sublist(sortedEntries.length - 6)
        : sortedEntries;

    return last6.map((entry) {
      final monthKey = entry.key;
      final balance = entry.value;
      final isPositive = balance >= 0;

      try {
        final date = DateFormat('yyyy-MM').parse(monthKey);
        final monthName = DateFormat('MMM yyyy', 'id_ID').format(date);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  monthName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPositive ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatRupiah(balance.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        return const SizedBox.shrink();
      }
    }).toList();
  }

  List<Widget> _buildInsights() {
    final insights = <Widget>[];
    final totalIncome = _summary['totalIncome'] ?? 0;
    final totalExpense = _summary['totalExpense'] ?? 0;
    final balance = _summary['balance'] ?? 0;

    // Insight 1: Savings rate
    if (totalIncome > 0) {
      final savingsRate = ((totalIncome - totalExpense) / totalIncome * 100);
      insights.add(
        _buildInsightItem(
          savingsRate >= 20
              ? '💰 Bagus! Anda menabung ${savingsRate.toStringAsFixed(1)}% dari pendapatan'
              : '⚠️ Tingkatkan tabungan Anda. Saat ini hanya ${savingsRate.toStringAsFixed(1)}%',
          savingsRate >= 20 ? Colors.green : Colors.orange,
        ),
      );
    }

    // Insight 2: Balance status
    if (balance < 0) {
      insights.add(
        _buildInsightItem(
          '⚠️ Pengeluaran melebihi pemasukan sebesar ${formatRupiah(balance.abs())}',
          Colors.red,
        ),
      );
    } else if (balance > 0) {
      insights.add(
        _buildInsightItem(
          '✅ Anda surplus ${formatRupiah(balance)}. Pertahankan!',
          Colors.green,
        ),
      );
    }

    // Insight 3: Top category
    final breakdown = (_summary['categoryBreakdown'] as Map? ?? {})
        .cast<String, double>();
    if (breakdown.isNotEmpty) {
      final topEntry = breakdown.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final topCategory = _categoryNames[topEntry.key] ?? 'Kategori';
      insights.add(
        _buildInsightItem(
          '📊 Pengeluaran terbesar: $topCategory (${formatRupiah(topEntry.value)})',
          Colors.blue,
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        _buildInsightItem(
          '📝 Mulai catat transaksi untuk mendapat insight',
          Colors.grey,
        ),
      );
    }

    return insights;
  }

  Widget _buildInsightItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String formatRupiah(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }
}
