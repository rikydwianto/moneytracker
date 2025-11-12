import 'package:flutter/material.dart';
import '../../widgets/pin_keyboard.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AppPinVerifyScreen extends StatefulWidget {
  const AppPinVerifyScreen({super.key});

  @override
  State<AppPinVerifyScreen> createState() => _AppPinVerifyScreenState();
}

class _AppPinVerifyScreenState extends State<AppPinVerifyScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  int _attempts = 0;
  final int _maxAttempts = 3;
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
      if (mounted) {
        setState(() => _canCheckBiometrics = false);
      }
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onPinChanged(String pin) {
    setState(() {
      _enteredPin = pin;
    });

    if (pin.length == 6) {
      _onPinCompleted();
    }
  }

  void _onPinCompleted() async {
    final enteredPin = _enteredPin;
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final correctPin = args?['pin'] as String?;

    if (correctPin == null) {
      Navigator.pop(context, false);
      return;
    }

    if (enteredPin == correctPin) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _attempts++;
        _enteredPin = '';
      });
      _shakeController.forward(from: 0);

      if (_attempts >= _maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, false);
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    if (!_canCheckBiometrics || _isAuthenticating) return;
    setState(() => _isAuthenticating = true);
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Gunakan biometrik untuk verifikasi PIN',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (didAuth && mounted) {
        Navigator.pop(context, true); // Treat as successful PIN entry
      }
    } on PlatformException {
      // Ignore errors silently; could show a snackbar if desired
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
          'Untuk reset PIN, silakan hapus dan buat ulang PIN di Pengaturan aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final purpose = args?['purpose'] as String? ?? 'verify';
    final title = args?['title'] as String? ?? 'Masukkan PIN';

    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final small = h < 620;
              final iconBox = small ? 64.0 : 80.0;
              final topGap = small ? 12.0 : 24.0;
              final afterIconGap = small ? 12.0 : 24.0;
              final errorGap = small ? 8.0 : 16.0;

              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: topGap),

                    // Top cluster
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: iconBox,
                          height: iconBox,
                          decoration: BoxDecoration(
                            color: _attempts > 0
                                ? Colors.red.shade50
                                : theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _attempts > 0
                                ? Icons.lock_clock
                                : Icons.lock_outline,
                            size: small ? 34 : 40,
                            color: _attempts > 0
                                ? Colors.red
                                : theme.colorScheme.primary,
                          ),
                        ),

                        SizedBox(height: afterIconGap),

                        Text(
                          purpose == 'app_lock'
                              ? 'Buka Aplikasi'
                              : 'Verifikasi PIN',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masukkan PIN 6 digit',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        if (_attempts > 0) ...[
                          SizedBox(height: errorGap),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PIN salah. $_attempts dari $_maxAttempts percobaan',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Keypad area that scales to fit
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 280,
                              maxWidth: 380,
                            ),
                            child: PinKeyboard(
                              currentPin: _enteredPin,
                              onPinChanged: _onPinChanged,
                              obscureText: true,
                              showBiometricButton: _canCheckBiometrics,
                              onBiometricPressed: _authenticateBiometric,
                              biometricIcon: Icons.fingerprint,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom action
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _showForgotPinDialog,
                        child: const Text('Lupa PIN?'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Helper function to show PIN verification dialog
Future<bool> showAppPinVerification(
  BuildContext context, {
  required String pin,
  String purpose = 'verify',
  String title = 'Masukkan PIN',
}) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const AppPinVerifyScreen(),
      settings: RouteSettings(
        arguments: {'pin': pin, 'purpose': purpose, 'title': title},
      ),
    ),
  );
  return result == true;
}
