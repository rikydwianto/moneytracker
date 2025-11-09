import 'package:flutter/material.dart';

class MiniAppsScreen extends StatelessWidget {
  const MiniAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MiniAppItem(
        title: 'Hitung Tip',
        icon: Icons.percent,
        description: 'Kalkulator cepat untuk menghitung tip & pembagian tagihan.',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _PlaceholderFeature(title: 'Hitung Tip')), 
        ),
      ),
      _MiniAppItem(
        title: 'Konversi Mata Uang',
        icon: Icons.currency_exchange,
        description: 'Lihat estimasi nilai tukar (dummy).',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _PlaceholderFeature(title: 'Konversi Mata Uang')), 
        ),
      ),
      _MiniAppItem(
        title: 'Target Tabungan',
        icon: Icons.flag_outlined,
        description: 'Rencanakan target tabungan sederhana.',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _PlaceholderFeature(title: 'Target Tabungan')), 
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini Apps'),
      ),
      body: ListView.builder(
        itemCount: items.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = items[index];
          return _MiniAppCard(item: item);
        },
      ),
    );
  }
}

class _MiniAppItem {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;
  _MiniAppItem({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });
}

class _MiniAppCard extends StatelessWidget {
  final _MiniAppItem item;
  const _MiniAppCard({required this.item});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Icon(item.icon,
                  color: Theme.of(context).colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderFeature extends StatelessWidget {
  final String title;
  const _PlaceholderFeature({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'Fitur "$title" akan datang nanti',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
