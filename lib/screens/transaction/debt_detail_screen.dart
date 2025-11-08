import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../models/debt_payment.dart';
import '../../utils/idr.dart';
import '../../utils/date_helpers.dart';
import '../../services/transaction_service.dart';

class DebtDetailScreen extends StatefulWidget {
  final TransactionModel debt;

  const DebtDetailScreen({super.key, required this.debt});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  List<DebtPayment> _payments = [];
  bool _loading = true;

  // Helper getter to check if this is hutang (loan received) or piutang (loan given)
  bool get isHutang => widget.debt.categoryId == 'loan_received';

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/debt_payments/${widget.debt.id}')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final map = (snapshot.value as Map).cast<String, dynamic>();
        _payments =
            map.entries
                .map((e) => DebtPayment.fromRtdb(e.key, e.value))
                .toList()
              ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      }
    } catch (e) {
      debugPrint('Error loading payments: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get totalPaid {
    return _payments.fold(0.0, (sum, payment) => sum + payment.amount);
  }

  double get remaining {
    return widget.debt.amount - totalPaid;
  }

  double get percentagePaid {
    if (widget.debt.amount == 0) return 0;
    return (totalPaid / widget.debt.amount * 100).clamp(0, 100);
  }

  bool get isOverdue {
    if (widget.debt.dueDate == null) return false;
    return DateTime.now().isAfter(widget.debt.dueDate!) && remaining > 0;
  }

  String get dueDateStatus {
    if (widget.debt.dueDate == null) return '';
    final diff = widget.debt.dueDate!.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Terlambat ${-diff} hari';
    if (diff == 0) return 'Jatuh tempo hari ini';
    return 'Sisa $diff hari';
  }

  Future<void> _showPaymentDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final formattedRemaining = IdrFormatters.format(
      remaining,
    ).replaceAll('Rp', 'Rp ');
    final amountController = TextEditingController(text: formattedRemaining);
    final notesController = TextEditingController();
    DateTime paymentDate = DateTime.now();
    String? selectedWalletId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Catat Pembayaran'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isHutang ? Colors.red : Colors.green).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isHutang
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: isHutang ? Colors.red : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHutang
                                  ? 'Bayar Hutang (Uang Keluar)'
                                  : 'Terima Piutang (Uang Masuk)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isHutang
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                            Text(
                              'Sisa: ${IdrFormatters.format(remaining)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    IdrFormatters.rupiahInputFormatter(withSymbol: true),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Dibayar',
                    hintText: 'Rp 0',
                    prefixIcon: Icon(Icons.payments_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Wallet Selector
                StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance
                      .ref('users/${user.uid}/wallets')
                      .onValue,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return const SizedBox.shrink();
                    }
                    final map = (snapshot.data!.snapshot.value as Map)
                        .cast<String, dynamic>();
                    final items =
                        map.entries.map((e) {
                          final m = (e.value as Map).cast<dynamic, dynamic>();
                          final name = (m['name'] ?? 'Dompet').toString();
                          final alias = (m['alias'] ?? '').toString();
                          return DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(
                              alias.isEmpty ? name : '$name (@$alias)',
                            ),
                          );
                        }).toList()..sort(
                          (a, b) => (a.child as Text).data!.compareTo(
                            (b.child as Text).data!,
                          ),
                        );

                    return DropdownButtonFormField<String>(
                      value: selectedWalletId,
                      decoration: InputDecoration(
                        labelText: isHutang
                            ? 'Bayar dari Dompet'
                            : 'Terima ke Dompet',
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet_rounded,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      items: items,
                      onChanged: (v) {
                        setDialogState(() => selectedWalletId = v);
                      },
                      validator: (v) => v == null ? 'Pilih dompet' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'Pembayaran via...',
                    prefixIcon: Icon(Icons.note_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded),
                  title: const Text('Tanggal Bayar'),
                  subtitle: Text(DateHelpers.dateOnly.format(paymentDate)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_calendar_rounded),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: widget.debt.date,
                        lastDate: DateTime.now(),
                        initialDate: paymentDate,
                        locale: const Locale('id', 'ID'),
                      );
                      if (date != null) {
                        setDialogState(() => paymentDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final amount = IdrFormatters.parse(amountController.text);
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Jumlah harus lebih dari 0')),
                  );
                  return;
                }
                if (amount > remaining) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Jumlah melebihi sisa hutang/piutang'),
                    ),
                  );
                  return;
                }
                if (selectedWalletId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pilih dompet terlebih dahulu'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'amount': amount,
                  'notes': notesController.text.trim(),
                  'date': paymentDate,
                  'walletId': selectedWalletId,
                });
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _savePayment(
        result['amount'] as double,
        result['notes'] as String?,
        result['date'] as DateTime,
        result['walletId'] as String,
      );
    }
  }

  Future<void> _savePayment(
    double amount,
    String? notes,
    DateTime date,
    String walletId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      // 1. Buat transaksi baru dulu (expense untuk bayar hutang, income untuk terima piutang)
      final transactionTitle = isHutang
          ? 'Bayar Hutang (Angsuran) ke ${widget.debt.counterpartyName ?? 'Tanpa Nama'}'
          : 'Terima Piutang (Tagihan) dari ${widget.debt.counterpartyName ?? 'Tanpa Nama'}';

      final transaction = TransactionModel(
        id: '',
        title: transactionTitle,
        amount: amount,
        type: isHutang ? TransactionType.expense : TransactionType.income,
        categoryId: isHutang ? 'debt_payment' : 'debt_collection',
        walletId: walletId,
        toWalletId: null,
        date: date,
        notes: notes,
        photoUrl: null,
        userId: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        counterpartyName: widget.debt.counterpartyName,
        debtDirection: null, // Ini transaksi pembayaran, bukan debt utama
        eventId: widget.debt.eventId,
      );

      final transactionId = await TransactionService().add(
        user.uid,
        transaction,
      );

      // 2. Simpan payment record dengan transaction ID
      final ref = FirebaseDatabase.instance
          .ref('users/${user.uid}/debt_payments/${widget.debt.id}')
          .push();

      final payment = DebtPayment(
        id: ref.key!,
        debtTransactionId: widget.debt.id,
        amount: amount,
        paymentDate: date,
        notes: notes,
        createdAt: DateTime.now(),
        transactionId: transactionId, // Simpan ID transaksi
      );

      await ref.set(payment.toRtdbMap());

      // 3. Update paidAmount di debt transaction
      final newPaidAmount = totalPaid + amount;
      await TransactionService().update(
        user.uid,
        widget.debt.copyWith(paidAmount: newPaidAmount),
      );

      await _loadPayments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHutang
                  ? 'Pembayaran hutang berhasil dicatat'
                  : 'Penerimaan piutang berhasil dicatat',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePayment(DebtPayment payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yakin ingin menghapus pembayaran ini?'),
            if (payment.transactionId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transaksi terkait juga akan dihapus',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      // 1. Hapus payment record
      await FirebaseDatabase.instance
          .ref(
            'users/${user.uid}/debt_payments/${widget.debt.id}/${payment.id}',
          )
          .remove();

      // 2. Hapus transaksi terkait jika ada
      if (payment.transactionId != null) {
        await TransactionService().delete(user.uid, payment.transactionId!);
      }

      // 3. Update paidAmount di debt transaction
      final newPaidAmount = totalPaid - payment.amount;
      await TransactionService().update(
        user.uid,
        widget.debt.copyWith(paidAmount: newPaidAmount),
      );

      await _loadPayments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran berhasil dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteDebt() async {
    // Cek apakah ada pembayaran
    if (_payments.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hapus semua pembayaran terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Hutang/Piutang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yakin ingin menghapus ${isHutang ? 'hutang' : 'piutang'} ini?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data tidak dapat dikembalikan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      // 1. Hapus semua payment records (seharusnya sudah kosong)
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/debt_payments/${widget.debt.id}')
          .remove();

      // 2. Cari dan hapus transaksi kas awal (loan_received/loan_given)
      // Transaksi ini memiliki notes yang berisi debt ID
      final txSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/transactions')
          .orderByChild('notes')
          .startAt('Terkait')
          .endAt('Terkait\uf8ff')
          .get();

      if (txSnapshot.exists) {
        final txMap = (txSnapshot.value as Map).cast<String, dynamic>();
        for (var entry in txMap.entries) {
          final txData = (entry.value as Map).cast<String, dynamic>();
          final notes = txData['notes']?.toString() ?? '';
          // Cek apakah notes mengandung debt ID ini
          if (notes.contains('ID: ${widget.debt.id}')) {
            await FirebaseDatabase.instance
                .ref('users/${user.uid}/transactions/${entry.key}')
                .remove();
            break;
          }
        }
      }

      // 3. Hapus debt transaction
      await TransactionService().delete(user.uid, widget.debt.id);

      if (mounted) {
        Navigator.of(context).pop(true); // Kembali ke halaman sebelumnya
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isHutang ? 'Hutang' : 'Piutang'} berhasil dihapus',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = isHutang ? Colors.red : Colors.green;
    final isFullyPaid = remaining <= 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(isHutang ? 'Detail Hutang' : 'Detail Piutang'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteDebt,
            tooltip: 'Hapus',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isHutang
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: primaryColor,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Name
                        Text(
                          widget.debt.counterpartyName ?? 'Tidak ada nama',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.debt.title.isNotEmpty &&
                            widget.debt.title != 'Hutang' &&
                            widget.debt.title != 'Piutang') ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.debt.title,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Total Amount
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Total ${isHutang ? 'Hutang' : 'Piutang'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                IdrFormatters.format(widget.debt.amount),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Payment Progress
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Info Box - Penjelasan
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.blue.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isHutang
                                      ? 'Saat catat: uang masuk (dapat pinjaman)\nSaat bayar: uang keluar (lunasi hutang)'
                                      : 'Saat catat: uang keluar (kasih pinjaman)\nSaat dibayar: uang masuk (tagihan dilunasi)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade900,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Status Badge
                        if (isFullyPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'LUNAS',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dueDateStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isFullyPaid || isOverdue)
                          const SizedBox(height: 16),
                        // Progress Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Progress Pembayaran',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${percentagePaid.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: percentagePaid / 100,
                                  minHeight: 12,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Payment Details
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoItem(
                                      'Terbayar',
                                      IdrFormatters.format(totalPaid),
                                      Colors.green,
                                      Icons.check_circle_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInfoItem(
                                      'Sisa',
                                      IdrFormatters.format(remaining),
                                      Colors.orange,
                                      Icons.pending_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Due Date Info
                        if (widget.debt.dueDate != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isOverdue
                                  ? Colors.orange.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isOverdue
                                    ? Colors.orange.shade300
                                    : Colors.blue.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isOverdue
                                        ? Colors.orange.shade100
                                        : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.alarm_rounded,
                                    color: isOverdue
                                        ? Colors.orange.shade700
                                        : Colors.blue.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Jatuh Tempo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isOverdue
                                              ? Colors.orange.shade700
                                              : Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateHelpers.dateOnly.format(
                                          widget.debt.dueDate!,
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isOverdue
                                              ? Colors.orange.shade900
                                              : Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (dueDateStatus.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOverdue
                                          ? Colors.orange.shade100
                                          : Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      dueDateStatus,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isOverdue
                                            ? Colors.orange.shade700
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        // Payment History
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Riwayat Pembayaran',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_payments.length} kali',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_payments.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada pembayaran',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _payments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final payment = _payments[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.green.shade600,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    IdrFormatters.format(payment.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        DateHelpers.dateOnly.format(
                                          payment.paymentDate,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (payment.notes != null &&
                                          payment.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          payment.notes!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red.shade400,
                                    ),
                                    onPressed: () => _deletePayment(payment),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: !isFullyPaid
          ? FloatingActionButton.extended(
              onPressed: _showPaymentDialog,
              backgroundColor: primaryColor,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Catat Bayar'),
            )
          : null,
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    // Buat warna lebih gelap untuk text
    final HSLColor hslColor = HSLColor.fromColor(color);
    final Color darkerColor = hslColor
        .withLightness((hslColor.lightness - 0.2).clamp(0.0, 1.0))
        .toColor();
    final Color darkestColor = hslColor
        .withLightness((hslColor.lightness - 0.3).clamp(0.0, 1.0))
        .toColor();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: darkerColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: darkestColor,
            ),
          ),
        ],
      ),
    );
  }
}
