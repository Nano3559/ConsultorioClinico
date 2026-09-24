// ============================================================================
// SERVICIO DEL KIOSCO DE AUTO-CHECK-IN
// ----------------------------------------------------------------------------
// Consume los endpoints públicos del kiosco del backend:
//   POST /api/kiosco/verificar-rostro  { imagen }  -> verificación facial
//   POST /api/kiosco/confirmar-cita    { paciente_id, cita_id } -> check-in
//
// El kiosco debe llamar a confirmar-cita DESDE LA MISMA IP a los pocos
// segundos de verificar el rostro: el backend exige una verificación facial
// exitosa reciente del mismo paciente (ventana KIOSCO_VERIFICATION_WINDOW_MIN)
// antes de confirmar la cita.
// ============================================================================

import '../../../services/api_client.dart';

/// Cita del día devuelta junto con la verificación facial.
class KioskCita {
  const KioskCita({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.estado,
    this.medicoNombre,
  });

  factory KioskCita.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const KioskCita(id: 0, fecha: '', hora: '', estado: '');
    final medico = json['medicos'];
    final String medicoNombre;
    if (medico is Map<String, dynamic>) {
      final nombre = medico['nombre']?.toString() ?? '';
      final apellido = medico['apellido']?.toString() ?? '';
      medicoNombre = '$nombre $apellido'.trim();
    } else {
      medicoNombre = '';
    }
    return KioskCita(
      id: json['id'] as int? ?? 0,
      fecha: json['fecha']?.toString() ?? '',
      hora: json['hora']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      medicoNombre: medicoNombre,
    );
  }

  final int id;
  final String fecha;
  final String hora;
  final String estado;
  final String? medicoNombre;

  bool get existe => id > 0;
}

/// Respuesta de `POST /api/kiosco/verificar-rostro` cuando el rostro
/// fue reconocido y el paciente tiene o no cita registrada para el día.
class KioskVerificacion {
  const KioskVerificacion({
    required this.pacienteId,
    required this.nombre,
    required this.confianza,
    required this.cita,
  });

  factory KioskVerificacion.fromData(Map<String, dynamic> data) {
    return KioskVerificacion(
      pacienteId: data['paciente_id'] as int? ?? 0,
      nombre: data['nombre'] as String?,
      confianza: (data['confianza'] as num?)?.toDouble(),
      cita: KioskCita.fromJson(data['cita']),
    );
  }

  final int pacienteId;
  final String? nombre;
  final double? confianza;
  final KioskCita cita;

  bool get reconocido => pacienteId > 0;
}

/// Error controlado del servicio del kiosco (mensaje listo para el paciente).
class KioskServiceException implements Exception {
  const KioskServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Llamadas HTTP del kiosco. Toda petición pasa por [ApiClient].
class KioskService {
  KioskService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  /// Envía la foto (base64) al microservicio de visión vía backend.
  ///
  /// Lanza [KioskServiceException] si el rostro no se reconoce o el servicio
  /// no está disponible (el error lleva un mensaje apto para el paciente).
  Future<KioskVerificacion> verificarRostro(String imagenBase64) async {
    final res = await _api.postJson(
      '/kiosco/verificar-rostro',
      {'imagen': imagenBase64},
    );
    if (!res.isSuccess) {
      throw KioskServiceException(_mensaje(res.error));
    }
    final body = res.data!;
    final data = (body['data'] as Map<String, dynamic>?) ?? const {};
    final verificacion = KioskVerificacion.fromData(data);
    if (!verificacion.reconocido) {
      throw KioskServiceException(
        body['message']?.toString() ?? 'No se pudo reconocer el rostro. ',
      );
    }
    return verificacion;
  }

  /// Confirma la cita del día del paciente (check-in) en el backend.
  ///
  /// Debe llamarse justo después de [verificarRostro] desde el mismo
  /// dispositivo (misma IP) para que el backend acepte el check-in.
  Future<Map<String, dynamic>> confirmarCita({
    required int pacienteId,
    required int citaId,
  }) async {
    final res = await _api.postJson(
      '/kiosco/confirmar-cita',
      {'paciente_id': pacienteId, 'cita_id': citaId},
    );
    if (!res.isSuccess) {
      throw KioskServiceException(_mensaje(res.error));
    }
    return res.data!;
  }

  String _mensaje(String? error) {
    if (error == null || error.isEmpty) {
      return 'No se pudo completar la operación. Intente de nuevo.';
    }
    // Evitar mensajes técnicos en la tablet: los mensajes del backend ya
    // vienen en español y en formato de respuesta estándar.
    return error;
  }
}