import 'package:flutter/material.dart';
import '../../widgets/pin_keyboard.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Screen untuk verifikasi PIN sebelum akses wallet yang di-hide
class WalletPinVerifyScreen extends StatefulWidget {
  final String walletName;
  final String correctPin;
  final VoidCallback onSuccess;

  const WalletPinVerifyScreen({
    super.key,
    required this.walletName,
    required this.correctPin,
    required this.onSuccess,
  });

  @override
  State<WalletPinVerifyScreen> createState() => _WalletPinVerifyScreenState();
}

class _WalletPinVerifyScreenState extends State<WalletPinVerifyScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  int _attemptCount = 0;
  bool _isError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false; // reflects device+setting combined
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();
      bool settingEnabled = false;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseDatabase.instance
            .ref('users/${user.uid}/settings/biometricForPinEnabled')
            .get();
        settingEnabled = snap.value == true;
      }
      if (mounted) {
        setState(() {
          _canCheckBiometrics =
              canCheck &&
              isDeviceSupported &&
              available.isNotEmpty &&
              settingEnabled;
        });
      }
    } on PlatformException {
      if (mounted) setState(() => _canCheckBiometrics = false);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi PIN'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Lock Icon
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isError ? Colors.red.shade50 : Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isError ? Icons.lock_clock : Icons.lock_outline,
                  size: 50,
                  color: _isError ? Colors.red.shade700 : Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Wallet Name
            Text(
              widget.walletName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Instruction
            Text(
              'Masukkan PIN untuk membuka dompet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 40),
            // PIN Keyboard
            PinKeyboard(
              currentPin: _pin,
              pinLength: 6,
              onPinChanged: (pin) {
                setState(() {
                  _pin = pin;
                  _isError = false;
                });
              },
              onCompleted: _verifyPin,
              showBiometricButton: _canCheckBiometrics,
              onBiometricPressed: _authenticateBiometric,
              biometricIcon: Icons.fingerprint,
            ),
            const SizedBox(height: 24),
            // Error Message
            if (_isError)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PIN salah!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sisa percobaan: ${3 - _attemptCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // Forgot PIN
            TextButton.icon(
              onPressed: _showForgotPinDialog,
              icon: const Icon(Icons.help_outline),
              label: const Text('Lupa PIN?'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verifyPin() {
    if (_pin == widget.correctPin) {
      // Success
      widget.onSuccess();
      Navigator.pop(context, true);
    } else {
      // Wrong PIN
      _attemptCount++;

      if (_attemptCount >= 3) {
        // Too many attempts
        Navigator.pop(context, false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Terlalu banyak percobaan. Silakan coba lagi nanti.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Show error and shake
        setState(() {
          _isError = true;
          _pin = '';
        });
        _shakeController.forward(from: 0);
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    if (!_canCheckBiometrics || _isAuthenticating) return;
    setState(() => _isAuthenticating = true);
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Gunakan biometrik untuk membuka dompet',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (didAuth && mounted) {
        widget.onSuccess();
        Navigator.pop(context, true);
      }
    } on PlatformException {
      // Ignore error
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _showForgotPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lupa PIN?'),
        content: const Text(
          'Untuk keamanan, Anda perlu menghubungi admin atau reset dari pengaturan aplikasi.\n\nCatatan: Reset PIN akan menghapus proteksi dompet ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, false); // Close verify screen
            },
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show PIN verification
Future<bool> showWalletPinVerification(
  BuildContext context, {
  required String walletName,
  required String correctPin,
  required VoidCallback onSuccess,
}) async {
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (context) => WalletPinVerifyScreen(
        walletName: walletName,
        correctPin: correctPin,
        onSuccess: onSuccess,
      ),
    ),
  );
  return result ?? false;
}
