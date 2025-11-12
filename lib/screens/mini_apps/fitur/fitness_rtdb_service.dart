import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FitnessRTDBService {
  FitnessRTDBService._();

  static Future<String?> _ensureUser() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    var user = FirebaseAuth.instance.currentUser;
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
    return user?.uid;
  }

  /// Ensure fitness (kebugaran) node exists under users/{uid}/miniApps/kebugaran with
  /// profile, records (sample), and stats placeholders. Also set miniApp metadata including `order`.
  static Future<void> ensureFitnessForCurrentUser({
    double initialWeight = 70,
    double initialHeight = 170,
    double goalWeight = 65,
    String goalDescription = 'Menurunkan berat badan secara sehat',
    bool withSampleRecords = true,
  }) async {
    final uid = await _ensureUser();
    if (uid == null) return;
    final baseRef = FirebaseDatabase.instance.ref(
      'users/$uid/miniApps/kebugaran',
    );

    final snap = await baseRef.get();
    if (snap.exists) {
      // Already exists: do not overwrite, but ensure metadata keys exist.
      await baseRef.update({
        'name': 'Kebugaran',
        'icon': '💪',
        'color': '#2196F3',
        'description': 'Pantau berat dan tinggi badanmu setiap hari',
        'order': 2,
      });
      return;
    }

    // Prepare sample dates (today and tomorrow) if desired
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final records = <String, dynamic>{};
    if (withSampleRecords) {
      records[fmt(today)] = {
        'weight': initialWeight + 0.5,
        'height': initialHeight,
        'timestamp': today.millisecondsSinceEpoch,
      };
      records[fmt(tomorrow)] = {
        'weight': initialWeight + 0.3,
        'height': initialHeight,
        'timestamp': tomorrow.millisecondsSinceEpoch,
      };
    }

    final payload = {
      'name': 'Kebugaran',
      'icon': '💪',
      'color': '#2196F3',
      'description': 'Pantau berat dan tinggi badanmu setiap hari',
      'order': 2,
      'fitness': {
        'profile': {
          'initialWeight': initialWeight,
          'initialHeight': initialHeight,
          'goalWeight': goalWeight,
          'goalDescription': goalDescription,
        },
        'records': records,
        'stats': {
          'daily': {
            'averageWeight': withSampleRecords ? initialWeight + 0.4 : 0,
            'averageHeight': initialHeight,
          },
          'weekly': {
            'averageWeight': withSampleRecords ? initialWeight + 0.6 : 0,
            'averageHeight': initialHeight,
          },
          'monthly': {
            'averageWeight': withSampleRecords ? initialWeight + 0.8 : 0,
            'averageHeight': initialHeight,
          },
          'allTime': {
            'minWeight': withSampleRecords ? initialWeight + 0.3 : 0,
            'maxWeight': withSampleRecords ? initialWeight + 1.0 : 0,
            'totalRecords': withSampleRecords ? 2 : 0,
          },
        },
      },
    };

    await baseRef.set(payload);
  }
}
