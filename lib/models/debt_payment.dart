class DebtPayment {
  final String id;
  final String debtTransactionId;
  final double amount;
  final DateTime paymentDate;
  final String? notes;
  final DateTime createdAt;
  final String? transactionId; // ID transaksi terkait

  DebtPayment({
    required this.id,
    required this.debtTransactionId,
    required this.amount,
    required this.paymentDate,
    this.notes,
    required this.createdAt,
    this.transactionId,
  });

  Map<String, dynamic> toRtdbMap() {
    return {
      'debtTransactionId': debtTransactionId,
      'amount': amount,
      'paymentDate': paymentDate.millisecondsSinceEpoch,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'transactionId': transactionId,
    };
  }

  factory DebtPayment.fromRtdb(String id, Map<dynamic, dynamic> data) {
    return DebtPayment(
      id: id,
      debtTransactionId: data['debtTransactionId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      paymentDate: DateTime.fromMillisecondsSinceEpoch(
        data['paymentDate'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      notes: data['notes'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      transactionId: data['transactionId'],
    );
  }
}
