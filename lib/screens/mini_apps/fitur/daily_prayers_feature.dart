// bisa menyambung ke setoran hafalan

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'memorization_module_feature.dart';

class DailyPrayer {
  final String id;
  final String title;
  final String arabicText;
  final String latinText;
  final String translation;
  final String category;
  final bool isFavorite;

  const DailyPrayer({
    required this.id,
    required this.title,
    required this.arabicText,
    required this.latinText,
    required this.translation,
    required this.category,
    required this.isFavorite,
  });

  DailyPrayer copyWith({bool? isFavorite}) => DailyPrayer(
    id: id,
    title: title,
    arabicText: arabicText,
    latinText: latinText,
    translation: translation,
    category: category,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'arabicText': arabicText,
    'latinText': latinText,
    'translation': translation,
    'category': category,
    'isFavorite': isFavorite,
  };
  static DailyPrayer fromJson(Map<String, dynamic> m) => DailyPrayer(
    id: m['id'] as String,
    title: m['title'] as String,
    arabicText: m['arabicText'] as String,
    latinText: m['latinText'] as String,
    translation: m['translation'] as String,
    category: m['category'] as String,
    isFavorite: m['isFavorite'] as bool,
  );
}

class DailyPrayersFeature extends StatefulWidget {
  final String heroTag;
  final Color color;
  const DailyPrayersFeature({
    super.key,
    required this.heroTag,
    required this.color,
  });

  @override
  State<DailyPrayersFeature> createState() => _DailyPrayersFeatureState();
}

class _DailyPrayersFeatureState extends State<DailyPrayersFeature> {
  static const _prefsKey = 'miniapps.daily_prayers.items';
  List<DailyPrayer> _items = [];
  String _categoryFilter = 'Semua';
  String _search = '';
  bool _loading = true;
  String _tab = 'doa'; // 'doa' | 'surah'

  // Minimal seed for Surat Pendek (static, not persisted for now)
  final List<DailyPrayer> _surahItems = const [
    DailyPrayer(
      id: 'surah:al-ikhlas',
      title: 'Al-Ikhlāṣ',
      arabicText: 'قُلْ هُوَ اللّٰهُ اَحَدٌ',
      latinText: 'Qul huwallāhu aḥad',
      translation: 'Katakanlah (Muhammad), Dialah Allah, Yang Maha Esa',
      category: 'Surat Pendek',
      isFavorite: false,
    ),
    DailyPrayer(
      id: 'surah:an-nas',
      title: 'An-Nās',
      arabicText: 'قُلْ اَعُوْذُ بِرَبِّ النَّاسِ',
      latinText: 'Qul a‘ūdzu birabbin-nās',
      translation: 'Katakanlah: Aku berlindung kepada Tuhan manusia',
      category: 'Surat Pendek',
      isFavorite: false,
    ),
  ];

  final List<String> _categories = const [
    'Semua',
    'Pagi',
    'Petang',
    'Makan',
    'Tidur',
    'Perjalanan',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(DailyPrayer.fromJson)
          .toList();
      setState(() => _items = list);
    } else {
      // Seed a few examples on first run
      _items = [
        DailyPrayer(
          id: 'pagi-1',
          title: 'Doa Pagi',
          arabicText: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
          latinText: 'Ashbahnaa wa ashbahal mulku lillah',
          translation:
              'Kami telah memasuki waktu pagi dan kerajaan milik Allah',
          category: 'Pagi',
          isFavorite: false,
        ),
        DailyPrayer(
          id: 'makan-1',
          title: 'Doa Makan',
          arabicText: 'اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا',
          latinText: 'Allahumma barik lana fima razaqtana',
          translation:
              'Ya Allah berkahilah rezeki yang Engkau berikan kepada kami',
          category: 'Makan',
          isFavorite: false,
        ),
      ];
      await _persist();
      setState(() {});
    }
    setState(() => _loading = false);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  Iterable<DailyPrayer> _filtered() {
    return _items.where((p) {
      final matchCat =
          _categoryFilter == 'Semua' || p.category == _categoryFilter;
      final q = _search.trim().toLowerCase();
      final matchText =
          q.isEmpty ||
          p.title.toLowerCase().contains(q) ||
          p.translation.toLowerCase().contains(q);
      return matchCat && matchText;
    });
  }

  Iterable<DailyPrayer> _filteredSurah() {
    final q = _search.trim().toLowerCase();
    return _surahItems.where(
      (s) =>
          q.isEmpty ||
          s.title.toLowerCase().contains(q) ||
          s.translation.toLowerCase().contains(q),
    );
  }

  Future<void> _toggleFav(String id) async {
    setState(() {
      _items = _items
          .map((e) => e.id == id ? e.copyWith(isFavorite: !e.isFavorite) : e)
          .toList();
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doa Harian & Surat Pendek'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Doa Harian'),
                  selected: _tab == 'doa',
                  onSelected: (_) => setState(() => _tab = 'doa'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Surat Pendek'),
                  selected: _tab == 'surah',
                  onSelected: (_) => setState(() => _tab = 'surah'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Cari...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                if (_tab == 'doa')
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, i) {
                        final c = _categories[i];
                        final sel = c == _categoryFilter;
                        return ChoiceChip(
                          label: Text(c),
                          selected: sel,
                          onSelected: (_) =>
                              setState(() => _categoryFilter = c),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemCount: _categories.length,
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _tab == 'doa'
                        ? _filtered().length
                        : _filteredSurah().length,
                    itemBuilder: (context, i) {
                      final p = (_tab == 'doa'
                          ? _filtered().elementAt(i)
                          : _filteredSurah().elementAt(i));
                      return Card(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _toggleFav(p.id),
                                    icon: Icon(
                                      p.isFavorite
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.arabicText,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.latinText,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(p.translation),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
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
                                      child: Text(p.category),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () {
                                      final initialCategory = _tab == 'doa'
                                          ? 'daily_prayers'
                                          : 'short_surahs';
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MemorizationModuleFeature(
                                                heroTag:
                                                    'miniapp-memorization_module',
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                initialCategory:
                                                    initialCategory,
                                                initialSearch: p.title,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.self_improvement),
                                    label: const Text('Hafalkan'),
                                  ),
                                ],
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
    );
  }
}
