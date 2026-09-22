// Modelos del kiosco de auto-check-in (KIO-09 / KIO-15).
//
// Reflejan la respuesta del backend:
//   POST /api/kiosco/verificar-rostro { imagen: base64 }
//     -> { success, message, data: { paciente_id, nombre, confianza, cita } }
//   POST /api/kiosco/confirmar-cita { paciente_id, cita_id }
//     -> { success, message, data: citaActualizada }

/// Cita del día devuelta por el microservicio de visión (Python + FastAPI).
/// Se mantiene flexible (mapa) porque el backend hace join con
/// pacientes/medicos y el esquema puede variar.
class KioskCita {
  const KioskCita({
    required this.id,
    required this.fecha,
    required this.hora,
    this.medicoNombre,
    this.especialidad,
    this.raw = const {},
  });

  final dynamic id;
  final String fecha;
  final String hora;
  final String? medicoNombre;
  final String? especialidad;
  final Map<String, dynamic> raw;

  factory KioskCita.fromJson(Map<String, dynamic> json) {
    String? medico;
    String? especialidad;
    final medicos = json['medicos'];
    if (medicos is Map<String, dynamic>) {
      final n = (medicos['nombre'] ?? '').toString();
      final a = (medicos['apellido'] ?? '').toString();
      medico = '$n $a'.trim().isEmpty ? null : '$n $a'.trim();
      especialidad = medicos['especialidad']?.toString();
    }
    return KioskCita(
      id: json['id'],
      fecha: (json['fecha'] ?? '').toString(),
      hora: (json['hora'] ?? '').toString(),
      medicoNombre: medico,
      especialidad: especialidad,
      raw: json,
    );
  }
}

/// Resultado de `POST /api/kiosco/verificar-rostro`.
class KioskVerification {
  const KioskVerification({
    required this.success,
    required this.message,
    this.pacienteId,
    this.nombre,
    this.confianza,
    this.cita,
  });

  final bool success;
  final String message;
  final dynamic pacienteId;
  final String? nombre;
  final num? confianza;
  final KioskCita? cita;

  /// `true` cuando el rostro fue reconocido (haya o no cita del día).
  bool get reconocido => success && pacienteId != null;

  /// `true` cuando además hay cita para hoy que se puede confirmar.
  bool get tieneCitaHoy => reconocido && cita != null;

  factory KioskVerification.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      return KioskVerification(
        success: json['success'] == true,
        message: (json['message'] ?? 'Sin respuesta del servidor').toString(),
      );
    }
    KioskCita? cita;
    final citaJson = data['cita'];
    if (citaJson is Map<String, dynamic>) {
      cita = KioskCita.fromJson(citaJson);
    }
    final conf = data['confianza'];
    return KioskVerification(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      pacienteId: data['paciente_id'],
      nombre: data['nombre']?.toString(),
      confianza: conf is num ? conf : num.tryParse('$conf'),
      cita: cita,
    );
  }

  /// Resultado de fallo local (sin conexión, timeout, 5xx...).
  factory KioskVerification.failure(String message) =>
      KioskVerification(success: false, message: message);
}
