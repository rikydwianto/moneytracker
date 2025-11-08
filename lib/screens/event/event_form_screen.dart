import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/event.dart';
import '../../services/event_service.dart';
import '../../utils/idr.dart';
import '../../utils/date_helpers.dart';

class EventFormScreen extends StatefulWidget {
  final Event? eventToEdit;

  const EventFormScreen({super.key, this.eventToEdit});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  late TextEditingController _nameController;
  late TextEditingController _budgetController;
  late TextEditingController _notesController;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;
    _nameController = TextEditingController(text: event?.name ?? '');
    _budgetController = TextEditingController(
      text: event?.budget != null ? IdrFormatters.format(event!.budget!) : '',
    );
    _notesController = TextEditingController(text: event?.notes ?? '');
    _startDate = event?.startDate;
    _endDate = event?.endDate;
    _isActive = event?.isActive ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final budgetText = _budgetController.text.trim();
      final budget = budgetText.isEmpty
          ? null
          : IdrFormatters.parse(budgetText);

      final now = DateTime.now();
      final event = Event(
        id: widget.eventToEdit?.id ?? '',
        name: _nameController.text.trim(),
        isActive: _isActive,
        startDate: _startDate,
        endDate: _endDate,
        budget: budget,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        userId: userId,
        createdAt: widget.eventToEdit?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.eventToEdit == null) {
        await _eventService.createEvent(event);
      } else {
        await _eventService.updateEvent(event);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.eventToEdit == null
                  ? 'Acara berhasil dibuat'
                  : 'Acara berhasil diperbarui',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateHelpers.longDate;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventToEdit == null ? 'Acara Baru' : 'Edit Acara'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
              tooltip: 'Simpan',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Acara',
                hintText: 'Misal: Pernikahan, Liburan, Arisan',
                prefixIcon: Icon(Icons.event),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama acara wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Start Date
            InkWell(
              onTap: () => _pickDate(true),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal Mulai (Opsional)',
                  prefixIcon: Icon(Icons.calendar_today),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                child: Text(
                  _startDate == null
                      ? 'Pilih tanggal mulai'
                      : dateFormat.format(_startDate!),
                  style: TextStyle(
                    color: _startDate == null ? Colors.grey : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // End Date
            InkWell(
              onTap: () => _pickDate(false),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal Selesai (Opsional)',
                  prefixIcon: Icon(Icons.event_available),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                child: Text(
                  _endDate == null
                      ? 'Pilih tanggal selesai'
                      : dateFormat.format(_endDate!),
                  style: TextStyle(
                    color: _endDate == null ? Colors.grey : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Budget field
            TextFormField(
              controller: _budgetController,
              decoration: const InputDecoration(
                labelText: 'Budget (Opsional)',
                hintText: 'Rp 0',
                prefixIcon: Icon(Icons.account_balance_wallet),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                IdrFormatters.rupiahInputFormatter(withSymbol: true),
              ],
            ),
            const SizedBox(height: 16),

            // Notes field
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan (Opsional)',
                hintText: 'Deskripsi atau catatan acara',
                prefixIcon: Icon(Icons.notes),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Active toggle
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text('Aktifkan Acara'),
                subtitle: const Text(
                  'Transaksi baru akan otomatis terhubung ke acara ini',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isActive,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
                secondary: Icon(
                  _isActive ? Icons.toggle_on : Icons.toggle_off_outlined,
                  color: _isActive
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(widget.eventToEdit == null ? 'Buat Acara' : 'Simpan'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
