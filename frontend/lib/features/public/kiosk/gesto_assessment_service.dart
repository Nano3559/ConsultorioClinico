import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../services/api_client.dart';

/// Veredicto del servidor para un frame de la vista previa.
class VeredictoGesto {
  const VeredictoGesto({
    required this.gestoOk,
    required this.mensaje,
    required this.tieneRostro,
    this.yaw,
    this.pitch,
  });

  final bool gestoOk;
  final String mensaje;
  final bool tieneRostro;
  final double? yaw;
  final double? pitch;

  static VeredictoGesto? desdeApi(Map<String, dynamic>? data, String mensaje) {
    if (data == null || data['gesto_ok'] is! bool) return null;
    double? comoDouble(String k) {
      final v = data[k];
      return v is num ? v.toDouble() : null;
    }

    return VeredictoGesto(
      gestoOk: data['gesto_ok'] as bool,
      mensaje: mensaje,
      tieneRostro: data['tiene_rostro'] == true,
      yaw: comoDouble('yaw'),
      pitch: comoDouble('pitch'),
    );
  }
}

/// Evaluación de gesto en el servidor (landmarks YuNet reales).
///
/// El diálogo la usa como veredicto autoritativo cuando el encuadre local
/// ya está decente; si tarda o falla, el diálogo sigue con la heurística
/// local (por eso esto NUNCA lanza: devuelve null).
class GestoAssessmentService {
  GestoAssessmentService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  Future<VeredictoGesto?> evaluar({
    required String base64Jpeg,
    required String pose,
    double? yawRef,
    double? pitchRef,
    bool espejado = kIsWeb,
  }) async {
    try {
      final body = <String, dynamic>{
        'imagen': base64Jpeg,
        'pose': pose,
        'espejado': espejado,
      };
      if (yawRef != null) body['yaw_ref'] = yawRef;
      if (pitchRef != null) body['pitch_ref'] = pitchRef;
      final res = await _api
          .postJson('/vision/evaluar-gesto', body)
          .timeout(const Duration(seconds: 8));
      if (!res.isSuccess) return null;
      final data = res.data?['data'];
      final info = data is Map<String, dynamic> ? data : null;
      final mensaje = (res.data?['message'] ?? '').toString();
      return VeredictoGesto.desdeApi(info, mensaje);
    } catch (_) {
      return null;
    }
  }
}
