// ============================================================================
// CLIENTE HTTP PARA EL BACKEND (Node.js)
// ----------------------------------------------------------------------------
// El backend lo desarrollan tus compañeras. Este archivo centraliza la
// configuración de la API y el contrato de endpoints esperado, para que al
// conectar solo haya que completar la URL base y habilitar los métodos.
//
// CONTRATO DE ENDPOINTS ESPERADO (REST / JSON):
//   Auth
//     POST /api/auth/login        { email, password } -> { user, token }
//     POST /api/auth/register     { ...datos }        -> { user }
//   Especialidades
//     GET  /api/especialidades                          -> [Specialty]
//     POST /api/especialidades                          -> Specialty
//   Médicos
//     GET  /api/medicos                                 -> [Doctor]
//     GET  /api/medicos/:id                             -> Doctor
//     POST /api/medicos                                 -> Doctor
//     PUT  /api/medicos/:id                             -> Doctor
//     PATCH /api/medicos/:id/estado     { active }      -> Doctor
//   Pacientes
//     GET  /api/pacientes                               -> [Patient]
//     GET  /api/pacientes/:id                           -> Patient
//     POST /api/pacientes                               -> Patient
//     PUT  /api/pacientes/:id                           -> Patient
//   Citas
//     GET    /api/citas                                 -> [Appointment]
//     GET    /api/citas?fecha=YYYY-MM-DD                -> [Appointment]
//     POST   /api/citas                                 -> Appointment
//     PATCH  /api/citas/:id/estado     { status }       -> Appointment
//     PATCH  /api/citas/:id/reprogramar { fecha, hora } -> Appointment
//     DELETE /api/citas/:id                             -> 204 (libera horario)
//   Historia clínica
//     GET  /api/pacientes/:id/historia                  -> { patient, consults }
//     POST /api/consultas                               -> ConsultRecord
//   Pagos
//     GET  /api/pagos                                   -> [Payment]
//     POST /api/pagos                                   -> Payment
//     PATCH /api/pagos/:id/estado     { status }        -> Payment
//   Reportes
//     GET /api/reportes?desde=&hasta=&medico=&especialidad=&estado=
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Configuración de la API.
class ApiConfig {
  ApiConfig._();

  /// Reemplazar con la URL del backend desplegado (ej: https://api.clinica.com).
  static const String baseUrl = 'http://localhost:3000/api';

  static const Duration timeout = Duration(seconds: 15);
}

/// Resultado genérico de una petición.
class ApiResult<T> {
  const ApiResult.success(this.data) : error = null;
  const ApiResult.failure(this.error) : data = null;

  final T? data;
  final String? error;

  bool get isSuccess => error == null;
}

/// Cliente HTTP listo para consumir el backend.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<ApiResult<Map<String, dynamic>>> getJson(
    String path, {
    Map<String, String>? query,
    String? token,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
        queryParameters: query,
      );
      final res = await _client
          .get(uri, headers: _headers(token: token))
          .timeout(ApiConfig.timeout);
      return _parse(res);
    } catch (e) {
      return ApiResult.failure('Sin conexión con el servidor');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final res = await _client
          .post(uri, headers: _headers(token: token), body: jsonEncode(body))
          .timeout(ApiConfig.timeout);
      return _parse(res);
    } catch (e) {
      return ApiResult.failure('Sin conexión con el servidor');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> putJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final res = await _client
          .put(uri, headers: _headers(token: token), body: jsonEncode(body))
          .timeout(ApiConfig.timeout);
      return _parse(res);
    } catch (e) {
      return ApiResult.failure('Sin conexión con el servidor');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final res = await _client
          .patch(uri, headers: _headers(token: token), body: jsonEncode(body))
          .timeout(ApiConfig.timeout);
      return _parse(res);
    } catch (e) {
      return ApiResult.failure('Sin conexión con el servidor');
    }
  }

  ApiResult<Map<String, dynamic>> _parse(http.Response res) {
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(decoded);
      }
      final msg = decoded['message'] ?? decoded['error'] ?? 'Error del servidor';
      return ApiResult.failure(msg.toString());
    }
    return ApiResult.failure('Respuesta inesperada del servidor');
  }

  void dispose() => _client.close();
}