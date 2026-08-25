import 'package:flutter/material.dart';

/// Especialidad médica del consultorio.
class Specialty {
  const Specialty({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.color = const Color(0xFF0D9488),
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  /// Construye una Specialty desde la fila de Supabase (sin icono/color).
  factory Specialty.fromApi(Map<String, dynamic> json) {
    return Specialty(
      id: json['id'].toString(),
      name: (json['nombre'] ?? '').toString(),
      description: (json['descripcion'] ?? '').toString(),
      icon: iconForName(json['nombre']?.toString() ?? ''),
      color: const Color(0xFF0D9488),
    );
  }

  /// Asigna un icono por defecto según el nombre de la especialidad.
  static IconData iconForName(String name) {
    final n = name.toLowerCase();
    if (n.contains('pediatr')) return Icons.child_care_outlined;
    if (n.contains('ginec')) return Icons.favorite_outline;
    if (n.contains('cardi')) return Icons.monitor_heart_outlined;
    if (n.contains('dermat')) return Icons.spa_outlined;
    if (n.contains('odont')) return Icons.emoji_emotions_outlined;
    return Icons.medical_services_outlined;
  }
}