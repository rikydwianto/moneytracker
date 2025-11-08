import 'package:firebase_database/firebase_database.dart';
import '../models/wallet.dart';

class CleanupService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  /// Remove duplicate wallets with the same name for a user
  /// Keeps the oldest wallet (by createdAt) and removes duplicates
  Future<Map<String, dynamic>> removeDuplicateWallets(String uid) async {
    final walletsRef = _rtdb.ref('users/$uid/wallets');
    final snapshot = await walletsRef.get();

    if (!snapshot.exists) {
      return {'success': true, 'message': 'No wallets found', 'removed': 0};
    }

    final data = snapshot.value as Map;
    final wallets = <Wallet>[];

    // Parse all wallets
    data.forEach((key, value) {
      try {
        final wallet = Wallet.fromRtdb(
          key,
          (value as Map).cast<dynamic, dynamic>(),
        );
        wallets.add(wallet);
      } catch (e) {
        print('Error parsing wallet $key: $e');
      }
    });

    // Group by name (case-insensitive)
    final walletsByName = <String, List<Wallet>>{};
    for (final wallet in wallets) {
      final key = wallet.name.toLowerCase().trim();
      walletsByName.putIfAbsent(key, () => []).add(wallet);
    }

    // Find and remove duplicates
    final toRemove = <String>[];
    int removedCount = 0;

    walletsByName.forEach((name, walletsWithSameName) {
      if (walletsWithSameName.length > 1) {
        // Sort by createdAt, keep the oldest
        walletsWithSameName.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        print('Found ${walletsWithSameName.length} wallets named "$name"');
        print(
          'Keeping: ${walletsWithSameName.first.id} (created: ${walletsWithSameName.first.createdAt})',
        );

        // Mark all except the first (oldest) for removal
        for (int i = 1; i < walletsWithSameName.length; i++) {
          toRemove.add(walletsWithSameName[i].id);
          print(
            'Removing duplicate: ${walletsWithSameName[i].id} (created: ${walletsWithSameName[i].createdAt})',
          );
        }
      }
    });

    // Remove duplicates
    if (toRemove.isNotEmpty) {
      final updates = <String, dynamic>{};
      for (final id in toRemove) {
        updates['users/$uid/wallets/$id'] = null;
      }

      await _rtdb.ref().update(updates);
      removedCount = toRemove.length;
    }

    return {
      'success': true,
      'message': removedCount > 0
          ? 'Removed $removedCount duplicate wallet(s)'
          : 'No duplicates found',
      'removed': removedCount,
      'duplicateWalletIds': toRemove,
    };
  }

  /// Get statistics about current wallets
  Future<Map<String, dynamic>> getWalletStats(String uid) async {
    final walletsRef = _rtdb.ref('users/$uid/wallets');
    final snapshot = await walletsRef.get();

    if (!snapshot.exists) {
      return {
        'totalWallets': 0,
        'uniqueNames': 0,
        'duplicates': 0,
        'walletsByName': <String, int>{},
      };
    }

    final data = snapshot.value as Map;
    final wallets = <Wallet>[];

    data.forEach((key, value) {
      try {
        final wallet = Wallet.fromRtdb(
          key,
          (value as Map).cast<dynamic, dynamic>(),
        );
        wallets.add(wallet);
      } catch (e) {
        print('Error parsing wallet $key: $e');
      }
    });

    // Count by name
    final nameCount = <String, int>{};
    for (final wallet in wallets) {
      final key = wallet.name.toLowerCase().trim();
      nameCount[key] = (nameCount[key] ?? 0) + 1;
    }

    final duplicates = nameCount.values.where((count) => count > 1).length;

    return {
      'totalWallets': wallets.length,
      'uniqueNames': nameCount.length,
      'duplicates': duplicates,
      'walletsByName': nameCount,
      'walletList': wallets
          .map(
            (w) => {
              'id': w.id,
              'name': w.name,
              'balance': w.balance,
              'alias': w.alias,
              'createdAt': w.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };
  }
}
