import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/category.dart';
import '../models/wallet.dart';

class UserService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  // Realtime Database references
  DatabaseReference rtdbUser(String uid) => _rtdb.ref('users/$uid');
  DatabaseReference rtdbCategories(String uid) =>
      rtdbUser(uid).child('categories');
  DatabaseReference rtdbWallets(String uid) => rtdbUser(uid).child('wallets');
  DatabaseReference rtdbTransactions(String uid) =>
      rtdbUser(uid).child('transactions');

  Future<void> ensureUserInitialized(User user) async {
    try {
      // Keep minimal profile in RTDB
      final profileRef = rtdbUser(user.uid).child('profile');
      final snap = await profileRef.get();
      if (!snap.exists) {
        await profileRef.set({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Run defaults in background, don't wait
      _ensureDefaults(user.uid).catchError((e) {
        print('Error ensuring defaults: $e');
      });
    } catch (e) {
      print('Error in ensureUserInitialized: $e');
      // Don't throw, just continue
    }
  }

  Future<void> _ensureDefaults(String uid) async {
    final catsSnap = await rtdbCategories(uid).limitToFirst(1).get();
    if (!catsSnap.exists) {
      await _createDefaultCategories(uid);
    }
    // Backfill any newly added default categories for existing users
    await _backfillDefaultCategories(uid);

    // Only create default wallets if no wallets exist at all
    final walletsSnap = await rtdbWallets(uid).limitToFirst(1).get();
    if (!walletsSnap.exists) {
      await _createDefaultWallets(uid);
    }
  }

  Future<void> _backfillDefaultCategories(String uid) async {
    final catsRef = rtdbCategories(uid);
    final snap = await catsRef.get();
    final existing = <String>{};
    if (snap.exists && snap.value is Map) {
      final map = (snap.value as Map).cast<String, dynamic>();
      existing.addAll(map.keys);
    }
    final updates = <String, dynamic>{};
    for (final c in DefaultCategories.allCategories) {
      if (!existing.contains(c.id)) {
        updates['users/$uid/categories/${c.id}'] = c
            .copyWith(userId: uid, isDefault: true)
            .toMap();
      }
    }
    if (updates.isNotEmpty) {
      await _rtdb.ref().update(updates);
    }
  }

  Future<void> _createDefaultCategories(String uid) async {
    final updates = <String, dynamic>{};
    for (final c in DefaultCategories.allCategories) {
      updates['users/$uid/categories/${c.id}'] = c
          .copyWith(userId: uid, isDefault: true)
          .toMap();
    }
    await _rtdb.ref().update(updates);
  }

  Future<void> _createDefaultWallets(String uid) async {
    final now = DateTime.now();
    final cashRef = rtdbWallets(uid).push();
    final bankRef = rtdbWallets(uid).push();
    final cash = Wallet(
      id: cashRef.key!,
      name: 'Tunai',
      balance: 0.0,
      currency: 'IDR',
      icon: '💵',
      color: '#4CAF50',
      userId: uid,
      createdAt: now,
      updatedAt: now,
    ).toRtdbMap();
    final bank = Wallet(
      id: bankRef.key!,
      name: 'Bank',
      balance: 0.0,
      currency: 'IDR',
      icon: '🏦',
      color: '#1E88E5',
      userId: uid,
      createdAt: now,
      updatedAt: now,
    ).toRtdbMap();
    await Future.wait([cashRef.set(cash), bankRef.set(bank)]);
  }

  // Find user by email, username, or phone number
  Future<String?> findUserByIdentifier(String identifier) async {
    final cleanIdentifier = identifier.trim().toLowerCase();

    // Try to find by username first
    final usernameSnap = await _rtdb.ref('usernames/$cleanIdentifier').get();
    if (usernameSnap.exists) {
      return usernameSnap.value.toString();
    }

    // Try to find by email or phone
    final usersSnap = await _rtdb.ref('users').get();
    if (usersSnap.exists && usersSnap.value is Map) {
      final users = (usersSnap.value as Map).cast<String, dynamic>();
      for (final entry in users.entries) {
        final uid = entry.key;
        final userData = entry.value;
        if (userData is Map) {
          final profile = userData['profile'];
          if (profile is Map) {
            final email = profile['email']?.toString().toLowerCase();
            final phone = profile['phone']?.toString().trim();

            // Match by email
            if (email == cleanIdentifier) {
              return uid;
            }

            // Match by phone number (with or without +62 prefix)
            if (phone != null && phone.isNotEmpty) {
              // Normalize both input and stored phone number
              final normalizedInput = _normalizePhoneNumber(identifier.trim());
              final normalizedPhone = _normalizePhoneNumber(phone);

              if (normalizedInput == normalizedPhone) {
                return uid;
              }
            }
          }
        }
      }
    }

    return null;
  }

  // Normalize phone number for comparison
  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    String digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Remove leading country code if exists
    if (digitsOnly.startsWith('62')) {
      digitsOnly = digitsOnly.substring(2);
    }

    // Remove leading 0 if exists
    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }

    return digitsOnly;
  }

  // Get user display info
  Future<Map<String, String>?> getUserInfo(String uid) async {
    final snap = await _rtdb.ref('users/$uid/profile').get();
    if (!snap.exists) return null;

    if (snap.value is Map) {
      final profile = (snap.value as Map).cast<String, dynamic>();
      return {
        'displayName': profile['displayName']?.toString() ?? 'User',
        'email': profile['email']?.toString() ?? '',
        'username': profile['username']?.toString() ?? '',
      };
    }

    return null;
  }
}
