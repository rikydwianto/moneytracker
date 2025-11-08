import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wallet.dart';
import '../utils/idr.dart';
import '../utils/date_helpers.dart';
import '../services/transaction_service.dart';
import '../models/transaction.dart';
import '../widgets/wallet/modern_wallet_card.dart';
import 'transaction/debt_detail_screen.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';
import 'event/events_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const WalletsPage(),
    const TransactionsPage(),
    const DebtPage(),
    const StatsPage(),
  ];

  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Dompet';
      case 2:
        return 'Transaksi';
      case 3:
        return 'Hutang/Piutang';
      case 4:
        return 'Statistik';
      default:
        return 'Money Tracker';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: user?.photoURL != null
                ? ClipOval(
                    child: Image.network(
                      user!.photoURL!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, size: 18),
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
          ),
          onPressed: () {
            Navigator.of(context).pushNamed('/profile');
          },
          tooltip: 'Profile Saya',
        ),
        title: Text(_getTitle()),
        elevation: 2,
        actions: [
          // Notification Icon with Badge
          StreamBuilder<int>(
            stream: NotificationService().streamUnreadCount(user?.uid ?? ''),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/notifications');
                    },
                    tooltip: 'Notifikasi',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => SettingsScreen()));
            },
            tooltip: 'Pengaturan',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dasbor',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Dompet',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Hutang/Piutang',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistik',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 3
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed('/add-debt');
                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hutang/Piutang disimpan')),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Catat Hutang/Piutang'),
            )
          : null,
    );
  }
}

// Dashboard Page
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _showBalance = true;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final profileSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/profile/isPremium')
          .get();
      if (profileSnap.exists && mounted) {
        setState(() {
          _isPremium = profileSnap.value == true;
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _handleRefresh() async {
    // Trigger rebuild by calling setState
    setState(() {});
    // Add a small delay to show refresh animation
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    // Get month name in Indonesian
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
    final currentMonth = months[now.month - 1];

    Stream<double> _sumByType(String type) {
      if (user == null) return const Stream.empty();
      final ref = FirebaseDatabase.instance.ref(
        'users/${user.uid}/transactions',
      );
      return ref.onValue.map((event) {
        final data = event.snapshot.value;
        if (data == null) return 0.0;
        final map = (data as Map).cast<String, dynamic>();
        double total = 0.0;
        for (final entry in map.entries) {
          final m = (entry.value as Map).cast<dynamic, dynamic>();
          final t = (m['type'] ?? 'expense') as String;
          if (t != type) continue;
          final dateMs = (m['date'] ?? 0) as int;
          if (dateMs == 0) continue;
          final dt = DateTime.fromMillisecondsSinceEpoch(dateMs);
          if (dt.isBefore(monthStart) || dt.isAfter(monthEnd)) continue;
          final amt = ((m['amount'] ?? 0) as num).toDouble();
          total += amt;
        }
        return total;
      });
    }

    Stream<double> _getTotalBalance() {
      if (user == null) return const Stream.empty();

      // Ambil daftar wallet yang exclude from total atau type savings
      return FirebaseDatabase.instance
          .ref('users/${user.uid}/wallets')
          .onValue
          .asyncMap((walletEvent) async {
            final walletData = walletEvent.snapshot.value;
            List<String> excludeWalletIds = [];

            if (walletData != null) {
              final walletMap = (walletData as Map).cast<String, dynamic>();
              for (final entry in walletMap.entries) {
                final m = (entry.value as Map).cast<dynamic, dynamic>();
                final excludeFromTotal =
                    (m['excludeFromTotal'] ?? false) as bool;
                final walletType = m['type'] as String? ?? 'regular';

                // Exclude jika excludeFromTotal=true atau type=savings
                if (excludeFromTotal || walletType == 'savings') {
                  excludeWalletIds.add(entry.key);
                }
              }
            }

            // Hitung total balance dari transaksi real
            final txStream = TransactionService().streamTotalBalance(
              user.uid,
              excludeWalletIds: excludeWalletIds.isEmpty
                  ? null
                  : excludeWalletIds,
            );

            return await txStream.first;
          });
    }

    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card dengan Total Saldo - Modern Design
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background pattern
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Total Saldo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _showBalance
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showBalance = !_showBalance;
                                  });
                                },
                                tooltip: _showBalance
                                    ? 'Sembunyikan Saldo'
                                    : 'Tampilkan Saldo',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        StreamBuilder<double>(
                          stream: _getTotalBalance(),
                          builder: (context, snapshot) {
                            final value = snapshot.data ?? 0;
                            return Text(
                              _showBalance
                                  ? _formatCurrency(value)
                                  : 'Rp •••••••',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bulan $currentMonth ${now.year}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ), // Statistik Bulan Ini - Modern Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: StreamBuilder<double>(
                      stream: _sumByType('income'),
                      builder: (context, snapshot) {
                        final value = snapshot.data ?? 0;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Pemasukan',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _showBalance
                                      ? _formatCurrency(value)
                                      : 'Rp •••••',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StreamBuilder<double>(
                      stream: _sumByType('expense'),
                      builder: (context, snapshot) {
                        final value = snapshot.data ?? 0;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade400,
                                Colors.red.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Pengeluaran',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _showBalance
                                      ? _formatCurrency(value)
                                      : 'Rp •••••',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Premium Card - Jika belum premium
            if (!_isPremium)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: const [
                            Icon(
                              Icons.workspace_premium,
                              color: Color(0xFFFFD700),
                            ),
                            SizedBox(width: 8),
                            Text('Upgrade ke Premium'),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Dapatkan fitur premium:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text('✨ Kategori unlimited'),
                            Text('✨ Export data ke Excel/PDF'),
                            Text('✨ Backup otomatis ke cloud'),
                            Text('✨ Analisis keuangan mendalam'),
                            Text('✨ Tanpa iklan'),
                            Text('✨ Badge premium eksklusif'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Nanti'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // TODO: Implement premium upgrade
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Fitur upgrade akan segera tersedia!',
                                  ),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Upgrade Sekarang'),
                          ),
                        ],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Belum Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Upgrade untuk fitur eksklusif!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Quick Actions - Modern Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.flash_on_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Aksi Cepat',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.add_circle_rounded,
                          label: 'Tambah Transaksi',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.of(context).pushNamed('/add-transaction');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.category_rounded,
                          label: 'Kelola Kategori',
                          color: Colors.purple,
                          onTap: () {
                            Navigator.of(context).pushNamed('/categories');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Transfer Saldo',
                          color: Colors.green,
                          onTap: () => _showTransferOptions(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.send_rounded,
                          label: 'Transfer Rekening',
                          color: Colors.orange,
                          onTap: () => _showTransferAcrossOptions(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.tune_rounded,
                          label: 'Sesuaikan Saldo',
                          color: Colors.teal,
                          onTap: () => _showAdjustBalanceOptions(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.event_rounded,
                          label: 'Atur Acara',
                          color: Colors.pink,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const EventsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Info Card
            if (user == null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Masuk untuk sinkronisasi data keuangan Anda',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    return IdrFormatters.format(value);
  }

  void _showTransferOptions(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masuk terlebih dahulu')),
      );
      return;
    }

    // Show wallet selection bottom sheet for internal transfer
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WalletSelectionSheet(
        title: 'Pilih Dompet Sumber',
        subtitle: 'Transfer antar saldo dalam dompet',
        onWalletSelected: (sourceWallet, allWallets) {
          Navigator.pop(context);
          final otherWallets = allWallets
              .where((w) => w.id != sourceWallet.id)
              .toList();
          Navigator.pushNamed(
            context,
            '/transfer',
            arguments: {
              'sourceWallet': sourceWallet,
              'otherWallets': otherWallets,
            },
          );
        },
      ),
    );
  }

  void _showTransferAcrossOptions(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masuk terlebih dahulu')),
      );
      return;
    }

    // Show wallet selection bottom sheet for cross-account transfer
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WalletSelectionSheet(
        title: 'Pilih Dompet Sumber',
        subtitle: 'Transfer ke rekening lain',
        onWalletSelected: (sourceWallet, allWallets) {
          Navigator.pop(context);
          Navigator.pushNamed(
            context,
            '/transfer-across',
            arguments: {'sourceWallet': sourceWallet},
          );
        },
      ),
    );
  }

  void _showAdjustBalanceOptions(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masuk terlebih dahulu')),
      );
      return;
    }

    // Show wallet selection bottom sheet for balance adjustment
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WalletSelectionSheet(
        title: 'Pilih Dompet',
        subtitle: 'Sesuaikan saldo dompet',
        onWalletSelected: (wallet, allWallets) {
          Navigator.pop(context);
          Navigator.pushNamed(
            context,
            '/adjust-balance',
            arguments: {'wallet': wallet},
          );
        },
      ),
    );
  }
}

// Quick Action Card Widget - Modern Design
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Wallet Selection Sheet
class _WalletSelectionSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Function(Wallet, List<Wallet>) onWalletSelected;

  const _WalletSelectionSheet({
    required this.title,
    required this.subtitle,
    required this.onWalletSelected,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Wallet List
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('users/${user?.uid}/wallets')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(
                    child: Text('Tidak ada dompet ditemukan'),
                  );
                }

                final data =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final wallets = data.entries.map((entry) {
                  return Wallet.fromRtdb(
                    entry.key,
                    entry.value as Map<dynamic, dynamic>,
                  );
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: StreamBuilder<double>(
                        stream: TransactionService().streamWalletBalance(
                          user!.uid,
                          wallet.id,
                        ),
                        builder: (context, balanceSnapshot) {
                          final realTimeBalance = balanceSnapshot.data ?? 0.0;

                          return ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color(
                                  int.tryParse(
                                        wallet.color.replaceFirst('#', '0xFF'),
                                      ) ??
                                      0xFF2196F3,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  wallet.icon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            title: Text(
                              wallet.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Saldo: ${IdrFormatters.format(realTimeBalance)}',
                              style: TextStyle(
                                color: realTimeBalance >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              // Create updated wallet with real-time balance
                              final updatedWallet = Wallet(
                                id: wallet.id,
                                name: wallet.name,
                                balance: realTimeBalance,
                                currency: wallet.currency,
                                icon: wallet.icon,
                                color: wallet.color,
                                userId: wallet.userId,
                                createdAt: wallet.createdAt,
                                updatedAt: wallet.updatedAt,
                                isShared: wallet.isShared,
                                sharedWith: wallet.sharedWith,
                                alias: wallet.alias,
                                isDefault: wallet.isDefault,
                                excludeFromTotal: wallet.excludeFromTotal,
                              );
                              onWalletSelected(updatedWallet, wallets);
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Wallets Page
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
                  return !wallet.excludeFromTotal && type != 'savings';
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
                              excludeWalletIds: excludedWallets
                                  .map((w) => w.id)
                                  .toList(),
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
                        return ModernWalletCard(
                          wallet: w,
                          balance: balance,
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
                            excludeWalletIds: includedWallets
                                .map((w) => w.id)
                                .toList(),
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
                          balance: balance,
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

// Transactions Page
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

// Debt Page (Hutang/Piutang)
class DebtPage extends StatefulWidget {
  const DebtPage({super.key});

  @override
  State<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends State<DebtPage> {
  String _filter = 'semua'; // semua, hutang, piutang

  Future<void> _handleRefresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: user == null
            ? const Center(child: Text('Silakan login'))
            : Column(
                children: [
                  // Filter Tabs
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'semua',
                                label: Text('Semua'),
                              ),
                              ButtonSegment(
                                value: 'hutang',
                                label: Text('Hutang'),
                                icon: Icon(Icons.arrow_upward, size: 16),
                              ),
                              ButtonSegment(
                                value: 'piutang',
                                label: Text('Piutang'),
                                icon: Icon(Icons.arrow_downward, size: 16),
                              ),
                            ],
                            selected: {_filter},
                            onSelectionChanged: (Set<String> selected) {
                              setState(() {
                                _filter = selected.first;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Transaction List
                  Expanded(
                    child: StreamBuilder<List<TransactionModel>>(
                      stream: TransactionService().streamTransactions(user.uid),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        // Filter by categoryId: loan_received (hutang) or loan_given (piutang)
                        var debtList = snapshot.data!
                            .where(
                              (t) =>
                                  t.categoryId == 'loan_received' ||
                                  t.categoryId == 'loan_given',
                            )
                            .toList();

                        // Apply filter
                        if (_filter == 'hutang') {
                          debtList = debtList
                              .where((t) => t.categoryId == 'loan_received')
                              .toList();
                        } else if (_filter == 'piutang') {
                          debtList = debtList
                              .where((t) => t.categoryId == 'loan_given')
                              .toList();
                        }

                        if (debtList.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance,
                                  size: 80,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _filter == 'hutang'
                                      ? 'Tidak ada hutang'
                                      : _filter == 'piutang'
                                      ? 'Tidak ada piutang'
                                      : 'Belum ada catatan hutang/piutang',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Calculate totals
                        double totalHutang = 0;
                        double totalPiutang = 0;
                        for (final t in debtList) {
                          if (t.categoryId == 'loan_received') {
                            totalHutang += t.amount;
                          } else if (t.categoryId == 'loan_given') {
                            totalPiutang += t.amount;
                          }
                        }

                        return Column(
                          children: [
                            // Summary Card
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(20),
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.arrow_upward,
                                              color: Colors.red.shade400,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Hutang',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          IdrFormatters.format(totalHutang),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.arrow_downward,
                                              color: Colors.green.shade400,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Piutang',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          IdrFormatters.format(totalPiutang),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Transaction List
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: debtList.length,
                                itemBuilder: (context, index) {
                                  final t = debtList[index];
                                  final isHutang =
                                      t.categoryId == 'loan_received';

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isHutang
                                            ? Colors.red.shade50
                                            : Colors.green.shade50,
                                        child: Icon(
                                          isHutang
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          color: isHutang
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                      title: Text(
                                        t.counterpartyName ?? 'Tanpa nama',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        DateHelpers.dateOnly.format(t.date),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      trailing: Text(
                                        IdrFormatters.format(t.amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isHutang
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DebtDetailScreen(debt: t),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Statistics Page
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
