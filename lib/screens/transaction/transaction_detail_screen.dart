import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/transaction.dart';
import '../../services/transaction_service.dart';
import '../../utils/date_helpers.dart';
import '../../utils/idr.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  Future<Map<String, dynamic>?> _getCategoryDetails(
    String userId,
    String categoryId,
  ) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/$userId/categories/$categoryId')
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        return data.cast<String, dynamic>();
      }
    } catch (e) {
      debugPrint('Error getting category: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getWalletDetails(
    String userId,
    String walletId,
  ) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/$userId/wallets/$walletId')
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        return data.cast<String, dynamic>();
      }
    } catch (e) {
      debugPrint('Error getting wallet: $e');
    }
    return null;
  }

  Future<void> _deleteTransaction(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini?'),
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

    if (confirmed == true && context.mounted) {
      try {
        await TransactionService().delete(transaction.userId, transaction.id);
        if (context.mounted) {
          Navigator.pop(context, true); // Return true to indicate deletion
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaksi berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
        }
      }
    }
  }

  Future<void> _duplicateTransaction(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final duplicatedTx = TransactionModel(
        id: '',
        title: '${transaction.title} (Copy)',
        amount: transaction.amount,
        type: transaction.type,
        categoryId: transaction.categoryId,
        walletId: transaction.walletId,
        toWalletId: transaction.toWalletId,
        date: DateTime.now(),
        notes: transaction.notes,
        photoUrl: transaction.photoUrl,
        userId: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        eventId: transaction.eventId,
        withPerson: transaction.withPerson,
        location: transaction.location,
        reminderAt: transaction.reminderAt,
      );

      await TransactionService().add(user.uid, duplicatedTx);

      if (context.mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil diduplikat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menduplikat: $e')));
      }
    }
  }

  Future<Map<String, dynamic>?> _getEventDetails(
    String userId,
    String eventId,
  ) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/$userId/events/$eventId')
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        return data.cast<String, dynamic>();
      }
    } catch (e) {
      debugPrint('Error getting event: $e');
    }
    return null;
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('makanan') || name.contains('makan')) {
      return Icons.restaurant;
    } else if (name.contains('minuman')) {
      return Icons.local_cafe;
    } else if (name.contains('transportasi') || name.contains('transport')) {
      return Icons.directions_car;
    } else if (name.contains('belanja') || name.contains('shopping')) {
      return Icons.shopping_cart;
    } else if (name.contains('hiburan') || name.contains('entertainment')) {
      return Icons.movie;
    } else if (name.contains('kesehatan') || name.contains('health')) {
      return Icons.local_hospital;
    } else if (name.contains('pendidikan') || name.contains('education')) {
      return Icons.school;
    } else if (name.contains('tagihan') || name.contains('bill')) {
      return Icons.receipt_long;
    } else if (name.contains('gaji') || name.contains('salary')) {
      return Icons.paid;
    } else if (name.contains('bonus')) {
      return Icons.card_giftcard;
    }
    return Icons.category;
  }

  Color _getCategoryColor(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('makanan') || name.contains('makan')) {
      return Colors.orange;
    } else if (name.contains('minuman')) {
      return Colors.brown;
    } else if (name.contains('transportasi') || name.contains('transport')) {
      return Colors.blue;
    } else if (name.contains('belanja') || name.contains('shopping')) {
      return Colors.purple;
    } else if (name.contains('hiburan') || name.contains('entertainment')) {
      return Colors.pink;
    } else if (name.contains('kesehatan') || name.contains('health')) {
      return Colors.red;
    } else if (name.contains('pendidikan') || name.contains('education')) {
      return Colors.indigo;
    } else if (name.contains('tagihan') || name.contains('bill')) {
      return Colors.amber;
    } else if (name.contains('gaji') || name.contains('salary')) {
      return Colors.green;
    } else if (name.contains('bonus')) {
      return Colors.teal;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isExpense = transaction.type == TransactionType.expense;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Detail Transaksi'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  // TODO: Navigate to edit transaction
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit akan segera hadir')),
                  );
                  break;
                case 'duplicate':
                  _duplicateTransaction(context);
                  break;
                case 'delete':
                  _deleteTransaction(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.content_copy, size: 20),
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
                    Text('Hapus', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Silakan masuk terlebih dahulu'))
          : FutureBuilder<List<Map<String, dynamic>?>>(
              future: Future.wait([
                _getCategoryDetails(user.uid, transaction.categoryId),
                _getWalletDetails(user.uid, transaction.walletId),
                if (transaction.eventId != null)
                  _getEventDetails(user.uid, transaction.eventId!)
                else
                  Future.value(null),
              ]),
              builder: (context, snapshot) {
                final categoryData =
                    snapshot.data != null && snapshot.data!.isNotEmpty
                    ? snapshot.data![0]
                    : null;
                final walletData =
                    snapshot.data != null && snapshot.data!.length >= 2
                    ? snapshot.data![1]
                    : null;
                final eventData =
                    snapshot.data != null && snapshot.data!.length >= 3
                    ? snapshot.data![2]
                    : null;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Amount Header (enhanced visual)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            colors: isExpense
                                ? [Colors.red.shade700, Colors.red.shade400]
                                : [
                                    Colors.green.shade700,
                                    Colors.green.shade400,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isExpense ? Colors.red : Colors.green)
                                  .withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Decorative circles
                            Positioned(
                              top: -30,
                              left: -10,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -20,
                              right: -10,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.04),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                28,
                                24,
                                24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.15),
                                          border: Border.all(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: Icon(
                                          isExpense
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        isExpense ? 'Pengeluaran' : 'Pemasukan',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ShaderMask(
                                    shaderCallback: (rect) => LinearGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.white.withOpacity(0.85),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ).createShader(rect),
                                    blendMode: BlendMode.srcIn,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: Text(
                                        IdrFormatters.format(
                                          transaction.amount,
                                        ),
                                        key: ValueKey(transaction.amount),
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  // Horizontal scroll chips
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        if (categoryData != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: _buildChip(
                                              label:
                                                  categoryData['name'] ??
                                                  'Kategori',
                                              icon: _getCategoryIcon(
                                                categoryData['name'] ?? '',
                                              ),
                                              color: _getCategoryColor(
                                                categoryData['name'] ?? '',
                                              ),
                                              lightOnDark: true,
                                            ),
                                          ),
                                        if (walletData != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: _buildChip(
                                              label:
                                                  walletData['name'] ??
                                                  'Dompet',
                                              icon:
                                                  Icons.account_balance_wallet,
                                              color: Colors.orange,
                                              lightOnDark: true,
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: _buildChip(
                                            label: DateHelpers.dateTime.format(
                                              transaction.date,
                                            ),
                                            icon: Icons.schedule,
                                            color: Colors.blueGrey,
                                            lightOnDark: true,
                                          ),
                                        ),
                                        if (eventData != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: _buildChip(
                                              label:
                                                  eventData['name'] ?? 'Acara',
                                              icon: Icons.event,
                                              color: Colors.purple,
                                              lightOnDark: true,
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

                      // Details Card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blueGrey[400],
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Rincian',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Title
                            _buildDetailRow(
                              icon: Icons.title,
                              label: 'Judul',
                              value: transaction.title,
                            ),
                            const Divider(height: 1),
                            // Category
                            if (categoryData != null)
                              _buildDetailRow(
                                icon: _getCategoryIcon(
                                  categoryData['name'] ?? '',
                                ),
                                iconColor: _getCategoryColor(
                                  categoryData['name'] ?? '',
                                ),
                                label: 'Kategori',
                                value: categoryData['name'] ?? 'Tidak ada',
                              ),
                            const Divider(height: 1),
                            // Wallet
                            if (walletData != null)
                              _buildDetailRow(
                                icon: Icons.account_balance_wallet,
                                iconColor: Colors.orange,
                                label: 'Dompet',
                                value: walletData['name'] ?? 'Tidak ada',
                              ),
                            const Divider(height: 1),
                            // Event
                            if (eventData != null)
                              _buildDetailRow(
                                icon: Icons.event,
                                iconColor: Colors.purple,
                                label: 'Acara',
                                value: eventData['name'] ?? 'Acara',
                              ),
                            const Divider(height: 1),
                            // Date
                            _buildDetailRow(
                              icon: Icons.calendar_today,
                              label: 'Tanggal',
                              value: DateHelpers.longDate.format(
                                transaction.date,
                              ),
                            ),
                            const Divider(height: 1),
                            // Time
                            _buildDetailRow(
                              icon: Icons.access_time,
                              label: 'Waktu',
                              value: DateHelpers.dateTime.format(
                                transaction.date,
                              ),
                            ),
                            const Divider(height: 1),
                            // With Person
                            if (transaction.withPerson != null &&
                                transaction.withPerson!.isNotEmpty)
                              _buildDetailRow(
                                icon: Icons.people_outline,
                                label: 'Dengan',
                                value: transaction.withPerson!,
                              ),
                            if (transaction.withPerson != null &&
                                transaction.withPerson!.isNotEmpty)
                              const Divider(height: 1),
                            // Location
                            if (transaction.location != null &&
                                transaction.location!.isNotEmpty)
                              _buildDetailRow(
                                icon: Icons.location_on_outlined,
                                iconColor: Colors.redAccent,
                                label: 'Lokasi',
                                value: transaction.location!,
                              ),
                            if (transaction.location != null &&
                                transaction.location!.isNotEmpty)
                              const Divider(height: 1),
                            // Reminder
                            if (transaction.reminderAt != null)
                              _buildDetailRow(
                                icon: Icons.alarm,
                                iconColor: Colors.teal,
                                label: 'Pengingat',
                                value: DateHelpers.dateTime.format(
                                  transaction.reminderAt!,
                                ),
                              ),
                            // Notes
                            if (transaction.notes != null &&
                                transaction.notes!.isNotEmpty) ...[
                              const Divider(height: 1),
                              _buildDetailRow(
                                icon: Icons.notes,
                                label: 'Catatan',
                                value: transaction.notes!,
                                maxLines: 3,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Photo preview
                      if (transaction.photoUrl != null &&
                          transaction.photoUrl!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  'Foto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: GestureDetector(
                                    onTap: () => _showPhotoViewer(
                                      context,
                                      transaction.photoUrl!,
                                    ),
                                    child: Image.network(
                                      transaction.photoUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _duplicateTransaction(context),
                                icon: const Icon(Icons.content_copy),
                                label: const Text('Duplikat'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  // TODO: Navigate to edit
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Edit akan segera hadir'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Delete Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteTransaction(context),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text(
                            'Hapus Transaksi',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: (iconColor ?? Colors.blue).withOpacity(0.1),
            radius: 20,
            child: Icon(icon, color: iconColor ?? Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build a small info chip used in the header section
  Widget _buildChip({
    required String label,
    required IconData icon,
    required Color color,
    bool lightOnDark = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: lightOnDark
            ? Colors.white.withOpacity(0.15)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: lightOnDark ? Colors.white24 : color.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: lightOnDark ? Colors.white : color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: lightOnDark ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }

  // Show photo fullscreen dialog
  void _showPhotoViewer(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Hero(
                  tag: url,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
