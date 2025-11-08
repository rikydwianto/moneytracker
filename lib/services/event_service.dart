import 'package:firebase_database/firebase_database.dart';
import '../models/event.dart';
import '../models/transaction.dart';

class EventService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Get events reference for a user
  DatabaseReference _eventsRef(String userId) =>
      _database.child('users/$userId/events');

  // Get transactions reference for a user
  DatabaseReference _transactionsRef(String userId) =>
      _database.child('users/$userId/transactions');

  // Stream all events for a user
  Stream<List<Event>> streamEvents(String userId) {
    return _eventsRef(userId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Event>[];

      final map = Map<String, dynamic>.from(data as Map);
      return map.entries
          .map((e) => Event.fromRtdb(Map<String, dynamic>.from(e.value), e.key))
          .toList()
        ..sort((a, b) {
          // Active events first, then by start date descending
          if (a.isActive != b.isActive) {
            return a.isActive ? -1 : 1;
          }
          if (a.startDate != null && b.startDate != null) {
            return b.startDate!.compareTo(a.startDate!);
          }
          return b.createdAt.compareTo(a.createdAt);
        });
    });
  }

  // Get active event (if any)
  Future<Event?> getActiveEvent(String userId) async {
    final snapshot = await _eventsRef(
      userId,
    ).orderByChild('isActive').equalTo(true).limitToFirst(1).get();

    if (!snapshot.exists) return null;

    final data = snapshot.value as Map;
    final entry = data.entries.first;
    return Event.fromRtdb(Map<String, dynamic>.from(entry.value), entry.key);
  }

  // Set an event as active (deactivates all others)
  Future<void> setActiveEvent(String userId, String eventId) async {
    // First, deactivate all events
    final snapshot = await _eventsRef(userId).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      final updates = <String, dynamic>{};

      for (var key in data.keys) {
        updates['users/$userId/events/$key/isActive'] = key == eventId;
        updates['users/$userId/events/$key/updatedAt'] = DateTime.now()
            .toIso8601String();
      }

      await _database.update(updates);
    }
  }

  // Activate a specific event (deactivates all others)
  Future<void> activateEvent(String userId, String eventId) async {
    await setActiveEvent(userId, eventId);
  }

  // Deactivate a specific event
  Future<void> deactivateEvent(String userId, String eventId) async {
    await _eventsRef(userId).child(eventId).update({
      'isActive': false,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Deactivate all events
  Future<void> deactivateAllEvents(String userId) async {
    final snapshot = await _eventsRef(userId).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      final updates = <String, dynamic>{};

      for (var key in data.keys) {
        updates['users/$userId/events/$key/isActive'] = false;
        updates['users/$userId/events/$key/updatedAt'] = DateTime.now()
            .toIso8601String();
      }

      await _database.update(updates);
    }
  }

  // Create a new event
  Future<String> createEvent(Event event) async {
    // If this event is set as active, deactivate all others first
    if (event.isActive) {
      await deactivateAllEvents(event.userId);
    }

    final ref = _eventsRef(event.userId).push();
    final newEvent = event.copyWith(id: ref.key!);
    await ref.set(newEvent.toRtdbMap());
    return ref.key!;
  }

  // Update an existing event
  Future<void> updateEvent(Event event) async {
    // If setting this event as active, deactivate all others first
    if (event.isActive) {
      await deactivateAllEvents(event.userId);
    }

    await _eventsRef(event.userId).child(event.id).update(event.toRtdbMap());
  }

  // Delete an event
  Future<void> deleteEvent(String userId, String eventId) async {
    await _eventsRef(userId).child(eventId).remove();
  }

  // Get event by ID
  Future<Event?> getEventById(String userId, String eventId) async {
    final snapshot = await _eventsRef(userId).child(eventId).get();
    if (!snapshot.exists) return null;

    return Event.fromRtdb(
      Map<String, dynamic>.from(snapshot.value as Map),
      eventId,
    );
  }

  // Get transactions for a specific event
  Stream<List<TransactionModel>> streamEventTransactions(
    String userId,
    String eventId,
  ) {
    return _transactionsRef(userId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <TransactionModel>[];

      final map = Map<String, dynamic>.from(data as Map);
      return map.entries
          .where((e) {
            final tx = Map<String, dynamic>.from(e.value);
            return tx['eventId'] == eventId;
          })
          .map(
            (e) => TransactionModel.fromRtdb(
              e.key,
              Map<dynamic, dynamic>.from(e.value),
            ),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  // Calculate event balance (income - expense)
  Future<Map<String, double>> calculateEventBalance(
    String userId,
    String eventId,
  ) async {
    final snapshot = await _transactionsRef(
      userId,
    ).orderByChild('eventId').equalTo(eventId).get();

    double income = 0;
    double expense = 0;

    if (snapshot.exists) {
      final data = snapshot.value as Map;
      for (var entry in data.values) {
        final tx = Map<String, dynamic>.from(entry);
        final type = tx['type'] as String?;
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0;

        if (type == 'income') {
          income += amount;
        } else if (type == 'expense') {
          expense += amount;
        }
        // Note: transfers and debts could be included based on business logic
      }
    }

    return {'income': income, 'expense': expense, 'balance': income - expense};
  }

  // Get event summary with transaction count
  Future<Map<String, dynamic>> getEventSummary(
    String userId,
    String eventId,
  ) async {
    final event = await getEventById(userId, eventId);
    if (event == null) return {};

    final balance = await calculateEventBalance(userId, eventId);

    final snapshot = await _transactionsRef(
      userId,
    ).orderByChild('eventId').equalTo(eventId).get();

    int transactionCount = 0;
    if (snapshot.exists) {
      transactionCount = (snapshot.value as Map).length;
    }

    return {
      'event': event,
      'income': balance['income'],
      'expense': balance['expense'],
      'balance': balance['balance'],
      'transactionCount': transactionCount,
    };
  }
}
