import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/cleanup_service.dart';
import '../services/notification_service.dart';
import '../services/export_service.dart';
import '../services/pdf_export_service.dart';
import 'premium/analytics_screen.dart';
import '../../utils/google_signout_helper.dart';

import 'premium/advanced_filter_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isPremium = false;
  bool _loading = true;
  bool _travelMode = false;

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
    _loadTravelMode();
  }

  Future<void> _loadPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final profileSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/profile/isPremium')
          .get();
      if (mounted) {
        setState(() {
          _isPremium = profileSnap.exists && profileSnap.value == true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadTravelMode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final travelModeSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/travelMode')
          .get();
      if (mounted) {
        setState(() {
          _travelMode = travelModeSnap.exists && travelModeSnap.value == true;
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _toggleTravelMode(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _travelMode = value);

    try {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/travelMode')
          .set(value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? '✈️ Mode Perjalanan/Acara diaktifkan'
                  : 'Mode Perjalanan/Acara dinonaktifkan',
            ),
            backgroundColor: value ? Colors.blue : Colors.grey,
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() => _travelMode = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengaturan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          // User Info Section
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? Text(
                                (user.displayName?.isNotEmpty == true
                                        ? user.displayName![0]
                                        : (user.email ?? 'U')[0])
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      // Premium Badge
                      if (_isPremium)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.displayName?.isNotEmpty == true
                        ? user.displayName!
                        : 'Pengguna',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? user.uid,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  if (_isPremium) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'PREMIUM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 0),
          ],

          // Menu Items
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profil Saya'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          // Keamanan PIN
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Keamanan PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/app-pin-settings');
            },
          ),

          // Premium Features Section
          if (_isPremium) ...[
            const Divider(height: 0),
            Container(
              color: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: const [
                  Icon(
                    Icons.workspace_premium,
                    size: 16,
                    color: Color(0xFFFF8C00),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'FITUR PREMIUM',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C00),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.file_download_outlined,
                color: Color(0xFFFF8C00),
              ),
              title: const Text('Export Data'),
              subtitle: const Text('Export ke Excel atau PDF'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showExportDialog(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.cloud_upload_outlined,
                color: Color(0xFFFF8C00),
              ),
              title: const Text('Backup Otomatis'),
              subtitle: const Text('Backup data ke cloud'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showBackupDialog(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.analytics_outlined,
                color: Color(0xFFFF8C00),
              ),
              title: const Text('Analisis Mendalam'),
              subtitle: const Text('Laporan keuangan detail'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAnalyticsDialog(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.filter_alt_outlined,
                color: Color(0xFFFF8C00),
              ),
              title: const Text('Filter Lanjutan'),
              subtitle: const Text('Filter transaksi dengan lebih detail'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAdvancedFilterDialog(context),
            ),
            const Divider(height: 0),
          ] else ...[
            const Divider(height: 0),
            ListTile(
              leading: const Icon(
                Icons.workspace_premium,
                color: Color(0xFFFFD700),
              ),
              title: const Text(
                'Upgrade ke Premium',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Dapatkan akses ke semua fitur premium'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showUpgradeDialog(context),
            ),
            const Divider(height: 0),
          ],

          // Sort: Kategori lebih dulu, lalu Acara
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Kategori'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/categories');
            },
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Atur Acara'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/events');
            },
          ),

          // Travel Mode Switch
          const Divider(height: 0),
          SwitchListTile(
            secondary: Icon(
              Icons.flight_takeoff_rounded,
              color: _travelMode ? Colors.blue : Colors.grey,
            ),
            title: const Text(
              'Mode Perjalanan/Acara',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _travelMode
                  ? 'Aktif - Transaksi akan ditandai dengan acara aktif'
                  : 'Nonaktif - Transaksi tidak akan dikaitkan dengan acara',
              style: const TextStyle(fontSize: 12),
            ),
            value: _travelMode,
            onChanged: _toggleTravelMode,
            activeColor: Colors.blue,
          ),
          const Divider(height: 0),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/about');
            },
          ),

          // Debug section
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'DEBUG',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          // App Check Debug removed per request
          ListTile(
            leading: const Icon(
              Icons.notifications_outlined,
              color: Colors.blue,
            ),
            title: const Text('Test Notifikasi'),
            subtitle: const Text(
              'Kirim notifikasi percobaan',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () => _testLocalNotification(context),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.deepPurple,
            ),
            title: const Text('Notifikasi Permanen'),
            subtitle: const Text(
              'Notifikasi yang tidak bisa dihapus',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              Navigator.of(context).pushNamed('/persistent-notifications');
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(
              Icons.cleaning_services_outlined,
              color: Colors.orange,
            ),
            title: const Text('Bersihkan Data Duplikat'),
            subtitle: const Text(
              'Hapus dompet duplikat',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () async {
              await _showCleanupDialog(context, user);
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Keluar', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Keluar dari akun?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await signOutGoogleIfNeeded();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close settings screen
                }
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showCleanupDialog(BuildContext context, User? user) async {
    if (user == null) return;

    final cleanupService = CleanupService();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Memeriksa data...'),
          ],
        ),
      ),
    );

    try {
      // Get stats first
      final stats = await cleanupService.getWalletStats(user.uid);

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      final duplicates = stats['duplicates'] as int;
      final totalWallets = stats['totalWallets'] as int;
      final walletsByName = stats['walletsByName'] as Map<String, int>;

      if (duplicates == 0) {
        // No duplicates found
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Data Bersih'),
              ],
            ),
            content: Text(
              'Tidak ada duplikat ditemukan.\n\nTotal dompet: $totalWallets',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Show duplicates and ask for confirmation
        final duplicateNames = walletsByName.entries
            .where((e) => e.value > 1)
            .map((e) => '• ${e.key}: ${e.value} dompet')
            .join('\n');

        if (!context.mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 12),
                Text('Duplikat Ditemukan'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ditemukan $duplicates dompet duplikat:\n'),
                Text(duplicateNames),
                const SizedBox(height: 16),
                const Text(
                  'Dompet terlama akan dipertahankan, duplikat akan dihapus.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Hapus Duplikat'),
              ),
            ],
          ),
        );

        if (confirm == true && context.mounted) {
          // Show loading again
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Menghapus duplikat...'),
                ],
              ),
            ),
          );

          try {
            final result = await cleanupService.removeDuplicateWallets(
              user.uid,
            );

            if (!context.mounted) return;
            Navigator.pop(context); // Close loading dialog

            // Show result
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Selesai'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dompet duplikat telah dihapus.'),
                    const SizedBox(height: 8),
                    Text('• Dihapus: ${result['deleted']}'),
                    Text('• Dipertahankan: ${result['kept']}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } catch (e) {
            if (!context.mounted) return;
            Navigator.pop(context); // Close loading dialog

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Gagal'),
                  ],
                ),
                content: Text('Gagal menghapus duplikat: $e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 12),
              Text('Error'),
            ],
          ),
          content: Text('Gagal memeriksa data: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _testLocalNotification(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    // Check and request notification permission first
    final permissionStatus = await _checkNotificationPermission(context);
    if (!permissionStatus) {
      return; // User cancelled or permission denied
    }

    // Show options dialog
    final testType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Notifikasi'),
        content: const Text('Pilih jenis notifikasi yang ingin di-test:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'simple'),
            child: const Text('Notifikasi Sederhana'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'reminder'),
            child: const Text('Pengingat Hutang'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'budget'),
            child: const Text('Peringatan Budget'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'transaction'),
            child: const Text('Transaksi Baru'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (testType == null) return;

    try {
      // 1. Create notification in Firebase
      await _notificationService.createTestNotification(user.uid, testType);

      // 2. Also send local notification
      await _sendLocalNotification(testType);

      // Show success dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Berhasil'),
              ],
            ),
            content: const Text(
              'Notifikasi test telah dikirim!\n\n'
              '✅ Tersimpan di Firebase (cek halaman Notifikasi)\n'
              '✅ Dikirim sebagai notifikasi lokal\n\n'
              'Periksa status bar atau panel notifikasi Anda.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Show error dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 12),
                Text('Error'),
              ],
            ),
            content: Text('Gagal mengirim notifikasi: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _sendLocalNotification(String testType) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Initialize plugin
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Setup notification details based on type
    AndroidNotificationDetails androidNotificationDetails;
    String title, body;

    switch (testType) {
      case 'simple':
        title = 'Money Tracker';
        body =
            'Test notifikasi berhasil! 🎉\nNotifikasi lokal berfungsi dengan baik.';
        androidNotificationDetails = const AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Channel untuk test notifikasi',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        );
        break;

      case 'reminder':
        title = 'Pengingat Hutang 💰';
        body =
            'Anda memiliki hutang yang jatuh tempo hari ini sebesar Rp 500.000 kepada John Doe';
        androidNotificationDetails = const AndroidNotificationDetails(
          'debt_reminder_channel',
          'Debt Reminders',
          channelDescription: 'Pengingat untuk hutang yang jatuh tempo',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFFF5722),
          ledColor: Color(0xFFFF5722),
          ledOnMs: 1000,
          ledOffMs: 500,
        );
        break;

      case 'budget':
        title = 'Peringatan Budget ⚠️';
        body =
            'Budget "Makanan" sudah mencapai 80%. Sisa: Rp 200.000 dari Rp 1.000.000';
        androidNotificationDetails = const AndroidNotificationDetails(
          'budget_warning_channel',
          'Budget Warnings',
          channelDescription: 'Peringatan ketika budget hampir habis',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFFFC107),
          styleInformation: BigTextStyleInformation(''),
        );
        break;

      case 'transaction':
        title = 'Transaksi Baru 💳';
        body =
            'Pengeluaran sebesar Rp 150.000 untuk "Makan Siang" telah ditambahkan';
        androidNotificationDetails = const AndroidNotificationDetails(
          'transaction_channel',
          'Transaction Notifications',
          channelDescription: 'Notifikasi untuk transaksi baru',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF4CAF50),
        );
        break;

      default:
        return;
    }

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    // Show notification
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
    );
  }

  Future<bool> _checkNotificationPermission(BuildContext context) async {
    // Check current permission status
    PermissionStatus status = await Permission.notification.status;

    if (status.isGranted) {
      return true;
    }

    // Show explanation dialog first
    if (context.mounted) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_outlined, color: Colors.blue),
              SizedBox(width: 12),
              Text('Izin Notifikasi'),
            ],
          ),
          content: const Text(
            'Aplikasi memerlukan izin notifikasi untuk mengirim pengingat dan peringatan.\n\n'
            'Izin ini diperlukan untuk:\n'
            '• Pengingat hutang jatuh tempo\n'
            '• Peringatan budget\n'
            '• Notifikasi transaksi penting',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Izinkan'),
            ),
          ],
        ),
      );

      if (shouldRequest != true) {
        return false;
      }
    }

    // Request permission
    status = await Permission.notification.request();

    if (status.isGranted) {
      return true;
    }

    // Permission denied, show dialog to go to settings
    if (context.mounted) {
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.orange),
              SizedBox(width: 12),
              Text('Izin Diperlukan'),
            ],
          ),
          content: const Text(
            'Izin notifikasi ditolak. Untuk menggunakan fitur notifikasi, '
            'silakan aktifkan izin notifikasi melalui pengaturan aplikasi.\n\n'
            'Langkah:\n'
            '1. Buka Pengaturan\n'
            '2. Pilih "Aplikasi" atau "Apps"\n'
            '3. Cari "Money Tracker"\n'
            '4. Tap "Izin" atau "Permissions"\n'
            '5. Aktifkan "Notifikasi"',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );

      if (goToSettings == true) {
        await openAppSettings();
      }
    }

    return false;
  }

  // Premium Features Methods
  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.file_download_outlined, color: Color(0xFFFF8C00)),
            SizedBox(width: 12),
            Text('Export Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pilih format export data:'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _exportToExcel(context);
              },
              icon: const Icon(Icons.table_chart),
              label: const Text('Export ke Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _exportToPDF(context);
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export ke PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Membuat file CSV/Excel...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final exportService = ExportService();
      final filePath = await exportService.exportToCSV(user.uid);

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        // Show success dialog with share option
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Export Berhasil!'),
              ],
            ),
            content: const Text(
              'File CSV berhasil dibuat dan dapat dibuka dengan Excel atau spreadsheet lainnya.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await exportService.shareFile(
                    filePath,
                    'MoneyTracker Export',
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.share),
                label: const Text('Bagikan'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportToPDF(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Membuat file PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final pdfService = PDFExportService();
      final filePath = await pdfService.generateTransactionReport(user.uid);

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        // Show success dialog with share option
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Export Berhasil!'),
              ],
            ),
            content: const Text('Laporan PDF berhasil dibuat dengan lengkap.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final exportService = ExportService();
                  await exportService.shareFile(
                    filePath,
                    'MoneyTracker Report',
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.share),
                label: const Text('Bagikan'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.cloud_upload_outlined, color: Color(0xFFFF8C00)),
            SizedBox(width: 12),
            Text('Backup Otomatis'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Data Anda sudah otomatis ter-backup di Firebase Cloud.'),
            SizedBox(height: 16),
            Text('✨ Backup otomatis real-time'),
            Text('✨ Data tersimpan aman di cloud'),
            Text('✨ Sinkronisasi antar device'),
            Text('✨ Login dari device lain untuk restore'),
            SizedBox(height: 16),
            Text(
              'Status: ✓ Aktif',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsDialog(BuildContext context) {
    // Navigate to Analytics Screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
    );
  }

  void _showAdvancedFilterDialog(BuildContext context) {
    // Navigate to Advanced Filter Screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdvancedFilterScreen()),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.workspace_premium, color: Color(0xFFFFD700)),
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
            SizedBox(height: 12),
            Text('✨ Export data ke Excel/PDF'),
            Text('✨ Backup otomatis ke cloud'),
            Text('✨ Analisis keuangan mendalam'),
            Text('✨ Filter transaksi lanjutan'),
            Text('✨ Kategori unlimited'),
            Text('✨ Tanpa iklan'),
            Text('✨ Badge premium eksklusif'),
            SizedBox(height: 16),
            Text(
              'Harga: Rp 49.000/bulan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF8C00),
              ),
            ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur upgrade akan segera tersedia!'),
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
  }
}
