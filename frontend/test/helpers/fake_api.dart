import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:consultorio_clinico/services/api_client.dart';

/// Respuestas simuladas de la API para los tests (sin red).
///
/// Emula POST /api/auth/login con las cuentas sembradas en MySQL.
ApiClient fakeApiClient() {
  const rolesByEmail = {
    'admin@consultorio.com': 'admin',
    'carlos@consultorio.com': 'medico',
    'maria@consultorio.com': 'recepcion',
    'pedro@gmail.com': 'paciente',
  };

  return ApiClient(
    client: MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/auth/login')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final email = (body['email'] as String).trim().toLowerCase();
        final password = body['password'] as String? ?? '';
        const passwords = {
          'admin@consultorio.com': 'admin123',
          'carlos@consultorio.com': 'medico123',
          'maria@consultorio.com': 'recepcion123',
          'pedro@gmail.com': 'paciente123',
        };
        if (rolesByEmail.containsKey(email) && passwords[email] == password) {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Inicio de sesión exitoso',
              'data': {
                'id': 1,
                'nombre': 'Usuario Demo',
                'email': email,
                'rol': rolesByEmail[email],
                'token': 'token-de-prueba',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'success': false, 'message': 'Credenciales inválidas'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'success': false, 'message': 'Endpoint no simulado'}),
        404,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}
