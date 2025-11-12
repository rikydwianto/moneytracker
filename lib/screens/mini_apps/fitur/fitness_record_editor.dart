import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class FitnessRecordEditor extends StatefulWidget {
  final String uid;
  final String basePath; // users/{uid}/miniApps/kebugaran/fitness
  final Color color;
  final String? initialDateKey; // 'YYYY-MM-DD'
  final double? initialWeight;
  final double? initialHeight;
  final String? initialNote;
  const FitnessRecordEditor({
    super.key,
    required this.uid,
    required this.basePath,
    required this.color,
    this.initialDateKey,
    this.initialWeight,
    this.initialHeight,
    this.initialNote,
  });

  @override
  State<FitnessRecordEditor> createState() => _FitnessRecordEditorState();
}

class _FitnessRecordEditorState extends State<FitnessRecordEditor> {
  late DateTime _date;
  late TextEditingController _wC;
  late TextEditingController _hC;
  late TextEditingController _noteC;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.initialDateKey != null) {
      final parts = widget.initialDateKey!.split('-').map(int.parse).toList();
      _date = DateTime(parts[0], parts[1], parts[2]);
    } else {
      _date = DateTime(now.year, now.month, now.day);
    }
    _wC = TextEditingController(text: widget.initialWeight?.toString() ?? '');
    _hC = TextEditingController(text: widget.initialHeight?.toString() ?? '');
    _noteC = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _wC.dispose();
    _hC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final w = double.tryParse(_wC.text.trim());
    final h = double.tryParse(_hC.text.trim());
    if (w == null || h == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan angka yang valid')),
      );
      return;
    }
    final dateKey = _fmt(_date);
    final ref = FirebaseDatabase.instance.ref(
      '${widget.basePath}/records/$dateKey',
    );
    try {
      await ref.set({
        'weight': w,
        'height': h,
        'timestamp': DateTime(
          _date.year,
          _date.month,
          _date.day,
        ).millisecondsSinceEpoch,
        'note': _noteC.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Kebugaran'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_alt)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Header modern
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(0.85),
                  widget.color.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tambah / Ubah',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tanggal: ${_fmt(_date)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                  onPressed: _pickDate,
                  child: const Text('Pilih Tanggal'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Form fields
          TextField(
            controller: _wC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Berat (kg)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.monitor_weight_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tinggi (cm)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.height),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteC,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Keterangan (opsional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
