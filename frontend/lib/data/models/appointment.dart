import '../../core/widgets/app_status_badge.dart';

/// Cita médica. Un mismo horario no puede repetirse por médico.
class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.date,
    required this.time,
    required this.reason,
    this.status = AppointmentStatus.pendiente,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final DateTime date;
  final String time;
  final String reason;
  final AppointmentStatus status;

  /// Construye una Appointment desde la fila de Supabase.
  factory Appointment.fromApi(Map<String, dynamic> json) {
    final fecha = json['fecha'];
    final hora = (json['hora'] ?? '').toString();
    return Appointment(
      id: json['id'].toString(),
      patientId: json['paciente_id'].toString(),
      doctorId: json['medico_id'].toString(),
      date: fecha is DateTime
          ? fecha
          : DateTime.tryParse(fecha?.toString() ?? '') ?? DateTime.now(),
      time: hora.length >= 5 ? hora.substring(0, 5) : hora,
      reason: (json['motivo'] ?? '').toString(),
      status: AppointmentStatus.fromApi(json['estado']),
    );
  }

  Appointment copyWith({
    String? patientId,
    String? doctorId,
    DateTime? date,
    String? time,
    String? reason,
    AppointmentStatus? status,
  }) {
    return Appointment(
      id: id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      date: date ?? this.date,
      time: time ?? this.time,
      reason: reason ?? this.reason,
      status: status ?? this.status,
    );
  }
}