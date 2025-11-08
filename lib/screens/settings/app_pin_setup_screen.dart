import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../widgets/pin_keyboard.dart';

class AppPinSetupScreen extends StatefulWidget {
  const AppPinSetupScreen({super.key});

  @override
  State<AppPinSetupScreen> createState() => _AppPinSetupScreenState();
}

class _AppPinSetupScreenState extends State<AppPinSetupScreen> {
  String? _savedCurrentPin;
  String? _newPin;
  String _enteredPin = '';
  int _step = 0; // 0: verify current (if exists), 1: new PIN, 2: confirm
  bool _hasExistingPin = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPin();
  }

  Future<void> _checkExistingPin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/pin')
          .get();

      if (snapshot.exists) {
        setState(() {
          _savedCurrentPin = snapshot.value as String;
          _hasExistingPin = true;
          _step = 0; // Verify current PIN first
        });
      } else {
        setState(() {
          _step = 1; // No existing PIN, go directly to new PIN
        });
      }
    } catch (e) {
      debugPrint('Error checking existing PIN: $e');
      setState(() {
        _step = 1;
      });
    }
  }

  void _onPinChanged(String pin) {
    setState(() {
      _enteredPin = pin;
    });

    // Auto proceed when PIN complete
    if (pin.length == 6) {
      _onPinCompleted();
    }
  }

  void _onPinCompleted() {
    final pin = _enteredPin;

    if (_step == 0) {
      // Verify current PIN
      if (pin == _savedCurrentPin) {
        setState(() {
          _step = 1;
          _newPin = null;
          _enteredPin = '';
        });
      } else {
        _showError('PIN salah');
        setState(() {
          _enteredPin = '';
        });
      }
    } else if (_step == 1) {
      // Enter new PIN
      setState(() {
        _newPin = pin;
        _step = 2;
        _enteredPin = '';
      });
    } else if (_step == 2) {
      // Confirm new PIN
      if (pin == _newPin) {
        _savePin(pin);
      } else {
        setState(() {
          _newPin = null;
          _step = 1;
          _enteredPin = '';
        });
        _showError('PIN tidak cocok');
      }
    }
  }

  Future<void> _savePin(String pin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/pin')
          .set(pin);

      await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/updatedAt')
          .set(DateTime.now().toIso8601String());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _hasExistingPin ? 'PIN berhasil diubah' : 'PIN berhasil dibuat',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showError('Gagal menyimpan PIN: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _getTitle() {
    if (_step == 0) return 'Verifikasi PIN Lama';
    if (_step == 1) {
      return _hasExistingPin ? 'Masukkan PIN Baru' : 'Buat PIN Aplikasi';
    }
    return 'Konfirmasi PIN Baru';
  }

  String _getSubtitle() {
    if (_step == 0) return 'Masukkan PIN lama Anda';
    if (_step == 1) {
      return _hasExistingPin
          ? 'Masukkan 6 digit PIN baru'
          : 'Buat PIN 6 digit untuk keamanan';
    }
    return 'Masukkan ulang PIN baru';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_hasExistingPin ? 'Ubah PIN' : 'Buat PIN'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Lock Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                _getTitle(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                _getSubtitle(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // PIN Keyboard
              PinKeyboard(
                currentPin: _enteredPin,
                onPinChanged: _onPinChanged,
                obscureText: true,
              ),

              const Spacer(),

              // Info
              if (_step == 1 && !_hasExistingPin)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'PIN ini dapat digunakan untuk mengunci aplikasi dan menyembunyikan dompet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
