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
    this.photoUrl = '',
    this.faceBase64 = '',
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

  /// URL de la foto del rostro (para el kiosco). Vacía = sin foto registrada.
  final String photoUrl;

  /// Foto del rostro en base64 (capturada al agendar, sin procesar).
  final String faceBase64;

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
      observaciones: (json['observaciones'] ?? json['contacto_emergencia'] ?? '').toString(),
      photoUrl: (json['foto_url'] ?? '').toString(),
      faceBase64: (json['foto_base64'] ?? '').toString(),
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
        'observaciones': observaciones,
        if (photoUrl.isNotEmpty) 'foto_url': photoUrl,
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
    String? photoUrl,
    String? faceBase64,
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
      photoUrl: photoUrl ?? this.photoUrl,
      faceBase64: faceBase64 ?? this.faceBase64,
    );
  }
}