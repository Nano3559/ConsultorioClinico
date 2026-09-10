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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              gradient: light
                  ? LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.06),
                    ])
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.gradientPrimary,
                    ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                if (!light)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
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