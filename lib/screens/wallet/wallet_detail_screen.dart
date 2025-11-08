import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/wallet.dart';
import '../../models/transaction.dart';
import '../../services/transaction_service.dart';
import '../../utils/idr.dart';
import '../../utils/date_helpers.dart';
import '../transaction/transaction_detail_screen.dart';

class WalletDetailScreen extends StatefulWidget {
  final Wallet wallet;

  const WalletDetailScreen({super.key, required this.wallet});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransactionService _transactionService = TransactionService();
  String? _userId;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Show title when scrolled down more than 120 pixels
    if (_scrollController.offset > 120 && !_showTitle) {
      setState(() => _showTitle = true);
    } else if (_scrollController.offset <= 120 && _showTitle) {
      setState(() => _showTitle = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Helper methods untuk safe type conversion
  int _getWalletColor() {
    // wallet.color adalah String dalam format hex seperti "#1E88E5"
    String colorStr = widget.wallet.color;
    if (colorStr.startsWith('#')) {
      return int.tryParse(colorStr.replaceFirst('#', '0xFF')) ?? 0xFF2196F3;
    }
    return int.tryParse(colorStr) ?? 0xFF2196F3;
  }

  String _getWalletIconString() {
    // Gunakan emoji string dari wallet
    return widget.wallet.icon.isNotEmpty ? widget.wallet.icon : '💰';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(theme),
            _buildWalletInfo(theme),
            _buildTabBar(theme),
          ];
        },
        body: _buildTabContent(),
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      elevation: 0,
      backgroundColor: Color(_getWalletColor()),
      foregroundColor: Colors.white,
      centerTitle: false,
      title: _showTitle
          ? Text(
              widget.wallet.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(_getWalletColor()),
                Color(_getWalletColor()).withOpacity(0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40), // Space for app bar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      _getWalletIconString(),
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.wallet.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.wallet.alias != null &&
                    widget.wallet.alias!.isNotEmpty)
                  Text(
                    '@${widget.wallet.alias}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.black),
                  SizedBox(width: 12),
                  Text('Edit Dompet'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'adjust',
              child: Row(
                children: [
                  Icon(Icons.tune, color: Colors.black),
                  SizedBox(width: 12),
                  Text('Atur Saldo'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Hapus Dompet', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletInfo(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: StreamBuilder<double>(
          stream: _userId != null
              ? _transactionService.streamWalletBalance(
                  _userId!,
                  widget.wallet.id,
                )
              : const Stream.empty(),
          builder: (context, snapshot) {
            final balance = snapshot.data ?? 0.0;
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            return Column(
              children: [
                // Balance
                Text(
                  'Saldo Saat Ini',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        IdrFormatters.format(balance),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: balance >= 0
                              ? theme.colorScheme.primary
                              : Colors.red,
                        ),
                      ),

                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Masuk'),
            Tab(text: 'Keluar'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTransactionList(null), // All transactions
        _buildTransactionList(TransactionType.income), // Income only
        _buildTransactionList(TransactionType.expense), // Expense only
      ],
    );
  }

  Widget _buildTransactionList(TransactionType? filterType) {
    if (_userId == null) {
      return const Center(child: Text('Silakan login terlebih dahulu'));
    }

    return StreamBuilder<List<TransactionModel>>(
      stream: _transactionService
          .streamTransactions(_userId!)
          .asBroadcastStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allTransactions = snapshot.data ?? [];

        // Filter transactions for this wallet
        var walletTransactions = allTransactions
            .where((tx) => tx.walletId == widget.wallet.id)
            .toList();

        // Apply type filter if specified
        if (filterType != null) {
          walletTransactions = walletTransactions
              .where((tx) => tx.type == filterType)
              .toList();
        }

        // Sort by date descending
        walletTransactions.sort((a, b) => b.date.compareTo(a.date));

        if (walletTransactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada transaksi',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  filterType == TransactionType.income
                      ? 'Belum ada pemasukan'
                      : filterType == TransactionType.expense
                      ? 'Belum ada pengeluaran'
                      : 'Transaksi akan muncul di sini',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: walletTransactions.length,
          itemBuilder: (context, index) {
            final transaction = walletTransactions[index];
            return _buildTransactionTile(transaction);
          },
        );
      },
    );
  }

  Widget _buildTransactionTile(TransactionModel transaction) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    Color bgColor = isIncome
        ? Colors.green.withOpacity(0.1)
        : isTransfer
        ? Colors.blue.withOpacity(0.1)
        : Colors.red.withOpacity(0.1);

    Color iconColor = isIncome
        ? Colors.green
        : isTransfer
        ? Colors.blue
        : Colors.red;

    IconData iconData = isIncome
        ? Icons.arrow_downward
        : isTransfer
        ? Icons.swap_horiz
        : Icons.arrow_upward;

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
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TransactionDetailScreen(transaction: transaction),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateHelpers.format(transaction.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome
                          ? '+'
                          : isTransfer
                          ? ''
                          : '-'} ${IdrFormatters.format(transaction.amount)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: iconColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        Navigator.pushNamed(context, '/add-wallet', arguments: widget.wallet);
        break;
      case 'adjust':
        Navigator.pushNamed(
          context,
          '/adjust-balance',
          arguments: {'wallet': widget.wallet},
        );
        break;
      case 'delete':
        _showDeleteDialog();
        break;
    }
  }

  void _showDeleteDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Dompet'),
        content: Text(
          'Yakin ingin menghapus dompet "${widget.wallet.name}"? '
          'Semua transaksi yang terkait akan ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              navigator.pop(); // Close dialog

              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  await FirebaseDatabase.instance
                      .ref('users/${user.uid}/wallets/${widget.wallet.id}')
                      .remove();

                  navigator.pop(); // Go back to previous screen

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Dompet berhasil dihapus'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
