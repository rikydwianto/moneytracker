// Wallets Page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../models/wallet.dart';
import '../../services/transaction_service.dart';
import '../../utils/idr.dart';
import '../../widgets/wallet/modern_wallet_card.dart';

class WalletsPage extends StatefulWidget {
  const WalletsPage({super.key});

  @override
  State<WalletsPage> createState() => _WalletsPageState();
}

class _WalletsPageState extends State<WalletsPage> {
  Future<void> _handleRefresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  String _formatCurrency(double value) => IdrFormatters.format(value);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Masuk untuk melihat dompet'));
    }
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('users/${user.uid}/wallets')
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.snapshot.value;
        final map = (data is Map)
            ? data.cast<String, dynamic>()
            : <String, dynamic>{};

        // Parse wallets dengan type dan isHidden information
        final List<Map<String, dynamic>> walletsWithType = [];
        for (final entry in map.entries) {
          final walletData = (entry.value as Map).cast<dynamic, dynamic>();
          final wallet = Wallet.fromRtdb(entry.key, walletData);
          final type = walletData['type'] as String? ?? 'regular';
          final isHidden = walletData['isHidden'] as bool? ?? false;
          walletsWithType.add({
            'wallet': wallet,
            'type': type,
            'isHidden': isHidden,
          });
        }

        final wallets =
            walletsWithType.map((e) => e['wallet'] as Wallet).toList()
              ..sort((a, b) {
                // Tunai selalu di atas
                if (a.name.toLowerCase() == 'tunai') return -1;
                if (b.name.toLowerCase() == 'tunai') return 1;
                // Sisanya diurutkan alfabetis
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

        // Pisahkan dompet berdasarkan excludeFromTotal atau type=savings
        final includedWallets =
            walletsWithType
                .where((w) {
                  final wallet = w['wallet'] as Wallet;
                  final type = w['type'] as String;
                  return !wallet.excludeFromTotal &&
                      type != 'savings' &&
                      !(w['isHidden'] as bool);
                })
                .map((e) => e['wallet'] as Wallet)
                .toList()
              ..sort((a, b) {
                // Tunai selalu di atas
                if (a.name.toLowerCase() == 'tunai') return -1;
                if (b.name.toLowerCase() == 'tunai') return 1;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });
        final excludedWallets =
            walletsWithType
                .where((w) {
                  final wallet = w['wallet'] as Wallet;
                  final type = w['type'] as String;
                  return wallet.excludeFromTotal || type == 'savings';
                })
                .map((e) => e['wallet'] as Wallet)
                .toList()
              ..sort((a, b) {
                // Tunai selalu di atas
                if (a.name.toLowerCase() == 'tunai') return -1;
                if (b.name.toLowerCase() == 'tunai') return 1;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // Aksi cepat: Tambah Dompet (desain lebih menonjol)
              InkWell(
                onTap: () async {
                  final result = await Navigator.of(
                    context,
                  ).pushNamed('/add-wallet');
                  if (result == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dompet ditambahkan')),
                    );
                    setState(() {});
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Tambah Dompet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Buat dompet baru untuk mengelola saldo',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Aksi sekunder: Kelola Dompet
              // Total Balance Card dengan gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Saldo Aktif',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          StreamBuilder<double>(
                            stream: TransactionService().streamTotalBalance(
                              user.uid,
                              excludeWalletIds: [
                                ...includedWallets.map((w) => w.id),
                                ...walletsWithType
                                    .where((w) => w['isHidden'] == true)
                                    .map((w) => (w['wallet'] as Wallet).id),
                              ],
                            ),
                            builder: (context, snapshot) {
                              final balance = snapshot.data ?? 0.0;
                              return Text(
                                _formatCurrency(balance),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (wallets.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada dompet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tambahkan dompet dari Pengaturan',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Dompet yang masuk dalam total
                if (includedWallets.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Masuk dalam Total',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${includedWallets.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...includedWallets.map((w) {
                    // Get wallet data from walletsWithType
                    final walletData = walletsWithType.firstWhere(
                      (item) => (item['wallet'] as Wallet).id == w.id,
                      orElse: () => {
                        'wallet': w,
                        'type': 'regular',
                        'isHidden': false,
                        'pin': null,
                      },
                    );
                    final type = walletData['type'] as String;
                    final isHidden = walletData['isHidden'] as bool;

                    return StreamBuilder<double>(
                      stream: TransactionService().streamWalletBalance(
                        FirebaseAuth.instance.currentUser!.uid,
                        w.id,
                      ),
                      builder: (context, snapshot) {
                        final balance = snapshot.data ?? 0.0;
                        // Jika dompet hidden, jangan tampilkan saldo (pass null & showBalance=false via isHidden)
                        return ModernWalletCard(
                          wallet: w,
                          balance: isHidden ? null : balance,
                          isCompact: true,
                          walletType: type,
                          isHidden: isHidden,
                        );
                      },
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // Dompet yang dikecualikan dari total
                if (excludedWallets.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kecualikan dari Total',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${excludedWallets.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        StreamBuilder<double>(
                          stream: TransactionService().streamTotalBalance(
                            user.uid,
                            excludeWalletIds: [
                              ...includedWallets.map((w) => w.id),
                              ...walletsWithType
                                  .where((w) => w['isHidden'] == true)
                                  .map((w) => (w['wallet'] as Wallet).id),
                            ],
                          ),
                          builder: (context, snapshot) {
                            // This calculates total of excluded wallets
                            // by excluding the included wallets
                            final balance = snapshot.data ?? 0.0;
                            return Text(
                              _formatCurrency(balance),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...excludedWallets.map((w) {
                    // Get wallet data from walletsWithType
                    final walletData = walletsWithType.firstWhere(
                      (item) => (item['wallet'] as Wallet).id == w.id,
                      orElse: () => {
                        'wallet': w,
                        'type': 'regular',
                        'isHidden': false,
                      },
                    );
                    final type = walletData['type'] as String;
                    final isHidden = walletData['isHidden'] as bool;

                    return StreamBuilder<double>(
                      stream: TransactionService().streamWalletBalance(
                        FirebaseAuth.instance.currentUser!.uid,
                        w.id,
                      ),
                      builder: (context, snapshot) {
                        final balance = snapshot.data ?? 0.0;
                        return ModernWalletCard(
                          wallet: w,
                          balance: isHidden ? null : balance,
                          isCompact: true,
                          walletType: type,
                          isHidden: isHidden,
                        );
                      },
                    );
                  }),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

// Debt Page (Hutang/Piutang)
