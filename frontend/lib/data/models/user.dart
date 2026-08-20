import 'package:flutter/material.dart';

/// Roles del sistema.
enum UserRole {
  admin('Administrador', Icons.dashboard_outlined),
  medico('Médico', Icons.medical_services_outlined),
  recepcion('Recepción', Icons.support_agent_outlined),
  paciente('Paciente', Icons.person_outline);

  const UserRole(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Usuario del sistema (inicialmente con mock, luego desde la API).
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.doctorId,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? doctorId;

  User copyWith({String? name, String? email, UserRole? role}) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      doctorId: doctorId,
    );
  }
}