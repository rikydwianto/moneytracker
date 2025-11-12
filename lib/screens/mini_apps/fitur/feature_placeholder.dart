import 'package:flutter/material.dart';

class FeaturePlaceholder extends StatelessWidget {
  final String title;
  final String heroTag;
  final Color color;
  final IconData icon;
  const FeaturePlaceholder({
    super.key,
    required this.title,
    required this.heroTag,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: heroTag,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 38),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Fitur "$title" akan segera hadir',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
