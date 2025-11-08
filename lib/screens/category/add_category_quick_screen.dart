import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';

class AddCategoryQuickScreen extends StatefulWidget {
  final TransactionType? initialType;

  const AddCategoryQuickScreen({super.key, this.initialType});

  @override
  State<AddCategoryQuickScreen> createState() => _AddCategoryQuickScreenState();
}

class _AddCategoryQuickScreenState extends State<AddCategoryQuickScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _applies = 'expense';
  String? _parentId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Get the transaction type from route arguments if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is TransactionType) {
        setState(() {
          _applies = args == TransactionType.income ? 'income' : 'expense';
        });
      } else if (widget.initialType == TransactionType.income) {
        setState(() {
          _applies = 'income';
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final ref = FirebaseDatabase.instance.ref('users/${user.uid}/categories');
      final newRef = ref.push();

      final category = Category(
        id: newRef.key!,
        name: _nameController.text.trim(),
        type: _applies == 'income'
            ? TransactionType.income
            : TransactionType.expense,
        applies: _applies,
        icon: _getDefaultIcon(_nameController.text.trim()),
        color: _getDefaultColor(_nameController.text.trim()),
        parentId: _parentId,
      );

      await newRef.set(category.toMap());

      if (mounted) {
        // Return the new category ID to the transaction form
        Navigator.pop(context, newRef.key);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _getDefaultIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('makanan') || n.contains('makan')) return '🍴';
    if (n.contains('minuman')) return '☕';
    if (n.contains('transport')) return '🚗';
    if (n.contains('belanja')) return '🛒';
    if (n.contains('hiburan')) return '🎬';
    if (n.contains('kesehatan')) return '🏥';
    if (n.contains('pendidikan')) return '🎓';
    if (n.contains('tagihan')) return '📄';
    if (n.contains('gaji')) return '💰';
    if (n.contains('bonus')) return '🎁';
    return '📁';
  }

  String _getDefaultColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('makanan') || n.contains('makan')) return '#FF9800';
    if (n.contains('minuman')) return '#795548';
    if (n.contains('transport')) return '#2196F3';
    if (n.contains('belanja')) return '#9C27B0';
    if (n.contains('hiburan')) return '#E91E63';
    if (n.contains('kesehatan')) return '#F44336';
    if (n.contains('pendidikan')) return '#3F51B5';
    if (n.contains('tagihan')) return '#FFC107';
    if (n.contains('gaji')) return '#4CAF50';
    if (n.contains('bonus')) return '#009688';
    return '#1E88E5';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(fontSize: 14)),
        ),
        leadingWidth: 70,
        title: const Text('Tambah Kategori'),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Silakan masuk terlebih dahulu'))
          : StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('users/${user.uid}/categories')
                  .onValue,
              builder: (context, snapshot) {
                final categoriesData = snapshot.data?.snapshot.value;
                final categoriesMap = (categoriesData is Map)
                    ? categoriesData.cast<String, dynamic>()
                    : <String, dynamic>{};

                final parentCategories = categoriesMap.entries
                    .where((e) {
                      final map = (e.value as Map).cast<String, dynamic>();
                      return map['parentId'] == null;
                    })
                    .map(
                      (e) => {
                        'id': e.key,
                        ...((e.value as Map).cast<String, dynamic>()),
                      },
                    )
                    .toList();

                return Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Nama Kategori
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nama Kategori',
                                      hintText: 'Contoh: Makanan',
                                      border: InputBorder.none,
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Nama wajib diisi'
                                        : null,
                                    autofocus: true,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Jenis Transaksi
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Jenis Transaksi',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      SegmentedButton<String>(
                                        segments: const [
                                          ButtonSegment(
                                            value: 'expense',
                                            label: Text('Pengeluaran'),
                                            icon: Icon(Icons.north_east),
                                          ),
                                          ButtonSegment(
                                            value: 'income',
                                            label: Text('Pemasukan'),
                                            icon: Icon(Icons.south_west),
                                          ),
                                          ButtonSegment(
                                            value: 'both',
                                            label: Text('Keduanya'),
                                          ),
                                        ],
                                        selected: {_applies},
                                        onSelectionChanged:
                                            (Set<String> selected) {
                                              setState(() {
                                                _applies = selected.first;
                                              });
                                            },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Kategori Induk (Opsional)
                              if (parentCategories.isNotEmpty)
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Kategori Induk (Opsional)',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String?>(
                                          value: _parentId,
                                          decoration: const InputDecoration(
                                            hintText: 'Pilih kategori induk',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: [
                                            const DropdownMenuItem(
                                              value: null,
                                              child: Text(
                                                'Tidak ada (Kategori Utama)',
                                              ),
                                            ),
                                            ...parentCategories
                                                .where((p) {
                                                  final applies =
                                                      p['applies'] as String?;
                                                  return applies == 'both' ||
                                                      applies == _applies;
                                                })
                                                .map(
                                                  (p) => DropdownMenuItem(
                                                    value: p['id'] as String,
                                                    child: Text(
                                                      p['name'] as String? ??
                                                          '',
                                                    ),
                                                  ),
                                                ),
                                          ],
                                          onChanged: (value) {
                                            setState(() => _parentId = value);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              // Info
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
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
                                        'Icon dan warna akan dipilih otomatis sesuai nama kategori',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bottom Save Button
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: FilledButton(
                            onPressed: _loading ? null : _saveCategory,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 22,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Simpan & Gunakan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
