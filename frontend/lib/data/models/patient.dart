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
    this.uid,
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

  /// Firebase UID del usuario que "es" este paciente (vínculo paciente <-> cuenta).
  final String? uid;

  String get fullName => '$firstName $lastName';

  /// Construye un Patient desde la fila de Supabase (snake_case).
  factory Patient.fromApi(Map<String, dynamic> json) {
    final birth = json['fecha_nacimiento'];
    return Patient(
      id: json['id'].toString(),
      firstName: (json['nombre'] ?? '').toString(),
      lastName: (json['apellido'] ?? '').toString(),
      ci: (json['cedula'] ?? '').toString(),
      birthDate: birth == null
          ? DateTime(1900)
          : (birth is DateTime ? birth : DateTime.tryParse(birth.toString()) ?? DateTime(1900)),
      phone: (json['telefono'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      antecedentes: (json['antecedentes'] ?? '').toString(),
      alergias: (json['alergias'] ?? '').toString(),
      observaciones: (json['contacto_emergencia'] ?? '').toString(),
      uid: json['uid']?.toString(),
    );
  }

  /// Cuerpo para POST/PUT del backend.
  Map<String, dynamic> toApiJson() => {
        'nombre': firstName,
        'apellido': lastName,
        'cedula': ci,
        'telefono': phone,
        'email': email,
        'fecha_nacimiento':
            '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        'antecedentes': antecedentes,
        'alergias': alergias,
        'contacto_emergencia': observaciones,
      };

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
    String? uid,
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
      uid: uid ?? this.uid,
    );
  }
}