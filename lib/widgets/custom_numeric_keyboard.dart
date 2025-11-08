import 'package:flutter/material.dart';

class CustomNumericKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onDone;
  final String? doneLabel;
  final Color? doneColor;

  const CustomNumericKeyboard({
    super.key,
    required this.controller,
    this.onDone,
    this.doneLabel,
    this.doneColor,
  });

  // Fungsi untuk mengevaluasi ekspresi matematika
  double? _evaluateExpression(String expression) {
    try {
      // Hapus spasi
      expression = expression.replaceAll(' ', '');

      // Jika kosong atau hanya angka, return langsung
      if (expression.isEmpty) return null;
      if (!expression.contains(RegExp(r'[+\-*/]'))) {
        return double.tryParse(expression);
      }

      // Parse dan evaluasi ekspresi
      List<double> numbers = [];
      List<String> operators = [];
      String currentNumber = '';

      for (int i = 0; i < expression.length; i++) {
        String char = expression[i];

        if (char == '+' || char == '-' || char == '*' || char == '/') {
          if (currentNumber.isNotEmpty) {
            numbers.add(double.parse(currentNumber));
            currentNumber = '';
          }
          operators.add(char);
        } else {
          currentNumber += char;
        }
      }

      if (currentNumber.isNotEmpty) {
        numbers.add(double.parse(currentNumber));
      }

      if (numbers.isEmpty) return null;

      // Evaluasi perkalian dan pembagian terlebih dahulu
      for (int i = 0; i < operators.length; i++) {
        if (operators[i] == '*' || operators[i] == '/') {
          double result = operators[i] == '*'
              ? numbers[i] * numbers[i + 1]
              : numbers[i] / numbers[i + 1];
          numbers[i] = result;
          numbers.removeAt(i + 1);
          operators.removeAt(i);
          i--;
        }
      }

      // Evaluasi penjumlahan dan pengurangan
      double result = numbers[0];
      for (int i = 0; i < operators.length; i++) {
        if (operators[i] == '+') {
          result += numbers[i + 1];
        } else if (operators[i] == '-') {
          result -= numbers[i + 1];
        }
      }

      return result;
    } catch (e) {
      return null;
    }
  }

  void _onKeyTap(String value) {
    final text = controller.text;
    final selection = controller.selection;

    if (value == '⌫') {
      // Backspace
      if (selection.start > 0) {
        final newText =
            text.substring(0, selection.start - 1) +
            text.substring(selection.end);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(
          offset: selection.start - 1,
        );
      }
    } else if (value == 'C') {
      // Clear
      controller.clear();
    } else if (value == '÷') {
      // Division
      final newText =
          text.substring(0, selection.start) +
          '/' +
          text.substring(selection.end);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: selection.start + 1,
      );
    } else if (value == '×') {
      // Multiplication
      final newText =
          text.substring(0, selection.start) +
          '*' +
          text.substring(selection.end);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: selection.start + 1,
      );
    } else {
      // Number or operator
      final newText =
          text.substring(0, selection.start) +
          value +
          text.substring(selection.end);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: selection.start + value.length,
      );
    }
  }

  Widget _buildKey(
    String label, {
    Color? backgroundColor,
    Color? textColor,
    bool isWide = false,
  }) {
    return Expanded(
      flex: isWide ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: backgroundColor ?? Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              if (label == 'SELESAI' || label == (doneLabel ?? 'SELESAI')) {
                onDone?.call();
              } else {
                _onKeyTap(label);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize:
                      label == 'SELESAI' || label == (doneLabel ?? 'SELESAI')
                      ? 16
                      : 24,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonDoneColor = doneColor ?? Colors.green;
    final buttonDoneLabel = doneLabel ?? 'SELESAI';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick amount buttons
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickAmount('10,000'),
                  const SizedBox(width: 8),
                  _buildQuickAmount('5,000'),
                  const SizedBox(width: 8),
                  _buildQuickAmount('15,000'),
                  const SizedBox(width: 8),
                  _buildQuickAmount('100,000'),
                ],
              ),
            ),
          ),

          // Keyboard grid
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // Row 1: C ÷ × ⌫
                Row(
                  children: [
                    _buildKey(
                      'C',
                      backgroundColor: Colors.green.shade100,
                      textColor: Colors.green.shade700,
                    ),
                    _buildKey(
                      '÷',
                      backgroundColor: Colors.grey.shade100,
                      textColor: Colors.grey.shade700,
                    ),
                    _buildKey(
                      '×',
                      backgroundColor: Colors.grey.shade100,
                      textColor: Colors.grey.shade700,
                    ),
                    _buildKey(
                      '⌫',
                      backgroundColor: Colors.green.shade100,
                      textColor: Colors.green.shade700,
                    ),
                  ],
                ),
                // Row 2: 7 8 9 -
                Row(
                  children: [
                    _buildKey('7'),
                    _buildKey('8'),
                    _buildKey('9'),
                    _buildKey(
                      '-',
                      backgroundColor: Colors.grey.shade100,
                      textColor: Colors.grey.shade700,
                    ),
                  ],
                ),
                // Row 3: 4 5 6 +
                Row(
                  children: [
                    _buildKey('4'),
                    _buildKey('5'),
                    _buildKey('6'),
                    _buildKey(
                      '+',
                      backgroundColor: Colors.grey.shade100,
                      textColor: Colors.green.shade700,
                    ),
                  ],
                ),
                // Row 4: 1 2 3 SELESAI (row 1)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          // Baris 1 2 3
                          Row(
                            children: [
                              _buildKey('1'),
                              _buildKey('2'),
                              _buildKey('3'),
                            ],
                          ),
                          // Baris 0 000 .
                          Row(
                            children: [
                              _buildKey('0'),
                              _buildKey('000'),
                              _buildKey('.'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Material(
                          color: buttonDoneColor,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () {
                              // Evaluasi ekspresi matematika sebelum menutup
                              final expression = controller.text;
                              final result = _evaluateExpression(expression);
                              if (result != null) {
                                // Bulatkan jika hasil adalah bilangan bulat
                                if (result == result.roundToDouble()) {
                                  controller.text = result.round().toString();
                                } else {
                                  controller.text = result.toString();
                                }
                                controller.selection = TextSelection.collapsed(
                                  offset: controller.text.length,
                                );
                              }
                              onDone?.call();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 120,
                              alignment: Alignment.center,
                              child: Text(
                                buttonDoneLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildQuickAmount(String amount) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          final numericValue = amount.replaceAll(',', '');
          controller.text = numericValue;
          controller.selection = TextSelection.collapsed(
            offset: numericValue.length,
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
