import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  TransactionType? _filterType; // null = all

  Stream<DatabaseEvent> _categoriesStream(String uid) {
    final ref = FirebaseDatabase.instance.ref('users/$uid/categories');
    return ref.onValue;
  }

  Future<void> _addOrEditCategory({
    Category? category,
    Category? parent,
    List<Category>? parentChoices,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: category?.name ?? '');
    TransactionType type =
        category?.type ?? parent?.type ?? TransactionType.expense;
    String applies =
        category?.applies ??
        parent?.applies ??
        (type == TransactionType.income ? 'income' : 'expense');
    final iconCtrl = TextEditingController(text: category?.icon ?? '📁');
    final colorCtrl = TextEditingController(text: category?.color ?? '#1E88E5');
    String? parentId = category?.parentId ?? parent?.id;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(category == null ? 'Tambah Kategori' : 'Ubah Kategori'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 8),
              if (parentChoices != null && parentChoices.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  value: parentId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tidak ada (Kategori Utama)'),
                    ),
                    ...parentChoices.map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ),
                  ],
                  onChanged: (v) {
                    parentId = v;
                    if (v != null) {
                      final p = parentChoices.firstWhere((e) => e.id == v);
                      applies = p.applies;
                      type = p.type;
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Di bawah kategori',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<String>(
                value: applies,
                items: const [
                  DropdownMenuItem(value: 'income', child: Text('Pemasukan')),
                  DropdownMenuItem(
                    value: 'expense',
                    child: Text('Pengeluaran'),
                  ),
                  DropdownMenuItem(value: 'both', child: Text('Keduanya')),
                ],
                onChanged: parentId != null
                    ? null
                    : (v) {
                        applies = v ?? 'expense';
                        if (applies == 'income') type = TransactionType.income;
                        if (applies == 'expense' || applies == 'both')
                          type = TransactionType.expense;
                      },
                decoration: const InputDecoration(labelText: 'Jenis'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: iconCtrl,
                decoration: const InputDecoration(labelText: 'Ikon (emoji)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Warna (hex, mis. #1E88E5)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final data = Category(
      id: category?.id ?? '',
      name: nameCtrl.text.trim(),
      icon: iconCtrl.text.trim().isEmpty ? '📁' : iconCtrl.text.trim(),
      color: colorCtrl.text.trim().isEmpty ? '#1E88E5' : colorCtrl.text.trim(),
      type: type,
      isDefault: category?.isDefault ?? false,
      userId: user.uid,
      applies: applies,
      parentId: parentId,
    ).toMap();

    final ref = FirebaseDatabase.instance.ref('users/${user.uid}/categories');
    if (category == null) {
      final newRef = ref.push();
      await newRef.set(data);
    } else {
      await ref.child(category.id).update(data);
    }
  }

  Future<void> _deleteCategory(
    Category category, {
    required Map<String, List<Category>> childrenMap,
  }) async {
    if (category.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori bawaan tidak dapat dihapus')),
      );
      return;
    }
    final hasChildren =
        (childrenMap[category.id] ?? const <Category>[]).isNotEmpty;
    if (hasChildren) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hapus dulu subkategori di bawah kategori ini'),
        ),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Yakin ingin menghapus "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/categories/${category.id}')
          .remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              setState(() {
                if (v == 'all') _filterType = null;
                if (v == 'income') _filterType = TransactionType.income;
                if (v == 'expense') _filterType = TransactionType.expense;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('Semua')),
              PopupMenuItem(value: 'income', child: Text('Pemasukan')),
              PopupMenuItem(value: 'expense', child: Text('Pengeluaran')),
            ],
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Masuk untuk mengatur kategori'))
          : StreamBuilder<DatabaseEvent>(
              stream: _categoriesStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data?.snapshot.value;
                if (data == null) {
                  return const Center(child: Text('Belum ada kategori'));
                }
                final map = (data as Map).cast<String, dynamic>();
                final categories = map.entries
                    .map(
                      (e) => Category.fromMap(
                        e.key,
                        (e.value as Map).cast<String, dynamic>(),
                      ),
                    )
                    .where(
                      (c) =>
                          _filterType == null ||
                          c.applies == 'both' ||
                          c.type == _filterType,
                    )
                    .toList();
                final parents =
                    categories.where((c) => c.parentId == null).toList()
                      ..sort((a, b) => a.name.compareTo(b.name));
                final Map<String, List<Category>> childrenMap = {};
                for (final c in categories.where((c) => c.parentId != null)) {
                  childrenMap.putIfAbsent(c.parentId!, () => []).add(c);
                }
                for (final list in childrenMap.values) {
                  list.sort((a, b) => a.name.compareTo(b.name));
                }
                if (categories.isEmpty) {
                  return const Center(child: Text('Belum ada kategori'));
                }
                // Always show parents and their children inline (no expansion tap)
                return ListView.builder(
                  itemCount: parents.length,
                  itemBuilder: (context, index) {
                    final p = parents[index];
                    final kids = childrenMap[p.id] ?? const <Category>[];
                    final tiles = <Widget>[
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(p.icon.isNotEmpty ? p.icon : '📁'),
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          p.applies == 'both'
                              ? 'Keduanya'
                              : (p.type == TransactionType.income
                                    ? 'Pemasukan'
                                    : 'Pengeluaran'),
                        ),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Tambah Subkategori',
                              onPressed: () => _addOrEditCategory(
                                parent: p,
                                parentChoices: parents,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _addOrEditCategory(
                                category: p,
                                parentChoices: parents,
                              ),
                              tooltip: 'Ubah',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _deleteCategory(p, childrenMap: childrenMap),
                              tooltip: 'Hapus',
                            ),
                          ],
                        ),
                      ),
                    ];
                    for (final c in kids) {
                      tiles.add(
                        ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 72,
                            right: 16,
                          ),
                          leading: CircleAvatar(
                            child: Text(c.icon.isNotEmpty ? c.icon : '📁'),
                          ),
                          title: Text(c.name),
                          subtitle: Text(
                            c.applies == 'both'
                                ? 'Keduanya'
                                : (c.type == TransactionType.income
                                      ? 'Pemasukan'
                                      : 'Pengeluaran'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _addOrEditCategory(
                                  category: c,
                                  parentChoices: parents,
                                ),
                                tooltip: 'Ubah',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteCategory(
                                  c,
                                  childrenMap: childrenMap,
                                ),
                                tooltip: 'Hapus',
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(children: tiles);
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditCategory(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}
