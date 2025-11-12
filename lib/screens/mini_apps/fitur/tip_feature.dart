import 'package:flutter/material.dart';
import 'feature_placeholder.dart';

class TipFeature extends StatelessWidget {
  final String heroTag;
  final Color color;
  const TipFeature({super.key, required this.heroTag, required this.color});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Hitung Tip',
      heroTag: 'miniapp-tip',
      color: Colors.indigo,
      icon: Icons.percent,
    );
  }
}
