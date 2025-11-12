import 'package:flutter/material.dart';
import 'fitur/mini_app_model.dart';
import 'fitur/mini_app_tile.dart';
import 'fitur/feature_placeholder.dart';
import 'fitur/tip_feature.dart';
import 'fitur/shopping_todo_feature.dart';
import 'fitur/doa_list_feature.dart';
import 'fitur/fitness_feature.dart';

class MiniAppsScreen extends StatefulWidget {
  const MiniAppsScreen({super.key});

  @override
  State<MiniAppsScreen> createState() => _MiniAppsScreenState();
}

class _MiniAppsScreenState extends State<MiniAppsScreen> {
  final TextEditingController _search = TextEditingController();
  String _category = 'Semua';
  final Set<String> _favorites = <String>{};

  late final List<MiniAppModel> _apps = [
    // 1) To-Do List Belanjaan
    MiniAppModel(
      id: 'shopping_todolist',
      title: 'To-Do List Belanjaan',
      subtitle: 'Catat dan tandai daftar belanja',
      icon: Icons.shopping_cart_outlined,
      category: 'Produktif',
      colors: [Colors.teal, Colors.greenAccent],
    ),
    // 2) Doa & Surat Pendek + Hafalan (gabungan)
    MiniAppModel(
      id: 'daily_prayers',
      title: 'Doa & Surat Pendek',
      subtitle: 'Arab • Latin • Arti • Hafalan 1%',
      icon: Icons.auto_stories,
      category: 'Religi',
      colors: [Colors.brown, Colors.orangeAccent],
    ),

    // 4) Setoran Hafalan
    MiniAppModel(
      id: 'child_memorization',
      title: 'Setoran Hafalan Anak',
      subtitle: 'Catatan hafalan + progres',
      icon: Icons.menu_book,
      category: 'Produktif',
      colors: [Colors.deepPurple, Colors.purpleAccent],
    ),
    // 5) Kebugaran (Fitness Tracking)
    MiniAppModel(
      id: 'fitness',
      title: 'Kebugaran',
      subtitle: 'Catat berat & tinggi + grafik',
      icon: Icons.fitness_center,
      category: 'Produktif',
      colors: [Colors.blue, Colors.lightBlueAccent],
    ),

    // (hapus tile terpisah memorization_module untuk hindari duplikasi)
    // others
  ];

  List<String> get _categories => [
    'Semua',
    'Keuangan',
    'Utilitas',
    'Produktif',
    'Religi',
    'Favorit',
  ];

  List<MiniAppModel> _filtered() {
    final q = _search.text.trim().toLowerCase();
    Iterable<MiniAppModel> list = _apps;
    if (_category == 'Keuangan') {
      list = list.where((a) => a.category == 'Keuangan');
    } else if (_category == 'Utilitas') {
      list = list.where((a) => a.category == 'Utilitas');
    } else if (_category == 'Favorit') {
      list = list.where((a) => _favorites.contains(a.id));
    }
    if (q.isNotEmpty) {
      list = list.where(
        (a) =>
            a.title.toLowerCase().contains(q) ||
            a.subtitle.toLowerCase().contains(q),
      );
    }
    return list.toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(elevation: 0, title: const Text('Mini Apps')),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari mini app...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          // Categories
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) {
                final c = _categories[i];
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _categories.length,
            ),
          ),
          const SizedBox(height: 8),
          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final app = items[index];
                final fav = _favorites.contains(app.id);
                return MiniAppTile(
                  app: app,
                  favorite: fav,
                  onToggleFav: () => setState(() {
                    if (fav) {
                      _favorites.remove(app.id);
                    } else {
                      _favorites.add(app.id);
                    }
                  }),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) {
                        switch (app.id) {
                          case 'tip':
                            return TipFeature(
                              heroTag: 'miniapp-${app.id}',
                              color: app.colors.first,
                            );
                          case 'shopping_todolist':
                            return ShoppingTodoFeature(
                              heroTag: 'miniapp-${app.id}',
                              color: app.colors.first,
                            );

                          case 'daily_prayers':
                            return DoaListFeature(
                              heroTag: 'miniapp-${app.id}',
                              color: app.colors.first,
                            );
                          case 'daily_prayer_checklist':
                            return FeaturePlaceholder(
                              title: app.title,
                              heroTag: 'miniapp-${app.id}',
                              color: app.colors.first,
                              icon: app.icon,
                            );
                          case 'fitness':
                            return FitnessFeature(
                              heroTag: 'miniapp-${app.id}',
                              color: app.colors.first,
                            );
                          default:
                            return FeaturePlaceholder(
                              title: app.title,
                              heroTag: 'miniapp-${app.id}',
                              color: app.colors.first,
                              icon: app.icon,
                            );
                        }
                      },
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
