import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Transactions collection reference
  CollectionReference get transactionsCollection =>
      _db.collection('transactions');

  // Categories collection reference
  CollectionReference get categoriesCollection => _db.collection('categories');

  // Add a new transaction
  Future<void> addTransaction(TransactionModel transaction) async {
    await transactionsCollection.add(transaction.toMap());
  }

  // Update a transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    await transactionsCollection
        .doc(transaction.id)
        .update(transaction.toMap());
  }

  // Delete a transaction
  Future<void> deleteTransaction(String id) async {
    await transactionsCollection.doc(id).delete();
  }

  // Get all transactions stream
  Stream<List<TransactionModel>> getTransactionsStream() {
    return transactionsCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get transactions by date range
  Stream<List<TransactionModel>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) {
    return transactionsCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get transactions by type
  Stream<List<TransactionModel>> getTransactionsByType(TransactionType type) {
    return transactionsCollection
        .where('type', isEqualTo: type.toString().split('.').last)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList();
        });
  }

  // Calculate total income
  Future<double> getTotalIncome() async {
    final snapshot = await transactionsCollection
        .where('type', isEqualTo: 'income')
        .get();

    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data() as Map<String, dynamic>)['amount'] ?? 0;
    }
    return total;
  }

  // Calculate total expenses
  Future<double> getTotalExpenses() async {
    final snapshot = await transactionsCollection
        .where('type', isEqualTo: 'expense')
        .get();

    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data() as Map<String, dynamic>)['amount'] ?? 0;
    }
    return total;
  }

  // Get balance
  Future<double> getBalance() async {
    final income = await getTotalIncome();
    final expenses = await getTotalExpenses();
    return income - expenses;
  }
}
