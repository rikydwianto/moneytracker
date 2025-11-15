// Transactions Page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../../services/transaction_service.dart';
import '../../utils/date_helpers.dart';
import '../../utils/idr.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String? _selectedWalletId; // null means all wallets
  DateTimeRange? _selectedDateRange; // null means all dates
  DateTime _currentMonth = DateTime.now();

  Future<void> _handleRefresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Format bulan untuk tampilan
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final monthYear =
        '${months[_currentMonth.month - 1]} ${_currentMonth.year}';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthYear,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          // Month navigation
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
              });
            },
            tooltip: 'Bulan Sebelumnya',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                );
              });
            },
            tooltip: 'Bulan Berikutnya',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, user?.uid),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Add Transaction Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed('/add-transaction');
                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaksi disimpan')),
                  );
                  setState(() {}); // Refresh data
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah Transaksi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          // Filter chips
          if (_selectedWalletId != null || _selectedDateRange != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedWalletId != null)
                    StreamBuilder<DatabaseEvent>(
                      stream: user == null
                          ? null
                          : FirebaseDatabase.instance
                                .ref(
                                  'users/${user.uid}/wallets/$_selectedWalletId',
                                )
                                .onValue,
                      builder: (context, snap) {
                        String name = 'Dompet';
                        if (snap.hasData && snap.data!.snapshot.value is Map) {
                          final m = (snap.data!.snapshot.value as Map)
                              .cast<dynamic, dynamic>();
                          name = (m['name'] ?? 'Dompet').toString();
                        }
                        return Chip(
                          avatar: const Icon(
                            Icons.account_balance_wallet,
                            size: 18,
                          ),
                          label: Text(name),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() => _selectedWalletId = null);
                          },
                        );
                      },
                    ),
                  if (_selectedDateRange != null)
                    Chip(
                      avatar: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        '${DateHelpers.shortDate.format(_selectedDateRange!.start)} - ${DateHelpers.shortDate.format(_selectedDateRange!.end)}',
                      ),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() => _selectedDateRange = null);
                      },
                    ),
                ],
              ),
            ),
          // Transaction list
          Expanded(
            child: user == null
                ? const Center(child: Text('Masuk untuk melihat transaksi'))
                : RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: StreamBuilder<List<TransactionModel>>(
                      stream: TransactionService().streamByMonth(
                        user.uid,
                        _currentMonth,
                      ),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<TransactionModel>> snapshot,
                          ) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Error: ${snapshot.error}'),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {}); // Refresh
                                      },
                                      child: const Text('Coba Lagi'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final list =
                                (snapshot.data ?? <TransactionModel>[]).where((
                                  TransactionModel t,
                                ) {
                                  // Filter by wallet
                                  if (_selectedWalletId != null &&
                                      t.walletId != _selectedWalletId) {
                                    return false;
                                  }
                                  // Filter by date range
                                  if (_selectedDateRange != null) {
                                    final dateOnly = DateTime(
                                      t.date.year,
                                      t.date.month,
                                      t.date.day,
                                    );
                                    final startDate = DateTime(
                                      _selectedDateRange!.start.year,
                                      _selectedDateRange!.start.month,
                                      _selectedDateRange!.start.day,
                                    );
                                    final endDate = DateTime(
                                      _selectedDateRange!.end.year,
                                      _selectedDateRange!.end.month,
                                      _selectedDateRange!.end.day,
                                      23,
                                      59,
                                      59,
                                    );
                                    if (dateOnly.isBefore(startDate) ||
                                        dateOnly.isAfter(endDate)) {
                                      return false;
                                    }
                                  }
                                  return true;
                                }).toList()..sort(
                                  (a, b) => b.date.compareTo(a.date),
                                ); // Sort by date descending

                            if (list.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Belum ada transaksi',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap tombol + untuk menambah transaksi',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Group transactions by date
                            final groupedTransactions =
                                <String, List<TransactionModel>>{};

                            for (final t in list) {
                              final dateKey = DateHelpers.dateOnly.format(
                                t.date,
                              );
                              groupedTransactions
                                  .putIfAbsent(dateKey, () => [])
                                  .add(t);
                            }

                            final dateKeys = groupedTransactions.keys.toList();

                            return Column(
                              children: [
                                // Transaction list
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 92),
                                    itemCount: dateKeys.length,
                                    itemBuilder: (context, groupIndex) {
                                      final dateKey = dateKeys[groupIndex];
                                      final transactions =
                                          groupedTransactions[dateKey]!;
                                      final firstDate = transactions.first.date;

                                      // Format tanggal
                                      final now = DateTime.now();
                                      final today = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                      );
                                      final yesterday = today.subtract(
                                        const Duration(days: 1),
                                      );
                                      final transactionDate = DateTime(
                                        firstDate.year,
                                        firstDate.month,
                                        firstDate.day,
                                      );

                                      String dateLabel;
                                      Color dateColor;
                                      IconData dateIcon;

                                      if (transactionDate == today) {
                                        dateLabel = 'Hari Ini';
                                        dateColor = Colors.green;
                                        dateIcon = Icons.today;
                                      } else if (transactionDate == yesterday) {
                                        dateLabel = 'Kemarin';
                                        dateColor = Colors.orange;
                                        dateIcon = Icons.event;
                                      } else {
                                        dateLabel = DateHelpers.dateOnly.format(
                                          firstDate,
                                        );
                                        dateColor = Colors.blue;
                                        dateIcon = Icons.calendar_today;
                                      }

                                      // Calculate total for this date
                                      double dateTotal = 0;
                                      for (final t in transactions) {
                                        final isIncome =
                                            t.type == TransactionType.income;
                                        dateTotal +=
                                            t.amount * (isIncome ? 1 : -1);
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Date Header - Modern Design
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  dateColor.withOpacity(0.1),
                                                  dateColor.withOpacity(0.05),
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                              border: Border(
                                                left: BorderSide(
                                                  color: dateColor,
                                                  width: 4,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: dateColor
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    dateIcon,
                                                    size: 18,
                                                    color: dateColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      dateLabel,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                        color: dateColor,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${transactions.length} transaksi',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Spacer(),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      IdrFormatters.format(
                                                        dateTotal.abs(),
                                                      ),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: dateTotal >= 0
                                                            ? Colors
                                                                  .green
                                                                  .shade700
                                                            : Colors
                                                                  .red
                                                                  .shade700,
                                                      ),
                                                    ),
                                                    Text(
                                                      dateTotal >= 0
                                                          ? 'Surplus'
                                                          : 'Defisit',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Transactions for this date
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.03),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              children: [
                                                ...transactions.map((t) {
                                                  final isIncome =
                                                      t.type ==
                                                      TransactionType.income;
                                                  final isTransfer =
                                                      t.type ==
                                                      TransactionType.transfer;
                                                  final amountText =
                                                      IdrFormatters.format(
                                                        t.amount *
                                                            (isIncome ? 1 : -1),
                                                      );

                                                  return _TransactionTile(
                                                    transaction: t,
                                                    isIncome: isIncome,
                                                    isTransfer: isTransfer,
                                                    amountText: amountText,
                                                  );
                                                }),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Show filter bottom sheet
  Future<void> _showFilterSheet(BuildContext context, String? uid) async {
    if (uid == null) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Filter Transaksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 0),
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('users/$uid/wallets')
                    .onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: Icon(Icons.account_balance_wallet),
                      title: Text('Filter Dompet'),
                      subtitle: Text('Memuat...'),
                    );
                  }
                  Wallet? selectedWallet;
                  if (_selectedWalletId != null) {
                    final data = snapshot.data?.snapshot.value;
                    if (data != null) {
                      final map = (data as Map).cast<String, dynamic>();
                      if (map.containsKey(_selectedWalletId)) {
                        selectedWallet = Wallet.fromRtdb(
                          _selectedWalletId!,
                          (map[_selectedWalletId] as Map)
                              .cast<dynamic, dynamic>(),
                        );
                      }
                    }
                  }
                  return ListTile(
                    leading: selectedWallet != null
                        ? Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                      selectedWallet.color.substring(1),
                                      radix: 16,
                                    ) +
                                    0xFF000000,
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                selectedWallet.icon,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          )
                        : const Icon(Icons.account_balance_wallet),
                    title: const Text('Filter Dompet'),
                    subtitle: Text(
                      _selectedWalletId == null
                          ? 'Semua dompet'
                          : (selectedWallet?.name ?? 'Dompet dipilih'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      Navigator.pop(context);
                      final selected = await _pickWalletFilter(context, uid);
                      if (selected != null && mounted) {
                        setState(() => _selectedWalletId = selected);
                      }
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Filter Tanggal'),
                subtitle: Text(
                  _selectedDateRange == null
                      ? 'Semua tanggal'
                      : '${DateHelpers.shortDate.format(_selectedDateRange!.start)} - ${DateHelpers.shortDate.format(_selectedDateRange!.end)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(context);
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _selectedDateRange,
                    locale: const Locale('id', 'ID'),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (range != null && mounted) {
                    setState(() => _selectedDateRange = range);
                  }
                },
              ),
              if (_selectedWalletId != null || _selectedDateRange != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () {
                        setState(() {
                          _selectedWalletId = null;
                          _selectedDateRange = null;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Reset Filter'),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickWalletFilter(BuildContext context, String uid) async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('users/$uid/wallets').onValue,
          builder: (context, snapshot) {
            final tiles = <Widget>[];
            tiles.add(
              ListTile(
                leading: const Icon(Icons.all_inbox),
                title: const Text('Semua Dompet'),
                selected: _selectedWalletId == null,
                onTap: () => Navigator.pop(context, null),
              ),
            );
            if (snapshot.hasData && snapshot.data!.snapshot.value is Map) {
              final map = (snapshot.data!.snapshot.value as Map)
                  .cast<String, dynamic>();
              final wallets =
                  map.entries
                      .map(
                        (e) => Wallet.fromRtdb(
                          e.key,
                          (e.value as Map).cast<dynamic, dynamic>(),
                        ),
                      )
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));
              for (final w in wallets) {
                tiles.add(
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(w.color.substring(1), radix: 16) +
                              0xFF000000,
                        ).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          w.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    title: Text(w.name),
                    subtitle: Text(
                      w.alias == null || w.alias!.isEmpty
                          ? w.currency
                          : '${w.currency} • @${w.alias}',
                    ),
                    selected: _selectedWalletId == w.id,
                    onTap: () => Navigator.pop(context, w.id),
                  ),
                );
              }
            }
            return ListView(shrinkWrap: true, children: tiles);
          },
        ),
      ),
    );
  }
}

// Transaction Tile Widget dengan Category Icon
class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final bool isIncome;
  final bool isTransfer;
  final String amountText;

  const _TransactionTile({
    required this.transaction,
    required this.isIncome,
    required this.isTransfer,
    required this.amountText,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DatabaseEvent>(
      stream: user == null || transaction.categoryId.isEmpty
          ? null
          : FirebaseDatabase.instance
                .ref('users/${user.uid}/categories/${transaction.categoryId}')
                .onValue,
      builder: (context, categorySnapshot) {
        // Default icon dan color (hanya untuk fallback jika tidak ada kategori)
        // Tidak perlu variabel iconData/iconColor/backgroundColor karena leading pakai emoji string

        // Jika ada data kategori, gunakan icon dan color dari kategori
        if (categorySnapshot.hasData &&
            categorySnapshot.data!.snapshot.value != null) {
          // final categoryData = ... tidak dipakai lagi

          // Parse icon dari kategori
          // iconName dan colorStr tidak dipakai lagi karena leading pakai emoji string
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/transaction-detail',
                  arguments: transaction,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isIncome
                            ? Colors.green.withOpacity(0.1)
                            : isTransfer
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isIncome
                              ? Colors.green.withOpacity(0.2)
                              : isTransfer
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (() {
                            if (categorySnapshot.hasData &&
                                categorySnapshot.data!.snapshot.value != null) {
                              final categoryData =
                                  (categorySnapshot.data!.snapshot.value as Map)
                                      .cast<dynamic, dynamic>();
                              final iconString =
                                  categoryData['icon'] as String?;
                              if (iconString != null && iconString.isNotEmpty) {
                                return iconString;
                              }
                            }
                            // fallback emoji
                            return isTransfer ? '🔄' : (isIncome ? '💰' : '💸');
                          })(),
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (categorySnapshot.hasData &&
                                    categorySnapshot.data!.snapshot.value !=
                                        null)
                                ? ((categorySnapshot.data!.snapshot.value
                                                  as Map)
                                              .cast<dynamic, dynamic>()['name']
                                          as String? ??
                                      'Tidak ada kategori')
                                : 'Tidak ada kategori',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (transaction.title.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 13,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    transaction.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              DateHelpers.dateTime.format(transaction.date),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amountText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: isIncome
                                ? Colors.green.shade700
                                : (isTransfer
                                      ? Colors.blue.shade700
                                      : Colors.red.shade700),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isIncome
                                        ? Colors.green
                                        : (isTransfer
                                              ? Colors.blue
                                              : Colors.red))
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isTransfer
                                ? 'Transfer'
                                : (isIncome ? 'Masuk' : 'Keluar'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isIncome
                                  ? Colors.green.shade700
                                  : (isTransfer
                                        ? Colors.blue.shade700
                                        : Colors.red.shade700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (value) async {
                        if (value == 'edit') {
                          // Navigate to edit transaction
                          // TODO: Implement edit transaction screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fitur edit belum tersedia'),
                            ),
                          );
                        } else if (value == 'delete') {
                          // Show delete confirmation
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Transaksi'),
                              content: const Text(
                                'Yakin ingin menghapus transaksi ini?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await TransactionService().delete(
                                  user.uid,
                                  transaction.id,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Transaksi berhasil dihapus',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        } else if (value == 'duplicate') {
                          // Duplicate transaction
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final newTransaction = TransactionModel(
                                id: '',
                                title: transaction.title,
                                amount: transaction.amount,
                                type: transaction.type,
                                categoryId: transaction.categoryId,
                                walletId: transaction.walletId,
                                toWalletId: transaction.toWalletId,
                                date:
                                    DateTime.now(), // Use current date for duplicate
                                notes: transaction.notes,
                                photoUrl: transaction.photoUrl,
                                userId: user.uid,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                                eventId: transaction.eventId,
                              );
                              await TransactionService().add(
                                user.uid,
                                newTransaction,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Transaksi berhasil diduplikat',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20, color: Colors.blue),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 20, color: Colors.orange),
                              SizedBox(width: 12),
                              Text('Duplikat'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Hapus'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
