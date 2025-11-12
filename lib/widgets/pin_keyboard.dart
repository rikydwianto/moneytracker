import 'package:flutter/material.dart';

/// Custom PIN Keyboard Widget
/// Keyboard 6 digit yang bisa digunakan untuk verifikasi PIN di berbagai screen
class PinKeyboard extends StatelessWidget {
  final String currentPin;
  final int pinLength;
  final Function(String) onPinChanged;
  final VoidCallback? onCompleted;
  final bool obscureText;
  final Color? buttonColor;
  final Color? deleteColor;
  // Biometric button support (left slot on last row)
  final bool showBiometricButton;
  final VoidCallback? onBiometricPressed;
  final IconData biometricIcon;

  const PinKeyboard({
    super.key,
    required this.currentPin,
    this.pinLength = 6,
    required this.onPinChanged,
    this.onCompleted,
    this.obscureText = true,
    this.buttonColor,
    this.deleteColor,
    this.showBiometricButton = false,
    this.onBiometricPressed,
    this.biometricIcon = Icons.fingerprint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN Display
        _buildPinDisplay(context),
        const SizedBox(height: 32),
        // Number Pad
        _buildNumberPad(context),
      ],
    );
  }

  Widget _buildPinDisplay(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pinLength, (index) {
        final isFilled = index < currentPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: isFilled && !obscureText
              ? Center(
                  child: Text(
                    currentPin[index],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        );
      }),
    );
  }

  Widget _buildNumberPad(BuildContext context) {
    return Column(
      children: [
        // Row 1: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton(context, '1'),
            const SizedBox(width: 16),
            _buildNumberButton(context, '2'),
            const SizedBox(width: 16),
            _buildNumberButton(context, '3'),
          ],
        ),
        const SizedBox(height: 16),
        // Row 2: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton(context, '4'),
            const SizedBox(width: 16),
            _buildNumberButton(context, '5'),
            const SizedBox(width: 16),
            _buildNumberButton(context, '6'),
          ],
        ),
        const SizedBox(height: 16),
        // Row 3: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton(context, '7'),
            const SizedBox(width: 16),
            _buildNumberButton(context, '8'),
            const SizedBox(width: 16),
            _buildNumberButton(context, '9'),
          ],
        ),
        const SizedBox(height: 16),
        // Row 4: Biometric/Empty, 0, Delete
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            showBiometricButton
                ? _buildBiometricButton(context)
                : const SizedBox(width: 80, height: 80), // Empty space
            const SizedBox(width: 16),
            _buildNumberButton(context, '0'),
            const SizedBox(width: 16),
            _buildDeleteButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildBiometricButton(BuildContext context) {
    return InkWell(
      onTap: onBiometricPressed,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(biometricIcon, size: 28, color: Colors.blue.shade700),
      ),
    );
  }

  Widget _buildNumberButton(BuildContext context, String number) {
    return InkWell(
      onTap: () => _onNumberTap(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: buttonColor ?? Colors.grey.shade100,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return InkWell(
      onTap: _onDeleteTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: deleteColor ?? Colors.red.shade50,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.backspace_outlined,
          size: 28,
          color: Colors.red.shade700,
        ),
      ),
    );
  }

  void _onNumberTap(String number) {
    if (currentPin.length < pinLength) {
      final newPin = currentPin + number;
      onPinChanged(newPin);

      // Auto trigger onCompleted when PIN is complete
      if (newPin.length == pinLength && onCompleted != null) {
        Future.delayed(const Duration(milliseconds: 200), () {
          onCompleted!();
        });
      }
    }
  }

  void _onDeleteTap() {
    if (currentPin.isNotEmpty) {
      onPinChanged(currentPin.substring(0, currentPin.length - 1));
    }
  }
}

/// PIN Input Dialog
/// Dialog untuk input PIN dengan custom keyboard
class PinInputDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int pinLength;
  final Function(String) onPinEntered;
  final bool obscureText;

  const PinInputDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.pinLength = 6,
    required this.onPinEntered,
    this.obscureText = true,
  });

  @override
  State<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<PinInputDialog> {
  String _pin = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // PIN Keyboard
            PinKeyboard(
              currentPin: _pin,
              pinLength: widget.pinLength,
              onPinChanged: (pin) {
                setState(() => _pin = pin);
              },
              onCompleted: () {
                widget.onPinEntered(_pin);
                Navigator.pop(context);
              },
              obscureText: widget.obscureText,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show PIN dialog
Future<String?> showPinDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  int pinLength = 6,
  bool obscureText = true,
}) {
  String? enteredPin;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PinInputDialog(
      title: title,
      subtitle: subtitle,
      pinLength: pinLength,
      obscureText: obscureText,
      onPinEntered: (pin) {
        enteredPin = pin;
      },
    ),
  ).then((_) => enteredPin);
}
