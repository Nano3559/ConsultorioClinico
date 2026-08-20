import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Encabezado reutilizable de sección (público y privado).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.label,
    this.light = false,
  });

  final String title;
  final String? subtitle;
  final String? label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final accent = light ? AppColors.primaryLight : AppColors.primary;
    final titleColor = light ? Colors.white : AppColors.dark;
    final subColor = light ? const Color(0xFF94A3B8) : AppColors.muted;
    return Column(
      children: [
        if (label != null) ...[
          Text(label!, style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: titleColor),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: subColor),
          ),
        ],
      ],
    );
  }
}