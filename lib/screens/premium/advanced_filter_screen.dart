import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdvancedFilterScreen extends StatefulWidget {
  const AdvancedFilterScreen({super.key});

  @override
  State<AdvancedFilterScreen> createState() => _AdvancedFilterScreenState();
}

class _AdvancedFilterScreenState extends State<AdvancedFilterScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedWallet;
  String? _selectedCategory;
  String? _selectedEvent;
  String? _selectedType; // 'income' or 'expense'
  double? _minAmount;
  double? _maxAmount;

  List<Map<String, dynamic>> _filteredTransactions = [];
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _events = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Load wallets
      final walletsSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/wallets')
          .get();
      if (walletsSnapshot.exists) {
        final walletsMap = (walletsSnapshot.value as Map)
            .cast<String, dynamic>();
        _wallets = walletsMap.entries
            .map(
              (e) => {
                'id': e.key,
                ...((e.value as Map).cast<String, dynamic>()),
              },
            )
            .toList();
      }

      // Load categories
      final categoriesSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/categories')
          .get();
      if (categoriesSnapshot.exists) {
        final categoriesMap = (categoriesSnapshot.value as Map)
            .cast<String, dynamic>();
        _categories = categoriesMap.entries
            .map(
              (e) => {
                'id': e.key,
                ...((e.value as Map).cast<String, dynamic>()),
              },
            )
            .toList();
      }

      // Load events
      final eventsSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/events')
          .get();
      if (eventsSnapshot.exists) {
        final eventsMap = (eventsSnapshot.value as Map).cast<String, dynamic>();
        _events = eventsMap.entries
            .map(
              (e) => {
                'id': e.key,
                ...((e.value as Map).cast<String, dynamic>()),
              },
            )
            .toList();
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _applyFilter() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/transactions')
          .get();

      if (!snapshot.exists) {
        setState(() {
          _filteredTransactions = [];
          _loading = false;
        });
        return;
      }

      final transactionsMap = (snapshot.value as Map).cast<String, dynamic>();
      List<Map<String, dynamic>> filtered = [];

      for (final entry in transactionsMap.entries) {
        final data = (entry.value as Map).cast<String, dynamic>();
        final date = DateTime.parse(data['date'] ?? DateTime.now().toString());
        final amount = (data['amount'] ?? 0).toDouble();

        // Apply filters
        if (_startDate != null && date.isBefore(_startDate!)) continue;
        if (_endDate != null &&
            date.isAfter(_endDate!.add(const Duration(days: 1))))
          continue;
        if (_selectedWallet != null && data['walletId'] != _selectedWallet)
          continue;
        if (_selectedCategory != null &&
            data['categoryId'] != _selectedCategory)
          continue;
        if (_selectedEvent != null && data['eventId'] != _selectedEvent)
          continue;
        if (_selectedType != null && data['type'] != _selectedType) continue;
        if (_minAmount != null && amount < _minAmount!) continue;
        if (_maxAmount != null && amount > _maxAmount!) continue;

        filtered.add({'id': entry.key, ...data, 'dateObj': date});
      }

      // Sort by date
      filtered.sort((a, b) => b['dateObj'].compareTo(a['dateObj']));

      setState(() {
        _filteredTransactions = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedWallet = null;
      _selectedCategory = null;
      _selectedEvent = null;
      _selectedType = null;
      _minAmount = null;
      _maxAmount = null;
      _filteredTransactions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Lanjutan'),
        actions: [
          TextButton(onPressed: _resetFilters, child: const Text('Reset')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Date Range
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rentang Tanggal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    setState(() => _startDate = date);
                                  }
                                },
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  _startDate != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_startDate!)
                                      : 'Dari Tanggal',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate ?? DateTime.now(),
                                    firstDate: _startDate ?? DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    setState(() => _endDate = date);
                                  }
                                },
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  _endDate != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_endDate!)
                                      : 'Sampai Tanggal',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Type Filter
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tipe Transaksi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String?>(
                          segments: const [
                            ButtonSegment(value: null, label: Text('Semua')),
                            ButtonSegment(
                              value: 'income',
                              label: Text('Pemasukan'),
                            ),
                            ButtonSegment(
                              value: 'expense',
                              label: Text('Pengeluaran'),
                            ),
                          ],
                          selected: {_selectedType},
                          onSelectionChanged: (Set<String?> newSelection) {
                            setState(() => _selectedType = newSelection.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Wallet Filter
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dompet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: _selectedWallet,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Semua Dompet'),
                            ),
                            ..._wallets.map((wallet) {
                              return DropdownMenuItem(
                                value: wallet['id'],
                                child: Text(wallet['name'] ?? 'Dompet'),
                              );
                            }),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedWallet = value),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Category Filter
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kategori',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Semua Kategori'),
                            ),
                            ..._categories.map((category) {
                              return DropdownMenuItem(
                                value: category['id'],
                                child: Text(category['name'] ?? 'Kategori'),
                              );
                            }),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedCategory = value),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Event Filter
                if (_events.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Acara',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: _selectedEvent,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Semua Acara'),
                              ),
                              ..._events.map((event) {
                                return DropdownMenuItem(
                                  value: event['id'],
                                  child: Text(event['name'] ?? 'Acara'),
                                );
                              }),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedEvent = value),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Amount Range
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rentang Jumlah',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Min',
                                  border: OutlineInputBorder(),
                                  prefixText: 'Rp ',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _minAmount = double.tryParse(
                                      value.replaceAll(RegExp(r'[^\d]'), ''),
                                    );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Max',
                                  border: OutlineInputBorder(),
                                  prefixText: 'Rp ',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _maxAmount = double.tryParse(
                                      value.replaceAll(RegExp(r'[^\d]'), ''),
                                    );
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Results
                if (_filteredTransactions.isNotEmpty) ...[
                  Text(
                    'Hasil: ${_filteredTransactions.length} transaksi',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._filteredTransactions.map(_buildTransactionTile),
                ] else if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_startDate != null ||
                    _endDate != null ||
                    _selectedWallet != null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Tidak ada transaksi yang sesuai filter'),
                    ),
                  ),
              ],
            ),
          ),

          // Apply Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _loading ? null : _applyFilter,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Terapkan Filter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] ?? 0).toDouble();
    final type = transaction['type'] ?? 'expense';
    final isIncome = type == 'income';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? Colors.green.shade100
              : Colors.red.shade100,
          child: Icon(
            isIncome ? Icons.arrow_upward : Icons.arrow_downward,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(transaction['title'] ?? 'Transaksi'),
        subtitle: Text(
          DateFormat(
            'dd MMM yyyy, HH:mm',
            'id_ID',
          ).format(transaction['dateObj']),
        ),
        trailing: Text(
          formatRupiah(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isIncome ? Colors.green : Colors.red,
            fontSize: 16,
          ),
        ),
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
