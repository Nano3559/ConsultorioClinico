// ============================================================================
// SERVICIO DE REGISTRO FACIAL
// ----------------------------------------------------------------------------
// Expone los endpoints de vision/ para que recepción capture el pack
// multi-pose de un paciente y lo registre con InsightFace:
//
//   POST /api/vision/registrar-rostro/:id  { imagenes: [{imagen, pose}] }
//   GET  /api/vision/rostro/:id             -> estado del descriptor
//
// Ambos exigen verifyToken + checkRole('admin','recepcion'), por eso el token
// se toma de AuthProvider en cada llamada.
// ============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;

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
    required this.registrado,
    this.porPose = const {},
    this.rechazadas = const {},
  });

  factory RostroRegistro.fromData(Map<String, dynamic> data) {
    final porPose = <String, double>{};
    final raw = data['por_pose'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) porPose[k.toString()] = v.toDouble();
      });
    }
    final rechazadas = <String, String>{};
    final rawR = data['rechazadas'];
    if (rawR is Map) {
      rawR.forEach((k, v) {
        rechazadas[k.toString()] = v.toString();
      });
    }
    return RostroRegistro(
      imagenesGuardadas: (data['imagenes_guardadas'] as num?)?.toInt() ?? 0,
      registrado: data['rostro_registrado'] == true,
      porPose: porPose,
      rechazadas: rechazadas,
    );
  }

  final int imagenesGuardadas;
  final bool registrado;

  /// Calidad por pose devuelta por el servidor (0-100).
  final Map<String, double> porPose;

  /// Poses rechazadas con su motivo (repetir esas fotos).
  final Map<String, String> rechazadas;
}

class VisionService {
  VisionService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  /// Registra el pack multi-pose del paciente (YuNet+SFace).
  ///
  /// [muestras] = [{imagen: base64 liviano, pose: frontal|izquierda|...}].
  /// Se envían en un solo lote (una llamada, un procesamiento).
  Future<RostroRegistro> registrarRostro({
    required int pacienteId,
    required List<Map<String, String>> muestras,
    required String token,
  }) async {
    final res = await _api.postJson(
      '/vision/registrar-rostro/$pacienteId',
      {
        'imagenes': muestras,
        // La recepción también puede operar desde la web (espejada).
        'espejado': kIsWeb,
      },
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
