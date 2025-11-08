import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class AppCheckDebugScreen extends StatefulWidget {
  const AppCheckDebugScreen({super.key});

  @override
  State<AppCheckDebugScreen> createState() => _AppCheckDebugScreenState();
}

class _AppCheckDebugScreenState extends State<AppCheckDebugScreen> {
  String _status = 'Initializing...';
  String _token = '';
  bool _isInitializing = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _checkAppCheckStatus();
  }

  Future<void> _checkAppCheckStatus() async {
    try {
      setState(() {
        _status = 'Checking Firebase initialization...';
      });

      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        setState(() {
          _status = 'Firebase not initialized';
          _isInitializing = false;
        });
        return;
      }

      setState(() {
        _status = 'Firebase initialized. Checking App Check...';
      });

      // Try to get App Check token
      try {
        final token = await FirebaseAppCheck.instance.getToken();
        setState(() {
          _status = 'App Check working';
          _token = token ?? 'No token received';
          _isInitializing = false;
        });
      } catch (e) {
        setState(() {
          _status = 'App Check token failed';
          _error = e.toString();
          _isInitializing = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error during check';
        _error = e.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _reinitializeAppCheck() async {
    setState(() {
      _isInitializing = true;
      _status = 'Reinitializing App Check...';
      _error = '';
      _token = '';
    });

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );

      setState(() {
        _status = 'App Check reinitialized successfully';
      });

      // Wait a bit then check token
      await Future.delayed(const Duration(seconds: 2));
      await _checkAppCheckStatus();
    } catch (e) {
      setState(() {
        _status = 'App Check reinitialization failed';
        _error = e.toString();
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Check Debug'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isInitializing
                              ? Icons.hourglass_empty
                              : _error.isEmpty
                              ? Icons.check_circle
                              : Icons.error,
                          color: _isInitializing
                              ? Colors.orange
                              : _error.isEmpty
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Status: $_status',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Error:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          _error,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                    if (_token.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Token:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          _token.length > 100
                              ? '${_token.substring(0, 100)}...'
                              : _token,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitializing ? null : _checkAppCheckStatus,
                    child: const Text('Check Again'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitializing ? null : _reinitializeAppCheck,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reinitialize'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Firebase Apps:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...Firebase.apps.map(
              (app) => Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud, color: Colors.orange),
                  title: Text(app.name),
                  subtitle: Text('Options: ${app.options.projectId}'),
                  trailing: Icon(Icons.check_circle, color: Colors.green[600]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Auth State:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      user != null ? Icons.person : Icons.person_outline,
                      color: user != null ? Colors.green : Colors.grey,
                    ),
                    title: Text(user != null ? 'Logged In' : 'Not Logged In'),
                    subtitle: user != null
                        ? Text('UID: ${user.uid.substring(0, 8)}...')
                        : const Text('No user authenticated'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
