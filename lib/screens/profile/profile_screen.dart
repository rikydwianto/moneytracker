import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:flutter/material.dart';
import '../../utils/google_signout_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;
  String? _currentUsername;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _nameController.text = user.displayName ?? '';

    // Load username and phone from Firebase RTDB
    try {
      final profileSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/profile')
          .get();
      if (profileSnap.exists) {
        final profile = profileSnap.value as Map<dynamic, dynamic>?;
        if (profile != null) {
          _currentUsername = profile['username']?.toString();
          _usernameController.text = _currentUsername ?? '';
          _phoneController.text = profile['phone']?.toString() ?? '';
          _isPremium = profile['isPremium'] == true;
        }
      }
    } catch (e) {
      // Ignore error, username is optional
    }

    if (mounted) setState(() {});
  }

  Future<bool> _checkUsernameAvailable(String username) async {
    if (username.trim().isEmpty) return true;
    if (username.trim() == _currentUsername) return true;

    // Check if username already taken
    final snap = await FirebaseDatabase.instance
        .ref('usernames/${username.trim().toLowerCase()}')
        .get();
    return !snap.exists;
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Validate username
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      if (username.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username minimal 3 karakter'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check if username contains invalid characters
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username hanya boleh huruf, angka, dan underscore'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check availability
      final available = await _checkUsernameAvailable(username);
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Username sudah digunakan'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Validate phone number
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      // Remove non-digit characters for validation
      final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.length < 10 || digitsOnly.length > 15) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nomor handphone tidak valid (10-15 digit)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      // Update display name
      await user.updateDisplayName(_nameController.text.trim());

      // Update username and phone in Firebase RTDB
      final updates = <String, dynamic>{};

      if (username.isNotEmpty) {
        // Add new username mapping
        updates['usernames/${username.toLowerCase()}'] = user.uid;
        updates['users/${user.uid}/profile/username'] = username;

        // Remove old username mapping if changed
        if (_currentUsername != null &&
            _currentUsername != username &&
            _currentUsername!.isNotEmpty) {
          updates['usernames/${_currentUsername!.toLowerCase()}'] = null;
        }
      } else if (_currentUsername != null && _currentUsername!.isNotEmpty) {
        // Remove username if cleared
        updates['usernames/${_currentUsername!.toLowerCase()}'] = null;
        updates['users/${user.uid}/profile/username'] = null;
      }

      // Update phone number
      if (phone.isNotEmpty) {
        updates['users/${user.uid}/profile/phone'] = phone;
      } else {
        updates['users/${user.uid}/profile/phone'] = null;
      }

      if (updates.isNotEmpty) {
        await FirebaseDatabase.instance.ref().update(updates);
      }

      await user.reload();
      _currentUsername = username.isEmpty ? null : username;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui profil: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: user == null
          ? const Center(child: Text('Tidak ada pengguna yang masuk'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? Text(
                                (user.displayName?.isNotEmpty == true
                                        ? user.displayName![0]
                                        : 'U')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      // Premium Badge
                      if (_isPremium)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      // Premium Badge di nama
                      if (_isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.workspace_premium,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isPremium) const SizedBox(height: 8),
                      Text(
                        user.email ?? user.uid,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama Tampilan',
                            prefixIcon: Icon(Icons.person_outline),
                            helperText: 'Nama yang ditampilkan di profil Anda',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.alternate_email),
                            helperText:
                                'Username unik untuk transfer (huruf, angka, _)',
                            hintText: 'contoh: john_doe',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Handphone',
                            prefixIcon: Icon(Icons.phone_outlined),
                            helperText:
                                'Contoh: 081234567890 atau +6281234567890',
                            hintText: '081234567890',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Username digunakan untuk menerima transfer dari user lain',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Simpan'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Keluar'),
                    onTap: () async {
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Konfirmasi'),
                          content: const Text(
                            'Apakah Anda yakin ingin keluar?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Keluar'),
                            ),
                          ],
                        ),
                      );
                      if (shouldLogout == true) {
                        await signOutGoogleIfNeeded();
                        await FirebaseAuth.instance.signOut();
                        if (mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
