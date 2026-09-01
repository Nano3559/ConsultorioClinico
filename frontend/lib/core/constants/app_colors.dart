import 'package:flutter/material.dart';

/// Paleta de color única de la aplicación (estilo clínico/teal).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0D9488);
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF2DD4BF);
  static const Color primaryBg = Color(0xFFCCFBF1);
  static const Color dark = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleBg = Color(0xFFEDE9FE);

  static const List<Color> accentPool = [
    Color(0xFF0D9488),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
  ];

  // ---- Gradientes (estilo 3D / profundidad) -----------------------------
  /// Gradiente de marca (teal → azul) para botones, chips y acentos.
  static const List<Color> gradientPrimary = [
    Color(0xFF14B8A6),
    Color(0xFF0D9488),
    Color(0xFF0F766E),
  ];

  /// Gradiente de fondo suave (blanco → teal muy tenue).
  static const List<Color> gradientBackground = [
    Color(0xFFFFFFFF),
    Color(0xFFF0FDFA),
    Color(0xFFE0F2FE),
  ];

  /// Gradiente profundo para la barra lateral (oscuro premium).
  static const List<Color> gradientSidebar = [
    Color(0xFF0F766E),
    Color(0xFF134E4A),
    Color(0xFF0B3B37),
  ];

  /// Sombras suaves para elevar tarjetas (multi-capa "3D").
  static const Color shadowSoft = Color(0x1A0F172A);
  static const Color shadowStrong = Color(0x330F172A);
}