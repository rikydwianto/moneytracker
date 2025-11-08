import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class IdrFormatters {
  static final NumberFormat currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String format(num value) => currency.format(value);

  static double parse(String input) {
    // Remove everything except digits
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.parse(digits);
  }

  static TextInputFormatter rupiahInputFormatter({bool withSymbol = false}) =>
      _RupiahInputFormatter(withSymbol: withSymbol);
}

class _RupiahInputFormatter extends TextInputFormatter {
  final bool withSymbol;
  _RupiahInputFormatter({required this.withSymbol});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Keep cursor at end after formatting
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      final text = withSymbol ? 'Rp ' : '';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    final number = double.parse(digitsOnly);
    final formatted = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    ).format(number).trim();
    final display = withSymbol ? 'Rp $formatted' : formatted;
    return TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
  }
}
