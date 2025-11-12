import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart'; // init handled by FirebaseBootstrap
import 'package:firebase_database/firebase_database.dart';
import '../../../shared/firebase_bootstrap.dart';

class ShoppingTodoItem {
  final String id;
  final String title;
  final bool isDone;
  final DateTime createdAt;
  final double qty;
  final double price;

  ShoppingTodoItem({
    required this.id,
    required this.title,
    required this.isDone,
    required this.createdAt,
    this.qty = 1.0,
    this.price = 0.0,
  });

  ShoppingTodoItem copyWith({
    String? title,
    bool? isDone,
    double? qty,
    double? price,
  }) => ShoppingTodoItem(
    id: id,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    createdAt: createdAt,
    qty: qty ?? this.qty,
    price: price ?? this.price,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isDone': isDone,
    'createdAt': createdAt.toIso8601String(),
    'qty': qty,
    'price': price,
  };
  static ShoppingTodoItem fromJson(Map<String, dynamic> m) => ShoppingTodoItem(
    id: m['id'] as String,
    title: m['title'] as String,
    isDone: m['isDone'] as bool,
    createdAt: DateTime.parse(m['createdAt'] as String),
    qty: (m['qty'] as num?)?.toDouble() ?? 1.0,
    price: (m['price'] as num?)?.toDouble() ?? 0.0,
  );
}

class ShoppingListModel {
  final String id;
  final String title;
  final String category;
  final DateTime createdAt;
  final DateTime date;
  final bool isDone;
  final List<ShoppingTodoItem> items;
  final DateTime updatedAt; // for sync/merge
  final bool dirty; // local changes pending sync

  ShoppingListModel({
    required this.id,
    required this.title,
    required this.category,
    required this.createdAt,
    required this.date,
    required this.isDone,
    required this.items,
    required this.updatedAt,
    required this.dirty,
  });

  ShoppingListModel copyWith({
    String? title,
    String? category,
    DateTime? date,
    bool? isDone,
    List<ShoppingTodoItem>? items,
    DateTime? updatedAt,
    bool? dirty,
  }) => ShoppingListModel(
    id: id,
    title: title ?? this.title,
    category: category ?? this.category,
    createdAt: createdAt,
    date: date ?? this.date,
    isDone: isDone ?? this.isDone,
    items: items ?? this.items,
    updatedAt: updatedAt ?? this.updatedAt,
    dirty: dirty ?? this.dirty,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'date': date.toIso8601String(),
    'isDone': isDone,
    'items': items.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
    'dirty': dirty,
  };
  static ShoppingListModel fromJson(Map<String, dynamic> m) =>
      ShoppingListModel(
        id: m['id'] as String,
        title: m['title'] as String,
        category: m['category'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
        date: (m['date'] != null)
            ? DateTime.parse(m['date'] as String)
            : DateTime.parse(m['createdAt'] as String),
        isDone: (m['isDone'] as bool?) ?? false,
        items: ((m['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ShoppingTodoItem.fromJson)
            .toList(),
        updatedAt: (m['updatedAt'] != null)
            ? DateTime.parse(m['updatedAt'] as String)
            : DateTime.parse(m['createdAt'] as String),
        dirty: (m['dirty'] as bool?) ?? false,
      );
}

class ShoppingTodoFeature extends StatefulWidget {
  final String heroTag;
  final Color color;
  const ShoppingTodoFeature({
    super.key,
    required this.heroTag,
    required this.color,
  });

  @override
  State<ShoppingTodoFeature> createState() => _ShoppingTodoFeatureState();
}

class _ShoppingTodoFeatureState extends State<ShoppingTodoFeature> {
  static const _prefsKey = 'miniapps.shopping_lists';

  final _titleCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  DateTime _newListDate = DateTime.now();
  final List<String> _suggestedCats = const [
    'Keperluan Rumah',
    'Dapur',
    'Bulanan',
    'Sekolah',
    'Kantor',
    'Bayi/Anak',
    'Lainnya',
  ];

  List<ShoppingListModel> _lists = [];
  bool _loading = true;
  bool _syncScheduled = false; // debounce flag
  FirebaseDatabase? _rtdb;
  DatabaseReference? _listsRef;
  // persistence is handled globally via FirebaseBootstrap
  String? _uid;
  // Track IDs of lists deleted locally to remove from RTDB when online
  final Set<String> _pendingDeletes = <String>{};

  Future<void> _ensureFirebase() async {
    try {
      await FirebaseBootstrap.ensureAll();
      _rtdb ??= FirebaseDatabase.instance;
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = (await FirebaseAuth.instance.signInAnonymously()).user;
      }
      _uid = user?.uid;
      if (_uid != null) {
        _listsRef = _rtdb!.ref('users/$_uid/shopping_lists');
        try {
          await _listsRef!.keepSynced(true);
        } catch (_) {}
      }
    } catch (e) {
      // Silent; offline or not authenticated yet.
    }
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    Future.delayed(const Duration(seconds: 2), () {
      _syncScheduled = false;
      _syncToCloud();
    });
  }

  Future<void> _syncToCloud() async {
    await _ensureFirebase();
    final ref = _listsRef;
    if (ref == null) return; // not logged in or RTDB not ready
    // Process pending deletes first
    if (_pendingDeletes.isNotEmpty) {
      final toRemove = List<String>.from(_pendingDeletes);
      for (final id in toRemove) {
        try {
          await ref.child(id).remove();
          _pendingDeletes.remove(id);
        } catch (_) {
          // keep for retry later
        }
      }
      await _persist();
    }
    for (final l in _lists.where((e) => e.dirty)) {
      try {
        await ref.child(l.id).set(l.toJson());
        final idx = _lists.indexWhere((e) => e.id == l.id);
        if (idx >= 0) {
          setState(() => _lists[idx] = _lists[idx].copyWith(dirty: false));
        }
      } catch (e) {
        // keep dirty, retry later
      }
    }
  }

  Future<void> _fetchFromCloud() async {
    await _ensureFirebase();
    final ref = _listsRef;
    if (ref == null) return;
    try {
      final snap = await ref.get();
      final remote = <ShoppingListModel>[];
      if (snap.exists && snap.value is Map) {
        final data = (snap.value as Map).cast<String, dynamic>();
        data.forEach((key, value) {
          if (value is Map) {
            final m = value.cast<String, dynamic>();
            // Ensure id is present for model
            m['id'] ??= key;
            remote.add(ShoppingListModel.fromJson(m));
          }
        });
      }
      // Merge: replace local non-dirty with newer remote (by updatedAt)
      for (final r in remote) {
        final idx = _lists.indexWhere((e) => e.id == r.id);
        if (idx < 0) {
          _lists.add(r);
        } else {
          final local = _lists[idx];
          if (!local.dirty) {
            if (r.updatedAt.isAfter(local.updatedAt)) {
              _lists[idx] = r;
            }
          }
        }
      }
      setState(() {
        _lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      });
      await _persist();
    } catch (_) {
      // ignore offline errors
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Migrate legacy single-list items if any
    final legacy = prefs.getString('miniapps.shopping_todo.items');
    final raw = prefs.getString(_prefsKey);
    // Load pending deletions list (for offline delete retries)
    final pendingRaw = prefs.getString('${_prefsKey}.pending_deletes');
    if (pendingRaw != null) {
      try {
        _pendingDeletes.addAll((jsonDecode(pendingRaw) as List).cast<String>());
      } catch (_) {}
    }
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ShoppingListModel.fromJson)
          .toList();
      _lists = list;
    } else if (legacy != null) {
      final items = (jsonDecode(legacy) as List)
          .cast<Map<String, dynamic>>()
          .map(ShoppingTodoItem.fromJson)
          .toList();
      _lists = [
        ShoppingListModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Belanja',
          category: 'Umum',
          createdAt: DateTime.now(),
          date: DateTime.now(),
          isDone: false,
          items: items,
          updatedAt: DateTime.now(),
          dirty: true,
        ),
      ];
      await prefs.setString(
        _prefsKey,
        jsonEncode(_lists.map((e) => e.toJson()).toList()),
      );
      await prefs.remove('miniapps.shopping_todo.items');
    }
    setState(() => _loading = false);
    // Try initial cloud fetch after local load
    _fetchFromCloud();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_lists.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
    await prefs.setString(
      '${_prefsKey}.pending_deletes',
      jsonEncode(_pendingDeletes.toList()),
    );
  }

  Future<void> _createList() async {
    final title = _titleCtrl.text.trim();
    final cat = _categoryCtrl.text.trim().isEmpty
        ? 'Umum'
        : _categoryCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _lists.insert(
        0,
        ShoppingListModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          category: cat,
          createdAt: DateTime.now(),
          date: _newListDate,
          isDone: false,
          items: const [],
          updatedAt: DateTime.now(),
          dirty: true,
        ),
      );
      _titleCtrl.clear();
      _categoryCtrl.clear();
      _newListDate = DateTime.now();
    });
    await _persist();
    _scheduleSync();
  }

  Future<void> _duplicateList(ShoppingListModel src) async {
    final copy = ShoppingListModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '${src.title} (salinan)',
      category: src.category,
      createdAt: DateTime.now(),
      date: src.date,
      isDone: false,
      items: src.items
          .map(
            (e) => ShoppingTodoItem(
              id: '${DateTime.now().millisecondsSinceEpoch}${e.id.hashCode}',
              title: e.title,
              isDone: false,
              createdAt: DateTime.now(),
              qty: e.qty,
              price: e.price,
            ),
          )
          .toList(),
      updatedAt: DateTime.now(),
      dirty: true,
    );
    setState(() {
      _lists.insert(0, copy);
    });
    await _persist();
    _scheduleSync();
  }

  Future<void> _deleteList(String id) async {
    setState(() {
      _lists.removeWhere((e) => e.id == id);
    });
    await _persist();
    // Mark for remote deletion and attempt immediately
    _pendingDeletes.add(id);
    try {
      await _ensureFirebase();
      final ref = _listsRef;
      if (ref != null) {
        await ref.child(id).remove();
        _pendingDeletes.remove(id);
      }
    } catch (_) {
      // offline - will retry later
    }
    await _persist();
    _scheduleSync();
  }

  Future<void> _toggleListDone(String id, bool v) async {
    setState(() {
      final idx = _lists.indexWhere((e) => e.id == id);
      if (idx >= 0)
        _lists[idx] = _lists[idx].copyWith(
          isDone: v,
          dirty: true,
          updatedAt: DateTime.now(),
        );
    });
    await _persist();
    _scheduleSync();
  }

  Future<void> _editList(ShoppingListModel l) async {
    final titleCtrl = TextEditingController(text: l.title);
    final catCtrl = TextEditingController(text: l.category);
    DateTime pickedDate = l.date;
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Daftar Belanja'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Judul'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.list_alt),
                    onSelected: (v) => (context as Element).markNeedsBuild(),
                    itemBuilder: (_) => _suggestedCats
                        .map(
                          (c) => PopupMenuItem(
                            value: c,
                            child: InkWell(
                              onTap: () {
                                catCtrl.text = c;
                                Navigator.pop(context);
                              },
                              child: Text(c),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(DateFormat('dd MMM yyyy').format(pickedDate)),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: pickedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        pickedDate = d;
                        (context as Element).markNeedsBuild();
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Pilih tanggal'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (res == true) {
      setState(() {
        final idx = _lists.indexWhere((e) => e.id == l.id);
        if (idx >= 0) {
          _lists[idx] = _lists[idx].copyWith(
            title: titleCtrl.text.trim().isEmpty
                ? l.title
                : titleCtrl.text.trim(),
            category: catCtrl.text.trim().isEmpty
                ? l.category
                : catCtrl.text.trim(),
            date: pickedDate,
            dirty: true,
            updatedAt: DateTime.now(),
          );
        }
      });
      await _persist();
      _scheduleSync();
    }
  }

  void _openDetail(ShoppingListModel list) async {
    Future<void> onChanged(ShoppingListModel updated) async {
      setState(() {
        final idx = _lists.indexWhere((e) => e.id == updated.id);
        if (idx >= 0) {
          _lists[idx] = updated.copyWith(
            updatedAt: DateTime.now(),
            dirty: true,
          );
        }
      });
      await _persist();
      await _syncToCloud();
    }

    final updated = await Navigator.push<ShoppingListModel>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ShoppingListDetailScreen(initial: list, onChanged: onChanged),
      ),
    );
    if (updated != null) {
      setState(() {
        final idx = _lists.indexWhere((e) => e.id == updated.id);
        if (idx >= 0) {
          _lists[idx] = updated.copyWith(
            updatedAt: DateTime.now(),
            dirty: true,
          );
        }
      });
      await _persist();
      await _syncToCloud();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Belanja')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Form input judul & kategori sebelum menyimpan
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Judul daftar (contoh: Belanja Bulanan)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _categoryCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Kategori (contoh: Keperluan Rumah)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.list_alt),
                            onSelected: (v) =>
                                setState(() => _categoryCtrl.text = v),
                            itemBuilder: (_) => _suggestedCats
                                .map(
                                  (c) =>
                                      PopupMenuItem(value: c, child: Text(c)),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM yyyy').format(_newListDate),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _newListDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setState(() => _newListDate = d);
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: const Text('Pilih tanggal'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _createList,
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Simpan Daftar'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _lists.isEmpty
                      ? const Center(child: Text('Belum ada daftar belanja.'))
                      : ListView.separated(
                          itemCount: _lists.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final l = _lists[i];
                            final doneCount = l.items
                                .where((e) => e.isDone)
                                .length;
                            return Dismissible(
                              key: ValueKey(l.id),
                              background: Container(color: Colors.redAccent),
                              onDismissed: (_) => _deleteList(l.id),
                              child: ListTile(
                                leading: Checkbox(
                                  value: l.isDone,
                                  onChanged: (v) =>
                                      _toggleListDone(l.id, v ?? false),
                                ),
                                title: Text(l.title),
                                subtitle: Text(
                                  '${l.category} • ${DateFormat('dd MMM yyyy').format(l.date)} • ${doneCount}/${l.items.length} selesai',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    switch (v) {
                                      case 'toggle':
                                        _toggleListDone(l.id, !l.isDone);
                                        break;
                                      case 'edit':
                                        _editList(l);
                                        break;
                                      case 'delete':
                                        _deleteList(l.id);
                                        break;
                                      case 'duplicate':
                                        _duplicateList(l);
                                        break;
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        l.isDone
                                            ? 'Tandai Belum'
                                            : 'Tandai Selesai',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Hapus'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'duplicate',
                                      child: Text('Duplikat'),
                                    ),
                                  ],
                                ),
                                onTap: () => _openDetail(l),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _ShoppingListDetailScreen extends StatefulWidget {
  final ShoppingListModel initial;
  final ValueChanged<ShoppingListModel> onChanged;
  const _ShoppingListDetailScreen({
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_ShoppingListDetailScreen> createState() =>
      _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<_ShoppingListDetailScreen> {
  late ShoppingListModel _current;
  final _itemCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
  }

  void _syncBack() {
    // Return the modified list so caller can merge into collection.
    Navigator.pop(context, _current);
  }

  void _addItem(String title) {
    if (title.trim().isEmpty) return;
    setState(() {
      final newItem = ShoppingTodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.trim(),
        isDone: false,
        createdAt: DateTime.now(),
      );
      _current = _current.copyWith(
        items: [newItem, ..._current.items],
        updatedAt: DateTime.now(),
        dirty: true,
      );
      _itemCtrl.clear();
    });
    widget.onChanged(_current);
  }

  void _toggle(String id, bool v) {
    setState(() {
      final updated = _current.items
          .map((e) => e.id == id ? e.copyWith(isDone: v) : e)
          .toList();
      _current = _current.copyWith(
        items: updated,
        updatedAt: DateTime.now(),
        dirty: true,
      );
    });
    widget.onChanged(_current);
  }

  void _remove(String id) {
    setState(() {
      final updated = _current.items.where((e) => e.id != id).toList();
      _current = _current.copyWith(
        items: updated,
        updatedAt: DateTime.now(),
        dirty: true,
      );
    });
    widget.onChanged(_current);
  }

  void _duplicateItem(ShoppingTodoItem it) {
    setState(() {
      final newItem = ShoppingTodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${it.title} (salinan)',
        isDone: false,
        createdAt: DateTime.now(),
        qty: it.qty,
        price: it.price,
      );
      _current = _current.copyWith(
        items: [newItem, ..._current.items],
        updatedAt: DateTime.now(),
        dirty: true,
      );
    });
    widget.onChanged(_current);
  }

  Future<void> _editItem(ShoppingTodoItem it) async {
    final titleCtrl = TextEditingController(text: it.title);
    final qtyCtrl = TextEditingController(text: it.qty.toString());
    final priceCtrl = TextEditingController(
      text: it.price == 0 ? '' : it.price.toStringAsFixed(0),
    );
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Nama item'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      decoration: const InputDecoration(labelText: 'Qty'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => (context as Element).markNeedsBuild(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Harga (estimasi)',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => (context as Element).markNeedsBuild(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Builder(
                  builder: (_) {
                    final qty =
                        double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ??
                        it.qty;
                    final price =
                        double.tryParse(
                          priceCtrl.text
                              .replaceAll('.', '')
                              .replaceAll(',', ''),
                        ) ??
                        it.price;
                    final total = qty * price;
                    return Text(
                      'Subtotal: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(total)}',
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (res == true) {
      setState(() {
        final updated = _current.items.map((e) {
          if (e.id == it.id) {
            final qty =
                double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? it.qty;
            final price =
                double.tryParse(
                  priceCtrl.text.replaceAll('.', '').replaceAll(',', ''),
                ) ??
                it.price;
            return e.copyWith(
              title: titleCtrl.text.trim().isEmpty
                  ? it.title
                  : titleCtrl.text.trim(),
              qty: qty <= 0 ? 1.0 : qty,
              price: price < 0 ? 0.0 : price,
            );
          }
          return e;
        }).toList();
        _current = _current.copyWith(
          items: updated,
          updatedAt: DateTime.now(),
          dirty: true,
        );
      });
      widget.onChanged(_current);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _syncBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_current.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _syncBack,
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Tambah item... (contoh: Beras 5kg)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: _addItem,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _addItem(_itemCtrl.text),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _current.items.isEmpty
                  ? const Center(child: Text('Belum ada item.'))
                  : ListView.separated(
                      itemCount: _current.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final it = _current.items[i];
                        return Dismissible(
                          key: ValueKey(it.id),
                          background: Container(color: Colors.redAccent),
                          onDismissed: (_) => _remove(it.id),
                          child: ListTile(
                            leading: Checkbox(
                              value: it.isDone,
                              onChanged: (v) => _toggle(it.id, v ?? false),
                            ),
                            title: Text(
                              it.title,
                              style: TextStyle(
                                decoration: it.isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: it.isDone ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Text(
                              '${(it.qty % 1 == 0 ? it.qty.toInt().toString() : it.qty.toString())} x ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(it.price)} = ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(it.qty * it.price)}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'toggle':
                                    _toggle(it.id, !it.isDone);
                                    break;
                                  case 'edit':
                                    _editItem(it);
                                    break;
                                  case 'delete':
                                    _remove(it.id);
                                    break;
                                  case 'duplicate':
                                    _duplicateItem(it);
                                    break;
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    it.isDone
                                        ? 'Tandai Belum'
                                        : 'Tandai Selesai',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus'),
                                ),
                                const PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text('Duplikat'),
                                ),
                              ],
                            ),
                            onTap: () => _editItem(it),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Estimasi'),
                  Text(
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                    ).format(
                      _current.items.fold<double>(
                        0,
                        (sum, e) => sum + (e.qty * e.price),
                      ),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
