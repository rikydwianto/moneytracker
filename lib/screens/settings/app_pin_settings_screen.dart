import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AppPinSettingsScreen extends StatefulWidget {
  const AppPinSettingsScreen({super.key});

  @override
  State<AppPinSettingsScreen> createState() => _AppPinSettingsScreenState();
}

class _AppPinSettingsScreenState extends State<AppPinSettingsScreen> {
  bool _loading = true;
  bool _appLockEnabled = false;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _appLockEnabled = false;
        _hasPin = false;
      });
      return;
    }
    try {
      final settingsRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/settings',
      );
      final pinSnap = await settingsRef.child('pin').get();
      final lockSnap = await settingsRef.child('appLockEnabled').get();
      setState(() {
        _hasPin =
            pinSnap.exists &&
            pinSnap.value is String &&
            (pinSnap.value as String).isNotEmpty;
        _appLockEnabled = (lockSnap.value as bool?) ?? false;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Require PIN to enable app lock
    if (value && !_hasPin) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PIN belum diatur'),
          content: const Text(
            'Anda perlu mengatur PIN terlebih dahulu untuk mengaktifkan kunci aplikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Atur PIN'),
            ),
          ],
        ),
      );
      if (proceed == true) {
        await Navigator.pushNamed(context, '/app-pin-setup');
        await _load();
        if (!_hasPin) return; // still no PIN
      } else {
        return;
      }
    }

    try {
      await FirebaseDatabase.instance.ref('users/${user.uid}/settings').update({
        'appLockEnabled': value,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() => _appLockEnabled = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan PIN')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(_hasPin ? 'Ubah PIN' : 'Atur PIN'),
                    subtitle: Text(
                      _hasPin ? 'PIN sudah diatur' : 'Belum ada PIN',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.pushNamed(context, '/app-pin-setup');
                      await _load();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.verified_user_outlined,
                      color: _appLockEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    title: const Text('Buka aplikasi dengan PIN'),
                    subtitle: const Text('Minta PIN saat aplikasi dibuka'),
                    value: _appLockEnabled,
                    onChanged: _toggleAppLock,
                  ),
                ),
                const SizedBox(height: 8),
                if (_appLockEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Catatan: Kunci aplikasi akan aktif saat fitur diterapkan sepenuhnya.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
