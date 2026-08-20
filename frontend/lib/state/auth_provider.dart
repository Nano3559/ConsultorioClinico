import 'package:flutter/foundation.dart';
import '../data/models/user.dart';
import '../data/mock/mock_data.dart';

/// Autenticación. Con datos mock por ahora; al conectar el backend delegará
/// en POST /api/auth/login.
class AuthProvider extends ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;
  UserRole? get role => _currentUser?.role;
  bool get isLogged => _currentUser != null;

  String? login(String email, String password) {
    final normalized = email.trim().toLowerCase();
    // Demo: cualquier contraseña (mínimo 4 caracteres) con un correo registrado.
    if (password.length < 4) {
      return 'La contraseña debe tener al menos 4 caracteres';
    }
    User? user;
    for (final u in MockData.users) {
      if (u.email == normalized) {
        user = u;
        break;
      }
    }
    if (user == null) return 'Credenciales inválidas';
    _currentUser = user;
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}