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
}