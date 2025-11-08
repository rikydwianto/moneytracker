import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/event.dart';
import '../../models/transaction.dart';
import '../../services/event_service.dart';
import '../../utils/idr.dart';
import '../../utils/date_helpers.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService();
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateHelpers.longDate;

    return Scaffold(
      appBar: AppBar(title: Text(widget.event.name)),
      body: ListView(
        children: [
          // Event Info Card
          Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.event.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (widget.event.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'AKTIF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (widget.event.startDate != null ||
                      widget.event.endDate != null) ...[
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Periode',
                      value: _formatDateRange(dateFormat),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.event.budget != null) ...[
                    _InfoRow(
                      icon: Icons.account_balance_wallet,
                      label: 'Budget',
                      value: IdrFormatters.format(widget.event.budget!),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.event.notes != null &&
                      widget.event.notes!.isNotEmpty) ...[
                    _InfoRow(
                      icon: Icons.notes,
                      label: 'Catatan',
                      value: widget.event.notes!,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Balance Summary
          FutureBuilder<Map<String, double>>(
            future: _eventService.calculateEventBalance(
              userId,
              widget.event.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final balance = snapshot.data ?? {};
              final income = balance['income'] ?? 0;
              final expense = balance['expense'] ?? 0;
              final total = balance['balance'] ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Saldo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _BalanceItem(
                            icon: Icons.arrow_downward,
                            iconColor: Colors.green,
                            label: 'Pemasukan',
                            amount: income,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          _BalanceItem(
                            icon: Icons.arrow_upward,
                            iconColor: Colors.red,
                            label: 'Pengeluaran',
                            amount: expense,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Saldo',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            IdrFormatters.format(total),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: total >= 0 ? Colors.green : Colors.red,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Transactions List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Transaksi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          StreamBuilder<List<TransactionModel>>(
            stream: _eventService.streamEventTransactions(
              userId,
              widget.event.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final transactions = snapshot.data ?? [];

              if (transactions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada transaksi',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return _TransactionItem(transaction: tx);
                },
              );
            },
          ),
          const SizedBox(height: 80), // Bottom spacing
        ],
      ),
    );
  }

  String _formatDateRange(dateFormat) {
    if (widget.event.startDate != null && widget.event.endDate != null) {
      return '${dateFormat.format(widget.event.startDate!)} - ${dateFormat.format(widget.event.endDate!)}';
    } else if (widget.event.startDate != null) {
      return 'Mulai: ${dateFormat.format(widget.event.startDate!)}';
    } else if (widget.event.endDate != null) {
      return 'Sampai: ${dateFormat.format(widget.event.endDate!)}';
    }
    return '-';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double amount;

  const _BalanceItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            IdrFormatters.format(amount),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final TransactionModel transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateHelpers.shortDate;
    final isIncome = transaction.type == TransactionType.income;
    final isExpense = transaction.type == TransactionType.expense;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? Colors.green.withOpacity(0.1)
              : isExpense
              ? Colors.red.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
          child: Icon(
            isIncome
                ? Icons.arrow_downward
                : isExpense
                ? Icons.arrow_upward
                : Icons.swap_horiz,
            color: isIncome
                ? Colors.green
                : isExpense
                ? Colors.red
                : Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          dateFormat.format(transaction.date),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(
          '${isExpense ? "-" : "+"} ${IdrFormatters.format(transaction.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isIncome
                ? Colors.green
                : isExpense
                ? Colors.red
                : Colors.blue,
          ),
        ),
      ),
    );
  }
}
