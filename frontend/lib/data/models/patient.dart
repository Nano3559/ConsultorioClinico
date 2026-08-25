/// Paciente del consultorio.
class Patient {
  const Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.ci,
    required this.birthDate,
    required this.phone,
    required this.email,
    this.antecedentes = '',
    this.alergias = '',
    this.observaciones = '',
  });

  final String id;
  final String firstName;
  final String lastName;
  final String ci;
  final DateTime birthDate;
  final String phone;
  final String email;
  final String antecedentes;
  final String alergias;
  final String observaciones;

  String get fullName => '$firstName $lastName';

  Patient copyWith({
    String? firstName,
    String? lastName,
    String? ci,
    DateTime? birthDate,
    String? phone,
    String? email,
    String? antecedentes,
    String? alergias,
    String? observaciones,
  }) {
    return Patient(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      ci: ci ?? this.ci,
      birthDate: birthDate ?? this.birthDate,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      antecedentes: antecedentes ?? this.antecedentes,
      alergias: alergias ?? this.alergias,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}