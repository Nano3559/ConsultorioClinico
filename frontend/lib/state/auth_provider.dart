import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/patient.dart';
import '../data/models/user.dart';

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

  /// Registra un nuevo usuario (paciente o, si lo crea un admin, cualquier rol).
  /// Crea la cuenta en Firebase Auth y el documento de perfil en `usuarios`.
  Future<String?> register({
    required String email,
    required String password,
    required String nombre,
    required UserRole rol,
    String? perfilId,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      await _db.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nombre': nombre.trim(),
        'email': email.trim(),
        'rol': _rolToString(rol),
        'perfilTipo':
            rol == UserRole.medico ? 'medico' : rol == UserRole.paciente ? 'paciente' : null,
        'perfilId': perfilId,
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

  // ---- Credenciales derivadas para pacientes (login solo con CI + nacimiento) ----
  static String patientEmail(String ci) {
    final clean = ci.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return 'pac_$clean@clinica.app';
  }

  static String patientPassword(String ci, DateTime birthDate) {
    final ymd =
        '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
    return 'Pac.$ci.$ymd';
  }

  /// Inicia sesión de un paciente usando solo su CI y fecha de nacimiento.
  Future<String?> loginPatient(String ci, DateTime birthDate) async {
    return login(patientEmail(ci), patientPassword(ci, birthDate));
  }

  /// App de Firebase secundaria para crear cuentas sin alterar la sesión actual.
  static FirebaseApp? _secondaryApp;
  static Future<FirebaseAuth> _secondaryAuth() async {
    _secondaryApp ??=
        await Firebase.initializeApp(name: 'secondary', options: Firebase.app().options);
    return FirebaseAuth.instanceFor(app: _secondaryApp!);
  }

  static String _tempPassword() =>
      'Temp${DateTime.now().microsecondsSinceEpoch.abs()}';

  /// Crea la cuenta de un paciente (Auth + pacientes + usuarios) sin afectar la
  /// sesión actual. Si [autoSignIn] es true, además inicia sesión en la app
  /// principal (para el flujo de autoregistro público).
  /// Devuelve (uid, null) en éxito o (null, mensajeError) en fallo.
  Future<(String?, String?)> registerPatient(Patient p, {bool autoSignIn = false}) async {
    try {
      final secondary = await _secondaryAuth();
      final cred = await secondary.createUserWithEmailAndPassword(
        email: patientEmail(p.ci),
        password: patientPassword(p.ci, p.birthDate),
      );
      final uid = cred.user!.uid;
      final data = {...p.toApiJson(), 'id': uid, 'uid': uid};
      await _db.collection('pacientes').doc(uid).set(data);
      await _db.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nombre': p.fullName,
        'email': patientEmail(p.ci),
        'rol': 'paciente',
        'perfilTipo': 'paciente',
        'perfilId': uid,
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      if (autoSignIn) {
        final res = await _auth.signInWithEmailAndPassword(
          email: patientEmail(p.ci),
          password: patientPassword(p.ci, p.birthDate),
        );
        if (res.user != null) {
          _token = await res.user!.getIdToken();
          await _loadProfile(res.user!);
        }
      }
      return (uid, null);
    } on FirebaseAuthException catch (e) {
      return (null, _authError(e));
    } catch (e) {
      return (null, 'Error inesperado: $e');
    }
  }

  /// Alta de médico desde el admin: crea Auth + perfiles y envía correo de
  /// confirmación (restablecer contraseña de Firebase) para que fije su clave.
  Future<String?> registerDoctor({
    required String email,
    required String nombre,
    required Map<String, dynamic> medicoData,
  }) async {
    try {
      final secondary = await _secondaryAuth();
      final cred = await secondary.createUserWithEmailAndPassword(
        email: email.trim(),
        password: _tempPassword(),
      );
      final uid = cred.user!.uid;
      await _db.collection('medicos').doc(uid).set({
        ...medicoData,
        'id': uid,
        'uid': uid,
        'email': email.trim(),
        'activo': true,
      });
      await _db.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nombre': nombre.trim(),
        'email': email.trim(),
        'rol': 'medico',
        'perfilTipo': 'medico',
        'perfilId': uid,
        'activo': false,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      await secondary.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: ActionCodeSettings(
          url: 'https://consultorioclinico-2026.web.app/reset',
          handleCodeInApp: true,
          iOSBundleId: 'com.example.consultorioClinico',
          androidPackageName: 'com.example.consultorioClinico',
          androidInstallApp: false,
        ),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  /// Verifica un código de acción por correo (reset/confirmación).
  Future<String?> verifyResetCode(String oobCode) async {
    try {
      await _auth.checkActionCode(oobCode);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } catch (e) {
      return 'El enlace no es válido o expiró.';
    }
  }

  /// Fija la contraseña del médico tras confirmar el correo.
  Future<String?> confirmPasswordReset(String oobCode, String newPassword) async {
    try {
      await _auth.confirmPasswordReset(code: oobCode, newPassword: newPassword);
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

  String _rolToString(UserRole rol) {
    switch (rol) {
      case UserRole.admin:
        return 'admin';
      case UserRole.medico:
        return 'medico';
      case UserRole.recepcion:
        return 'recepcion';
      case UserRole.paciente:
        return 'paciente';
    }
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
        return 'La contraseña es muy débil (mínimo 6 caracteres)';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }
}
