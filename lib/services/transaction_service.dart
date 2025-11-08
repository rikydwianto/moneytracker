import 'package:firebase_database/firebase_database.dart';
import '../models/transaction.dart';

class TransactionService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  DatabaseReference _txRef(String uid) => _rtdb.ref('users/$uid/transactions');

  Future<String> add(String uid, TransactionModel tx) async {
    print(
      'TransactionService.add: uid=$uid, walletId=${tx.walletId}, type=${tx.type}, title=${tx.title}',
    );
    final ref = _txRef(uid).push();
    final withId = tx.copyWith(id: ref.key!);
    print('Generated transaction ID: ${ref.key}');
    final data = withId.toRtdbMap();
    print('Data to save: $data');
    await ref.set(data);
    print('Transaction saved successfully');

    // Verifikasi: baca kembali data yang baru disimpan
    final snapshot = await ref.get();
    if (snapshot.exists) {
      print('✓ Verification: Transaction exists in Firebase');
      print('  Data: ${snapshot.value}');
    } else {
      print('✗ WARNING: Transaction not found after save!');
    }

    return ref.key!;
  }

  Future<void> update(String uid, TransactionModel tx) async {
    await _txRef(uid).child(tx.id).update(tx.toRtdbMap());
  }

  Future<void> delete(String uid, String txId) async {
    await _txRef(uid).child(txId).remove();
  }

  Stream<List<TransactionModel>> streamByMonth(String uid, DateTime month) {
    final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    final end = DateTime(
      month.year,
      month.month + 1,
      0,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;
    return _txRef(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <TransactionModel>[];
      final map = (data as Map).cast<String, dynamic>();
      final list = <TransactionModel>[];
      map.forEach((key, value) {
        final m = (value as Map).cast<dynamic, dynamic>();
        final t = TransactionModel.fromRtdb(key, m);
        final ts = t.date.millisecondsSinceEpoch;
        if (ts >= start && ts <= end) {
          list.add(t);
        }
      });
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // Hitung balance wallet berdasarkan transaksi real
  Stream<double> streamWalletBalance(String uid, String walletId) {
    return _txRef(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return 0.0;

      final map = (data as Map).cast<String, dynamic>();
      double balance = 0.0;

      map.forEach((key, value) {
        final m = (value as Map).cast<dynamic, dynamic>();
        final t = TransactionModel.fromRtdb(key, m);

        // Hanya proses transaksi yang walletId-nya sesuai
        if (t.walletId == walletId) {
          if (t.type == TransactionType.income) {
            // Pemasukan (termasuk transfer masuk dari wallet lain)
            balance += t.amount;
          } else if (t.type == TransactionType.expense) {
            // Pengeluaran
            balance -= t.amount;
          } else if (t.type == TransactionType.debt) {
            // Hutang
            balance -= t.amount;
          } else if (t.type == TransactionType.transfer) {
            // Transfer keluar ke wallet lain
            balance -= t.amount;
          }
        }
      });

      return balance;
    });
  }

  // Hitung total balance semua wallet berdasarkan transaksi real
  Stream<double> streamTotalBalance(
    String uid, {
    List<String>? excludeWalletIds,
  }) {
    return _txRef(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return 0.0;

      final map = (data as Map).cast<String, dynamic>();
      final Map<String, double> walletBalances = {};

      map.forEach((key, value) {
        final m = (value as Map).cast<dynamic, dynamic>();
        final t = TransactionModel.fromRtdb(key, m);

        // Skip jika wallet di-exclude
        if (excludeWalletIds != null && excludeWalletIds.contains(t.walletId)) {
          return;
        }

        // Initialize balance if not exists
        if (!walletBalances.containsKey(t.walletId)) {
          walletBalances[t.walletId] = 0.0;
        }

        // Proses berdasarkan tipe transaksi di wallet ini
        if (t.type == TransactionType.income) {
          walletBalances[t.walletId] = walletBalances[t.walletId]! + t.amount;
        } else if (t.type == TransactionType.expense) {
          walletBalances[t.walletId] = walletBalances[t.walletId]! - t.amount;
        } else if (t.type == TransactionType.debt) {
          walletBalances[t.walletId] = walletBalances[t.walletId]! - t.amount;
        } else if (t.type == TransactionType.transfer) {
          // Transfer keluar dari wallet ini
          walletBalances[t.walletId] = walletBalances[t.walletId]! - t.amount;
        }
      });

      // Sum all balances
      return walletBalances.values.fold(0.0, (sum, balance) => sum + balance);
    });
  }

  // Stream semua transaksi user
  Stream<List<TransactionModel>> streamTransactions(String uid) {
    return _txRef(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <TransactionModel>[];

      final map = (data as Map).cast<String, dynamic>();
      final list = <TransactionModel>[];

      map.forEach((key, value) {
        final m = (value as Map).cast<dynamic, dynamic>();
        final t = TransactionModel.fromRtdb(key, m);
        list.add(t);
      });

      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
}
