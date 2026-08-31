import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/user.dart';
import '../core/utils/app_validators.dart';

/// Autenticación con Firebase Auth.
///
/// El perfil (rol, tipo de perfil y su id en la BD) se guarda en la colección
/// `usuarios` de Firestore, usando como id el uid de Firebase Auth. De esta
/// forma el rol del usuario define a qué datos puede acceder (RBAC).
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _currentUser;
  String? _uid;
  String? _token;
  UserRole? _role;
  String? _perfilTipo;
  String? _perfilId;

  User? get currentUser => _currentUser;
  UserRole? get role => _role ?? _currentUser?.role;
  bool get isLogged => _currentUser != null;
  String? get uid => _uid;

  /// Token (ID token de Firebase) de la sesión activa.
  String? get token => _token;

  /// Tipo de perfil asociado ('medico' | 'paciente') y su id en la BD.
  String? get perfilTipo => _perfilTipo;
  String? get perfilId => _perfilId;

  AuthProvider() {
    _auth.authStateChanges().listen((u) async {
      if (u != null) {
        await _loadProfile(u);
      } else {
        _clear();
      }
      notifyListeners();
    });
  }

  Future<void> _loadProfile(dynamic u) async {
    _uid = u.uid;
    try {
      final doc = await _db.collection('usuarios').doc(u.uid).get();
      if (doc.exists) {
        final d = doc.data()!;
        _role = UserRole.fromApi(d['rol']?.toString() ?? '');
        _perfilTipo = d['perfilTipo']?.toString();
        _perfilId = d['perfilId']?.toString();
        _currentUser = User(
          id: u.uid,
          name: (d['nombre']?.toString() ?? u.displayName ?? '').trim(),
          email: (d['email']?.toString() ?? u.email ?? '').trim(),
          role: _role!,
          doctorId: _perfilId,
        );
      } else {
        _role = UserRole.paciente;
        _currentUser = User(
          id: u.uid,
          name: u.displayName ?? '',
          email: u.email ?? '',
          role: UserRole.paciente,
        );
      }
    } catch (_) {
      _role = UserRole.paciente;
      _currentUser = User(
        id: u.uid,
        name: u.displayName ?? '',
        email: u.email ?? '',
        role: UserRole.paciente,
      );
    }
  }

  /// Inicia sesión con email y contraseña.
  /// Devuelve null en éxito o el mensaje de error.
  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Email y contraseña son requeridos';
    }
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user == null) return 'No se pudo iniciar sesión';
      _token = await cred.user!.getIdToken();
      await _loadProfile(cred.user!);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  /// Registra un NUEVO paciente por autoregistro.
  ///
  /// Por seguridad el cliente SOLO puede crear cuentas de tipo `paciente`:
  /// los roles staff (admin/recepcion/medico) se crean desde el admin SDK
  /// (migración) y no pueden autoelevarse desde el cliente. Al registrarse se
  /// crea tambien su ficha en `pacientes` (con su `uid`) y se vincula
  /// `perfilId`, para que pueda consultar y cancelar sus propias citas.
  Future<String?> register({
    required String email,
    required String password,
    required String nombre,
    UserRole rol = UserRole.paciente,
  }) async {
    final r = AppValidators.email(email);
    if (r != null) return r;
    final p = AppValidators.password(password);
    if (p != null) return p;
    if (rol != UserRole.paciente) {
      return 'No tienes permisos para crear cuentas con ese rol';
    }
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      // Ficha del paciente, vinculada a esta cuenta con su uid.
      final pacienteRef = await _db.collection('pacientes').add({
        'nombre': (nombre.trim().split(' ').isNotEmpty ? nombre.trim().split(' ').first : ''),
        'apellido': (nombre.trim().split(' ').length > 1 ? nombre.trim().split(' ').skip(1).join(' ') : ''),
        'cedula': '',
        'telefono': '',
        'email': email.trim(),
        'uid': uid,
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      await _db.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nombre': nombre.trim(),
        'email': email.trim(),
        'rol': 'paciente',
        'perfilTipo': 'paciente',
        'perfilId': pacienteRef.id,
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      _token = await cred.user!.getIdToken();
      await _loadProfile(cred.user!);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  void logout() async {
    await _auth.signOut();
    _clear();
    notifyListeners();
  }

  void _clear() {
    _currentUser = null;
    _uid = null;
    _token = null;
    _role = null;
    _perfilTipo = null;
    _perfilId = null;
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El email no es válido';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o contraseña incorrectos';
      case 'email-already-in-use':
        return 'El email ya está registrado';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 8 caracteres)';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }
}
