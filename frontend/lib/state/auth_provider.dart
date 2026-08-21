import 'package:flutter/foundation.dart';
import '../data/models/user.dart';
import '../services/api_client.dart';

/// Autenticación contra el backend (POST /api/auth/login con MySQL + JWT).
class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  User? _currentUser;
  String? _token;

  User? get currentUser => _currentUser;
  UserRole? get role => _currentUser?.role;
  bool get isLogged => _currentUser != null;

  /// Token JWT de la sesión activa; úsalo en las demás llamadas a la API.
  String? get token => _token;

  /// Intenta iniciar sesión. Devuelve null en éxito o el mensaje de error.
  Future<String?> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (password.isEmpty) {
      return 'La contraseña es requerida';
    }

    final result = await _api.postJson('/auth/login', {
      'email': normalized,
      'password': password,
    });

    if (!result.isSuccess) return result.error;

    final data = result.data!['data'];
    if (data is! Map<String, dynamic>) {
      return 'Respuesta inesperada del servidor';
    }

    _token = data['token']?.toString();
    _currentUser = User(
      id: data['id']?.toString() ?? '',
      name: data['nombre']?.toString() ?? '',
      email: data['email']?.toString() ?? normalized,
      role: UserRole.fromApi(data['rol']?.toString() ?? ''),
    );
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    _token = null;
    notifyListeners();
  }
}
