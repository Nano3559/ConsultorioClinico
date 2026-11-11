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
//     GET  /api/reportes?desde=&hasta=&medico=&especialidad=&estado=
//   Cardiología IA (CardiologiaEGC, FastAPI + PyTorch)
//     GET  /health                     -> { status }
//     POST /api/analizar-ecg (multipart, CSV de 12 derivaciones)
//          -> { diagnostico_principal, confianza, desglose, bpm,
//               causas, recomendaciones }
// ============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Configuración de la API.
class ApiConfig {
  ApiConfig._();

  /// URL del backend desplegado en Vercel. En local se puede sobreescribir con:
  /// flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://consultorio-clinico-brayan.vercel.app/api',
  );

  static const Duration timeout = Duration(seconds: 15);
}

/// Resultado genérico de una petición.
class ApiResult<T> {
  const ApiResult.success(this.data, [this.statusCode]) : error = null;
  const ApiResult.failure(this.error, [this.statusCode]) : data = null;

  final T? data;
  final String? error;

  /// Código HTTP de la respuesta (null si no hubo conexión).
  final int? statusCode;

  bool get isSuccess => error == null;
}

/// Cliente HTTP listo para consumir el backend.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers({String? token, Map<String, String>? extra}) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        ...?extra,
      };

  Future<ApiResult<Map<String, dynamic>>> getJson(
    String path, {
    Map<String, String>? query,
    String? token,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
        queryParameters: query,
      );
      final res = await _client
          .get(uri, headers: _headers(token: token, extra: extraHeaders))
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
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final res = await _client
          .post(uri,
              headers: _headers(token: token, extra: extraHeaders),
              body: jsonEncode(body))
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

  Future<ApiResult<Map<String, dynamic>>> deleteJson(
    String path, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final res = await _client
          .delete(uri, headers: _headers(token: token))
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
        return ApiResult.success(decoded, res.statusCode);
      }
      final msg = decoded['message'] ?? decoded['error'] ?? 'Error del servidor';
      return ApiResult.failure(msg.toString(), res.statusCode);
    }
    return ApiResult.failure(
        'Respuesta inesperada del servidor', res.statusCode);
  }

  void dispose() => _client.close();
}

/// Configuración del servicio de IA de ECG (carpeta CardiologiaEGC).
class EcgApiConfig {
  EcgApiConfig._();

  /// URL del servidor FastAPI del modelo ECG_ResNet1D (PyTorch). Se levanta
  /// en local con: `uvicorn app:app --host 127.0.0.1 --port 8000`.
  /// Se puede sobreescribir con:
  /// flutter run --dart-define=ECG_API_BASE_URL=http://localhost:8000
  static const String baseUrl = String.fromEnvironment(
    'ECG_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// La inferencia del modelo suele responder en milisegundos; el margen cubre
  /// equipos lentos sin dejar al usuario esperando si el servicio no responde.
  static const Duration timeout = Duration(seconds: 20);
}

/// Cliente HTTP para el servicio de análisis de ECG de Cardiología.
///
/// Es un backend distinto al de Node.js (FastAPI + PyTorch), por eso mantiene
/// su propia configuración ([EcgApiConfig]) reutilizando [ApiResult] para que
/// el manejo de errores sea uniforme en toda la app.
class EcgApiClient {
  EcgApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Comprueba si el servidor del modelo está activo (badge de estado).
  Future<bool> servidorActivo() async {
    try {
      final res = await _client
          .get(Uri.parse('${EcgApiConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Envía el CSV de 12 derivaciones a `POST /api/analizar-ecg` y devuelve el
  /// dictamen del modelo (diagnóstico, confianza, causas y recomendaciones).
  Future<ApiResult<Map<String, dynamic>>> analizarEcg({
    required String nombreArchivo,
    required Uint8List bytes,
  }) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${EcgApiConfig.baseUrl}/api/analizar-ecg'),
      )
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: nombreArchivo,
        ));
      final streamed = await _client
          .send(req)
          .timeout(EcgApiConfig.timeout)
          .then(http.Response.fromStream);
      final decoded = jsonDecode(utf8.decode(streamed.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
          return ApiResult.success(decoded);
        }
        // FastAPI responde los errores con { "detail": "..." }.
        final msg = decoded['detail'] ?? decoded['message'] ?? 'Error del servidor';
        return ApiResult.failure(msg.toString());
      }
      return ApiResult.failure('Respuesta inesperada del servidor');
    } on Exception {
      return ApiResult.failure('Sin conexión con el servidor de ECG');
    }
  }

  void dispose() => _client.close();
}