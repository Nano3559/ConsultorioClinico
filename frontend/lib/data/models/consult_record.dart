/// Consulta registrada dentro de una historia clínica.
class ConsultRecord {
  const ConsultRecord({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.date,
    required this.motivo,
    required this.diagnostico,
    required this.tratamiento,
    this.observaciones = '',
    this.proximoControl,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final DateTime date;
  final String motivo;
  final String diagnostico;
  final String tratamiento;
  final String observaciones;
  final DateTime? proximoControl;

  /// Construye una ConsultRecord desde la fila de Supabase.
  factory ConsultRecord.fromApi(Map<String, dynamic> json) {
    final fecha = json['fecha'];
    return ConsultRecord(
      id: json['id'].toString(),
      patientId: json['paciente_id'].toString(),
      doctorId: json['medico_id'].toString(),
      date: fecha is DateTime
          ? fecha
          : DateTime.tryParse(fecha?.toString() ?? '') ?? DateTime.now(),
      motivo: '',
      diagnostico: (json['diagnostico'] ?? '').toString(),
      tratamiento: (json['tratamiento'] ?? '').toString(),
      observaciones: (json['notas_clinicas'] ?? '').toString(),
      proximoControl: null,
    );
  }

  /// Cuerpo para POST /api/consultas.
  Map<String, dynamic> toApiJson() => {
        'cita_id': null,
        'paciente_id': patientId,
        'medico_id': doctorId,
        'diagnostico': diagnostico,
        'tratamiento': tratamiento,
        'notas_clinicas': observaciones,
        'signos_vitales': null,
      };
}