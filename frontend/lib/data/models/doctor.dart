/// Horario semanal de atención de un médico (día → franjas 'HH:mm').
class DoctorSchedule {
  const DoctorSchedule(this.byDay);

  final Map<String, List<String>> byDay;

  List<String> forDay(String day) => byDay[day] ?? const [];

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
  });

  final String id;
  final String name;
  final String specialtyId;
  final String description;
  final int yearsExperience;
  final DoctorSchedule schedule;
  final bool active;
  final String title;

  String get displayName => '$title $name';

  Doctor copyWith({
    String? name,
    String? specialtyId,
    String? description,
    int? yearsExperience,
    DoctorSchedule? schedule,
    bool? active,
    String? title,
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
    );
  }
}