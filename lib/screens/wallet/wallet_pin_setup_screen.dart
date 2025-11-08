import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../widgets/pin_keyboard.dart';

/// Screen untuk setup/change PIN dompet
class WalletPinSetupScreen extends StatefulWidget {
  final String walletId;
  final String walletName;
  final String? currentPin; // null jika baru setup, ada value jika change PIN

  const WalletPinSetupScreen({
    super.key,
    required this.walletId,
    required this.walletName,
    this.currentPin,
  });

  @override
  State<WalletPinSetupScreen> createState() => _WalletPinSetupScreenState();
}

class _WalletPinSetupScreenState extends State<WalletPinSetupScreen> {
  int _step = 1; // 1: enter new PIN, 2: confirm PIN
  String _newPin = '';
  String _confirmPin = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Jika ada current PIN, mulai dari verifikasi
    if (widget.currentPin != null) {
      _step = 0; // Step 0: verify current PIN
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.currentPin == null ? 'Atur PIN' : 'Ubah PIN'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 40,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Wallet Name
                  Text(
                    widget.walletName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Instruction
                  Text(
                    _getInstructionText(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 40),
                  // PIN Keyboard
                  PinKeyboard(
                    currentPin: _getCurrentPin(),
                    pinLength: 6,
                    onPinChanged: (pin) {
                      setState(() {
                        if (_step == 0) {
                          _confirmPin = pin; // Reuse for verification
                        } else if (_step == 1) {
                          _newPin = pin;
                        } else {
                          _confirmPin = pin;
                        }
                      });
                    },
                    onCompleted: _onPinCompleted,
                  ),
                  const SizedBox(height: 24),
                  // Error message
                  if (_step == 2 &&
                      _confirmPin.isNotEmpty &&
                      _confirmPin != _newPin)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'PIN tidak cocok. Silakan coba lagi.',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _getInstructionText() {
    if (_step == 0) {
      return 'Masukkan PIN lama untuk verifikasi';
    } else if (_step == 1) {
      return 'Masukkan PIN 6 digit untuk mengunci dompet ini';
    } else {
      return 'Ulangi PIN untuk konfirmasi';
    }
  }

  String _getCurrentPin() {
    if (_step == 0 || _step == 2) {
      return _confirmPin;
    } else {
      return _newPin;
    }
  }

  void _onPinCompleted() async {
    if (_step == 0) {
      // Verify current PIN
      if (_confirmPin == widget.currentPin) {
        setState(() {
          _step = 1;
          _confirmPin = '';
        });
      } else {
        _showError('PIN lama salah');
        setState(() => _confirmPin = '');
      }
    } else if (_step == 1) {
      // Move to confirmation
      setState(() {
        _step = 2;
        _confirmPin = '';
      });
    } else if (_step == 2) {
      // Verify confirmation
      if (_confirmPin == _newPin) {
        await _savePin();
      } else {
        setState(() => _confirmPin = '');
      }
    }
  }

  Future<void> _savePin() async {
    setState(() => _loading = true);

    try {
      final userId = FirebaseDatabase.instance.ref().root.key;

      // Save PIN and set isHidden=true
      await FirebaseDatabase.instance
          .ref('users/$userId/wallets/${widget.walletId}')
          .update({
            'pin': _newPin,
            'isHidden': true,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.currentPin == null
                  ? '✅ PIN berhasil diatur'
                  : '✅ PIN berhasil diubah',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
