import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Tema único de la aplicación (Material 3, optimizado para hardware modesto).
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.dark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.dark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      // Relieve "3D": sin borde duro, con sombra suave multicapa.
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 8,
        shadowColor: AppColors.shadowSoft,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.shadowStrong,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.background,
        side: BorderSide(color: AppColors.border),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.dark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      // Transiciones de ruta con zoom + fade (feeling 3D) en todas las plataformas.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomFadeTransitionsBuilder(),
          TargetPlatform.iOS: ZoomFadeTransitionsBuilder(),
          TargetPlatform.windows: ZoomFadeTransitionsBuilder(),
          TargetPlatform.macOS: ZoomFadeTransitionsBuilder(),
          TargetPlatform.linux: ZoomFadeTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Transición de ruta: la página entra con un leve zoom y desvanecimiento,
/// y la salida se oscurece — efecto de profundidad "3D".
class ZoomFadeTransitionsBuilder extends PageTransitionsBuilder {
  const ZoomFadeTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final fade = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.96 + (0.04 * t),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: Opacity(opacity: 1 - fade.value, child: child),
    );
  }
}