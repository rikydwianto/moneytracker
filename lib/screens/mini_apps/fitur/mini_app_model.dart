import 'package:flutter/material.dart';

class MiniAppModel {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String category;
  final List<Color> colors;
  const MiniAppModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    required this.colors,
  });
}
