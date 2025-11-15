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
import 'transaction/debt_page.dart';
import 'transaction/stats_page.dart';
import 'transaction/transactions_page.dart';
import 'wallet/wallet_page.dart';

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
    );
  }
}

// Draggable FAB removed; Mini Apps shortcut moved into Quick Actions section.

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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.grid_view_rounded,
                          label: 'Mini Apps',
                          color: Colors.indigo,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/mini-apps'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
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
                final entries = data.entries.toList();

                // Build list of wallet models for callback use
                final wallets = entries.map((e) {
                  final rawMap = (e.value as Map).cast<dynamic, dynamic>();
                  return Wallet.fromRtdb(e.key, rawMap);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final rawMap = (entry.value as Map)
                        .cast<dynamic, dynamic>();
                    final wallet = Wallet.fromRtdb(entry.key, rawMap);
                    final isHidden = (rawMap['isHidden'] as bool?) ?? false;
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
                            subtitle: isHidden
                                ? null
                                : Text(
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
