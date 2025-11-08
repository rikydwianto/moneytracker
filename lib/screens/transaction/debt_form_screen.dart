import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../models/event.dart';
import '../../utils/idr.dart';
import '../../services/transaction_service.dart';
import '../../services/event_service.dart';
import '../../widgets/custom_numeric_keyboard.dart';
import 'package:intl/intl.dart';

class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({super.key});

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController(text: 'Rp 0');
  final _counterparty = TextEditingController();
  String? _walletId;
  String _direction = 'hutang'; // 'hutang' or 'piutang'
  DateTime _date = DateTime.now();
  DateTime? _dueDate; // Tanggal jatuh tempo
  bool _loading = false;
  String? _eventId; // Auto-populated from active event
  Event? _activeEvent;

  @override
  void initState() {
    super.initState();
    _loadActiveEvent();
  }

  void _showCustomKeyboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: CustomNumericKeyboard(
            controller: _amount,
            onDone: () {
              Navigator.pop(context);
              // Format nilai setelah selesai input
              final cleanValue = _amount.text.replaceAll(RegExp(r'[^\d]'), '');
              if (cleanValue.isNotEmpty) {
                final formatter = NumberFormat('#,###', 'id_ID');
                _amount.text = 'Rp ${formatter.format(int.parse(cleanValue))}';
              }
            },
            doneLabel: 'SELESAI',
            doneColor: Colors.green,
          ),
        ),
      ),
    );
  }

  Future<void> _loadActiveEvent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final event = await EventService().getActiveEvent(user.uid);
      if (mounted) {
        setState(() {
          _activeEvent = event;
          _eventId = event?.id;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masuk terlebih dahulu')),
      );
      return;
    }
    if (_walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet terlebih dahulu')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final isHutang = _direction == 'hutang';

      // Buat transaksi debt untuk tracking
      // Buat transaksi dengan type yang sesuai untuk langsung pengaruhi saldo
      // HUTANG: INCOME (uang masuk ke dompet karena dapat pinjaman)
      // PIUTANG: EXPENSE (uang keluar dari dompet karena kasih pinjaman)
      final transaction = TransactionModel(
        id: '',
        title: _title.text.trim().isEmpty
            ? (isHutang
                  ? 'Hutang ke ${_counterparty.text.trim()}'
                  : 'Piutang dari ${_counterparty.text.trim()}')
            : _title.text.trim(),
        amount: IdrFormatters.parse(_amount.text),
        type: isHutang ? TransactionType.income : TransactionType.expense,
        categoryId: isHutang ? 'loan_received' : 'loan_given',
        walletId: _walletId!,
        toWalletId: null,
        date: _date,
        notes: null,
        photoUrl: null,
        userId: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        counterpartyName: _counterparty.text.trim(),
        debtDirection: _direction,
        eventId: _eventId,
        dueDate: _dueDate,
        paidAmount: 0,
      );

      await TransactionService().add(user.uid, transaction);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _date,
      locale: const Locale('id', 'ID'),
    );
    if (d != null) {
      setState(
        () =>
            _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute),
      );
    }
  }

  Future<void> _pickDueDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      locale: const Locale('id', 'ID'),
    );
    if (d != null) {
      setState(() => _dueDate = d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final primaryColor = _direction == 'hutang' ? Colors.red : Colors.green;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Catat Hutang/Piutang'), elevation: 0),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section with Type Selector
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Type Selector
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'hutang',
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 18,
                                  color: _direction == 'hutang'
                                      ? Colors.white
                                      : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                const Text('Hutang'),
                              ],
                            ),
                          ),
                          ButtonSegment(
                            value: 'piutang',
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 18,
                                  color: _direction == 'piutang'
                                      ? Colors.white
                                      : Colors.green,
                                ),
                                const SizedBox(width: 6),
                                const Text('Piutang'),
                              ],
                            ),
                          ),
                        ],
                        selected: {_direction},
                        onSelectionChanged: (s) =>
                            setState(() => _direction = s.first),
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return _direction == 'hutang'
                                  ? Colors.red
                                  : Colors.green;
                            }
                            return Colors.transparent;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return Colors.grey.shade700;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Info Box
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _direction == 'hutang'
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _direction == 'hutang' ? 'HUTANG' : 'PIUTANG',
                                  style: TextStyle(
                                    color: primaryColor.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _direction == 'hutang'
                                      ? 'Kamu berhutang (pinjam uang)\n• Catat: Uang MASUK ke dompet\n• Bayar nanti: Uang KELUAR dari dompet'
                                      : 'Orang berhutang ke kamu (kasih pinjaman)\n• Catat: Uang KELUAR dari dompet\n• Dibayar nanti: Uang MASUK ke dompet',
                                  style: TextStyle(
                                    color: primaryColor.shade700,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Form Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active Event Card (if exists)
                    if (_activeEvent != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.event_rounded,
                                color: theme.primaryColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Acara Aktif',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _activeEvent!.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _eventId = null;
                                  _activeEvent = null;
                                });
                              },
                              tooltip: 'Lepaskan dari acara',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Amount Input (Prominent)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.payments_rounded,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Jumlah',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _amount,
                            readOnly: true,
                            onTap: _showCustomKeyboard,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Rp 0',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            validator: (v) => IdrFormatters.parse(v ?? '') <= 0
                                ? 'Masukkan jumlah yang valid'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Counterparty Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _counterparty,
                        decoration: InputDecoration(
                          labelText: 'Nama Orang',
                          hintText: _direction == 'hutang'
                              ? 'Pinjam dari siapa?'
                              : 'Dipinjam oleh siapa?',
                          prefixIcon: Icon(
                            Icons.person_rounded,
                            color: primaryColor,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Isi nama orang'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _title,
                        decoration: InputDecoration(
                          labelText: 'Keterangan (opsional)',
                          hintText: 'Untuk apa?',
                          prefixIcon: Icon(
                            Icons.description_rounded,
                            color: Colors.grey.shade600,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Wallet Selector
                    if (user != null)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: StreamBuilder<DatabaseEvent>(
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
                                  final m = (e.value as Map)
                                      .cast<dynamic, dynamic>();
                                  final name = (m['name'] ?? 'Dompet')
                                      .toString();
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
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _walletId,
                                  decoration: InputDecoration(
                                    labelText: _direction == 'hutang'
                                        ? 'Dompet Penerima (Uang Masuk)'
                                        : 'Dompet Pemberi (Uang Keluar)',
                                    helperText: _direction == 'hutang'
                                        ? 'Saldo akan bertambah (dapat pinjaman)'
                                        : 'Saldo akan berkurang (kasih pinjaman)',
                                    helperStyle: TextStyle(
                                      fontSize: 11,
                                      color: _direction == 'hutang'
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: primaryColor,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  items: items,
                                  onChanged: (v) =>
                                      setState(() => _walletId = v),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Date Selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(
                              Icons.edit_calendar_rounded,
                              size: 18,
                            ),
                            label: const Text('Ubah'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Due Date Selector (Optional)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _dueDate != null
                              ? primaryColor.withOpacity(0.3)
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  (_dueDate != null
                                          ? primaryColor
                                          : Colors.grey)
                                      .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.alarm_rounded,
                              color: _dueDate != null
                                  ? primaryColor
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jatuh Tempo (opsional)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _dueDate != null
                                      ? '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}'
                                      : 'Belum diatur',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _dueDate != null
                                        ? Colors.black87
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_dueDate != null)
                            IconButton(
                              onPressed: () {
                                setState(() => _dueDate = null);
                              },
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              tooltip: 'Hapus',
                            ),
                          TextButton.icon(
                            onPressed: _pickDueDate,
                            icon: Icon(
                              _dueDate != null
                                  ? Icons.edit_calendar_rounded
                                  : Icons.add_rounded,
                              size: 18,
                            ),
                            label: Text(_dueDate != null ? 'Ubah' : 'Atur'),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Simpan ${_direction == 'hutang' ? 'Hutang' : 'Piutang'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
