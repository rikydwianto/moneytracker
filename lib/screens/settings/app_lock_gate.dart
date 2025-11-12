import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../utils/google_signout_helper.dart';
import 'app_pin_verify_screen.dart';
import '../home_screen.dart';
import '../splash_screen.dart';
import '../../services/notification_service.dart';

class AppLockGate extends StatefulWidget {
  final String uid;
  const AppLockGate({super.key, required this.uid});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  bool _loading = true;
  bool _unlocked = false;
  String? _pin;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAndMaybeVerify();
  }

  Future<void> _checkAndMaybeVerify() async {
    try {
      final settingsRef = FirebaseDatabase.instance.ref(
        'users/${widget.uid}/settings',
      );
      final snap = await settingsRef.get();
      final data = (snap.value as Map?)?.cast<dynamic, dynamic>() ?? {};
      final appLockEnabled = (data['appLockEnabled'] as bool?) ?? false;
      final pin = data['pin'] as String?;

      if (!appLockEnabled || pin == null || pin.isEmpty) {
        setState(() {
          _unlocked = true;
          _loading = false;
        });
        // Auto refresh persistent total balance notification if enabled
        await NotificationService().refreshTotalBalanceIfEnabled();
        return;
      }

      _pin = pin;
      _loading = false;
      if (!mounted) return;
      final ok = await showAppPinVerification(
        context,
        pin: pin,
        purpose: 'app_lock',
        title: 'Buka Aplikasi',
      );
      if (!mounted) return;
      setState(() {
        _unlocked = ok;
        _error = ok ? null : 'Verifikasi dibatalkan atau gagal';
      });
      if (ok) {
        // Auto refresh on successful unlock
        await NotificationService().refreshTotalBalanceIfEnabled();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unlocked = true; // fallback allow access if settings fetch failed
        _loading = false;
      });
      // Attempt refresh anyway
      await NotificationService().refreshTotalBalanceIfEnabled();
    }
  }

  Future<void> _retry() async {
    final pin = _pin;
    if (pin == null || pin.isEmpty) {
      setState(() => _unlocked = true);
      return;
    }
    final ok = await showAppPinVerification(
      context,
      pin: pin,
      purpose: 'app_lock',
      title: 'Buka Aplikasi',
    );
    if (!mounted) return;
    setState(() {
      _unlocked = ok;
      _error = ok ? null : 'Verifikasi dibatalkan atau gagal';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SplashScreen();
    if (_unlocked) return const HomeScreen();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verifikasi diperlukan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Masukkan PIN untuk membuka aplikasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _retry,
                  child: const Text('Verifikasi PIN'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await signOutGoogleIfNeeded();
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Text('Keluar Akun'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
