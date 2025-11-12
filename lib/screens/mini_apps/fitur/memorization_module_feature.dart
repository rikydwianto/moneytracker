import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MemorizationStatus { inProgress, mastered, review, repeat }

class CatalogItem {
  final String id; // e.g. prayer:doa_sebelum_makan, surah:al-ikhlas
  final String type; // 'prayer' | 'surah'
  final String categoryId; // 'daily_prayers' | 'short_surahs'
  final String title;
  final String arabic;
  final String latin;
  final String translation;
  final int order;
  const CatalogItem({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.title,
    required this.arabic,
    required this.latin,
    required this.translation,
    required this.order,
  });
}

class MemorizationEntry {
  final String id; // childId:itemId
  final String childId; // default
  final String itemId;
  final double progress; // 0.0 - 1.0
  final MemorizationStatus status;
  final DateTime? lastReviewedAt;
  final String? notes;
  final int growthPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemorizationEntry({
    required this.id,
    required this.childId,
    required this.itemId,
    required this.progress,
    required this.status,
    required this.lastReviewedAt,
    required this.notes,
    required this.growthPoints,
    required this.createdAt,
    required this.updatedAt,
  });

  MemorizationEntry copyWith({
    double? progress,
    MemorizationStatus? status,
    DateTime? lastReviewedAt,
    String? notes,
    int? growthPoints,
    DateTime? updatedAt,
  }) => MemorizationEntry(
    id: id,
    childId: childId,
    itemId: itemId,
    progress: progress ?? this.progress,
    status: status ?? this.status,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    notes: notes ?? this.notes,
    growthPoints: growthPoints ?? this.growthPoints,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'childId': childId,
    'itemId': itemId,
    'progress': progress,
    'status': status.name,
    'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    'notes': notes,
    'growthPoints': growthPoints,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  static MemorizationEntry fromJson(Map<String, dynamic> m) =>
      MemorizationEntry(
        id: m['id'] as String,
        childId: m['childId'] as String,
        itemId: m['itemId'] as String,
        progress: (m['progress'] as num).toDouble(),
        status: MemorizationStatus.values.firstWhere(
          (e) => e.name == m['status'],
          orElse: () => MemorizationStatus.inProgress,
        ),
        lastReviewedAt: m['lastReviewedAt'] == null
            ? null
            : DateTime.parse(m['lastReviewedAt'] as String),
        notes: m['notes'] as String?,
        growthPoints: (m['growthPoints'] as num).toInt(),
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}

class MemorizationModuleFeature extends StatefulWidget {
  final String heroTag;
  final Color color;
  final String? initialCategory; // 'daily_prayers' | 'short_surahs'
  final String? initialSearch; // prefill search box
  const MemorizationModuleFeature({
    super.key,
    required this.heroTag,
    required this.color,
    this.initialCategory,
    this.initialSearch,
  });

  @override
  State<MemorizationModuleFeature> createState() =>
      _MemorizationModuleFeatureState();
}

class _MemorizationModuleFeatureState extends State<MemorizationModuleFeature> {
  static const _prefsKey = 'miniapps.memorization.entries';
  static const defaultChild = 'default';

  final _searchCtrl = TextEditingController();
  String _tab = 'daily_prayers'; // or 'short_surahs'
  bool _loading = true;
  List<MemorizationEntry> _entries = [];

  // Seed minimal catalog
  late final List<CatalogItem> _catalog = [
    // Daily prayers
    CatalogItem(
      id: 'prayer:doa_sebelum_makan',
      type: 'prayer',
      categoryId: 'daily_prayers',
      title: 'Doa Sebelum Makan',
      arabic: 'اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا',
      latin: 'Allahumma bārik lanā fīmā razaqtanā',
      translation: 'Ya Allah berkahilah rezeki yang Engkau berikan kepada kami',
      order: 1,
    ),
    CatalogItem(
      id: 'prayer:doa_setelah_makan',
      type: 'prayer',
      categoryId: 'daily_prayers',
      title: 'Doa Setelah Makan',
      arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا',
      latin: 'Alhamdulillāhil-ladzī ath`amanā wasaqānā',
      translation:
          'Segala puji bagi Allah yang telah memberi kami makan dan minum',
      order: 2,
    ),
    // Short surahs
    CatalogItem(
      id: 'surah:al-ikhlas',
      type: 'surah',
      categoryId: 'short_surahs',
      title: 'Al-Ikhlāṣ',
      arabic: 'قُلْ هُوَ اللّٰهُ اَحَدٌ',
      latin: 'Qul huwallāhu aḥad',
      translation: 'Katakanlah (Muhammad), Dialah Allah, Yang Maha Esa',
      order: 1,
    ),
    CatalogItem(
      id: 'surah:an-nas',
      type: 'surah',
      categoryId: 'short_surahs',
      title: 'An-Nās',
      arabic: 'قُلْ اَعُوْذُ بِرَبِّ النَّاسِ',
      latin: 'Qul a‘ūdzu birabbin-nās',
      translation: 'Katakanlah: Aku berlindung kepada Tuhan manusia',
      order: 2,
    ),
    CatalogItem(
      id: 'prayer:doa_pagi',
      type: 'prayer',
      categoryId: 'daily_prayers',
      title: 'Doa Pagi',
      arabic: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
      latin: 'Ashbahnā wa ashbaha al-mulku lillāh',
      translation: 'Kami telah memasuki pagi dan kerajaan milik Allah',
      order: 3,
    ),
    CatalogItem(
      id: 'prayer:doa_makan',
      type: 'prayer',
      categoryId: 'daily_prayers',
      title: 'Doa Makan',
      arabic: 'اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا',
      latin: 'Allahumma bārik lanā fīmā razaqtanā',
      translation: 'Ya Allah berkahilah rezeki yang Engkau berikan kepada kami',
      order: 4,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Apply initial deep-link params before loading data
    if (widget.initialCategory == 'daily_prayers' ||
        widget.initialCategory == 'short_surahs') {
      _tab = widget.initialCategory!;
    }
    if ((widget.initialSearch ?? '').isNotEmpty) {
      _searchCtrl.text = widget.initialSearch!;
    }
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(MemorizationEntry.fromJson)
          .toList();
      _entries = list;
    }
    setState(() => _loading = false);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  MemorizationEntry _getOrCreateEntry(String itemId) {
    final id = '$defaultChild:$itemId';
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx >= 0) return _entries[idx];
    final now = DateTime.now();
    final entry = MemorizationEntry(
      id: id,
      childId: defaultChild,
      itemId: itemId,
      progress: 0.0,
      status: MemorizationStatus.inProgress,
      lastReviewedAt: null,
      notes: null,
      growthPoints: 0,
      createdAt: now,
      updatedAt: now,
    );
    _entries = [entry, ..._entries];
    return entry;
  }

  void _review(String itemId) {
    final entry = _getOrCreateEntry(itemId);
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    final updated = entry.copyWith(
      lastReviewedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    setState(() => _entries[idx] = updated);
    _persist();
  }

  void _increment(String itemId) {
    final entry = _getOrCreateEntry(itemId);
    // Gate: if needed, enforce review first (simple rule: if never reviewed and progress > 0)
    if (entry.progress > 0 &&
        (entry.lastReviewedAt == null || !_isToday(entry.lastReviewedAt!))) {
      _showSnackbar('Review dulu sebelum menambah hafalan.');
      return;
    }
    final next = (entry.progress + 0.01).clamp(0.0, 1.0);
    final isGain = next > entry.progress;
    final newStatus = next >= 1.0 ? MemorizationStatus.mastered : entry.status;
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    final updated = entry.copyWith(
      progress: next,
      status: newStatus,
      growthPoints: isGain ? (entry.growthPoints + 1) : entry.growthPoints,
      updatedAt: DateTime.now(),
    );
    setState(() => _entries[idx] = updated);
    _persist();
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return now.year == d.year && now.month == d.month && now.day == d.day;
  }

  Iterable<CatalogItem> _filteredCatalog() {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _catalog
        .where((c) => c.categoryId == _tab)
        .where(
          (c) =>
              q.isEmpty ||
              c.title.toLowerCase().contains(q) ||
              c.translation.toLowerCase().contains(q),
        );
  }

  double _progressFor(String itemId) {
    final id = '$defaultChild:$itemId';
    final e = _entries.firstWhere(
      (x) => x.id == id,
      orElse: () => _getOrCreateEntry(itemId),
    );
    return e.progress;
  }

  MemorizationStatus _statusFor(String itemId) {
    final id = '$defaultChild:$itemId';
    final e = _entries.firstWhere(
      (x) => x.id == id,
      orElse: () => _getOrCreateEntry(itemId),
    );
    return e.status;
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doa & Surat Pendek + Hafalan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Doa Harian'),
                selected: _tab == 'daily_prayers',
                onSelected: (_) => setState(() => _tab = 'daily_prayers'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Surat Pendek'),
                selected: _tab == 'short_surahs',
                onSelected: (_) => setState(() => _tab = 'short_surahs'),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Cari...',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _filteredCatalog().length,
              itemBuilder: (context, i) {
                final item = _filteredCatalog().elementAt(i);
                final prog = _progressFor(item.id);
                final status = _statusFor(item.id);
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(prog * 100).toStringAsFixed(0)}%',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.arabic,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.latin,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 6),
                        Text(item.translation),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _review(item.id),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Review'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _increment(item.id),
                              icon: const Icon(Icons.trending_up),
                              label: const Text('+1%'),
                            ),
                            const Spacer(),
                            Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: status == MemorizationStatus.mastered
                                    ? Colors.green
                                    : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: _loading ? null : _buildFooter(),
    );
  }

  Widget _buildFooter() {
    final all = _entries.isEmpty
        ? 0.0
        : _entries.map((e) => e.progress).reduce((a, b) => a + b);
    final totalCatalog = _catalog.length.toDouble();
    final overall = totalCatalog == 0 ? 0.0 : (all / totalCatalog);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
        children: [
          const Text('Progress Total'),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(value: overall.clamp(0.0, 1.0)),
          ),
          const SizedBox(width: 12),
          Text('${(overall * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  String _statusLabel(MemorizationStatus s) {
    switch (s) {
      case MemorizationStatus.inProgress:
        return 'Proses';
      case MemorizationStatus.mastered:
        return 'Selesai';
      case MemorizationStatus.review:
        return 'Review';
      case MemorizationStatus.repeat:
        return 'Ulangi';
    }
  }
}
