// Clean rebuilt transaction form screen
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';
import '../../models/transaction.dart';
import '../../services/event_service.dart';
import '../../services/transaction_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/custom_numeric_keyboard.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key});
  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final _withPersonController = TextEditingController();
  final _locationController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _walletId;
  DateTime _date = DateTime.now();

  bool _loading = false;
  String? _eventId;
  // Active event reference (loaded once, only id is used currently)
  Event? _activeEvent; // ignore: unused_field

  // Local cached values for optional fields (controllers hold authoritative text)
  String? _withPerson; // ignore: unused_field
  String? _location; // ignore: unused_field
  DateTime? _reminderAt;

  XFile? _photoFile;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadActiveEvent();
    _loadDefaultWallet();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    _withPersonController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final cleanAmount = _amount.text.replaceAll(RegExp(r'[^\d]'), '');
    final amt = int.tryParse(cleanAmount) ?? 0;
    return amt > 0 && _walletId != null && _categoryId != null && !_loading;
  }

  Future<void> _loadActiveEvent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final event = await EventService().getActiveEvent(user.uid);
      if (mounted) {
        setState(() {
          _activeEvent = event;
          _eventId = event?.id;
        });
      }
    }
  }

  Future<void> _loadDefaultWallet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _walletId == null) {
      final defaultWallet = await WalletService().getDefaultWallet(user.uid);
      if (defaultWallet != null && mounted) {
        setState(() => _walletId = defaultWallet.id);
      }
    }
  }

  void _showCustomKeyboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: CustomNumericKeyboard(
            controller: _amount,
            onDone: () {
              Navigator.pop(context);
              final cleanValue = _amount.text.replaceAll(RegExp(r'[^\d]'), '');
              if (cleanValue.isNotEmpty) {
                final formatter = NumberFormat('#,###', 'id_ID');
                _amount.text = formatter.format(int.parse(cleanValue));
              }
            },
            doneLabel: 'SELESAI',
            doneColor: Colors.green,
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => _photoFile = picked);
        await _uploadPhoto();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memilih foto: $e')));
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_photoFile == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/transactions/temp/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (kIsWeb) {
        final bytes = await _photoFile!.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(_photoFile!.path));
      }
      final url = await ref.getDownloadURL();
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal upload foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() {
      _photoFile = null;
      _photoUrl = null;
    });
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masuk terlebih dahulu')),
      );
      return;
    }
    if (_walletId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silakan pilih dompet')));
      return;
    }
    if (_categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silakan pilih kategori')));
      return;
    }
    final cleanAmount = _amount.text.replaceAll(RegExp(r'[^\d]'), '');
    final amountValue = int.tryParse(cleanAmount) ?? 0;
    if (amountValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah yang valid')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final tx = TransactionModel(
        id: '',
        title: _title.text.trim().isEmpty ? 'Transaksi' : _title.text.trim(),
        amount: amountValue.toDouble(),
        type: _type,
        categoryId: _categoryId!,
        walletId: _walletId!,
        toWalletId: null,
        date: _date,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        photoUrl: _photoUrl,
        userId: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        eventId: _eventId,
        withPerson: _withPersonController.text.trim().isEmpty
            ? null
            : _withPersonController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        reminderAt: _reminderAt,
      );
      await TransactionService().add(user.uid, tx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Silakan masuk untuk membuat transaksi')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Transaksi Baru'), elevation: 0),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref('users/${user.uid}/wallets')
            .onValue,
        builder: (context, walletSnap) {
          if (walletSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final walletData = walletSnap.data?.snapshot.value;
          final walletsMap = (walletData is Map)
              ? walletData.cast<String, dynamic>()
              : <String, dynamic>{};
          final wallets = walletsMap.entries
              .map((e) => {
                    'id': e.key,
                    ...((e.value as Map).cast<String, dynamic>()),
                  })
              .toList();
          // Custom sort: any wallet whose name contains 'tunai' (case-insensitive)
          // should appear on top, preserving alphabetical order within groups.
          wallets.sort((a, b) {
            final an = ((a['name'] ?? '') as String).toLowerCase();
            final bn = ((b['name'] ?? '') as String).toLowerCase();
            final aTunai = an.contains('tunai');
            final bTunai = bn.contains('tunai');
            if (aTunai && !bTunai) return -1;
            if (!aTunai && bTunai) return 1;
            return an.compareTo(bn);
          });

          return StreamBuilder(
            stream: FirebaseDatabase.instance
                .ref('users/${user.uid}/categories')
                .onValue,
            builder: (context, catSnap) {
              if (catSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final catData = catSnap.data?.snapshot.value;
              final catsMap = (catData is Map)
                  ? catData.cast<String, dynamic>()
                  : <String, dynamic>{};
              final cats =
                  catsMap.entries
                      .map(
                        (e) => {
                          'id': e.key,
                          ...((e.value as Map).cast<String, dynamic>()),
                        },
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          ((a['name'] ?? '') as String).toLowerCase().compareTo(
                            ((b['name'] ?? '') as String).toLowerCase(),
                          ),
                    );
              final Map<String, Map<String, dynamic>> catsIndex = {
                for (final m in cats) m['id'] as String: m,
              };

              return StreamBuilder(
                stream: FirebaseDatabase.instance
                    .ref('users/${user.uid}/events')
                    .onValue,
                builder: (context, eventSnap) {
                  if (eventSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final eventData = eventSnap.data?.snapshot.value;
                  final eventsMap = (eventData is Map)
                      ? eventData.cast<String, dynamic>()
                      : <String, dynamic>{};
                  final events =
                      eventsMap.entries
                          .map(
                            (e) => {
                              'id': e.key,
                              ...((e.value as Map).cast<String, dynamic>()),
                            },
                          )
                          .toList()
                        ..sort(
                          (a, b) => ((a['name'] ?? '') as String)
                              .toLowerCase()
                              .compareTo(
                                ((b['name'] ?? '') as String).toLowerCase(),
                              ),
                        );

                  // Auto-select an active event if present and nothing selected yet
                  if (_eventId == null) {
                    final active =
                        events.where((e) => e['isActive'] == true).toList();
                    if (active.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _eventId == null) {
                          setState(() => _eventId = active.first['id'] as String);
                        }
                      });
                    }
                  }

                  return Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                _buildWalletCard(wallets),
                                _buildAmountCard(),
                                _buildCategoryCard(cats, catsIndex),
                                _buildEventCard(events),
                                _buildNotesCard(),
                                _buildDateCard(),
                                _buildTitleCard(),
                                _buildWithPersonCard(),
                                _buildLocationCard(),
                                _buildReminderCard(),
                                const SizedBox(height: 16),
                                _buildPhotoSection(),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        _buildSaveButton(),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Section builders
  Widget _buildSectionCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
    ),
    child: child,
  );

  Widget _buildWalletCard(List<Map<String, dynamic>> wallets) {
    return _buildSectionCard(
      child: InkWell(
        onTap: () => _showWalletPicker(context, wallets),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                radius: 20,
                child: _walletId == null
                    ? Icon(
                        Icons.account_balance_wallet,
                        color: Colors.orange.shade700,
                        size: 20,
                      )
                    : Text(
                        wallets
                                .firstWhere(
                                  (w) => w['id'] == _walletId,
                                  orElse: () => {'icon': '💰'},
                                )['icon']
                                ?.toString() ??
                            '💰',
                        style: const TextStyle(fontSize: 20),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _walletId == null
                      ? 'Dompet'
                      : wallets
                                .firstWhere(
                                  (w) => w['id'] == _walletId,
                                  orElse: () => {'name': 'Dompet'},
                                )['name']
                                ?.toString() ??
                            'Dompet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _walletId == null
                        ? Colors.grey[400]
                        : Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return _buildSectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'IDR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _amount,
                readOnly: true,
                onTap: _showCustomKeyboard,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Rp. 1.000.000',
                  hintStyle: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black26,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                ),
                validator: (v) {
                  final cleanValue = (v ?? '').replaceAll(RegExp(r'[^\d]'), '');
                  final n = int.tryParse(cleanValue) ?? 0;
                  if (n <= 0) return 'Masukkan jumlah yang valid';
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    List<Map<String, dynamic>> cats,
    Map<String, Map<String, dynamic>> catsIndex,
  ) {
    return _buildSectionCard(
      child: InkWell(
        onTap: () => _showCategoryPicker(context, cats, catsIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Builder(
                builder: (context) {
                  if (_categoryId == null) {
                    return CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      radius: 20,
                      child: Icon(
                        Icons.category,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    );
                  }
                  final selectedCat = catsIndex[_categoryId];
                  final iconStr = selectedCat?['icon'] as String?;
                  final colorStr = selectedCat?['color'] as String?;
                  Color categoryColor = _getCategoryColor(
                    _getCategoryName(_categoryId!, cats, catsIndex),
                  );
                  if (colorStr != null && colorStr.isNotEmpty) {
                    try {
                      final colorValue = int.parse(
                        colorStr.replaceAll('#', ''),
                        radix: 16,
                      );
                      categoryColor = Color(colorValue);
                    } catch (_) {}
                  }
                  bool isEmoji = false;
                  IconData iconData = Icons.category;
                  if (iconStr != null && iconStr.isNotEmpty) {
                    final iconFromFirebase = _getIconDataFromString(iconStr);
                    if (iconFromFirebase != null) {
                      iconData = iconFromFirebase;
                    } else {
                      isEmoji = true;
                    }
                  }
                  return CircleAvatar(
                    backgroundColor: categoryColor.withOpacity(0.2),
                    radius: 20,
                    child: isEmoji
                        ? Text(
                            iconStr ?? '',
                            style: const TextStyle(fontSize: 20),
                          )
                        : Icon(iconData, color: categoryColor, size: 20),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _categoryId == null
                      ? 'Pilih Kategori'
                      : _getCategoryName(_categoryId!, cats, catsIndex),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _categoryId == null
                        ? Colors.grey[400]
                        : Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(List<Map<String, dynamic>> events) {
    return _buildSectionCard(
      child: InkWell(
        onTap: () => _showEventPicker(context, events),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _eventId == null
                    ? Colors.grey[200]
                    : Colors.purple.shade100,
                radius: 20,
                child: Icon(
                  Icons.event,
                  color: _eventId == null
                      ? Colors.grey[400]
                      : Colors.purple.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _eventId == null
                          ? 'Pilih Acara (Opsional)'
                          : _getEventName(_eventId!, events),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _eventId == null
                            ? Colors.grey[400]
                            : Colors.black87,
                      ),
                    ),
                    if (_eventId != null)
                      Text(
                        'Transaksi akan masuk ke acara ini',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return _buildSectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.notes, color: Colors.grey[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                  hintText: 'Catatan (opsional)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return _buildSectionCard(
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _date,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            locale: const Locale('id', 'ID'),
          );
          if (picked != null) {
            setState(() {
              _date = DateTime(
                picked.year,
                picked.month,
                picked.day,
                _date.hour,
                _date.minute,
              );
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.grey[600], size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatDate(_date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: () => setState(
                      () => _date = _date.subtract(const Duration(days: 1)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () => setState(
                      () => _date = _date.add(const Duration(days: 1)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleCard() {
    return _buildSectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextFormField(
          controller: _title,
          decoration: const InputDecoration(
            hintText: 'Keterangan transaksi (opsional)',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildWithPersonCard() {
    return _buildSectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.people_outline, color: Colors.grey[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _withPersonController,
                decoration: const InputDecoration(
                  hintText: 'Dengan (opsional)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (v) => setState(
                  () => _withPerson = v.trim().isEmpty ? null : v.trim(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return _buildSectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: Colors.grey[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: 'Tetapkan lokasi (opsional)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (v) => setState(
                  () => _location = v.trim().isEmpty ? null : v.trim(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard() {
    return _buildSectionCard(
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: _reminderAt ?? now,
            firstDate: now.subtract(const Duration(days: 1)),
            lastDate: DateTime(now.year + 5),
            locale: const Locale('id', 'ID'),
          );
          if (pickedDate != null) {
            final pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(
                _reminderAt ?? now.add(const Duration(minutes: 30)),
              ),
            );
            if (pickedTime != null) {
              final dt = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
              setState(() => _reminderAt = dt);
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.alarm, color: Colors.grey[600], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _reminderAt == null
                      ? 'Tidak ada pengingat'
                      : 'Pengingat: ${DateFormat('dd/MM/yyyy HH:mm').format(_reminderAt!)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: _reminderAt == null
                        ? Colors.grey[400]
                        : Colors.black87,
                  ),
                ),
              ),
              if (_reminderAt != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _reminderAt = null),
                )
              else
                Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _photoFile != null || _photoUrl != null
          ? Column(
              children: [
                if (_photoFile != null)
                  Stack(
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(
                                  _photoFile!.path,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_photoFile!.path),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: _removePhoto,
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_uploadingPhoto)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Mengupload foto...'),
                      ],
                    ),
                  ),
              ],
            )
          : OutlinedButton.icon(
              onPressed: _uploadingPhoto ? null : _pickPhoto,
              icon: Icon(Icons.add_photo_alternate, color: Colors.green[600]),
              label: Text(
                'Tambahkan foto',
                style: TextStyle(
                  color: Colors.green[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green[600]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
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
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: _isFormValid
                ? Theme.of(context).primaryColor
                : Colors.grey[400],
            foregroundColor: Colors.white,
            elevation: _isFormValid ? 4 : 0,
            shadowColor: _isFormValid
                ? Theme.of(context).primaryColor.withOpacity(0.5)
                : Colors.transparent,
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
                    Icon(Icons.check_circle_outline, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Simpan Transaksi',
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
    );
  }

  // Utility helpers
  String _formatDate(DateTime date) {
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final dayName = days[date.weekday % 7];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$dayName, $day/$month/$year';
  }

  String _getCategoryName(
    String categoryId,
    List<Map<String, dynamic>> cats,
    Map<String, Map<String, dynamic>> catsIndex,
  ) {
    final cat = cats.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => {'name': 'Kategori'},
    );
    final name = (cat['name'] ?? 'Kategori') as String;
    final pid = cat['parentId'] as String?;
    if (pid == null) return name;
    final parentName = (catsIndex[pid]?['name'] ?? '') as String;
    if (parentName.isEmpty) return name;
    return '$parentName / $name';
  }

  IconData? _getIconDataFromString(String iconName) {
    const iconMap = <String, IconData>{
      'restaurant': Icons.restaurant,
      'local_cafe': Icons.local_cafe,
      'shopping_cart': Icons.shopping_cart,
      'local_mall': Icons.local_mall,
      'directions_car': Icons.directions_car,
      'local_gas_station': Icons.local_gas_station,
      'home': Icons.home,
      'bolt': Icons.bolt,
      'water_drop': Icons.water_drop,
      'phone_android': Icons.phone_android,
      'wifi': Icons.wifi,
      'school': Icons.school,
      'local_hospital': Icons.local_hospital,
      'fitness_center': Icons.fitness_center,
      'movie': Icons.movie,
      'sports_esports': Icons.sports_esports,
      'card_giftcard': Icons.card_giftcard,
      'pets': Icons.pets,
      'child_care': Icons.child_care,
      'work': Icons.work,
      'account_balance': Icons.account_balance,
      'attach_money': Icons.attach_money,
      'savings': Icons.savings,
      'trending_up': Icons.trending_up,
      'store': Icons.store,
      'volunteer_activism': Icons.volunteer_activism,
      'handshake': Icons.handshake,
      'redeem': Icons.redeem,
      'flight': Icons.flight,
      'hotel': Icons.hotel,
      'beach_access': Icons.beach_access,
      'attractions': Icons.attractions,
      'local_activity': Icons.local_activity,
      'celebration': Icons.celebration,
      'cake': Icons.cake,
      'flatware': Icons.flatware,
      'emoji_food_beverage': Icons.emoji_food_beverage,
      'local_pizza': Icons.local_pizza,
      'icecream': Icons.icecream,
      'ramen_dining': Icons.ramen_dining,
      'local_bar': Icons.local_bar,
      'lunch_dining': Icons.lunch_dining,
      'dinner_dining': Icons.dinner_dining,
      'fastfood': Icons.fastfood,
      'liquor': Icons.liquor,
      'coffee': Icons.coffee,
      'nightlife': Icons.nightlife,
      'brunch_dining': Icons.brunch_dining,
      'bakery_dining': Icons.bakery_dining,
      'receipt_long': Icons.receipt_long,
      'paid': Icons.paid,
      'category': Icons.category,
      'payments': Icons.payments,
      'credit_card': Icons.credit_card,
      'account_balance_wallet': Icons.account_balance_wallet,
    };
    return iconMap[iconName];
  }

  Color _getCategoryColor(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('makanan') || name.contains('makan'))
      return Colors.orange;
    if (name.contains('minuman')) return Colors.brown;
    if (name.contains('transportasi') || name.contains('transport'))
      return Colors.blue;
    if (name.contains('belanja') || name.contains('shopping'))
      return Colors.purple;
    if (name.contains('hiburan') || name.contains('entertainment'))
      return Colors.pink;
    if (name.contains('kesehatan') || name.contains('health'))
      return Colors.red;
    if (name.contains('pendidikan') || name.contains('education'))
      return Colors.indigo;
    if (name.contains('tagihan') || name.contains('bill')) return Colors.amber;
    if (name.contains('gaji') || name.contains('salary')) return Colors.green;
    if (name.contains('bonus')) return Colors.teal;
    if (name.contains('investasi')) return Colors.cyan;
    return Colors.grey;
  }

  void _showWalletPicker(
    BuildContext context,
    List<Map<String, dynamic>> wallets,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pilih Dompet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: wallets.length,
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  final isSelected = _walletId == wallet['id'];
                  final isDefault = wallet['isDefault'] == true;
                  return InkWell(
                    onTap: () {
                      setState(() => _walletId = wallet['id'] as String);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.orange.shade100,
                            radius: 24,
                            child: Text(
                              wallet['icon']?.toString() ?? '💰',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  wallet['name'] ?? 'Dompet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                if (isDefault) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Default',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventPicker(
    BuildContext context,
    List<Map<String, dynamic>> events,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih Acara',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            InkWell(
              onTap: () {
                setState(() => _eventId = null);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _eventId == null
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : null,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _eventId == null
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                      radius: 24,
                      child: Icon(
                        Icons.block,
                        color: _eventId == null
                            ? Colors.white
                            : Colors.grey[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Tanpa Acara',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_eventId == null)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final isSelected = _eventId == event['id'];
                  return InkWell(
                    onTap: () {
                      setState(() => _eventId = event['id'] as String);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.purple.shade100,
                            radius: 24,
                            child: Icon(
                              Icons.event,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.purple.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event['name'] ?? 'Acara',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    if (event['isActive'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          'AKTIF',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (event['description'] != null &&
                                    (event['description'] as String).isNotEmpty)
                                  Text(
                                    event['description'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Missing helper: get event name
  String _getEventName(String eventId, List<Map<String, dynamic>> events) {
    final ev = events.firstWhere(
      (e) => e['id'] == eventId,
      orElse: () => {'name': 'Acara'},
    );
    return (ev['name'] ?? 'Acara') as String;
  }

  // Category picker bottom sheet (simplified list view)
  void _showCategoryPicker(
    BuildContext context,
    List<Map<String, dynamic>> cats,
    Map<String, Map<String, dynamic>> catsIndex,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CategoryPickerSheet(
        categories: cats,
        catsIndex: catsIndex,
        selectedCategoryId: _categoryId,
        initialType: _type,
        onSelect: (id, type) {
          setState(() {
            _categoryId = id;
            _type = type;
          });
        },
      ),
    );
  }
}

// Hierarchical & sorted category picker sheet (restored improved UX)
class _CategoryPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final Map<String, Map<String, dynamic>> catsIndex;
  final String? selectedCategoryId;
  final TransactionType initialType;
  final void Function(String categoryId, TransactionType type) onSelect;

  const _CategoryPickerSheet({
    required this.categories,
    required this.catsIndex,
    required this.selectedCategoryId,
    required this.initialType,
    required this.onSelect,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TransactionType _currentType;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _currentType == TransactionType.expense ? 0 : 1,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentType = _tabController.index == 0
              ? TransactionType.expense
              : TransactionType.income;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered() {
    final need = _currentType == TransactionType.expense ? 'expense' : 'income';
    final list = widget.categories.where((c) {
      final t = (c['type'] ?? c['applies'] ?? 'expense').toString();
      return t == need || t == 'both';
    }).toList();
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list
        .where((c) => (c['name'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  Map<String?, List<Map<String, dynamic>>> _group(
    List<Map<String, dynamic>> list,
  ) {
    final m = <String?, List<Map<String, dynamic>>>{};
    for (final c in list) {
      final pid = c['parentId'] as String?;
      m.putIfAbsent(pid, () => []);
      m[pid]!.add(c);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final grouped = _group(filtered);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_ios, size: 18),
                        SizedBox(width: 4),
                        Text('Kembali', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Pilih Kategori',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Tabs (polished segmented look)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorPadding: const EdgeInsets.all(2),
              labelPadding: const EdgeInsets.symmetric(vertical: 6),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              isScrollable: false,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[700],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_downward, size: 16),
                      SizedBox(width: 6),
                      Text('Pengeluaran'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward, size: 16),
                      SizedBox(width: 6),
                      Text('Pemasukan'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari kategori...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _query = ''),
                        tooltip: 'Bersihkan',
                      ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Build each tab from its own filtered/grouped snapshot
                Builder(
                  builder: (context) {
                    final f = _filtered();
                    final g = _group(f);
                    return _buildList(g, scrollController);
                  },
                ),
                Builder(
                  builder: (context) {
                    // Switch current type to income temporarily for filtering in this tab
                    final prev = _currentType;
                    _currentType = TransactionType.income;
                    final f = _filtered();
                    final g = _group(f);
                    _currentType = prev; // restore
                    return _buildList(g, scrollController);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    Map<String?, List<Map<String, dynamic>>> grouped,
    ScrollController sc,
  ) {
    final parentCats = (grouped[null] ?? []).toList();
    // Prioritize makanan/minuman
    parentCats.sort((a, b) {
      final an = (a['name'] ?? '').toString().toLowerCase();
      final bn = (b['name'] ?? '').toString().toLowerCase();
      final aTop = an.contains('makanan') || an.contains('minuman');
      final bTop = bn.contains('makanan') || bn.contains('minuman');
      if (aTop && !bTop) return -1;
      if (!aTop && bTop) return 1;
      return an.compareTo(bn);
    });
    return ListView(
      controller: sc,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () async {
              Navigator.pop(context);
              await Navigator.pushNamed(context, '/categories');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    radius: 20,
                    child: Icon(Icons.settings, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Kelola kategori',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final parent in parentCats) ...[
          _buildParent(parent),
          for (final child in _sortedChildren(
            grouped[parent['id'] as String?] ?? [],
            parent,
          ))
            _buildChild(child, parent),
          const Divider(height: 1, indent: 16),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _sortedChildren(
    List<Map<String, dynamic>> list,
    Map<String, dynamic> parent,
  ) {
    final l = list.toList();
    l.sort(
      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
        (b['name'] ?? '').toString().toLowerCase(),
      ),
    );
    return l;
  }

  Widget _buildParent(Map<String, dynamic> cat) {
    final id = cat['id'] as String;
    final name = (cat['name'] ?? 'Kategori') as String;
    final iconStr = cat['icon'] as String?;
    final colorStr = cat['color'] as String?;
    Color color = _deriveColor(name, colorStr);
    final isSelected = widget.selectedCategoryId == id;
    final isEmoji = iconStr != null && _getIconDataFromString(iconStr) == null;
    final iconData = isEmoji
        ? Icons.category
        : (_getIconDataFromString(iconStr ?? '') ?? Icons.category);
    return InkWell(
      onTap: () {
        widget.onSelect(id, _currentType);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : null,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).primaryColor
                  : color.withOpacity(0.2),
              radius: 24,
              child: isEmoji
                  ? Text(iconStr ?? '', style: const TextStyle(fontSize: 24))
                  : Icon(
                      iconData,
                      color: isSelected ? Colors.white : color,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildChild(Map<String, dynamic> cat, Map<String, dynamic> parent) {
    final id = cat['id'] as String;
    final name = (cat['name'] ?? '') as String;
    final iconStr = cat['icon'] as String?;
    final colorStr = cat['color'] as String?;
    Color color = _deriveColor(
      name,
      colorStr,
      fallbackParent: parent['color'] as String?,
    );
    final isSelected = widget.selectedCategoryId == id;
    final isEmoji = iconStr != null && _getIconDataFromString(iconStr) == null;
    final iconData = isEmoji
        ? Icons.category_outlined
        : (_getIconDataFromString(iconStr ?? '') ?? Icons.category_outlined);
    return InkWell(
      onTap: () {
        widget.onSelect(id, _currentType);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.08)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.15)
                      : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isEmoji
                      ? Text(
                          iconStr ?? '',
                          style: const TextStyle(fontSize: 20),
                        )
                      : Icon(
                          iconData,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : color,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _deriveColor(String name, String? colorHex, {String? fallbackParent}) {
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        return Color(int.parse(colorHex.replaceAll('#', ''), radix: 16));
      } catch (_) {}
    }
    if (fallbackParent != null && fallbackParent.isNotEmpty) {
      try {
        return Color(int.parse(fallbackParent.replaceAll('#', ''), radix: 16));
      } catch (_) {}
    }
    final lower = name.toLowerCase();
    if (lower.contains('makan')) return Colors.orange;
    if (lower.contains('minum')) return Colors.brown;
    if (lower.contains('transport')) return Colors.blue;
    if (lower.contains('belanja')) return Colors.purple;
    if (lower.contains('hiburan')) return Colors.pink;
    if (lower.contains('kesehatan')) return Colors.red;
    if (lower.contains('pendidikan')) return Colors.indigo;
    if (lower.contains('tagihan') || lower.contains('bill'))
      return Colors.amber;
    if (lower.contains('gaji') || lower.contains('salary')) return Colors.green;
    if (lower.contains('bonus')) return Colors.teal;
    if (lower.contains('invest')) return Colors.cyan;
    return Colors.grey;
  }

  IconData? _getIconDataFromString(String iconName) {
    const iconMap = <String, IconData>{
      'restaurant': Icons.restaurant,
      'local_cafe': Icons.local_cafe,
      'shopping_cart': Icons.shopping_cart,
      'local_mall': Icons.local_mall,
      'directions_car': Icons.directions_car,
      'local_gas_station': Icons.local_gas_station,
      'home': Icons.home,
      'bolt': Icons.bolt,
      'water_drop': Icons.water_drop,
      'phone_android': Icons.phone_android,
      'wifi': Icons.wifi,
      'school': Icons.school,
      'local_hospital': Icons.local_hospital,
      'fitness_center': Icons.fitness_center,
      'movie': Icons.movie,
      'sports_esports': Icons.sports_esports,
      'card_giftcard': Icons.card_giftcard,
      'pets': Icons.pets,
      'child_care': Icons.child_care,
      'work': Icons.work,
      'account_balance': Icons.account_balance,
      'attach_money': Icons.attach_money,
      'savings': Icons.savings,
      'trending_up': Icons.trending_up,
      'store': Icons.store,
      'volunteer_activism': Icons.volunteer_activism,
      'handshake': Icons.handshake,
      'redeem': Icons.redeem,
      'flight': Icons.flight,
      'hotel': Icons.hotel,
      'beach_access': Icons.beach_access,
      'attractions': Icons.attractions,
      'local_activity': Icons.local_activity,
      'celebration': Icons.celebration,
      'cake': Icons.cake,
      'flatware': Icons.flatware,
      'emoji_food_beverage': Icons.emoji_food_beverage,
      'local_pizza': Icons.local_pizza,
      'icecream': Icons.icecream,
      'ramen_dining': Icons.ramen_dining,
      'local_bar': Icons.local_bar,
      'lunch_dining': Icons.lunch_dining,
      'dinner_dining': Icons.dinner_dining,
      'fastfood': Icons.fastfood,
      'liquor': Icons.liquor,
      'coffee': Icons.coffee,
      'nightlife': Icons.nightlife,
      'brunch_dining': Icons.brunch_dining,
      'bakery_dining': Icons.bakery_dining,
      'receipt_long': Icons.receipt_long,
      'paid': Icons.paid,
      'category': Icons.category,
      'payments': Icons.payments,
      'credit_card': Icons.credit_card,
      'account_balance_wallet': Icons.account_balance_wallet,
    };
    return iconMap[iconName];
  }
}
