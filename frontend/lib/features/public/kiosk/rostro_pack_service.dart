import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../services/api_client.dart';

/// Puente de la reserva online con el backend biométrico (Supabase).
///
/// La reserva vive en Firestore, pero el kiosco reconoce contra Supabase:
/// este servicio conecta ambos mundos por cédula —
///   GET  /api/pacientes/buscar?cedula=  -> existe + rostro_vigente
///   POST /api/kiosco/paquete-rostro      -> crea el paciente del backend
///                                           (si falta) y registra su pack
///                                           multi-pose en la carpeta
///                                           rostros/{cedula}_{nombre}/
class RostroPackService {
  RostroPackService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  /// Busca al paciente del backend por cédula. No requiere sesión
  /// (rate limit en el servidor + respuesta mínima anti-enumeración).
  Future<BusquedaPaciente> buscarPorCedula(String cedula) async {
    final res = await _api.getJson(
      '/pacientes/buscar',
      query: {'cedula': cedula.trim()},
    );
    if (!res.isSuccess) {
      throw RostroPackException(res.error ?? 'No se pudo buscar al paciente.');
    }
    return BusquedaPaciente.fromData(
        (res.data?['data'] as Map<String, dynamic>?) ?? const {});
  }

  /// Registra el pack facial multi-pose (una muestra por pose como mínimo).
  /// [muestras] = [{imagen: base64 liviano, pose: frontal|izquierda|...}].
  Future<PackRegistrado> ingestarPaquete({
    required String cedula,
    required String nombre,
    required String apellido,
    String? telefono,
    String? email,
    String? fechaNacimiento,
    required List<Map<String, String>> muestras,
  }) async {
    final res = await _api.postJson('/kiosco/paquete-rostro', {
      'cedula': cedula.trim(),
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      if (telefono != null && telefono.trim().isNotEmpty)
        'telefono': telefono.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (fechaNacimiento != null && fechaNacimiento.isNotEmpty)
        'fecha_nacimiento': fechaNacimiento,
      'muestras': muestras,
      // Avisa si las fotos vienen espejadas (web sí, móvil no) para que el
      // servidor mida el giro al lado correcto.
      'espejado': kIsWeb,
    });
    if (!res.isSuccess) {
      throw RostroPackException(res.error ?? 'No se pudo registrar el rostro.');
    }
    return PackRegistrado.fromData(
        (res.data?['data'] as Map<String, dynamic>?) ?? const {});
  }
}

/// Resultado de `GET /api/pacientes/buscar`.
class BusquedaPaciente {
  const BusquedaPaciente({
    required this.existe,
    this.nombre,
    this.apellido,
    this.telefono,
    this.email,
    this.fechaNacimiento,
    this.rostroVigente = false,
    this.fotoRequerida = true,
  });

  factory BusquedaPaciente.fromData(Map<String, dynamic> data) {
    final p = data['paciente'];
    final pm = p is Map<String, dynamic> ? p : null;
    return BusquedaPaciente(
      existe: data['existe'] == true,
      nombre: pm?['nombre']?.toString(),
      apellido: pm?['apellido']?.toString(),
      telefono: pm?['telefono']?.toString(),
      email: pm?['email']?.toString(),
      fechaNacimiento: pm?['fecha_nacimiento']?.toString(),
      rostroVigente: data['rostro_vigente'] == true,
      fotoRequerida: data['foto_requerida'] != false,
    );
  }

  final bool existe;
  final String? nombre;
  final String? apellido;
  final String? telefono;
  final String? email;
  final String? fechaNacimiento;
  final bool rostroVigente;
  final bool fotoRequerida;
}

/// Resultado de `POST /api/kiosco/paquete-rostro`.
class PackRegistrado {
  const PackRegistrado({
    required this.pacienteId,
    required this.guardadas,
    required this.registrado,
    this.rechazadas = const {},
  });

  factory PackRegistrado.fromData(Map<String, dynamic> data) {
    final rechazadas = <String, String>{};
    final rawR = data['rechazadas'];
    if (rawR is Map) {
      rawR.forEach((k, v) {
        rechazadas[k.toString()] = v.toString();
      });
    }
    return PackRegistrado(
      pacienteId: (data['paciente_id'] as num?)?.toInt() ?? 0,
      guardadas: (data['guardadas'] as num?)?.toInt() ?? 0,
      registrado: data['rostro_registrado'] == true,
      rechazadas: rechazadas,
    );
  }

  final int pacienteId;
  final int guardadas;
  final bool registrado;

  /// Poses rechazadas con su motivo.
  final Map<String, String> rechazadas;
}

class RostroPackException implements Exception {
  const RostroPackException(this.message);

  final String message;

  @override
  String toString() => message;
}
