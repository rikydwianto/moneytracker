import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/wallet.dart';
import '../../utils/idr.dart';
import '../../screens/wallet/wallet_detail_screen.dart';
import '../../screens/settings/app_pin_verify_screen.dart';

class ModernWalletCard extends StatelessWidget {
  final Wallet wallet;
  final double? balance;
  final VoidCallback? onTap;
  final bool showBalance;
  final bool isCompact;
  final String? walletType; // 'regular' atau 'savings'
  final bool isHidden; // Apakah wallet di-hide dengan PIN

  const ModernWalletCard({
    super.key,
    required this.wallet,
    this.balance,
    this.onTap,
    this.showBalance = true,
    this.isCompact = false,
    this.walletType,
    this.isHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: isCompact ? 4 : 8,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: GestureDetector(
        onTap: onTap ?? () => _navigateToDetail(context),
        onLongPress: () => _showWalletMenu(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                _getWalletColor().withOpacity(0.1),
                _getWalletColor().withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            child: isCompact
                ? _buildCompactContent(theme, context)
                : _buildFullContent(theme, context),
          ),
        ),
      ),
    );
  }

  Color _getWalletColor() {
    return Color(
      int.tryParse(wallet.color.replaceFirst('#', '0xFF')) ?? 0xFF2196F3,
    );
  }

  String _getWalletIconString() {
    // wallet.icon adalah string emoji/unicode dari Firebase
    return wallet.icon.isNotEmpty ? wallet.icon : '💰';
  }

  Widget _buildCompactContent(ThemeData theme, BuildContext context) {
    return Row(
      children: [
        // Wallet Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getWalletColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _getWalletIconString(),
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Wallet Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wallet.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (walletType == 'savings') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.savings_outlined,
                            size: 10,
                            color: Colors.green,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'SIMPANAN',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (wallet.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (showBalance && balance != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isHidden) ...[
                      Icon(
                        Icons.lock,
                        size: 12,
                        color: Colors.deepPurple.shade700,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isHidden ? '••••••' : IdrFormatters.format(balance!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isHidden
                            ? Colors.deepPurple.shade700
                            : (balance! >= 0
                                  ? theme.colorScheme.primary
                                  : Colors.red),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Lock & Arrow Icon
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isHidden)
              Icon(Icons.lock, size: 18, color: Colors.deepPurple.shade700),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullContent(ThemeData theme, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          children: [
            // Wallet Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getWalletColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _getWalletIconString(),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Wallet Name and Currency
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        wallet.currency,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (walletType == 'savings') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.savings_outlined,
                                size: 12,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'SIMPANAN',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (wallet.alias != null && wallet.alias!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '@${wallet.alias}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Menu Button
            IconButton(
              onPressed: () => _showWalletMenu(context),
              icon: Icon(Icons.more_vert, color: theme.colorScheme.outline),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                elevation: 1,
              ),
            ),
          ],
        ),

        if (showBalance) ...[
          const SizedBox(height: 16),

          // Balance Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo Saat Ini',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance != null
                      ? IdrFormatters.format(balance!)
                      : 'Memuat...',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: balance != null && balance! >= 0
                        ? theme.colorScheme.primary
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _navigateToDetail(BuildContext context) async {
    // Jika wallet di-hide, verify PIN dulu
    if (isHidden) {
      final verified = await _verifyPinBeforeAccess(context);
      if (!verified) return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WalletDetailScreen(wallet: wallet),
        ),
      );
    }
  }

  Future<bool> _verifyPinBeforeAccess(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Get global PIN from settings
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/pin')
          .get();

      // If PIN not set or invalid, offer to set it up
      String? pinFromDb = snapshot.exists ? (snapshot.value as String?) : null;
      if (pinFromDb == null || pinFromDb.isEmpty) {
        if (!context.mounted) return false;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('PIN belum diatur'),
            content: const Text(
              'Anda perlu mengatur PIN aplikasi terlebih dahulu untuk membuka dompet tersembunyi. Ingin atur sekarang?',
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

        if (proceed == true) {
          // Navigate to PIN setup
          await Navigator.pushNamed(context, '/app-pin-setup');
          // Re-fetch PIN after returning
          final afterSetup = await FirebaseDatabase.instance
              .ref('users/${user.uid}/settings/pin')
              .get();
          pinFromDb = afterSetup.exists ? (afterSetup.value as String?) : null;
          if (pinFromDb == null || pinFromDb.isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN belum diatur.')),
              );
            }
            return false;
          }
        } else {
          return false;
        }
      }

      // Verify existing PIN
      if (!context.mounted) return false;
      final verified = await showAppPinVerification(
        context,
        pin: pinFromDb,
        purpose: 'wallet',
        title: 'Buka ${wallet.name}',
      );
      return verified;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saat verifikasi PIN: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  void _showWalletMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => WalletMenuBottomSheet(wallet: wallet),
    ).catchError((error) {
      debugPrint('Error showing wallet menu: $error');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $error')));
    });
  }
}

class WalletMenuBottomSheet extends StatefulWidget {
  final Wallet wallet;

  const WalletMenuBottomSheet({super.key, required this.wallet});

  @override
  State<WalletMenuBottomSheet> createState() => _WalletMenuBottomSheetState();
}

class _WalletMenuBottomSheetState extends State<WalletMenuBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Wallet Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getWalletColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _getWalletIconString(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.wallet.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.wallet.currency,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Menu Options
            _buildMenuItem(
              context,
              icon: Icons.edit,
              title: 'Edit Dompet',
              subtitle: 'Ubah nama, ikon, atau mata uang',
              onTap: () => _editWallet(context),
            ),

            const SizedBox(height: 4),

            _buildMenuItem(
              context,
              icon: Icons.history,
              title: 'Riwayat Transaksi',
              subtitle: 'Lihat semua transaksi dompet ini',
              onTap: () => _viewTransactionHistory(context),
            ),

            const SizedBox(height: 4),

            _buildMenuItem(
              context,
              icon: Icons.swap_horiz,
              title: 'Transfer Antar Saldo',
              subtitle: 'Transfer ke dompet lain',
              onTap: () => _showTransferOptions(context),
            ),

            const SizedBox(height: 4),

            _buildMenuItem(
              context,
              icon: Icons.send_rounded,
              title: 'Transfer Antar Rekening',
              subtitle: 'Transfer ke rekening lain',
              onTap: () => _transferAcross(context),
            ),

            const SizedBox(height: 4),

            _buildMenuItem(
              context,
              icon: Icons.tune,
              title: 'Atur Saldo',
              subtitle: 'Sesuaikan saldo dompet',
              onTap: () => _adjustBalance(context),
            ),

            const SizedBox(height: 4),

            _buildMenuItem(
              context,
              icon: widget.wallet.isDefault ? Icons.star : Icons.star_border,
              title: widget.wallet.isDefault
                  ? 'Dompet Default'
                  : 'Jadikan Default',
              subtitle: widget.wallet.isDefault
                  ? 'Dompet utama saat ini'
                  : 'Gunakan sebagai dompet utama',
              onTap: () => _toggleDefault(context),
            ),

            const SizedBox(height: 4),

            _buildMenuItem(
              context,
              icon: widget.wallet.excludeFromTotal
                  ? Icons.visibility_off
                  : Icons.visibility,
              title: widget.wallet.excludeFromTotal
                  ? 'Masukkan ke Total'
                  : 'Kecualikan dari Total',
              subtitle: widget.wallet.excludeFromTotal
                  ? 'Sertakan dalam total saldo'
                  : 'Jangan hitung dalam total saldo',
              onTap: () => _toggleExcludeFromTotal(context),
            ),

            const SizedBox(height: 4),

            _buildMenuItem(
              context,
              icon: Icons.delete,
              title: 'Hapus Dompet',
              subtitle: 'Hapus dompet dan semua datanya',
              onTap: () => _deleteWallet(context),
              isDestructive: true,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color _getWalletColor() {
    return Color(
      int.tryParse(widget.wallet.color.replaceFirst('#', '0xFF')) ?? 0xFF2196F3,
    );
  }

  String _getWalletIconString() {
    return widget.wallet.icon.isNotEmpty ? widget.wallet.icon : '💰';
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _editWallet(BuildContext context) {
    Navigator.pushNamed(context, '/add-wallet', arguments: widget.wallet);
  }

  void _viewTransactionHistory(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/wallet-transactions',
      arguments: widget.wallet.id,
    );
  }

  void _adjustBalance(BuildContext context) {
    Navigator.pushNamed(context, '/adjust-balance', arguments: widget.wallet);
  }

  void _deleteWallet(BuildContext context) {
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
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement wallet deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur hapus dompet akan segera tersedia'),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showTransferOptions(BuildContext context) async {
    Navigator.pop(context); // Close menu first

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get all user wallets
    final walletsSnapshot = await FirebaseDatabase.instance
        .ref('users/${user.uid}/wallets')
        .once();

    if (walletsSnapshot.snapshot.value == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada dompet lain ditemukan')),
        );
      }
      return;
    }

    final data = walletsSnapshot.snapshot.value as Map<dynamic, dynamic>;
    final allWallets = data.entries
        .map(
          (entry) =>
              Wallet.fromRtdb(entry.key, entry.value as Map<dynamic, dynamic>),
        )
        .toList();

    final otherWallets = allWallets
        .where((w) => w.id != widget.wallet.id)
        .toList();

    if (otherWallets.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada dompet lain untuk transfer')),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.pushNamed(
        context,
        '/transfer',
        arguments: {
          'sourceWallet': widget.wallet,
          'otherWallets': otherWallets,
        },
      );
    }
  }

  void _transferAcross(BuildContext context) {
    Navigator.pop(context); // Close menu first

    Navigator.pushNamed(
      context,
      '/transfer-across',
      arguments: {'sourceWallet': widget.wallet},
    );
  }

  void _toggleDefault(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final updates = <String, dynamic>{};
      final currentIsDefault = widget.wallet.isDefault;

      if (!currentIsDefault) {
        // First, get all wallets to unset any existing default
        final walletsSnapshot = await FirebaseDatabase.instance
            .ref('users/${user.uid}/wallets')
            .once();

        if (walletsSnapshot.snapshot.value != null) {
          final data = walletsSnapshot.snapshot.value as Map<dynamic, dynamic>;

          // Unset all existing defaults
          for (final entry in data.entries) {
            final walletData = entry.value as Map<dynamic, dynamic>;
            if (walletData['isDefault'] == true) {
              updates['users/${user.uid}/wallets/${entry.key}/isDefault'] =
                  false;
            }
          }
        }

        // Set this wallet as the new default
        updates['users/${user.uid}/wallets/${widget.wallet.id}/isDefault'] =
            true;
      } else {
        // Unset this wallet as default (no default wallet)
        updates['users/${user.uid}/wallets/${widget.wallet.id}/isDefault'] =
            false;
      }

      // Apply all updates in one transaction
      await FirebaseDatabase.instance.ref().update(updates);

      // Close menu after successful update
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentIsDefault
                  ? 'Dompet ${widget.wallet.name} bukan lagi default'
                  : 'Dompet ${widget.wallet.name} dijadikan default',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _toggleExcludeFromTotal(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final currentExcludeFromTotal = widget.wallet.excludeFromTotal;
      final newValue = !currentExcludeFromTotal;

      await FirebaseDatabase.instance
          .ref('users/${user.uid}/wallets/${widget.wallet.id}/excludeFromTotal')
          .set(newValue);

      // Close menu after successful update
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? 'Dompet ${widget.wallet.name} dikecualikan dari total saldo'
                  : 'Dompet ${widget.wallet.name} disertakan dalam total saldo',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
