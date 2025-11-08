import 'package:firebase_database/firebase_database.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';
import '../utils/idr.dart';
import 'transaction_service.dart';
import 'notification_service.dart';

class WalletService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  DatabaseReference _wallets(String uid) => _rtdb.ref('users/$uid/wallets');

  Stream<List<Wallet>> streamWallets(String uid) {
    return _wallets(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Wallet>[];
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
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return wallets;
    });
  }

  Future<void> addWallet(String uid, Wallet wallet) async {
    await _wallets(uid).child(wallet.id).set(wallet.toRtdbMap());
  }

  Future<void> updateWallet(String uid, Wallet wallet) async {
    await _wallets(uid).child(wallet.id).update(wallet.toRtdbMap());
  }

  Future<bool> isAliasAvailable(
    String uid,
    String alias, {
    String? excludeWalletId,
  }) async {
    if (alias.trim().isEmpty) return true;
    final q = await _wallets(
      uid,
    ).orderByChild('alias').equalTo(alias.trim()).get();
    if (!q.exists) return true;
    if (q.value is Map) {
      final map = (q.value as Map).cast<String, dynamic>();
      // Available if only existing record is the excluded wallet id
      if (map.length == 1 &&
          excludeWalletId != null &&
          map.containsKey(excludeWalletId)) {
        return true;
      }
    }
    return false;
  }

  Future<String?> findWalletIdByAlias(String uid, String alias) async {
    final q = await _wallets(
      uid,
    ).orderByChild('alias').equalTo(alias.trim()).limitToFirst(1).get();
    if (!q.exists) return null;
    if (q.value is Map) {
      final map = (q.value as Map).cast<String, dynamic>();
      if (map.isNotEmpty) return map.keys.first;
    }
    return null;
  }

  Future<String?> getWalletName(String uid, String walletId) async {
    final snap = await _wallets(uid).child(walletId).child('name').get();
    if (!snap.exists) return null;
    return snap.value.toString();
  }

  Future<List<Map<String, String>>> getUserWallets(String uid) async {
    final snap = await _wallets(uid).get();
    final wallets = <Map<String, String>>[];

    if (snap.exists && snap.value is Map) {
      final walletsMap = (snap.value as Map).cast<String, dynamic>();
      for (final entry in walletsMap.entries) {
        final walletId = entry.key;
        final walletData = entry.value as Map;
        final walletName = walletData['name']?.toString() ?? 'Dompet';
        wallets.add({'id': walletId, 'name': walletName});
      }
    }

    return wallets;
  }

  Future<void> deleteWallet(String uid, String id) async {
    await _wallets(uid).child(id).remove();
  }

  Future<double?> getBalance(String uid, String walletId) async {
    final snap = await _wallets(uid).child(walletId).child('balance').get();
    if (!snap.exists) return null;
    final v = snap.value;
    return (v is num) ? v.toDouble() : double.tryParse(v.toString());
  }

  Future<void> adjustBalance(
    String uid,
    String walletId,
    double newBalance,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snap = await _wallets(uid).child(walletId).get();
    if (!snap.exists) throw StateError('Wallet not found');
    final w = Wallet.fromRtdb(
      walletId,
      (snap.value as Map).cast<dynamic, dynamic>(),
    );
    final delta = newBalance - w.balance;
    await _rtdb.ref().update({
      'users/$uid/wallets/$walletId/balance': newBalance,
      'users/$uid/wallets/$walletId/updatedAt': now,
    });
    // Log transaction if changed
    if (delta != 0) {
      final txService = TransactionService();
      final isIncome = delta > 0;
      final tx = TransactionModel(
        id: '',
        title: 'Penyesuaian Saldo',
        amount: delta.abs(),
        type: isIncome ? TransactionType.income : TransactionType.expense,
        categoryId: 'adjustment',
        walletId: walletId,
        toWalletId: null,
        date: DateTime.now(),
        notes:
            'Penyesuaian dari ${IdrFormatters.format(w.balance)} ke ${IdrFormatters.format(newBalance)}',
        photoUrl: null,
        userId: uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await txService.add(uid, tx);
    }
  }

  Future<void> transferWithinUser(
    String uid,
    String fromWalletId,
    String toWalletId,
    double amount,
  ) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be > 0');
    }
    if (fromWalletId == toWalletId) {
      throw ArgumentError('Wallets must differ');
    }

    final fromSnap = await _wallets(uid).child(fromWalletId).get();
    final toSnap = await _wallets(uid).child(toWalletId).get();
    if (!fromSnap.exists || !toSnap.exists) {
      throw StateError('Wallet not found');
    }
    final from = Wallet.fromRtdb(
      fromSnap.key!,
      (fromSnap.value as Map).cast<dynamic, dynamic>(),
    );
    final to = Wallet.fromRtdb(
      toSnap.key!,
      (toSnap.value as Map).cast<dynamic, dynamic>(),
    );

    // Hitung saldo riil dari transaksi
    final txService = TransactionService();
    final realBalance = await txService
        .streamWalletBalance(uid, fromWalletId)
        .first;

    if (realBalance < amount) {
      throw StateError(
        'Saldo tidak cukup (Saldo: ${realBalance.toStringAsFixed(0)})',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      'users/$uid/wallets/$fromWalletId/balance': (from.balance - amount),
      'users/$uid/wallets/$fromWalletId/updatedAt': now,
      'users/$uid/wallets/$toWalletId/balance': (to.balance + amount),
      'users/$uid/wallets/$toWalletId/updatedAt': now,
    };
    await _rtdb.ref().update(updates);

    // Log 2 transactions: satu untuk wallet pengirim, satu untuk wallet penerima
    // Supaya masing-masing wallet punya history transaksi

    // Transaksi di wallet pengirim (keluar) - EXPENSE
    final outTx = TransactionModel(
      id: '',
      title: 'Transfer ke ${to.name}',
      amount: amount,
      type: TransactionType.expense, // EXPENSE untuk pengeluaran
      categoryId: 'transfer_keluar',
      walletId: fromWalletId,
      toWalletId: toWalletId, // Simpan info tujuan transfer
      date: DateTime.now(),
      notes: 'Transfer ke ${to.name}',
      photoUrl: null,
      userId: uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Transaksi di wallet penerima (masuk) - INCOME
    final inTx = TransactionModel(
      id: '',
      title: 'Transfer dari ${from.name}',
      amount: amount,
      type: TransactionType.income, // INCOME untuk pemasukan
      categoryId: 'transfer_masuk',
      walletId: toWalletId,
      toWalletId: fromWalletId, // Simpan info asal transfer
      date: DateTime.now(),
      notes: 'Transfer dari ${from.name}',
      photoUrl: null,
      userId: uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Debug: Print transaksi yang akan disimpan
    print('=== TRANSFER DEBUG ===');
    print(
      'outTx: walletId=${outTx.walletId}, toWalletId=${outTx.toWalletId}, type=${outTx.type}, title=${outTx.title}',
    );
    print(
      'inTx: walletId=${inTx.walletId}, toWalletId=${inTx.toWalletId}, type=${inTx.type}, title=${inTx.title}',
    );

    // Simpan transaksi satu per satu dengan error handling
    try {
      print('=== SAVING outTx ===');
      await txService.add(uid, outTx);
      print('✓ outTx saved');
    } catch (e) {
      print('✗ Error saving outTx: $e');
      rethrow;
    }

    try {
      print('=== SAVING inTx ===');
      await txService.add(uid, inTx);
      print('✓ inTx saved');
    } catch (e) {
      print('✗ Error saving inTx: $e');
      rethrow;
    }

    print('=== BOTH TRANSACTIONS SAVED ===');
  }

  Future<void> transferAcrossUsers(
    String fromUid,
    String fromWalletId,
    String toUid,
    String toWalletId,
    double amount,
  ) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be > 0');
    }

    // Cek wallet exists
    final fromSnap = await _wallets(fromUid).child(fromWalletId).get();
    final toSnap = await _wallets(toUid).child(toWalletId).get();
    if (!fromSnap.exists || !toSnap.exists) {
      throw StateError('Wallet not found');
    }

    final from = Wallet.fromRtdb(
      fromSnap.key!,
      (fromSnap.value as Map).cast<dynamic, dynamic>(),
    );
    final to = Wallet.fromRtdb(
      toSnap.key!,
      (toSnap.value as Map).cast<dynamic, dynamic>(),
    );

    // Ambil info user untuk keterangan yang lebih jelas
    final fromUserSnap = await _rtdb.ref('users/$fromUid/profile').get();
    final toUserSnap = await _rtdb.ref('users/$toUid/profile').get();

    String fromUserInfo = 'User lain';
    String toUserInfo = 'User lain';

    if (fromUserSnap.exists) {
      final fromUserData = (fromUserSnap.value as Map).cast<dynamic, dynamic>();
      final username = fromUserData['username'] as String?;
      final email = fromUserData['email'] as String?;
      fromUserInfo = username != null && username.isNotEmpty
          ? '@$username'
          : email ?? 'User ${fromUid.substring(0, 6)}...';
    }

    if (toUserSnap.exists) {
      final toUserData = (toUserSnap.value as Map).cast<dynamic, dynamic>();
      final username = toUserData['username'] as String?;
      final email = toUserData['email'] as String?;
      toUserInfo = username != null && username.isNotEmpty
          ? '@$username'
          : email ?? 'User ${toUid.substring(0, 6)}...';
    }

    // Hitung saldo riil dari transaksi
    final txService = TransactionService();
    final realBalance = await txService
        .streamWalletBalance(fromUid, fromWalletId)
        .first;

    if (realBalance < amount) {
      throw StateError(
        'Saldo tidak cukup (Saldo: ${realBalance.toStringAsFixed(0)})',
      );
    }

    // Update balance di field wallet (untuk backup/reference)
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      'users/$fromUid/wallets/$fromWalletId/balance': (from.balance - amount),
      'users/$fromUid/wallets/$fromWalletId/updatedAt': now,
      'users/$toUid/wallets/$toWalletId/balance': (to.balance + amount),
      'users/$toUid/wallets/$toWalletId/updatedAt': now,
    };
    await _rtdb.ref().update(updates);

    // Log transactions for both users
    // txService sudah dibuat di atas untuk cek saldo

    // Untuk pengirim: transaksi transfer (keluar)
    final outTx = TransactionModel(
      id: '',
      title: 'Transfer ke $toUserInfo',
      amount: amount,
      type: TransactionType.transfer,
      categoryId: 'transfer',
      walletId: fromWalletId,
      toWalletId: toWalletId,
      date: DateTime.now(),
      notes: 'Dompet: ${to.name}',
      photoUrl: null,
      userId: fromUid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Untuk penerima: transaksi income (masuk)
    final inTx = TransactionModel(
      id: '',
      title: 'Transfer dari $fromUserInfo',
      amount: amount,
      type: TransactionType.income,
      categoryId: 'transfer_masuk',
      walletId: toWalletId,
      toWalletId: null,
      date: DateTime.now(),
      notes: 'Dompet: ${from.name}',
      photoUrl: null,
      userId: toUid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await Future.wait([
      txService.add(fromUid, outTx),
      txService.add(toUid, inTx),
    ]);

    // Send transfer notification to receiver
    final notificationService = NotificationService();
    await notificationService.createTransferNotification(
      receiverUid: toUid,
      amount: amount,
      senderName: fromUserInfo,
      transactionId: inTx.id, // Will be generated by transaction service
      walletName: to.name,
    );

    print('[TRANSFER] Notification sent to receiver: $toUid');
  }

  // Set a wallet as default and unset other wallets
  Future<void> setDefaultWallet(String uid, String walletId) async {
    // Get all wallets
    final snapshot = await _wallets(uid).get();
    if (!snapshot.exists) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{};

    // Unset all wallets first
    final data = snapshot.value as Map;
    final map = data.cast<String, dynamic>();
    for (final key in map.keys) {
      updates['users/$uid/wallets/$key/isDefault'] = false;
      updates['users/$uid/wallets/$key/updatedAt'] = now;
    }

    // Set the selected wallet as default
    updates['users/$uid/wallets/$walletId/isDefault'] = true;
    updates['users/$uid/wallets/$walletId/updatedAt'] = now;

    await _rtdb.ref().update(updates);
  }

  // Get the default wallet
  Future<Wallet?> getDefaultWallet(String uid) async {
    final snapshot = await _wallets(uid).get();
    if (!snapshot.exists) return null;

    final data = snapshot.value as Map;
    final map = data.cast<String, dynamic>();

    for (final entry in map.entries) {
      final walletData = (entry.value as Map).cast<dynamic, dynamic>();
      if (walletData['isDefault'] == true) {
        return Wallet.fromRtdb(entry.key, walletData);
      }
    }

    return null;
  }

  // Toggle exclude from total
  Future<void> toggleExcludeFromTotal(
    String uid,
    String walletId,
    bool exclude,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _rtdb.ref().update({
      'users/$uid/wallets/$walletId/excludeFromTotal': exclude,
      'users/$uid/wallets/$walletId/updatedAt': now,
    });
  }
}
