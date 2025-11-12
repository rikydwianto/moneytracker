import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/firebase_bootstrap.dart';

class DoaVerse {
  final String arabic;
  final String latin;
  final String translation;
  const DoaVerse({
    required this.arabic,
    this.latin = '',
    this.translation = '',
  });

  factory DoaVerse.fromMap(Map data) => DoaVerse(
    arabic: (data['arabic'] as String?) ?? '',
    latin: (data['latin'] as String?) ?? '',
    translation: (data['translation'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'arabic': arabic,
    'latin': latin,
    'translation': translation,
  };
}

class DoaItem {
  final String id;
  final String title;
  final String arabic;
  final String latin;
  final String translation;
  final List<DoaVerse> verses;
  final String type; // 'doa' or 'surah'
  final String category; // e.g. 'Doa Harian', 'Surat Pendek', ...
  final String? createdByUid;
  final String? createdByName;
  final int? createdAt;
  const DoaItem({
    required this.id,
    required this.title,
    required this.arabic,
    required this.latin,
    required this.translation,
    this.verses = const [],
    this.type = 'doa',
    this.category = 'Umum',
    this.createdByUid,
    this.createdByName,
    this.createdAt,
  });

  factory DoaItem.fromMap(String id, Map data) => DoaItem(
    id: id,
    title: (data['title'] as String?) ?? id,
    arabic: (data['arabic'] as String?) ?? '',
    latin: (data['latin'] as String?) ?? '',
    translation: (data['translation'] as String?) ?? '',
    verses: (data['verses'] is List)
        ? ((data['verses'] as List)
              .whereType<Map>()
              .map((m) => DoaVerse.fromMap(m))
              .toList())
        : const [],
    type:
        (data['type'] as String?) ??
        ((data['verses'] is List && (data['verses'] as List).isNotEmpty)
            ? 'surah'
            : 'doa'),
    category:
        (data['category'] as String?) ??
        ((data['verses'] is List && (data['verses'] as List).isNotEmpty)
            ? 'Surat Pendek'
            : 'Doa Harian'),
    createdByUid: data['createdByUid'] as String?,
    createdByName: data['createdByName'] as String?,
    createdAt: (data['createdAt'] is int) ? data['createdAt'] as int : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'arabic': arabic,
    'latin': latin,
    'translation': translation,
    if (verses.isNotEmpty) 'verses': verses.map((v) => v.toJson()).toList(),
    'type': type,
    'category': category,
    if (createdByUid != null) 'createdByUid': createdByUid,
    if (createdByName != null) 'createdByName': createdByName,
    if (createdAt != null) 'createdAt': createdAt,
  };
  static DoaItem fromJson(Map<String, dynamic> m) => DoaItem(
    id: m['id'] as String,
    title: m['title'] as String,
    arabic: m['arabic'] as String,
    latin: m['latin'] as String,
    translation: m['translation'] as String,
    verses: (m['verses'] is List)
        ? ((m['verses'] as List)
              .whereType<Map<String, dynamic>>()
              .map(
                (mm) => DoaVerse(
                  arabic: (mm['arabic'] as String?) ?? '',
                  latin: (mm['latin'] as String?) ?? '',
                  translation: (mm['translation'] as String?) ?? '',
                ),
              )
              .toList())
        : const [],
    type:
        (m['type'] as String?) ??
        (m['verses'] is List && (m['verses'] as List).isNotEmpty
            ? 'surah'
            : 'doa'),
    category:
        (m['category'] as String?) ??
        (m['verses'] is List && (m['verses'] as List).isNotEmpty
            ? 'Surat Pendek'
            : 'Doa Harian'),
    createdByUid: m['createdByUid'] as String?,
    createdByName: m['createdByName'] as String?,
    createdAt: (m['createdAt'] is int) ? m['createdAt'] as int : null,
  );
}

class DoaListFeature extends StatefulWidget {
  final String heroTag;
  final Color color;
  const DoaListFeature({super.key, required this.heroTag, required this.color});

  @override
  State<DoaListFeature> createState() => _DoaListFeatureState();
}

class _DoaListFeatureState extends State<DoaListFeature> {
  static const _cacheKey = 'miniapps.global_doa_list';
  // Ganti dengan UID admin Anda setelah mengetahui auth.uid hasil anonymous / email login admin.
  static const String kAdminUid = '7ekW10BRpxYRTYfxvyDT3XXfgZW2';
  List<DoaItem> _items = [];
  bool _loading = true;
  String _search = '';
  String? _uid;
  String _typeFilter = 'all'; // all | doa | surah
  static const List<String> _categories = [
    'Doa Harian',
    'Adab',
    'Surat Pendek',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        _items = (jsonDecode(cached) as List)
            .cast<Map<String, dynamic>>()
            .map(DoaItem.fromJson)
            .toList();
      } catch (_) {}
    }
    try {
      await FirebaseBootstrap.ensureAll();
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      _uid = user?.uid;
      final ref = FirebaseDatabase.instance.ref('doa_pendek/isi');
      await ref.keepSynced(true);
      final snap = await ref.get();
      if (snap.exists && snap.value is Map) {
        final map = (snap.value as Map).cast<String, dynamic>();
        final list = map.entries
            .map(
              (e) => DoaItem.fromMap(
                e.key,
                (e.value as Map).cast<String, dynamic>(),
              ),
            )
            .toList();
        list.sort((a, b) => a.id.compareTo(b.id));
        _items = list;
        await prefs.setString(
          _cacheKey,
          jsonEncode(_items.map((e) => e.toJson()).toList()),
        );
      }
    } catch (e) {
      // offline fallback uses cache
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  bool get _isAdmin => _uid == kAdminUid;

  Future<void> _showAddDialog() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya admin yang dapat menambah data.')),
      );
      return;
    }
    final titleC = TextEditingController();
    final arabicC = TextEditingController();
    final latinC = TextEditingController();
    final transC = TextEditingController();
    String type = 'doa';
    String category = 'Doa Harian';
    final verses = <Map<String, TextEditingController>>[];

    void addVerseRow() {
      verses.add({
        'arabic': TextEditingController(),
        'latin': TextEditingController(),
        'translation': TextEditingController(),
      });
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Tambah Entri',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Doa'),
                          selected: type == 'doa',
                          onSelected: (_) => setS(() => type = 'doa'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Surat'),
                          selected: type == 'surah',
                          onSelected: (_) => setS(() => type = 'surah'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleC,
                      decoration: const InputDecoration(
                        labelText: 'Judul',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setS(() => category = v ?? category),
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (type == 'doa') ...[
                      TextField(
                        controller: arabicC,
                        decoration: const InputDecoration(
                          labelText: 'Arab (opsional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: latinC,
                        decoration: const InputDecoration(
                          labelText: 'Latin (opsional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: transC,
                        decoration: const InputDecoration(
                          labelText: 'Terjemahan (minimal diisi)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Text('Ayat-ayat'),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () {
                              setS(addVerseRow);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah Ayat'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(verses.length, (i) {
                        final map = verses[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Ayat ${i + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () {
                                        setS(() => verses.removeAt(i));
                                      },
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                TextField(
                                  controller: map['arabic']!,
                                  decoration: const InputDecoration(
                                    labelText: 'Arab',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 2,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: map['latin']!,
                                  decoration: const InputDecoration(
                                    labelText: 'Latin (opsional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: map['translation']!,
                                  decoration: const InputDecoration(
                                    labelText: 'Terjemahan',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final title = titleC.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Judul wajib diisi'),
                              ),
                            );
                            return;
                          }
                          if (type == 'doa') {
                            if (arabicC.text.trim().isEmpty &&
                                transC.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Isi doa minimal terjemahan'),
                                ),
                              );
                              return;
                            }
                          } else {
                            if (verses.isEmpty ||
                                verses.first['arabic']!.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Minimal 1 ayat diisi (Arab)'),
                                ),
                              );
                              return;
                            }
                          }
                          try {
                            final ref = FirebaseDatabase.instance.ref(
                              'doa_pendek/isi',
                            );
                            String slug = title
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                                .replaceAll(RegExp(r'_+'), '_');
                            slug = slug.replaceAll(RegExp(r'^_+|_+$'), '');
                            final id =
                                '${type}_${slug}_${DateTime.now().millisecondsSinceEpoch}';
                            final payload = <String, dynamic>{
                              'title': title,
                              'type': type,
                              'category': category,
                              'createdByUid': _uid,
                              'createdByName':
                                  FirebaseAuth
                                      .instance
                                      .currentUser
                                      ?.displayName ??
                                  (_isAdmin ? 'Admin' : 'User'),
                              'createdAt': ServerValue.timestamp,
                            };
                            if (type == 'doa') {
                              payload.addAll({
                                'arabic': arabicC.text.trim(),
                                'latin': latinC.text.trim(),
                                'translation': transC.text.trim(),
                              });
                            } else {
                              payload['verses'] = verses
                                  .map(
                                    (m) => {
                                      'arabic': m['arabic']!.text.trim(),
                                      'latin': m['latin']!.text.trim(),
                                      'translation': m['translation']!.text
                                          .trim(),
                                    },
                                  )
                                  .toList();
                            }
                            await ref.child(id).set(payload);
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Entri tersimpan'),
                                ),
                              );
                              await _load();
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Gagal simpan: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _seedBulkIfEmpty() async {
    try {
      await FirebaseBootstrap.ensureAll();
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      _uid = user?.uid;
      if (!_isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bukan admin. UID: ${_uid ?? '-'}')),
        );
        return;
      }
      final ref = FirebaseDatabase.instance.ref('doa_pendek/isi');
      final snap = await ref.get();
      if (snap.exists && snap.value is Map && (snap.value as Map).isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data sudah ada. Tidak menimpa.')),
        );
        return;
      }
      // Dataset awal (bisa diperluas)
      final payload = <String, dynamic>{
        'doa_sebelum_makan': {
          'title': 'Doa Sebelum Makan',
          'arabic': 'اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا',
          'latin': 'Allahumma bārik lanā fīmā razaqtanā',
          'translation':
              'Ya Allah berkahilah rezeki yang Engkau berikan kepada kami',
          'type': 'doa',
          'category': 'Doa Harian',
        },
        'doa_setelah_makan': {
          'title': 'Doa Setelah Makan',
          'arabic': 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا',
          'latin': 'Alhamdulillāhil-ladzī ath`amanā wasaqānā',
          'translation':
              'Segala puji bagi Allah yang telah memberi kami makan dan minum',
          'type': 'doa',
          'category': 'Doa Harian',
        },
        'doa_sebelum_tidur': {
          'title': 'Doa Sebelum Tidur',
          'arabic': 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
          'latin': 'Bismikallāhumma amūtu wa aḥyā',
          'translation': 'Dengan nama-Mu ya Allah aku mati dan aku hidup',
          'type': 'doa',
          'category': 'Doa Harian',
        },
        'doa_bangun_tidur': {
          'title': 'Doa Bangun Tidur',
          'arabic':
              'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا',
          'latin': 'Alhamdulillāhil-ladzī aḥyānā ba‘da mā amātanā',
          'translation':
              'Segala puji bagi Allah yang menghidupkan kami setelah mematikan kami',
          'type': 'doa',
          'category': 'Doa Harian',
        },
        'doa_masuk_rumah': {
          'title': 'Doa Masuk Rumah',
          'arabic': 'اللهم إني أسألك خير المولج وخير المخرج',
          'latin':
              'Allahumma inni as’aluka khairal maulaji wa khairal makhraji',
          'translation':
              'Ya Allah aku memohon kepada-Mu kebaikan saat masuk dan keluar rumah',
          'type': 'doa',
          'category': 'Doa Harian',
        },
        'doa_keluar_rumah': {
          'title': 'Doa Keluar Rumah',
          'arabic':
              'بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ، لا حَوْلَ وَلا قُوَّةَ إِلَّا بِاللَّهِ',
          'latin':
              'Bismillāh tawakkaltu ‘alallāh, lā ḥaula wa lā quwwata illā billāh',
          'translation':
              'Dengan nama Allah, aku bertawakal kepada Allah. Tiada daya dan kekuatan kecuali dengan pertolongan Allah',
          'type': 'doa',
          'category': 'Doa Harian',
        },
        'doa_masuk_kamar_mandi': {
          'title': 'Doa Masuk Kamar Mandi',
          'arabic': 'اللهم إني أعوذ بك من الخبث والخبائث',
          'latin': 'Allahumma innī a‘ūdzu bika minal khubutsi wal khabā’its',
          'translation':
              'Ya Allah aku berlindung kepada-Mu dari godaan setan laki-laki dan perempuan',
          'type': 'doa',
          'category': 'Adab',
        },
        'doa_keluar_kamar_mandi': {
          'title': 'Doa Keluar Kamar Mandi',
          'arabic': 'غُفْرَانَكَ',
          'latin': 'Ghufrānaka',
          'translation': 'Aku memohon ampunan-Mu',
          'type': 'doa',
          'category': 'Adab',
        },
        'doa_masuk_masjid': {
          'title': 'Doa Masuk Masjid',
          'arabic': 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
          'latin': 'Allahumma iftaḥ lī abwāba raḥmatika',
          'translation': 'Ya Allah bukakanlah untukku pintu-pintu rahmat-Mu',
          'type': 'doa',
          'category': 'Adab',
        },
        'doa_keluar_masjid': {
          'title': 'Doa Keluar Masjid',
          'arabic': 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
          'latin': 'Allahumma innī as’aluka min faḍhlika',
          'translation':
              'Ya Allah aku memohon kepada-Mu sebagian dari karunia-Mu',
          'type': 'doa',
          'category': 'Adab',
        },
        'doa_naik_kendaraan': {
          'title': 'Doa Naik Kendaraan',
          'arabic':
              'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ',
          'latin':
              'Subḥānal-ladzī sakhkhara lanā hādzā wa mā kunnā lahu muqrinīn',
          'translation':
              'Maha Suci Allah yang telah menundukkan (kendaraan) ini bagi kami padahal kami sebelumnya tidak mampu menguasainya',
          'type': 'doa',
          'category': 'Doa Harian',
        },
        'doa_bercermin': {
          'title': 'Doa Bercermin',
          'arabic': 'اللَّهُمَّ كَمَا حَسَّنْتَ خَلْقِي فَحَسِّنْ خُلُقِي',
          'latin': 'Allahumma kamā ḥassanta khalqī fa ḥassin khuluqī',
          'translation':
              'Ya Allah sebagaimana Engkau telah memperindah rupaku maka perindahlah akhlakku',
          'type': 'doa',
          'category': 'Adab',
        },
        'doa_hujan_turun': {
          'title': 'Doa Ketika Turun Hujan',
          'arabic': 'اللَّهُمَّ صَيِّبًا نَافِعًا',
          'latin': 'Allahumma ṣayyiban nāfi‘a',
          'translation': 'Ya Allah turunkanlah hujan yang bermanfaat',
          'type': 'doa',
          'category': 'Doa Harian',
        },
        'doa_setelah_hujan': {
          'title': 'Doa Setelah Hujan',
          'arabic': 'مُطِرْنَا بِفَضْلِ اللَّهِ وَرَحْمَتِهِ',
          'latin': 'Muṭirnā bi faḍhlillāhi wa raḥmatih',
          'translation': 'Kami diberi hujan karena karunia dan rahmat Allah',
          'type': 'doa',
          'category': 'Doa Harian',
        },
        'surah_al_ikhlas': {
          'title': 'Al-Ikhlāṣ',
          'latin': 'Qul huwallāhu aḥad',
          'translation': 'Surah Al-Ikhlas',
          'type': 'surah',
          'category': 'Surat Pendek',
          'verses': [
            {
              'arabic': 'قُلْ هُوَ اللّٰهُ أَحَدٌ',
              'latin': 'Qul huwallāhu aḥad',
              'translation': 'Katakanlah: Dialah Allah, Yang Maha Esa',
            },
            {
              'arabic': 'اللّٰهُ الصَّمَدُ',
              'latin': 'Allāhuṣ-ṣamad',
              'translation': 'Allah tempat meminta segala sesuatu',
            },
            {
              'arabic': 'لَمْ يَلِدْ وَلَمْ يُولَدْ',
              'latin': 'Lam yalid wa lam yūlad',
              'translation': 'Dia tidak beranak dan tidak pula diperanakkan',
            },
            {
              'arabic': 'وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ',
              'latin': 'Wa lam yakun lahu kufuwan aḥad',
              'translation': 'Dan tidak ada sesuatu pun yang setara dengan-Nya',
            },
          ],
        },
        'surah_an_nas': {
          'title': 'An-Nās',
          'latin': 'Qul a‘ūdzu birabbin-nās',
          'translation': 'Surah An-Nas',
          'type': 'surah',
          'category': 'Surat Pendek',
          'verses': [
            {
              'arabic': 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ',
              'latin': 'Qul a‘ūdzu birabbin-nās',
              'translation': 'Katakanlah: Aku berlindung kepada Tuhan manusia',
            },
            {
              'arabic': 'مَلِكِ النَّاسِ',
              'latin': 'Malikin-nās',
              'translation': 'Raja manusia',
            },
            {
              'arabic': 'إِلَٰهِ النَّاسِ',
              'latin': 'Ilāhin-nās',
              'translation': 'Sembahan manusia',
            },
            {
              'arabic': 'مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ',
              'latin': 'Min sharri-l waswāsi-l khannās',
              'translation': 'Dari kejahatan (bisikan) setan yang bersembunyi',
            },
            {
              'arabic': 'الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ',
              'latin': 'Alladzī yuwaswisu fī ṣudūrin-nās',
              'translation': 'Yang membisikkan ke dalam dada manusia',
            },
            {
              'arabic': 'مِنَ الْجِنَّةِ وَالنَّاسِ',
              'latin': 'Minal-jinnati wan-nās',
              'translation': 'Dari (golongan) jin dan manusia',
            },
          ],
        },
        'surah_al_falaq': {
          'title': 'Al-Falaq',
          'latin': 'Qul a‘ūdzu birabbil-falaq',
          'translation': 'Surah Al-Falaq',
          'type': 'surah',
          'category': 'Surat Pendek',
          'verses': [
            {
              'arabic': 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ',
              'latin': 'Qul a‘ūdzu birabbil-falaq',
              'translation': 'Katakanlah: Aku berlindung kepada Tuhan subuh',
            },
            {
              'arabic': 'مِنْ شَرِّ مَا خَلَقَ',
              'latin': 'Min sharri mā khalaq',
              'translation': 'Dari kejahatan makhluk yang Dia ciptakan',
            },
            {
              'arabic': 'وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ',
              'latin': 'Wa min sharri ghāsiqin idzā waqab',
              'translation': 'Dari kejahatan malam apabila telah gelap gulita',
            },
            {
              'arabic': 'وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ',
              'latin': 'Wa min sharri-n naffāthāti fil-‘uqad',
              'translation':
                  'Dari kejahatan (perempuan) penyihir yang meniup pada buhul-buhul (talinya)',
            },
            {
              'arabic': 'وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ',
              'latin': 'Wa min sharri ḥāsidin idzā ḥasad',
              'translation':
                  'Dan dari kejahatan orang yang dengki apabila ia dengki',
            },
          ],
        },
        'surah_al_kafirun': {
          'title': 'Al-Kāfirūn',
          'latin': 'Qul yā ayyuhal-kāfirūn',
          'translation': 'Surah Al-Kafirun',
          'type': 'surah',
          'category': 'Surat Pendek',
          'verses': [
            {
              'arabic': 'قُلْ يَا أَيُّهَا الْكَافِرُونَ',
              'latin': 'Qul yā ayyuhal-kāfirūn',
              'translation': 'Katakanlah: Wahai orang-orang kafir',
            },
            {
              'arabic': 'لَا أَعْبُدُ مَا تَعْبُدُونَ',
              'latin': 'Lā a‘budu mā ta‘budūn',
              'translation': 'Aku tidak akan menyembah apa yang kamu sembah',
            },
            {
              'arabic': 'وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ',
              'latin': 'Wa lā antum ‘ābidūna mā a‘bud',
              'translation': 'Dan kamu bukan penyembah apa yang aku sembah',
            },
            {
              'arabic': 'وَلَا أَنَا عَابِدٌ مَا عَبَدْتُمْ',
              'latin': 'Wa lā ana ‘ābidun mā ‘abadtum',
              'translation':
                  'Dan aku tidak pernah menjadi penyembah apa yang kamu sembah',
            },
            {
              'arabic': 'وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ',
              'latin': 'Wa lā antum ‘ābidūna mā a‘bud',
              'translation':
                  'Dan kamu tidak pernah pula menjadi penyembah apa yang aku sembah',
            },
            {
              'arabic': 'لَكُمْ دِينُكُمْ وَلِيَ دِينِ',
              'latin': 'Lakum dīnukum wa liya dīn',
              'translation': 'Untukmu agamamu dan untukku agamaku',
            },
          ],
        },
        'surah_al_lahab': {
          'title': 'Al-Lahab',
          'latin': 'Tabbat yadā abī lahabin wa tabb',
          'translation': 'Surah Al-Lahab',
          'type': 'surah',
          'category': 'Surat Pendek',
          'verses': [
            {
              'arabic': 'تَبَّتْ يَدَا أَبِي لَهَبٍ وَتَبَّ',
              'latin': 'Tabbat yadā abī lahabin wa tabb',
              'translation':
                  'Binasalah kedua tangan Abu Lahab dan sesungguhnya ia akan binasa',
            },
            {
              'arabic': 'مَا أَغْنَىٰ عَنْهُ مَالُهُ وَمَا كَسَبَ',
              'latin': 'Mā aghnā ‘anhu māluhu wa mā kasab',
              'translation':
                  'Tidaklah berguna baginya hartanya dan apa yang ia usahakan',
            },
            {
              'arabic': 'سَيَصْلَىٰ نَارًا ذَاتَ لَهَبٍ',
              'latin': 'Sayashlā nāran dhāta lahab',
              'translation':
                  'Kelak dia akan masuk ke dalam api yang bergejolak',
            },
            {
              'arabic': 'وَامْرَأَتُهُ حَمَّالَةَ الْحَطَبِ',
              'latin': 'Wamra’atuhu ḥammālatal-ḥaṭab',
              'translation':
                  'Dan (begitu pula) istrinya, pembawa kayu bakar (penyebar fitnah)',
            },
            {
              'arabic': 'فِي جِيدِهَا حَبْلٌ مِنْ مَسَدٍ',
              'latin': 'Fī jīdihā ḥablum mim masad',
              'translation': 'Di lehernya ada tali dari sabut yang dipintal',
            },
          ],
        },
        'surah_al_kawthar': {
          'title': 'Al-Kawthar',
          'latin': 'Innā a‘ṭainākal-kawthar',
          'translation': 'Surah Al-Kawthar',
          'type': 'surah',
          'category': 'Surat Pendek',
          'verses': [
            {
              'arabic': 'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ',
              'latin': 'Innā a‘ṭainākal-kawthar',
              'translation':
                  'Sesungguhnya Kami telah memberikan kepadamu nikmat yang banyak',
            },
            {
              'arabic': 'فَصَلِّ لِرَبِّكَ وَانْحَرْ',
              'latin': 'Fa ṣalli lirabbika wanḥar',
              'translation':
                  'Maka laksanakanlah shalat karena Tuhanmu dan berkurbanlah',
            },
            {
              'arabic': 'إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ',
              'latin': 'Inna shāni’aka huwal-abtar',
              'translation':
                  'Sesungguhnya orang yang membenci kamu dialah yang terputus (dari rahmat Allah)',
            },
          ],
        },
        'surah_al_asr': {
          'title': 'Al-‘Aṣr',
          'latin': 'Wal-‘aṣr',
          'translation': 'Surah Al-Asr',
          'type': 'surah',
          'category': 'Surat Pendek',
          'verses': [
            {
              'arabic': 'وَالْعَصْرِ',
              'latin': 'Wal-‘aṣr',
              'translation': 'Demi masa',
            },
            {
              'arabic': 'إِنَّ الْإِنْسَانَ لَفِي خُسْرٍ',
              'latin': 'Innal-insāna lafī khusr',
              'translation':
                  'Sesungguhnya manusia itu benar-benar dalam kerugian',
            },
            {
              'arabic': 'إِلَّا الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ',
              'latin': 'Illal-ladzīna āmanū wa ‘amiluṣ-ṣāliḥāt',
              'translation':
                  'Kecuali orang-orang yang beriman dan mengerjakan kebajikan',
            },
            {
              'arabic': 'وَتَوَاصَوْا بِالْحَقِّ وَتَوَاصَوْا بِالصَّبْرِ',
              'latin': 'Wa tawāṣaw bil-ḥaqqi wa tawāṣaw biṣ-ṣabr',
              'translation':
                  'Serta saling menasihati untuk kebenaran dan kesabaran',
            },
          ],
        },
        'surah_al_maun': {
          'title': 'Al-Mā‘ūn',
          'latin': 'Ara’aita alladzī yukadzdzibu bid-dīn',
          'translation': 'Surah Al-Ma’un',
          'type': 'surah',
          'category': 'Surat Pendek',
          'verses': [
            {
              'arabic': 'أَرَأَيْتَ الَّذِي يُكَذِّبُ بِالدِّينِ',
              'latin': 'Ara’aita alladzī yukadzdzibu bid-dīn',
              'translation': 'Tahukah kamu orang yang mendustakan agama?',
            },
            {
              'arabic': 'فَذَٰلِكَ الَّذِي يَدُعُّ الْيَتِيمَ',
              'latin': 'Fa dzālika-l-ladzī yadu‘‘ul-yatīm',
              'translation': 'Maka itulah orang yang menghardik anak yatim',
            },
            {
              'arabic': 'وَلَا يَحُضُّ عَلَىٰ طَعَامِ الْمِسْكِينِ',
              'latin': 'Wa lā yaḥuḍḍu ‘alā ṭa‘āmil-miskīn',
              'translation': 'Dan tidak mendorong memberi makan orang miskin',
            },
            {
              'arabic': 'فَوَيْلٌ لِلْمُصَلِّينَ',
              'latin': 'Fa wailul-lil-muṣallīn',
              'translation': 'Maka celakalah orang-orang yang shalat',
            },
            {
              'arabic': 'الَّذِينَ هُمْ عَنْ صَلَاتِهِمْ سَاهُونَ',
              'latin': 'Alladzīna hum ‘an ṣalātihim sāhūn',
              'translation': 'Yang lalai terhadap shalatnya',
            },
            {
              'arabic': 'الَّذِينَ هُمْ يُرَاءُونَ',
              'latin': 'Alladzīna hum yurā’ūn',
              'translation': 'Yang berbuat riya',
            },
            {
              'arabic': 'وَيَمْنَعُونَ الْمَاعُونَ',
              'latin': 'Wa yamna‘ūnal-mā‘ūn',
              'translation': 'Dan enggan (memberikan) bantuan',
            },
          ],
        },
        'surah_al_qadr': {
          'title': 'Al-Qadr',
          'latin': 'Innā anzalnāhu fī lailatil-qadr',
          'translation': 'Surah Al-Qadr',
          'type': 'surah',
          'category': 'Surat Pendek',
          'verses': [
            {
              'arabic': 'إِنَّا أَنْزَلْنَاهُ فِي لَيْلَةِ الْقَدْرِ',
              'latin': 'Innā anzalnāhu fī lailatil-qadr',
              'translation':
                  'Sesungguhnya Kami telah menurunkannya pada malam kemuliaan',
            },
            {
              'arabic': 'وَمَا أَدْرَاكَ مَا لَيْلَةُ الْقَدْرِ',
              'latin': 'Wa mā adrāka mā lailatul-qadr',
              'translation': 'Dan tahukah kamu apakah malam kemuliaan itu?',
            },
            {
              'arabic': 'لَيْلَةُ الْقَدْرِ خَيْرٌ مِنْ أَلْفِ شَهْرٍ',
              'latin': 'Lailatul-qadri khairum min alfi shahr',
              'translation':
                  'Malam kemuliaan itu lebih baik daripada seribu bulan',
            },
            {
              'arabic': 'تَنَزَّلُ الْمَلَائِكَةُ وَالرُّوحُ فِيهَا',
              'latin': 'Tanazzalul-malā’ikatu war-rūḥu fīhā',
              'translation':
                  'Pada malam itu turun malaikat-malaikat dan Ruh (Jibril)',
            },
            {
              'arabic': 'بِإِذْنِ رَبِّهِمْ مِنْ كُلِّ أَمْرٍ',
              'latin': 'Bi’idhni rabbihim min kulli amr',
              'translation':
                  'Dengan izin Tuhannya untuk mengatur segala urusan',
            },
            {
              'arabic': 'سَلَامٌ هِيَ حَتَّىٰ مَطْلَعِ الْفَجْرِ',
              'latin': 'Salāmun hiya ḥattā maṭla‘il-fajr',
              'translation':
                  'Malam itu penuh kesejahteraan sampai terbit fajar',
            },
          ],
        },
      };
      // Tambahkan metadata pembuat pada semua entri payload
      for (final entry in payload.entries) {
        final m = (entry.value as Map);
        m['createdByUid'] = _uid;
        m['createdByName'] = 'Admin';
        m['createdAt'] = ServerValue.timestamp;
      }
      await ref.set(payload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seed doa sukses.')));
      // Refresh cache & UI
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal seed: $e')));
    }
  }

  Iterable<DoaItem> _filtered() {
    final q = _search.trim().toLowerCase();
    return _items.where((d) {
      final matchText =
          q.isEmpty ||
          d.title.toLowerCase().contains(q) ||
          d.translation.toLowerCase().contains(q);
      final matchType = _typeFilter == 'all' || d.type == _typeFilter;
      return matchText && matchType;
    });
  }

  void _openDetail(DoaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoaDetailScreen(item: item, color: widget.color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Doa & Surat Pendek'),
        actions: [
          IconButton(
            tooltip: 'Rekap hafalan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoaRekapScreen(color: widget.color),
                ),
              );
            },
            icon: const Icon(Icons.assessment_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Cari doa...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                // Inline filter chips for quick toggle
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: _typeFilter == 'all',
                        onSelected: (_) => setState(() => _typeFilter = 'all'),
                      ),
                      ChoiceChip(
                        label: const Text('Doa'),
                        selected: _typeFilter == 'doa',
                        onSelected: (_) => setState(() => _typeFilter = 'doa'),
                      ),
                      ChoiceChip(
                        label: const Text('Surat'),
                        selected: _typeFilter == 'surah',
                        onSelected: (_) =>
                            setState(() => _typeFilter = 'surah'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filtered().length,
                    itemBuilder: (context, i) {
                      final d = _filtered().elementAt(i);
                      final isSurah = d.type == 'surah' || d.verses.isNotEmpty;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSurah
                                ? Colors.indigo.shade100
                                : Colors.teal.shade100,
                            child: Icon(
                              isSurah
                                  ? Icons.menu_book
                                  : Icons.self_improvement,
                              color: isSurah ? Colors.indigo : Colors.teal,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(d.title)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (isSurah ? Colors.indigo : Colors.teal)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isSurah ? 'Surat' : 'Doa',
                                  style: TextStyle(
                                    color: isSurah
                                        ? Colors.indigo
                                        : Colors.teal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.translation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.label_rounded,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    d.category,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDetail(d),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            )
          : null,
    );
  }
}

class DoaDetailScreen extends StatefulWidget {
  final DoaItem item;
  final Color color;
  const DoaDetailScreen({super.key, required this.item, required this.color});

  @override
  State<DoaDetailScreen> createState() => _DoaDetailScreenState();
}

/// Rekap hafalan: menampilkan daftar doa yang pernah dicatat hafal/belum.
class DoaRekapScreen extends StatefulWidget {
  final Color color;
  const DoaRekapScreen({super.key, required this.color});

  @override
  State<DoaRekapScreen> createState() => _DoaRekapScreenState();
}

class _DoaRekapScreenState extends State<DoaRekapScreen> {
  String? _uid;
  bool _loading = true;
  Map<String, _RekapEntry> _entries = {}; // doaId -> aggregated entry

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await FirebaseBootstrap.ensureAll();
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      _uid = user?.uid;
      if (_uid != null) {
        final ref = FirebaseDatabase.instance.ref('users/$_uid/dialy_doa/isi');
        final snap = await ref.get();
        final mapAgg = <String, _RekapEntry>{};
        if (snap.exists && snap.value is Map) {
          final map = (snap.value as Map).cast<String, dynamic>();
          for (final e in map.entries) {
            final v = (e.value as Map).cast<String, dynamic>();
            final doaId = v['doaId'] as String?;
            final doaTitle = v['doaTitle'] as String? ?? doaId ?? '-';
            final hafal = v['hafal'] == true || v['hafal'] == 'true';
            final tglStr = v['tgl'] as String?;
            final note = v['note'] as String?;
            DateTime? dt;
            if (tglStr != null) {
              try {
                dt = DateTime.tryParse(tglStr);
              } catch (_) {}
            }
            if (doaId != null) {
              mapAgg.putIfAbsent(
                doaId,
                () => _RekapEntry(doaId: doaId, title: doaTitle),
              );
              mapAgg[doaId]!.addDetail(
                hafal: hafal,
                date: dt,
                key: e.key,
                keyIsIndex: false,
                note: note,
              );
            }
          }
        } else if (snap.exists && snap.value is List) {
          final rawList = (snap.value as List);
          for (var i = 0; i < rawList.length; i++) {
            final v0 = rawList[i];
            if (v0 is! Map) continue;
            final v = v0.cast<String, dynamic>();
            final doaId = v['doaId'] as String?;
            final doaTitle = v['doaTitle'] as String? ?? doaId ?? '-';
            final hafal = v['hafal'] == true || v['hafal'] == 'true';
            final tglStr = v['tgl'] as String?;
            final note = v['note'] as String?;
            DateTime? dt;
            if (tglStr != null) {
              try {
                dt = DateTime.tryParse(tglStr);
              } catch (_) {}
            }
            if (doaId != null) {
              mapAgg.putIfAbsent(
                doaId,
                () => _RekapEntry(doaId: doaId, title: doaTitle),
              );
              mapAgg[doaId]!.addDetail(
                hafal: hafal,
                date: dt,
                key: i.toString(),
                keyIsIndex: true,
                note: note,
              );
            }
          }
        }
        _entries = mapAgg;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _openDetail(_RekapEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoaRekapDetailScreen(entry: entry, color: widget.color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap Hafalan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const Center(child: Text('Belum ada catatan hafalan.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: _buildRekapList(),
            ),
    );
  }
}

List<Widget> _buildRekapListForEntries(
  Iterable<_RekapEntry> entries,
  void Function(_RekapEntry) onTap,
) {
  final list = entries.toList();
  // Sort by total interactions desc then by title asc
  list.sort((a, b) => a.title.compareTo(b.title));
  list.sort(
    (a, b) =>
        (b.hafalCount + b.belumCount).compareTo(a.hafalCount + a.belumCount),
  );
  return list
      .map(
        (e) => Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  (e.hafalCount >= e.belumCount ? Colors.green : Colors.red)
                      .withOpacity(0.15),
              child: Icon(
                Icons.bookmark_added,
                color: e.hafalCount >= e.belumCount ? Colors.green : Colors.red,
              ),
            ),
            title: Text(e.title),
            subtitle: Text('Hafal ${e.hafalCount} · Belum ${e.belumCount}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTap(e),
          ),
        ),
      )
      .toList();
}

extension on _DoaRekapScreenState {
  List<Widget> _buildRekapList() =>
      _buildRekapListForEntries(_entries.values, _openDetail);
}

class _RekapEntry {
  final String doaId;
  final String title;
  int hafalCount = 0;
  int belumCount = 0;
  final List<_RekapDetail> details = [];
  _RekapEntry({required this.doaId, required this.title});
  void addDetail({
    required bool hafal,
    DateTime? date,
    required String key,
    required bool keyIsIndex,
    String? note,
  }) {
    if (hafal) {
      hafalCount++;
    } else {
      belumCount++;
    }
    details.add(
      _RekapDetail(
        hafal: hafal,
        date: date,
        key: key,
        keyIsIndex: keyIsIndex,
        note: note,
      ),
    );
  }
}

class _RekapDetail {
  final bool hafal;
  final DateTime? date;
  final String key; // push key or list index
  final bool keyIsIndex;
  String? note;
  _RekapDetail({
    required this.hafal,
    required this.date,
    required this.key,
    required this.keyIsIndex,
    this.note,
  });
}

class DoaRekapDetailScreen extends StatefulWidget {
  final _RekapEntry entry;
  final Color color;
  const DoaRekapDetailScreen({
    super.key,
    required this.entry,
    required this.color,
  });

  @override
  State<DoaRekapDetailScreen> createState() => _DoaRekapDetailScreenState();
}

class _DoaRekapDetailScreenState extends State<DoaRekapDetailScreen> {
  late List<_RekapDetail> _list;

  @override
  void initState() {
    super.initState();
    _list = widget.entry.details.toList()
      ..sort(
        (a, b) => (b.date?.millisecondsSinceEpoch ?? 0).compareTo(
          a.date?.millisecondsSinceEpoch ?? 0,
        ),
      );
  }

  Future<void> _openLogDetail(_RekapDetail d) async {
    final updatedNote = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => DoaRekapLogDetailScreen(
          entryTitle: widget.entry.title,
          detail: d,
          color: widget.color,
        ),
      ),
    );
    if (updatedNote != null) {
      setState(() {
        d.note = updatedNote;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final color = widget.color;
    return Scaffold(
      appBar: AppBar(title: Text('Detail: ${entry.title}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Card(
            elevation: 0,
            color: color.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text('Hafal ${entry.hafalCount}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cancel,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text('Belum ${entry.belumCount}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._list.map(
            (d) => Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  d.hafal ? Icons.check_circle : Icons.cancel,
                  color: d.hafal ? Colors.green : Colors.red,
                ),
                title: Text(
                  d.date != null
                      ? _formatDate(d.date!)
                      : 'Tanggal tidak diketahui',
                ),
                subtitle: Text(
                  d.note == null || d.note!.isEmpty
                      ? (d.hafal ? 'Hafal' : 'Belum hafal')
                      : '${d.hafal ? 'Hafal' : 'Belum hafal'} · ${d.note}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openLogDetail(d),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class DoaRekapLogDetailScreen extends StatefulWidget {
  final String entryTitle;
  final _RekapDetail detail;
  final Color color;
  const DoaRekapLogDetailScreen({
    super.key,
    required this.entryTitle,
    required this.detail,
    required this.color,
  });

  @override
  State<DoaRekapLogDetailScreen> createState() =>
      _DoaRekapLogDetailScreenState();
}

class _DoaRekapLogDetailScreenState extends State<DoaRekapLogDetailScreen> {
  final _noteC = TextEditingController();
  String? _uid;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _noteC.text = widget.detail.note ?? '';
    try {
      await FirebaseBootstrap.ensureAll();
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      _uid = user?.uid;
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _save() async {
    if (_uid == null) return;
    setState(() => _saving = true);
    try {
      final ref = FirebaseDatabase.instance.ref('users/$_uid/dialy_doa/isi');
      final path = widget.detail.key; // key or index
      await ref.child(path).update({'note': _noteC.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Keterangan tersimpan')));
      Navigator.pop(context, _noteC.text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal simpan: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Hafalan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            widget.entryTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                d.hafal ? Icons.check_circle : Icons.cancel,
                color: d.hafal ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(d.hafal ? 'Hafal' : 'Belum hafal'),
              const Spacer(),
              Text(
                d.date != null
                    ? _formatDate(d.date!)
                    : 'Tanggal tidak diketahui',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteC,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Keterangan (opsional)',
              hintText: 'Tulis alasan/penjelasan',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _DoaDetailScreenState extends State<DoaDetailScreen> {
  int _hafalCount = 0;
  int _belumCount = 0;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    try {
      await FirebaseBootstrap.ensureAll();
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      _uid = user?.uid;
      await _loadCounts();
    } catch (_) {
      // ignore errors for header counts
    }
  }

  Future<void> _loadCounts() async {
    if (_uid == null) return;
    try {
      final ref = FirebaseDatabase.instance.ref('users/$_uid/dialy_doa/isi');
      final snap = await ref.get();
      int hafal = 0;
      int belum = 0;
      if (snap.exists && snap.value is Map) {
        final map = (snap.value as Map).cast<String, dynamic>();
        for (final e in map.entries) {
          final m = (e.value as Map).cast<String, dynamic>();
          final doaId = m['doaId'] as String?;
          final haf = m['hafal'] == true || m['hafal'] == 'true';
          if (doaId == widget.item.id) {
            if (haf) {
              hafal++;
            } else {
              belum++;
            }
          }
        }
      } else if (snap.exists && snap.value is List) {
        // In case of list storage
        final list = (snap.value as List).whereType<Map>();
        for (final m0 in list) {
          final m = m0.cast<String, dynamic>();
          final doaId = m['doaId'] as String?;
          final haf = m['hafal'] == true || m['hafal'] == 'true';
          if (doaId == widget.item.id) {
            if (haf) {
              hafal++;
            } else {
              belum++;
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _hafalCount = hafal;
        _belumCount = belum;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveResult(bool hafal) async {
    try {
      await FirebaseBootstrap.ensureAll();
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      final uid = user?.uid;
      if (uid == null) return;
      final ref = FirebaseDatabase.instance.ref('users/$uid/dialy_doa/isi');
      final now = DateTime.now();
      final data = {
        'tgl': now.toIso8601String(),
        'timestamp': ServerValue.timestamp,
        'doaId': widget.item.id,
        'doaTitle': widget.item.title,
        'hafal': hafal,
      };
      await ref.push().set(data);
      if (!mounted) return;
      setState(() {
        if (hafal) {
          _hafalCount += 1;
        } else {
          _belumCount += 1;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hafal
                ? 'Tercatat: Hafal hari ini'
                : 'Tercatat: Belum hafal hari ini',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  Future<void> _confirmAndSave(bool hafal) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text(
          hafal
              ? 'Catat sebagai HAFAL untuk "${widget.item.title}"?'
              : 'Catat sebagai BELUM HAFAL untuk "${widget.item.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, simpan'),
          ),
        ],
      ),
    );
    if (res == true) {
      await _saveResult(hafal);
    }
  }

  Future<void> _resetLogsForThisDoa() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Hafalan'),
        content: Text(
          'Hapus semua catatan hafalan untuk "${widget.item.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseBootstrap.ensureAll();
      var user = FirebaseAuth.instance.currentUser;
      user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      final uid = user?.uid;
      if (uid == null) return;
      final ref = FirebaseDatabase.instance.ref('users/$uid/dialy_doa/isi');
      final snap = await ref.get();
      if (snap.exists && snap.value is Map) {
        final map = (snap.value as Map).cast<String, dynamic>();
        final futures = <Future>[];
        for (final e in map.entries) {
          final m = (e.value as Map).cast<String, dynamic>();
          if (m['doaId'] == widget.item.id) {
            futures.add(ref.child(e.key).remove());
          }
        }
        await Future.wait(futures);
      } else if (snap.exists && snap.value is List) {
        final list = (snap.value as List).whereType<Map>().toList();
        final filtered = list.where((m0) {
          final m = m0.cast<String, dynamic>();
          return m['doaId'] != widget.item.id;
        }).toList();
        await ref.set(filtered);
      }
      await _loadCounts();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Berhasil direset.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal reset: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = widget.color;
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: _resetLogsForThisDoa,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: item.verses.isNotEmpty ? item.verses.length + 2 : 2,
        itemBuilder: (context, index) {
          final isLast =
              index == (item.verses.isNotEmpty ? item.verses.length + 1 : 1);
          if (isLast) {
            return Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirmAndSave(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Hafal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirmAndSave(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Belum hafal'),
                  ),
                ),
              ],
            );
          }
          if (index == 0 && item.verses.isEmpty) {
            return Card(
              elevation: 0,
              color: color.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        item.arabic,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (item.latin.isNotEmpty)
                      Text(
                        item.latin,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    const SizedBox(height: 12),
                    Text(item.translation),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(item.category)),
                        Chip(
                          label: Text(item.type == 'surah' ? 'Surat' : 'Doa'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text('Hafal $_hafalCount kali'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text('Belum $_belumCount kali'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          if (index == 0 && item.verses.isNotEmpty) {
            return Card(
              elevation: 0,
              color: color.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item.translation),
                    if (item.latin.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.latin,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(item.category)),
                        Chip(label: Text('Surat')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text('Hafal $_hafalCount kali'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text('Belum $_belumCount kali'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          final verse = item.verses[index - 1];
          return Card(
            elevation: 0,
            color: color.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        verse.arabic,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  if (verse.latin.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      verse.latin,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                  if (verse.translation.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(verse.translation),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
