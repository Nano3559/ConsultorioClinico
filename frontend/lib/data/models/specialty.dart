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
}