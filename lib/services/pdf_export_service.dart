import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class PDFExportService {
  final _database = FirebaseDatabase.instance;

  Future<String> generateTransactionReport(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    // Get data
    final snapshot = await _database.ref('users/$userId/transactions').get();

    if (!snapshot.exists) {
      throw Exception('Tidak ada data transaksi');
    }

    final transactionsMap = (snapshot.value as Map).cast<String, dynamic>();

    // Get additional data
    final categoriesSnapshot = await _database
        .ref('users/$userId/categories')
        .get();
    final walletsSnapshot = await _database.ref('users/$userId/wallets').get();
    final profileSnapshot = await _database.ref('users/$userId/profile').get();

    final categories = categoriesSnapshot.exists
        ? (categoriesSnapshot.value as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final wallets = walletsSnapshot.exists
        ? (walletsSnapshot.value as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final profile = profileSnapshot.exists
        ? (profileSnapshot.value as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    // Filter and prepare data
    List<Map<String, dynamic>> transactions = [];
    double totalIncome = 0;
    double totalExpense = 0;

    for (final entry in transactionsMap.entries) {
      final data = (entry.value as Map).cast<String, dynamic>();
      final date = DateTime.parse(data['date'] ?? DateTime.now().toString());

      // Filter by date range if provided
      if (startDate != null && date.isBefore(startDate)) continue;
      if (endDate != null && date.isAfter(endDate)) continue;

      final amount = (data['amount'] ?? 0).toDouble();
      if (data['type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }

      String categoryName = 'Tidak Ada';
      if (data['categoryId'] != null &&
          categories[data['categoryId']] != null) {
        categoryName = categories[data['categoryId']]['name'] ?? 'Tidak Ada';
      }

      String walletName = 'Tidak Ada';
      if (data['walletId'] != null && wallets[data['walletId']] != null) {
        walletName = wallets[data['walletId']]['name'] ?? 'Tidak Ada';
      }

      transactions.add({
        'id': entry.key,
        'date': date,
        'title': data['title'] ?? 'Transaksi',
        'amount': amount,
        'type': data['type'] ?? 'expense',
        'categoryName': categoryName,
        'walletName': walletName,
        'notes': data['notes'] ?? '',
      });
    }

    // Sort by date
    transactions.sort((a, b) => b['date'].compareTo(a['date']));

    // Build PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LAPORAN KEUANGAN',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  profile['name'] ?? 'MoneyTracker User',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Text(
                  'Periode: ${startDate != null ? DateFormat('dd/MM/yyyy').format(startDate) : 'Semua'} - ${endDate != null ? DateFormat('dd/MM/yyyy').format(endDate) : 'Sekarang'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),

          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Pemasukan:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      formatRupiah(totalIncome),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Pengeluaran:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      formatRupiah(totalExpense),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
                      ),
                    ),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Saldo Bersih:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.Text(
                      formatRupiah(totalIncome - totalExpense),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                        color: (totalIncome - totalExpense) >= 0
                            ? PdfColors.green
                            : PdfColors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // Transactions Table
          pw.Text(
            'Detail Transaksi',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),

          if (transactions.isEmpty)
            pw.Center(child: pw.Text('Tidak ada transaksi'))
          else
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
              },
              headers: ['Tanggal', 'Judul', 'Tipe', 'Kategori', 'Jumlah'],
              data: transactions.map((tx) {
                return [
                  DateFormat('dd/MM/yy').format(tx['date']),
                  tx['title'],
                  tx['type'] == 'income' ? 'Masuk' : 'Keluar',
                  tx['categoryName'],
                  formatRupiah(tx['amount']),
                ];
              }).toList(),
            ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Halaman ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ),
    );

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${directory.path}/MoneyTracker_Report_$timestamp.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    return path;
  }

  Future<String> generateMonthlyReport(
    String userId,
    int year,
    int month,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    return generateTransactionReport(
      userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  String formatRupiah(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }
}
