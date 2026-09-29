import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente REST mínimo de Firebase para el kiosco Windows.
///
/// La app de escritorio NO usa los plugins de Firebase (no compilan en
/// Windows): se autentica con una cuenta de servicio (rol recepción) vía
/// Identity Toolkit y opera Firestore con el token resultante.
class KioskRest {
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyC4LkmBEK4RozuqL374WsvB6dqyWZbtmgg',
  );
  static const email = String.fromEnvironment(
    'KIOSK_EMAIL',
    defaultValue: 'kiosco@consultorio.com',
  );
  static const password = String.fromEnvironment('KIOSK_PASSWORD');

  static const project = 'consultorioclinico-2026';
  static const _fs =
      'https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents';

  String? _idToken;

  bool get signedIn => _idToken != null;

  Map<String, String> get _h => {
        'Authorization': 'Bearer $_idToken',
        'Content-Type': 'application/json',
      };

  Future<void> signIn() async {
    final res = await http
        .post(
          Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
              {'email': email, 'password': password, 'returnSecureToken': true}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('No se pudo iniciar sesión del kiosco (${res.statusCode})');
    }
    _idToken = (jsonDecode(res.body) as Map)['idToken'] as String?;
    if (_idToken == null) throw Exception('Sin token de sesión');
  }

  static String today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Lee un valor de campo Firestore REST (stringValue/integer/timestamp).
  static String s(Map<String, dynamic> fields, String key) {
    final v = fields[key];
    if (v is! Map) return '';
    if (v['stringValue'] != null) return v['stringValue'].toString();
    if (v['integerValue'] != null) return v['integerValue'].toString();
    if (v['timestampValue'] != null) return v['timestampValue'].toString();
    return '';
  }

  static String docId(String name) => name.split('/').last;

  /// Citas de hoy que no están finalizadas.
  Future<List<KioskCita>> citasHoy() async {
    final res = await http
        .get(Uri.parse('$_fs/citas?pageSize=300'), headers: _h)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('No se pudo leer la agenda (${res.statusCode})');
    }
    final docs = ((jsonDecode(res.body) as Map)['documents'] as List?) ?? [];
    final hoy = today();
    final out = <KioskCita>[];
    for (final d in docs) {
      final m = d as Map<String, dynamic>;
      final f = (m['fields'] as Map?)?.cast<String, dynamic>() ?? {};
      if (s(f, 'fecha') != hoy) continue;
      final estado = s(f, 'estado');
      if (estado == 'completada' || estado == 'cancelada' || estado == 'no_show') {
        continue;
      }
      out.add(KioskCita(
        id: docId(m['name'].toString()),
        pacienteId: s(f, 'paciente_id'),
        medicoId: s(f, 'medico_id'),
        fecha: s(f, 'fecha'),
        hora: s(f, 'hora'),
        motivo: s(f, 'motivo'),
        estado: estado,
      ));
    }
    out.sort((a, b) => a.hora.compareTo(b.hora));
    return out;
  }

  Future<KioskPaciente?> paciente(String id) async {
    final res = await http
        .get(Uri.parse('$_fs/pacientes/$id'), headers: _h)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    final f = ((jsonDecode(res.body) as Map)['fields'] as Map?)
            ?.cast<String, dynamic>() ??
        {};
    return KioskPaciente(
      id: id,
      nombre: '${s(f, 'nombre')} ${s(f, 'apellido')}'.trim(),
      faceBase64: s(f, 'foto_base64'),
    );
  }

  Future<String> medicoNombre(String id) async {
    try {
      final res = await http
          .get(Uri.parse('$_fs/medicos/$id'), headers: _h)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return '';
      final f = ((jsonDecode(res.body) as Map)['fields'] as Map?)
              ?.cast<String, dynamic>() ??
          {};
      return '${s(f, 'nombre')} ${s(f, 'apellido')}'.trim();
    } catch (_) {
      return '';
    }
  }

  /// Marca la cita como confirmada (check-in del kiosco).
  Future<void> confirmarCita(String citaId) async {
    final res = await http
        .patch(
          Uri.parse('$_fs/citas/$citaId?updateMask.fieldPaths=estado'),
          headers: _h,
          body: jsonEncode({
            'fields': {
              'estado': {'stringValue': 'confirmada'}
            }
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('No se pudo confirmar la cita (${res.statusCode})');
    }
  }
}

class KioskCita {
  const KioskCita({
    required this.id,
    required this.pacienteId,
    required this.medicoId,
    required this.fecha,
    required this.hora,
    required this.motivo,
    required this.estado,
  });

  final String id;
  final String pacienteId;
  final String medicoId;
  final String fecha;
  final String hora;
  final String motivo;
  final String estado;

  /// programada/pendiente = por confirmar; confirmada = ya hizo check-in.
  bool get porConfirmar => estado == 'programada' || estado == 'pendiente';
}

class KioskPaciente {
  const KioskPaciente({
    required this.id,
    required this.nombre,
    required this.faceBase64,
  });

  final String id;
  final String nombre;
  final String faceBase64;
}
