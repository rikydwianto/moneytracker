import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/transaction_service.dart';

class PersistentNotificationScreen extends StatefulWidget {
  const PersistentNotificationScreen({super.key});

  @override
  State<PersistentNotificationScreen> createState() =>
      _PersistentNotificationScreenState();
}

class _PersistentNotificationScreenState
    extends State<PersistentNotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _totalBalanceActive = false;
  double? _latestTotal;
  bool _loadingAuto = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initializeLocalNotifications();
    // Optionally fetch initial total balance
    await _fetchTotalBalance();
    // Auto refresh on enter if previously enabled
    await _autoRefreshIfEnabled();
  }

  Future<void> _fetchTotalBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Build exclude wallet ids like HomeScreen (excludeFromTotal or type='savings')
      final walletsSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/wallets')
          .get();
      final excludeWalletIds = <String>[];
      if (walletsSnap.exists && walletsSnap.value is Map) {
        final wmap = (walletsSnap.value as Map).cast<String, dynamic>();
        for (final entry in wmap.entries) {
          final m = (entry.value as Map).cast<dynamic, dynamic>();
          final exclude = (m['excludeFromTotal'] ?? false) as bool;
          final type = m['type'] as String? ?? 'regular';
          if (exclude || type == 'savings') excludeWalletIds.add(entry.key);
        }
      }
      final stream = TransactionService().streamTotalBalance(
        user.uid,
        excludeWalletIds: excludeWalletIds.isEmpty ? null : excludeWalletIds,
      );
      final total = await stream.first;
      if (!mounted) return;
      setState(() => _latestTotal = total);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _autoRefreshIfEnabled() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final enabledSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/persistentTotalBalanceEnabled')
          .get();
      final enabled = enabledSnap.value == true;
      if (!enabled) return;
      setState(() {
        _totalBalanceActive = true;
        _loadingAuto = true;
      });
      await _fetchTotalBalance();
      final total = _latestTotal ?? 0;
      await _notificationService.showTotalBalancePersistent(
        totalBalance: total,
        currency: 'IDR',
      );
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingAuto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi Permanen'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifikasi permanen akan tetap tampil di notification bar dan tidak bisa dihapus oleh user sampai Anda menonaktifkannya.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Total Saldo Card (custom layout as requested)
          _buildTotalSaldoCard(),

          const SizedBox(height: 24),

          // Remove All Button
          OutlinedButton.icon(
            onPressed: () async {
              await _notificationService.removeAllPersistentNotifications();
              setState(() {
                _totalBalanceActive = false;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifikasi saldo total dihapus'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Hapus Notifikasi Saldo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSaldoCard() {
    final totalDisplay = _formatCurrency(_latestTotal ?? 0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Total Saldo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                if (_totalBalanceActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Aktif',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Tambah Transaksi',
                  onPressed: () {
                    Navigator.of(context).pushNamed('/add-transaction');
                  },
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              totalDisplay,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loadingAuto
                      ? null
                      : () async {
                          await _fetchTotalBalance();
                          if (_totalBalanceActive) {
                            final total = _latestTotal ?? 0;
                            await _notificationService
                                .showTotalBalancePersistent(
                                  totalBalance: total,
                                  currency: 'IDR',
                                );
                          }
                        },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: _loadingAuto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Refresh Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final newValue = !_totalBalanceActive;
                      setState(() => _totalBalanceActive = newValue);
                      if (newValue) {
                        await _fetchTotalBalance();
                        final total = _latestTotal ?? 0;
                        await _notificationService.showTotalBalancePersistent(
                          totalBalance: total,
                          currency: 'IDR',
                        );
                        // Persist enabled state
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          FirebaseDatabase.instance
                              .ref(
                                'users/${user.uid}/settings/persistentTotalBalanceEnabled',
                              )
                              .set(true);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Notifikasi saldo total aktif'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        }
                      } else {
                        await _notificationService.removePersistentNotification(
                          2001,
                        );
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          FirebaseDatabase.instance
                              .ref(
                                'users/${user.uid}/settings/persistentTotalBalanceEnabled',
                              )
                              .set(false);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _totalBalanceActive
                                ? Icons.toggle_on
                                : Icons.toggle_off_outlined,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _totalBalanceActive
                                ? 'Matikan Notifikasi'
                                : 'Aktifkan Notifikasi',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    // Simple Indonesian Rupiah formatting without intl dependency
    final intVal = value.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final reverseIndex = str.length - i - 1;
      buffer.write(str[i]);
      final posFromEnd = reverseIndex;
      if (posFromEnd > 0 && posFromEnd % 3 == 0) buffer.write('.');
    }
    return 'Rp$buffer';
  }

  // Removed old demo methods for other persistent notifications
}
