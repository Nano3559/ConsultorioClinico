// ============================================================================
// SERVICIO DE REGISTRO FACIAL
// ----------------------------------------------------------------------------
// Expone los endpoints de vision/ (KIO-10/KIO-07) para que recepcion capture
// las fotos de un paciente y las registre en el modelo LBPH:
//
//   POST /api/vision/registrar-rostro/:id  { imagenes: [base64, ...] }
//   GET  /api/vision/rostro/:id             -> estado del descriptor
//
// Ambos exigen verifyToken + checkRole('admin','recepcion'), por eso el token
// se toma de AuthProvider en cada llamada.
// ============================================================================

import '../../../services/api_client.dart';

/// Estado del descriptor facial de un paciente (KIO-07).
class RostroEstado {
  const RostroEstado({
    required this.registrado,
    required this.dimensiones,
    required this.nombre,
  });

  factory RostroEstado.fromData(Map<String, dynamic> data) {
    return RostroEstado(
      registrado: data['rostro_registrado'] == true,
      dimensiones: (data['dimensiones'] as num?)?.toInt() ?? 0,
      nombre: data['nombre']?.toString() ?? '',
    );
  }

  final bool registrado;
  final int dimensiones;
  final String nombre;
}

/// Resultado de `POST /api/vision/registrar-rostro/:id`.
class RostroRegistro {
  const RostroRegistro({
    required this.imagenesGuardadas,
    required this.entrenamiento,
    required this.registrado,
  });

  factory RostroRegistro.fromData(Map<String, dynamic> data) {
    return RostroRegistro(
      imagenesGuardadas: (data['imagenes_guardadas'] as num?)?.toInt() ?? 0,
      entrenamiento: data['entrenamiento']?.toString(),
      registrado: data['rostro_registrado'] == true,
    );
  }

  final int imagenesGuardadas;
  final String? entrenamiento;
  final bool registrado;
}

class VisionService {
  VisionService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  /// Registra las fotos del paciente y reentrena el modelo LBPH.
  ///
  /// [imagenes] son las capturas en base64. Se envían en un solo lote porque
  /// cada llamada reentrena el modelo completo: mandarlas de una en una
  /// multiplica el coste sin benefit.
  Future<RostroRegistro> registrarRostro({
    required int pacienteId,
    required List<String> imagenes,
    required String token,
  }) async {
    final res = await _api.postJson(
      '/vision/registrar-rostro/$pacienteId',
      {'imagenes': imagenes},
      token: token,
    );
    if (!res.isSuccess) {
      throw VisionException(_mensaje(res.error));
    }
    final data = (res.data?['data'] as Map<String, dynamic>?) ?? const {};
    return RostroRegistro.fromData(data);
  }

  /// Consulta si el paciente ya tiene un descriptor facial registrado.
  Future<RostroEstado> consultarRostro({
    required int pacienteId,
    required String token,
  }) async {
    final res = await _api.getJson(
      '/vision/rostro/$pacienteId',
      token: token,
    );
    if (!res.isSuccess) {
      throw VisionException(_mensaje(res.error));
    }
    final data = (res.data?['data'] as Map<String, dynamic>?) ?? const {};
    return RostroEstado.fromData(data);
  }

  String _mensaje(String? error) {
    if (error == null || error.isEmpty) {
      return 'No se pudo completar la operación. Intente de nuevo.';
    }
    return error;
  }
}

/// Error controlado del registro facial (mensaje listo para recepción).
class VisionException implements Exception {
  const VisionException(this.message);

  final String message;

  @override
  String toString() => message;
}
