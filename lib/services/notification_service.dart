import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  bool _initialized = false;

  DatabaseReference _userNotificationsRef(String uid) =>
      _database.ref('users/$uid/notifications');

  // Create notification
  Future<void> createNotification({
    required String uid,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    final ref = _userNotificationsRef(uid).push();
    final notification = NotificationModel(
      id: ref.key!,
      title: title,
      message: message,
      type: type,
      isRead: false,
      relatedId: relatedId,
      data: data,
      createdAt: DateTime.now(),
    );

    await ref.set(notification.toMap());
  }

  // Get all notifications for user
  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _userNotificationsRef(uid).orderByChild('createdAt').onValue.map((
      event,
    ) {
      if (!event.snapshot.exists) return <NotificationModel>[];

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final notifications = data.entries
          .map(
            (entry) => NotificationModel.fromMap(
              entry.key as String,
              entry.value as Map<dynamic, dynamic>,
            ),
          )
          .toList();

      // Sort by newest first
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  // Mark notification as read
  Future<void> markAsRead(String uid, String notificationId) async {
    await _userNotificationsRef(
      uid,
    ).child(notificationId).child('isRead').set(true);
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String uid) async {
    final snapshot = await _userNotificationsRef(uid).get();
    if (!snapshot.exists) return;

    final updates = <String, dynamic>{};
    final data = snapshot.value as Map<dynamic, dynamic>;

    for (final entry in data.entries) {
      updates['users/$uid/notifications/${entry.key}/isRead'] = true;
    }

    if (updates.isNotEmpty) {
      await _database.ref().update(updates);
    }
  }

  // Delete notification
  Future<void> deleteNotification(String uid, String notificationId) async {
    await _userNotificationsRef(uid).child(notificationId).remove();
  }

  // Delete all notifications
  Future<void> deleteAllNotifications(String uid) async {
    await _userNotificationsRef(uid).remove();
  }

  // Get unread count
  Stream<int> streamUnreadCount(String uid) {
    return _userNotificationsRef(
      uid,
    ).orderByChild('isRead').equalTo(false).onValue.map((event) {
      if (!event.snapshot.exists) return 0;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.length;
    });
  }

  // Create test notifications
  Future<void> createTestNotification(String uid, String type) async {
    switch (type) {
      case 'simple':
        await createNotification(
          uid: uid,
          title: 'Test Notifikasi',
          message:
              'Ini adalah test notifikasi sederhana. Sistem notifikasi berfungsi dengan baik! 🎉',
          type: 'test',
        );
        break;

      case 'reminder':
        await createNotification(
          uid: uid,
          title: 'Pengingat Hutang 💰',
          message:
              'Anda memiliki hutang yang jatuh tempo hari ini sebesar Rp 500.000 kepada John Doe',
          type: 'debt_reminder',
          relatedId: 'debt_123',
          data: {
            'amount': 500000,
            'counterparty': 'John Doe',
            'dueDate': DateTime.now().toIso8601String(),
          },
        );
        break;

      case 'budget':
        await createNotification(
          uid: uid,
          title: 'Peringatan Budget ⚠️',
          message:
              'Budget "Makanan" sudah mencapai 80%. Sisa: Rp 200.000 dari Rp 1.000.000',
          type: 'budget_warning',
          relatedId: 'budget_food',
          data: {
            'categoryName': 'Makanan',
            'percentage': 80,
            'remaining': 200000,
            'total': 1000000,
          },
        );
        break;

      case 'transaction':
        await createNotification(
          uid: uid,
          title: 'Transaksi Baru 💳',
          message:
              'Pengeluaran sebesar Rp 150.000 untuk "Makan Siang" telah ditambahkan',
          type: 'transaction_added',
          relatedId: 'transaction_456',
          data: {'amount': 150000, 'title': 'Makan Siang', 'type': 'expense'},
        );
        break;
    }
  }

  // Create reminder notifications (called by background service)
  Future<void> createDebtReminders(String uid) async {
    // This would be called by a background service to check for due debts
    // For now, we'll create a sample reminder
    await createNotification(
      uid: uid,
      title: 'Pengingat Otomatis 🔔',
      message: 'Sistem telah memeriksa hutang yang jatuh tempo',
      type: 'auto_reminder',
    );
  }

  // Transfer notification - called when user receives transfer
  Future<void> createTransferNotification({
    required String receiverUid,
    required double amount,
    required String senderName,
    required String transactionId,
    required String walletName,
  }) async {
    await createNotification(
      uid: receiverUid,
      title: 'Transfer Diterima',
      message:
          'Anda menerima transfer sebesar ${_formatAmount(amount)} dari $senderName ke wallet $walletName.',
      type: 'transfer_received',
      relatedId: transactionId,
      data: {
        'amount': amount,
        'senderName': senderName,
        'transactionId': transactionId,
        'walletName': walletName,
        'action': 'view_transaction',
      },
    );

    // Removed verbose transfer notification prints
  }

  // Event notification - called when event is activated/deactivated
  Future<void> createEventNotification({
    required String uid,
    required String eventName,
    required String action, // 'activated' or 'deactivated'
    String? eventId,
  }) async {
    final message = action == 'activated'
        ? 'Acara "$eventName" telah diaktifkan. Transaksi baru akan terkait dengan acara ini.'
        : 'Acara "$eventName" telah dinonaktifkan.';

    await createNotification(
      uid: uid,
      title: 'Acara ${action == 'activated' ? 'Aktif' : 'Nonaktif'}',
      message: message,
      type: 'event_toggle',
      relatedId: eventId,
      data: {'eventName': eventName, 'action': action, 'eventId': eventId},
    );

    // Removed verbose event notification print
  }

  // Format amount helper
  String _formatAmount(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // ========== PERSISTENT NOTIFICATION (TIDAK BISA DIHAPUS) ==========

  /// Initialize local notifications (Android & iOS only; web skipped gracefully)
  Future<void> initializeLocalNotifications() async {
    if (kIsWeb) {
      // flutter_local_notifications tidak mendukung web; kita lewati supaya tidak error.
      _initialized = true; // tandai supaya tidak inisialisasi ulang
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Primary tap payload
        if (response.payload == 'add_transaction' ||
            response.actionId == 'add_transaction') {
          navKey.currentState?.pushNamed('/add-transaction');
        }
        // Refresh total balance action
        if (response.actionId == 'refresh_total_balance') {
          final total = await _computeTotalBalance();
          await showTotalBalancePersistent(
            totalBalance: total,
            currency: 'IDR',
          );
        }
        debugPrint(
          '[NOTIFICATION] interaction payload=${response.payload} action=${response.actionId}',
        );
      },
    );
    _initialized = true;
  }

  /// Show persistent notification (tidak bisa dihapus oleh user)
  /// Cocok untuk: Budget monitoring, Debt reminders, Event tracking
  Future<void> showPersistentNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (kIsWeb) {
      // Web tidak didukung; cukup abaikan pemanggilan supaya tidak crash.
      return;
    }
    final androidDetails = AndroidNotificationDetails(
      'persistent_channel', // Channel ID
      'Persistent Notifications', // Channel name
      channelDescription: 'Notifikasi penting yang tidak bisa dihapus',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true, // Tidak bisa di-swipe
      autoCancel: false,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFF8C00),
      styleInformation: const BigTextStyleInformation(''),
      actions: actions,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Show persistent total balance notification with add button semantics
  Future<void> showTotalBalancePersistent({
    required double totalBalance,
    required String currency,
  }) async {
    if (kIsWeb) {
      // Skip on web; bisa diganti dengan in-app banner di masa depan.
      return;
    }
    final formatted = _formatAmount(totalBalance);
    await showPersistentNotification(
      id: 2001,
      title: '💼 Total Saldo',
      body: '$formatted $currency',
      payload: 'add_transaction', // tap on body adds transaction
      actions: const [
        AndroidNotificationAction(
          'add_transaction',
          'Tambah',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'refresh_total_balance',
          'Refresh',
          cancelNotification: false,
        ),
      ],
    );
  }

  Future<double> _computeTotalBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    try {
      // Determine excluded wallet IDs (excludeFromTotal or type == 'savings')
      final walletsSnap = await _database
          .ref('users/${user.uid}/wallets')
          .get();
      final excludeWalletIds = <String>{};
      if (walletsSnap.exists && walletsSnap.value is Map) {
        final wmap = (walletsSnap.value as Map).cast<String, dynamic>();
        for (final entry in wmap.entries) {
          final m = (entry.value as Map).cast<dynamic, dynamic>();
          final exclude = (m['excludeFromTotal'] ?? false) as bool;
          final type = m['type'] as String? ?? 'regular';
          if (exclude || type == 'savings') excludeWalletIds.add(entry.key);
        }
      }

      // Compute total based on transactions, excluding above wallets
      final txSnap = await _database
          .ref('users/${user.uid}/transactions')
          .get();
      if (!txSnap.exists || txSnap.value == null) return 0;
      final map = (txSnap.value as Map).cast<String, dynamic>();
      final Map<String, double> walletBalances = {};
      for (final entry in map.entries) {
        final m = (entry.value as Map).cast<dynamic, dynamic>();
        final walletId = (m['walletId'] ?? '') as String;
        if (walletId.isEmpty) continue;
        if (excludeWalletIds.contains(walletId)) continue;
        final type = (m['type'] ?? 'expense') as String;
        final amtNum = (m['amount'] ?? 0);
        final amount = (amtNum is num) ? amtNum.toDouble() : 0.0;
        walletBalances.putIfAbsent(walletId, () => 0.0);
        if (type == 'income') {
          walletBalances[walletId] = walletBalances[walletId]! + amount;
        } else if (type == 'expense' || type == 'debt' || type == 'transfer') {
          walletBalances[walletId] = walletBalances[walletId]! - amount;
        }
      }

      double total = 0.0;
      for (final v in walletBalances.values) {
        total += v;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Refresh total balance notification automatically if user enabled it in settings
  Future<void> refreshTotalBalanceIfEnabled() async {
    try {
      if (!_initialized) {
        await initializeLocalNotifications();
      }
      if (kIsWeb) return; // Tidak ada persistent notification di web
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final enabledSnap = await _database
          .ref('users/${user.uid}/settings/persistentTotalBalanceEnabled')
          .get();
      final enabled = (enabledSnap.value == true);
      if (!enabled) return;

      final total = await _computeTotalBalance();
      await showTotalBalancePersistent(totalBalance: total, currency: 'IDR');
    } catch (e) {
      // ignore
    }
  }

  /// Show persistent notification with progress bar
  /// Cocok untuk: Budget progress, Savings progress
  Future<void> showPersistentProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress, // 0-100
    required int maxProgress,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'persistent_progress_channel',
      'Progress Notifications',
      channelDescription: 'Notifikasi progress yang tidak bisa dihapus',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFF8C00),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Remove persistent notification
  Future<void> removePersistentNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Show Budget Monitor (Persistent)
  Future<void> showBudgetMonitor({
    required String categoryName,
    required double spent,
    required double total,
  }) async {
    final percentage = ((spent / total) * 100).round();
    final remaining = total - spent;

    String emoji = '💚';
    if (percentage >= 90)
      emoji = '🔴';
    else if (percentage >= 75)
      emoji = '🟡';
    else if (percentage >= 50)
      emoji = '🟠';

    await showPersistentProgressNotification(
      id: 1001, // Budget monitor ID
      title: '$emoji Budget Monitor: $categoryName',
      body:
          'Terpakai: ${_formatAmount(spent)} • Sisa: ${_formatAmount(remaining)}',
      progress: percentage,
      maxProgress: 100,
      payload: 'budget_monitor',
    );
  }

  /// Show Debt Reminder (Persistent)
  Future<void> showDebtReminder({
    required String creditorName,
    required double amount,
    required DateTime dueDate,
  }) async {
    final daysLeft = dueDate.difference(DateTime.now()).inDays;
    String message;

    if (daysLeft < 0) {
      message = '⚠️ TERLAMBAT ${daysLeft.abs()} hari!';
    } else if (daysLeft == 0) {
      message = '⚠️ JATUH TEMPO HARI INI!';
    } else {
      message = 'Jatuh tempo dalam $daysLeft hari';
    }

    await showPersistentNotification(
      id: 1002, // Debt reminder ID
      title: '💰 Hutang ke $creditorName',
      body: '${_formatAmount(amount)} • $message',
      payload: 'debt_reminder',
    );
  }

  /// Show Active Event Tracker (Persistent)
  Future<void> showActiveEventTracker({
    required String eventName,
    required int transactionCount,
    required double totalSpent,
  }) async {
    await showPersistentNotification(
      id: 1003, // Event tracker ID
      title: '🎉 Acara Aktif: $eventName',
      body: '$transactionCount transaksi • Total: ${_formatAmount(totalSpent)}',
      payload: 'event_tracker',
    );
  }

  /// Show Savings Goal Tracker (Persistent)
  Future<void> showSavingsGoalTracker({
    required String goalName,
    required double current,
    required double target,
  }) async {
    final percentage = ((current / target) * 100).round();
    final remaining = target - current;

    await showPersistentProgressNotification(
      id: 1004, // Savings goal ID
      title: '🎯 Target: $goalName',
      body:
          'Terkumpul: ${_formatAmount(current)} • Sisa: ${_formatAmount(remaining)}',
      progress: percentage,
      maxProgress: 100,
      payload: 'savings_goal',
    );
  }

  /// Show Daily Spending Limit (Persistent)
  Future<void> showDailySpendingLimit({
    required double spent,
    required double limit,
  }) async {
    final percentage = ((spent / limit) * 100).round();
    final remaining = limit - spent;

    String emoji = '✅';
    if (percentage >= 100)
      emoji = '🚫';
    else if (percentage >= 80)
      emoji = '⚠️';

    await showPersistentProgressNotification(
      id: 1005, // Daily limit ID
      title: '$emoji Batas Harian',
      body:
          'Terpakai: ${_formatAmount(spent)} • Sisa: ${_formatAmount(remaining)}',
      progress: percentage > 100 ? 100 : percentage,
      maxProgress: 100,
      payload: 'daily_limit',
    );
  }

  /// Remove all persistent notifications
  Future<void> removeAllPersistentNotifications() async {
    // Remove all predefined persistent notification IDs
    for (int id = 1001; id <= 1005; id++) {
      await _localNotifications.cancel(id);
    }
    await _localNotifications.cancel(2001); // total balance notification
  }
}
