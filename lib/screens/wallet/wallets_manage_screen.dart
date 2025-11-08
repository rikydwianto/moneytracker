import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/wallet_service.dart';
import 'package:flutter/material.dart';
import '../../models/wallet.dart';
import '../../utils/idr.dart';
import 'wallet_form_screen.dart';

class WalletsManageScreen extends StatelessWidget {
  const WalletsManageScreen({super.key});

  String _formatCurrency(double value) => IdrFormatters.format(value);

  Future<void> _edit(BuildContext context, Wallet wallet) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WalletFormScreen(initial: wallet)),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dompet diperbarui')));
    }
  }

  Future<double?> _promptNumber(
    BuildContext context,
    String title,
    String label,
  ) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            IdrFormatters.rupiahInputFormatter(withSymbol: true),
          ],
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Contoh: Rp 100.000',
            filled: true,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final v = IdrFormatters.parse(ctrl.text);
      return v;
    }
    return null;
  }

  Future<(Wallet, double)?> _promptTransferWithin(
    BuildContext context,
    Wallet from,
    List<Wallet> options,
  ) async {
    Wallet? to = options.first;
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Transfer antar saldo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Wallet>(
                value: to,
                items: options
                    .map(
                      (w) => DropdownMenuItem(
                        value: w,
                        child: Text('${w.name} (${w.currency})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => to = v),
                decoration: const InputDecoration(labelText: 'Tujuan'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  IdrFormatters.rupiahInputFormatter(withSymbol: true),
                ],
                decoration: const InputDecoration(
                  labelText: 'Jumlah',
                  hintText: 'Contoh: Rp 100.000',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
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
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && to != null) {
      final amt = IdrFormatters.parse(amountCtrl.text);
      if (amt > 0) return (to!, amt);
    }
    return null;
  }

  Future<(String toUid, String toWalletId, double amount)?>
  _promptTransferAcross(BuildContext context) async {
    final uidCtrl = TextEditingController();
    final aliasCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transfer antar rekening'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'UID Penerima'),
              controller: uidCtrl,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Alias Dompet Penerima',
                hintText: 'Contoh: bank-bca',
              ),
              controller: aliasCtrl,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Jumlah'),
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
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
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final amt = IdrFormatters.parse(amtCtrl.text);
      if (amt > 0 && uidCtrl.text.isNotEmpty && aliasCtrl.text.isNotEmpty) {
        // Resolve alias to wallet id when executing action
        return (uidCtrl.text.trim(), aliasCtrl.text.trim(), amt);
      }
    }
    return null;
  }

  Future<void> _delete(BuildContext context, Wallet wallet) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Dompet'),
        content: Text('Yakin ingin menghapus "${wallet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/wallets/${wallet.id}')
          .remove();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dompet dihapus')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Atur Dompet')),
      body: user == null
          ? const Center(child: Text('Masuk untuk mengatur dompet'))
          : StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('users/${user.uid}/wallets')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data?.snapshot.value;
                if (data == null) {
                  return const Center(child: Text('Belum ada dompet'));
                }
                final map = (data as Map).cast<String, dynamic>();
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
                return ListView.separated(
                  itemCount: wallets.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final w = wallets[index];
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(w.color.substring(1), radix: 16) +
                                0xFF000000,
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            w.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      title: Text(w.name),
                      subtitle: Text(
                        w.alias == null || w.alias!.isEmpty
                            ? w.currency
                            : '${w.currency} • @${w.alias}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatCurrency(w.balance),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            tooltip: 'Menu',
                            onSelected: (value) async {
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) return;
                              final service = WalletService();
                              try {
                                if (value == 'adjust') {
                                  final v = await _promptNumber(
                                    context,
                                    'Sesuaikan Saldo',
                                    'Masukkan saldo baru',
                                  );
                                  if (v != null) {
                                    await service.adjustBalance(uid, w.id, v);
                                  }
                                } else if (value == 'transfer_within') {
                                  final others = wallets
                                      .where((x) => x.id != w.id)
                                      .toList();
                                  if (others.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Tidak ada dompet tujuan',
                                        ),
                                      ),
                                    );
                                  } else {
                                    final result = await _promptTransferWithin(
                                      context,
                                      w,
                                      others,
                                    );
                                    if (result != null) {
                                      await service.transferWithinUser(
                                        uid,
                                        w.id,
                                        result.$1.id,
                                        result.$2,
                                      );
                                    }
                                  }
                                } else if (value == 'transfer_across') {
                                  final result = await _promptTransferAcross(
                                    context,
                                  );
                                  if (result != null) {
                                    // result.$2 contains alias; resolve to walletId
                                    final toWalletId = await service
                                        .findWalletIdByAlias(
                                          result.$1,
                                          result.$2,
                                        );
                                    if (toWalletId == null) {
                                      throw Exception(
                                        'Alias dompet tujuan tidak ditemukan',
                                      );
                                    }
                                    await service.transferAcrossUsers(
                                      uid,
                                      w.id,
                                      result.$1,
                                      toWalletId,
                                      result.$3,
                                    );
                                  }
                                } else if (value == 'edit') {
                                  _edit(context, w);
                                } else if (value == 'delete') {
                                  _delete(context, w);
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal: $e')),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'adjust',
                                child: Text('Sesuaikan Saldo'),
                              ),
                              PopupMenuItem(
                                value: 'transfer_within',
                                child: Text('Transfer antar saldo'),
                              ),
                              PopupMenuItem(
                                value: 'transfer_across',
                                child: Text('Transfer antar rekening'),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem(value: 'edit', child: Text('Ubah')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Hapus'),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WalletFormScreen()));
          if (result == true && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Dompet ditambahkan')));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}
