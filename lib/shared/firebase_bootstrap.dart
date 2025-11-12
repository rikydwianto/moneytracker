import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseBootstrap {
  static bool _initialized = false;
  static bool _persistenceSet = false;

  static Future<void> ensureInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    _initialized = true;
  }

  static Future<void> ensureDatabaseConfigured() async {
    if (!_initialized || Firebase.apps.isEmpty) {
      await ensureInitialized();
    }
    if (!_persistenceSet) {
      try {
        FirebaseDatabase.instance.setPersistenceEnabled(true);
        _persistenceSet = true;
      } catch (_) {
        // ignore if already set or not supported in this context
      }
    }
  }

  static Future<void> ensureAll() async {
    await ensureInitialized();
    await ensureDatabaseConfigured();
  }
}
