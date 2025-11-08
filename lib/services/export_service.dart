import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  final _database = FirebaseDatabase.instance;

  // Export to CSV (compatible with Excel)
  Future<String> exportToCSV(String userId) async {
    try {
      // Get all transactions
      final snapshot = await _database.ref('users/$userId/transactions').get();

      if (!snapshot.exists) {
        throw Exception('Tidak ada data transaksi');
      }

      final transactionsMap = (snapshot.value as Map).cast<String, dynamic>();
      final List<List<dynamic>> rows = [];

      // Header
      rows.add([
        'Tanggal',
        'Judul',
        'Tipe',
        'Kategori',
        'Dompet',
        'Jumlah',
        'Catatan',
        'Event',
      ]);

      // Get categories and wallets for names
      final categoriesSnapshot = await _database
          .ref('users/$userId/categories')
          .get();
      final walletsSnapshot = await _database
          .ref('users/$userId/wallets')
          .get();
      final eventsSnapshot = await _database.ref('users/$userId/events').get();

      final categories = categoriesSnapshot.exists
          ? (categoriesSnapshot.value as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final wallets = walletsSnapshot.exists
          ? (walletsSnapshot.value as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final events = eventsSnapshot.exists
          ? (eventsSnapshot.value as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      // Add data rows
      for (final entry in transactionsMap.entries) {
        final data = entry.value as Map;

        String categoryName = 'Tidak Ada';
        if (data['categoryId'] != null &&
            categories[data['categoryId']] != null) {
          categoryName = categories[data['categoryId']]['name'] ?? 'Tidak Ada';
        }

        String walletName = 'Tidak Ada';
        if (data['walletId'] != null && wallets[data['walletId']] != null) {
          walletName = wallets[data['walletId']]['name'] ?? 'Tidak Ada';
        }

        String eventName = '';
        if (data['eventId'] != null && events[data['eventId']] != null) {
          eventName = events[data['eventId']]['name'] ?? '';
        }

        final amount = (data['amount'] ?? 0).toDouble();
        final formattedAmount = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(amount);

        rows.add([
          DateFormat(
            'dd/MM/yyyy HH:mm',
          ).format(DateTime.parse(data['date'] ?? DateTime.now().toString())),
          data['title'] ?? 'Transaksi',
          data['type'] == 'expense' ? 'Pengeluaran' : 'Pemasukan',
          categoryName,
          walletName,
          formattedAmount,
          data['notes'] ?? '',
          eventName,
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/MoneyTracker_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);

      return path;
    } catch (e) {
      throw Exception('Gagal export data: $e');
    }
  }

  // Share exported file
  Future<void> shareFile(String filePath, String title) async {
    await Share.shareXFiles([XFile(filePath)], text: title);
  }

  // Get transactions summary for reports
  Future<Map<String, dynamic>> getTransactionsSummary(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId/transactions').get();

      if (!snapshot.exists) {
        return {
          'totalIncome': 0.0,
          'totalExpense': 0.0,
          'balance': 0.0,
          'transactionCount': 0,
          'categoryBreakdown': <String, double>{},
          'monthlyTrend': <String, double>{},
        };
      }

      final transactionsMap = (snapshot.value as Map).cast<String, dynamic>();
      double totalIncome = 0;
      double totalExpense = 0;
      int count = 0;
      Map<String, double> categoryBreakdown = {};
      Map<String, double> monthlyTrend = {};

      for (final entry in transactionsMap.entries) {
        final data = entry.value as Map;
        final amount = (data['amount'] ?? 0).toDouble();
        final type = data['type'] ?? 'expense';
        final categoryId = data['categoryId'] as String?;
        final date = DateTime.parse(data['date'] ?? DateTime.now().toString());
        final monthKey = DateFormat('yyyy-MM').format(date);

        count++;

        if (type == 'income') {
          totalIncome += amount;
          monthlyTrend[monthKey] = (monthlyTrend[monthKey] ?? 0) + amount;
        } else {
          totalExpense += amount;
          monthlyTrend[monthKey] = (monthlyTrend[monthKey] ?? 0) - amount;
        }

        // Category breakdown (only expenses)
        if (type == 'expense' && categoryId != null) {
          categoryBreakdown[categoryId] =
              (categoryBreakdown[categoryId] ?? 0) + amount;
        }
      }

      return {
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'balance': totalIncome - totalExpense,
        'transactionCount': count,
        'categoryBreakdown': categoryBreakdown,
        'monthlyTrend': monthlyTrend,
      };
    } catch (e) {
      throw Exception('Gagal mengambil ringkasan: $e');
    }
  }

  // Get date range transactions
  Future<List<Map<String, dynamic>>> getTransactionsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _database.ref('users/$userId/transactions').get();

      if (!snapshot.exists) {
        return [];
      }

      final transactionsMap = (snapshot.value as Map).cast<String, dynamic>();
      final List<Map<String, dynamic>> filtered = [];

      for (final entry in transactionsMap.entries) {
        final data = (entry.value as Map).cast<String, dynamic>();
        final date = DateTime.parse(data['date'] ?? DateTime.now().toString());

        if (date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            date.isBefore(endDate.add(const Duration(days: 1)))) {
          filtered.add({'id': entry.key, ...data});
        }
      }

      // Sort by date descending
      filtered.sort((a, b) {
        final dateA = DateTime.parse(a['date'] ?? DateTime.now().toString());
        final dateB = DateTime.parse(b['date'] ?? DateTime.now().toString());
        return dateB.compareTo(dateA);
      });

      return filtered;
    } catch (e) {
      throw Exception('Gagal filter transaksi: $e');
    }
  }
}
