import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../settings/app_pin_verify_screen.dart';
import '../../models/wallet.dart';
import '../../models/transaction.dart';
import '../../utils/idr.dart';
import 'package:flutter/services.dart';
import '../../services/wallet_service.dart';
import '../../services/transaction_service.dart';

class WalletFormScreen extends StatefulWidget {
  final Wallet? initial;
  const WalletFormScreen({super.key, this.initial});

  @override
  State<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends State<WalletFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _balance = TextEditingController(text: '0');
  final _alias = TextEditingController();
  String _currency = 'IDR';
  String _icon = '💳';
  String _color = '#1E88E5';
  String _type = 'regular'; // 'regular' atau 'savings'
  bool _loading = false;

  // Pilihan icon emoji
  final List<String> _iconOptions = [
    '💳',
    '💰',
    '🏦',
    '💵',
    '💴',
    '💶',
    '💷',
    '🪙',
    '💸',
    '🏧',
    '💎',
    '🎯',
    '🎁',
    '🛒',
    '🏠',
    '🚗',
    '✈️',
    '🍕',
    '☕',
    '📱',
    '💻',
  ];

  // Pilihan warna
  final List<Map<String, String>> _colorOptions = [
    {'name': 'Biru', 'hex': '#1E88E5'},
    {'name': 'Hijau', 'hex': '#43A047'},
    {'name': 'Merah', 'hex': '#E53935'},
    {'name': 'Oranye', 'hex': '#FB8C00'},
    {'name': 'Ungu', 'hex': '#8E24AA'},
    {'name': 'Pink', 'hex': '#D81B60'},
    {'name': 'Cyan', 'hex': '#00ACC1'},
    {'name': 'Kuning', 'hex': '#FDD835'},
    {'name': 'Abu-abu', 'hex': '#757575'},
    {'name': 'Cokelat', 'hex': '#6D4C41'},
  ];

  @override
  void initState() {
    super.initState();
    final w = widget.initial;
    if (w != null) {
      _name.text = w.name;
      _balance.text = IdrFormatters.format(w.balance);
      _currency = w.currency;
      _alias.text = w.alias ?? '';
      _icon = w.icon;
      _color = w.color;
      // Load type from Firebase data
      _loadWalletType(w.id);
    }
  }

  Future<void> _loadWalletType(String walletId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/wallets/$walletId/type')
          .get();
      if (snapshot.exists && mounted) {
        setState(() {
          _type = snapshot.value as String? ?? 'regular';
        });
      }
    } catch (e) {
      // Ignore error, use default
    }
  }

  Future<Map<String, dynamic>> _loadWalletSecurity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.initial == null) {
      return {'isHidden': false, 'hasGlobalPin': false};
    }

    try {
      // Read isHidden from wallet node
      final walletSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/wallets/${widget.initial!.id}/isHidden')
          .get();
      final isHidden = (walletSnap.value as bool?) ?? false;

      // Read global PIN existence from settings
      final pinSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/pin')
          .get();
      final hasGlobalPin =
          pinSnap.exists &&
          (pinSnap.value is String) &&
          ((pinSnap.value as String).isNotEmpty);

      return {'isHidden': isHidden, 'hasGlobalPin': hasGlobalPin};
    } catch (e) {
      // Ignore error
    }

    return {'isHidden': false, 'hasGlobalPin': false};
  }

  Future<bool> _verifyGlobalPin(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/pin')
          .get();
      if (!snap.exists ||
          snap.value == null ||
          (snap.value as String).isEmpty) {
        return false; // caller will handle setup flow
      }
      final pin = snap.value as String;
      if (!mounted) return false;
      final ok = await showAppPinVerification(
        context,
        pin: pin,
        purpose: 'wallet_toggle',
        title: 'Konfirmasi PIN',
      );
      return ok;
    } catch (_) {
      return false;
    }
  }

  void _toggleHideWallet(bool value, bool hasGlobalPin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.initial == null) return;

    if (value) {
      // Hide wallet: ensure global PIN exists
      bool pinReady = hasGlobalPin;
      if (!pinReady) {
        final goSetup = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('PIN belum diatur'),
            content: const Text(
              'Anda perlu mengatur PIN aplikasi terlebih dahulu untuk menyembunyikan dompet. Ingin atur sekarang?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Atur PIN'),
              ),
            ],
          ),
        );

        if (goSetup == true) {
          await Navigator.pushNamed(context, '/app-pin-setup');
          // Recheck
          final pinSnap = await FirebaseDatabase.instance
              .ref('users/${user.uid}/settings/pin')
              .get();
          pinReady =
              pinSnap.exists &&
              (pinSnap.value is String) &&
              ((pinSnap.value as String).isNotEmpty);
        }
      }

      if (!pinReady) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('PIN belum diatur.')));
        }
        return;
      }

      // Confirm PIN before hiding
      final confirmed = await _verifyGlobalPin(context);
      if (!confirmed) return;

      try {
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/wallets/${widget.initial!.id}')
            .update({'isHidden': true, 'excludeFromTotal': true});

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dompet berhasil disembunyikan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // Confirm PIN before showing wallet again (unhide)
      if (hasGlobalPin) {
        final confirmed = await _verifyGlobalPin(context);
        if (!confirmed) return; // cancel toggle
      } else {
        // No global PIN -> just proceed (unlikely path if we enforced earlier)
      }
      try {
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/wallets/${widget.initial!.id}')
            .update({'isHidden': false});

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dompet ditampilkan kembali'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // Removed per-wallet PIN change; PIN diatur global di Pengaturan

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masuk terlebih dahulu')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final walletsRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/wallets',
      );

      // Validate alias availability if provided
      final alias = _alias.text.trim().isEmpty ? null : _alias.text.trim();
      if (alias != null) {
        final service = WalletService();
        final ok = await service.isAliasAvailable(
          user.uid,
          alias,
          excludeWalletId: widget.initial?.id,
        );
        if (!ok) {
          throw Exception('Alias sudah digunakan. Silakan pilih alias lain.');
        }
      }

      if (widget.initial == null) {
        final doc = walletsRef.push();
        final walletId = doc.key!;
        final initialBalance = IdrFormatters.parse(_balance.text);

        // Buat wallet dengan balance 0 dulu
        final wallet = Wallet(
          id: walletId,
          name: _name.text.trim(),
          balance: 0, // Set 0 dulu, akan diupdate oleh transaksi
          currency: _currency,
          icon: _icon,
          color: _color,
          userId: user.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          alias: alias,
        );
        await doc.set(wallet.toRtdbMap());

        // Simpan type dompet
        await doc.child('type').set(_type);

        // Jika ada saldo awal, buat transaksi penyesuaian
        if (initialBalance != 0) {
          final adjustmentTransaction = TransactionModel(
            id: '',
            title: 'Saldo Awal - ${_name.text.trim()}',
            amount: initialBalance.abs(),
            type: initialBalance > 0
                ? TransactionType.income
                : TransactionType.expense,
            categoryId: 'adjustment',
            walletId: walletId,
            toWalletId: null,
            date: DateTime.now(),
            notes: 'Penyesuaian saldo awal saat membuat dompet',
            photoUrl: null,
            userId: user.uid,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            counterpartyName: null,
            debtDirection: null,
            eventId: null,
          );

          await TransactionService().add(user.uid, adjustmentTransaction);
        }
      } else {
        final doc = walletsRef.child(widget.initial!.id);
        await doc.update({
          'name': _name.text.trim(),
          'currency': _currency,
          'icon': _icon,
          'color': _color,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'alias': alias,
          'type': _type,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Tambah Dompet' : 'Ubah Dompet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nama Dompet',
                          prefixIcon: Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama dompet wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      // Icon Selector
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pilih Icon',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _iconOptions.map((emoji) {
                                final isSelected = _icon == emoji;
                                return InkWell(
                                  onTap: () => setState(() => _icon = emoji),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.shade100
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Wallet Type Selector
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.wallet_outlined,
                                  size: 20,
                                  color: Colors.deepPurple,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Tipe Dompet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _type = 'regular'),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _type == 'regular'
                                            ? Colors.blue.shade100
                                            : Colors.white,
                                        border: Border.all(
                                          color: _type == 'regular'
                                              ? Colors.blue
                                              : Colors.grey.shade300,
                                          width: _type == 'regular' ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.account_balance_wallet,
                                            color: _type == 'regular'
                                                ? Colors.blue
                                                : Colors.grey,
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Dompet Biasa',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _type == 'regular'
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Transaksi harian',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _type = 'savings'),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _type == 'savings'
                                            ? Colors.green.shade100
                                            : Colors.white,
                                        border: Border.all(
                                          color: _type == 'savings'
                                              ? Colors.green
                                              : Colors.grey.shade300,
                                          width: _type == 'savings' ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.savings_outlined,
                                            color: _type == 'savings'
                                                ? Colors.green
                                                : Colors.grey,
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Simpanan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _type == 'savings'
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tabungan/Investasi',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _type == 'savings'
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: _type == 'savings'
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _type == 'savings'
                                          ? 'Dompet simpanan tidak dihitung dalam total saldo harian. Cocok untuk investasi, tabungan jangka panjang, atau dana darurat.'
                                          : 'Dompet biasa akan dihitung dalam total saldo dan transaksi harian Anda.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _type == 'savings'
                                            ? Colors.green.shade700
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Hide Wallet with PIN (only for edit mode)
                      if (widget.initial != null)
                        FutureBuilder<Map<String, dynamic>>(
                          future: _loadWalletSecurity(),
                          builder: (context, snapshot) {
                            final isHidden =
                                snapshot.data?['isHidden'] ?? false;
                            final hasGlobalPin =
                                snapshot.data?['hasGlobalPin'] ?? false;

                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: isHidden
                                    ? Colors.deepPurple.shade50
                                    : Colors.grey.shade50,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  isHidden ? Icons.lock : Icons.lock_open,
                                  color: isHidden
                                      ? Colors.deepPurple
                                      : Colors.grey,
                                ),
                                title: const Text(
                                  'Sembunyikan Dompet',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  isHidden
                                      ? 'Dompet dilindungi PIN 6 digit'
                                      : 'Lindungi dompet dengan PIN',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!hasGlobalPin)
                                      TextButton(
                                        onPressed: () async {
                                          await Navigator.pushNamed(
                                            context,
                                            '/app-pin-setup',
                                          );
                                          if (mounted) setState(() {});
                                        },
                                        child: const Text('Atur PIN'),
                                      ),
                                    Switch(
                                      value: isHidden,
                                      onChanged: (value) => _toggleHideWallet(
                                        value,
                                        hasGlobalPin,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      // Color Selector
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pilih Warna',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _colorOptions.map((colorData) {
                                final hex = colorData['hex']!;
                                final name = colorData['name']!;
                                final isSelected = _color == hex;
                                final color = Color(
                                  int.parse(hex.substring(1), radix: 16) +
                                      0xFF000000,
                                );
                                return InkWell(
                                  onTap: () => setState(() => _color = hex),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.black
                                                : Colors.grey.shade300,
                                            width: isSelected ? 3 : 1,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _alias,
                        decoration: const InputDecoration(
                          labelText: 'Alias (opsional)',
                          hintText: 'Contoh: dompet-tunai',
                          prefixIcon: Icon(Icons.alternate_email),
                          helperText:
                              'Huruf/koma/penghubung. Unik per pengguna',
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_\-]'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Saldo Awal - hanya tampil saat tambah dompet baru
                      if (widget.initial == null) ...[
                        TextFormField(
                          controller: _balance,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            IdrFormatters.rupiahInputFormatter(
                              withSymbol: true,
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Saldo Awal',
                            hintText: 'Contoh: Rp 250.000',
                            prefixIcon: Icon(Icons.numbers),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<String>(
                        value: _currency,
                        items: const [
                          DropdownMenuItem(
                            value: 'IDR',
                            child: Text('IDR - Rupiah'),
                          ),
                          DropdownMenuItem(
                            value: 'USD',
                            child: Text('USD - Dollar AS'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _currency = v ?? 'IDR'),
                        decoration: const InputDecoration(
                          labelText: 'Mata Uang',
                          prefixIcon: Icon(Icons.payments_outlined),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan Dompet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
