/// Horario semanal de atención de un médico (día → franjas 'HH:mm').
class DoctorSchedule {
  const DoctorSchedule(this.byDay);

  final Map<String, List<String>> byDay;

  List<String> forDay(String day) => byDay[day] ?? const [];

  /// Convierte los turnos de 30 min de un día en franjas continuas
  /// ("08:00-12:00", "14:00-18:00") para mostrar bien los horarios.
  List<String> slotRanges(String day) {
    final slots = (byDay[day] ?? const []).toList()..sort();
    final out = <String>[];
    String start = '', prev = '';
    for (final t in slots) {
      if (start.isEmpty) {
        start = t;
        prev = t;
        continue;
      }
      if (_next30(prev) == t) {
        prev = t;
      } else {
        out.add('$start-$prev');
        start = t;
        prev = t;
      }
    }
    if (start.isNotEmpty) out.add('$start-$prev');
    return out;
  }

  static String _next30(String t) {
    final p = t.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    final total = h * 60 + m + 30;
    final nh = (total ~/ 60) % 24;
    final nm = total % 60;
    return '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
  }

  DoctorSchedule copyWith({Map<String, List<String>>? byDay}) {
    return DoctorSchedule(byDay ?? this.byDay);
  }
}

/// Profesional médico del consultorio.
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialtyId,
    required this.description,
    required this.yearsExperience,
    required this.schedule,
    this.active = true,
    this.title = 'Dr./Dra.',
    this.photoUrl = '',
    this.phone = '',
    this.email = '',
  });

  final String id;
  final String name;
  final String specialtyId;
  final String description;
  final int yearsExperience;
  final DoctorSchedule schedule;
  final bool active;
  final String title;

  /// URL de la fotografía del médico (vacía => avatar con iniciales).
  final String photoUrl;
  final String phone;
  final String email;

  String get displayName => '$title $name';

  /// Construye un Doctor desde la fila de Supabase.
  /// [specialtyId] es el id de la especialidad ya resuelto por nombre.
  factory Doctor.fromApi(
    Map<String, dynamic> json, {
    String specialtyId = '',
    DoctorSchedule schedule = const DoctorSchedule({}),
  }) {
    final nombre = (json['nombre'] ?? '').toString();
    final apellido = (json['apellido'] ?? '').toString();
    final titulo = (json['titulo'] ?? '').toString().trim();
    return Doctor(
      id: json['id'].toString(),
      name: '$nombre $apellido'.trim(),
      specialtyId: specialtyId,
      description: (json['descripcion'] ?? '').toString(),
      yearsExperience: int.tryParse((json['anios_experiencia'] ?? '0').toString()) ?? 0,
      schedule: schedule,
      active: json['activo'] ?? true,
      title: titulo.isEmpty ? 'Dr./Dra.' : titulo,
      photoUrl: (json['foto_url'] ?? '').toString(),
      phone: (json['telefono'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }

  /// Cuerpo para POST/PUT del backend (la especialidad se envía por nombre).
  Map<String, dynamic> toApiJson({required String especialidad}) {
    final partes = name.trim().split(RegExp(r'\s+'));
    final nombre = partes.isNotEmpty ? partes.first : name;
    final apellido = partes.length > 1 ? partes.sublist(1).join(' ') : '';
    const cedula = '';
    const telefono = '';
    const email = '';
    const consulorio = '';
    const tarifaConsulta = 0;
    return {
      'nombre': nombre,
      'apellido': apellido,
      if (cedula.isNotEmpty) 'cedula': cedula,
      'especialidad': especialidad,
      if (telefono.isNotEmpty) 'telefono': telefono,
      if (email.isNotEmpty) 'email': email,
      if (consulorio.isNotEmpty) 'consulorio': consulorio,
      'titulo': title,
      'descripcion': description,
      'anios_experiencia': yearsExperience,
      'tarifa_consulta': tarifaConsulta,
    };
  }

  Doctor copyWith({
    String? name,
    String? specialtyId,
    String? description,
    int? yearsExperience,
    DoctorSchedule? schedule,
    bool? active,
    String? title,
    String? photoUrl,
    String? phone,
    String? email,
  }) {
    return Doctor(
      id: id,
      name: name ?? this.name,
      specialtyId: specialtyId ?? this.specialtyId,
      description: description ?? this.description,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      schedule: schedule ?? this.schedule,
      active: active ?? this.active,
      title: title ?? this.title,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }
}