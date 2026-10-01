import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/user.dart';
import '../data/models/specialty.dart';
import '../data/models/doctor.dart';
import '../data/models/patient.dart';
import '../data/models/appointment.dart';
import '../data/models/consult_record.dart';
import '../data/models/payment.dart';
import '../data/mock/mock_data.dart';
import '../core/constants/app_constants.dart';
import '../core/widgets/app_status_badge.dart';
import '../services/firestore_service.dart';
import '../services/api_client.dart';

/// Proveedor principal de la clínica.
///
/// Fuentes de verdad (migración progresiva a Supabase):
/// catálogo público + pacientes + citas + consultas + pagos vía API
/// Express. En Firestore quedan solo puentes legacy (foto del rostro,
/// registro de pacientes sin cuenta, doc de rol) hasta la Fase 6.
/// [FirebaseAuth] notifica el cambio y [loadAll] recarga las listas
/// aplicando el alcance según el rol (RBAC).
class ClinicProvider extends ChangeNotifier {
  ClinicProvider() {
    FirebaseAuth.instance.authStateChanges().listen((_) => loadAll());
    loadAll();
  }

  final FirestoreService _fs = FirestoreService();
  final ApiClient _api = ApiClient();

  final List<Specialty> _specialties = [];
  final List<Doctor> _doctors = [];
  final List<Patient> _patients = [];
  final List<Appointment> _appointments = [];
  final List<ConsultRecord> _consults = [];
  final List<Payment> _payments = [];

  String? _uid;
  UserRole? _role;

  /// Firebase ID token para los endpoints protegidos de la API
  /// (pacientes, y en Fases 4-5: citas, consultas, pagos).
  String? _apiToken;
  String? _error;
  bool _loading = false;
  bool _catalogLoaded = false;

  /// Turnos ocupados (medico_id|fecha|hora). Fuente publica: coleccion
  /// `disponibilidad`. Permite calcular la disponibilidad sin leer las citas
  /// (que contienen datos de paciente y estan restringidas).
  final Set<String> _occupied = {};

  // ---- Getters inmutables ------------------------------------------------
  List<Specialty> get specialties => List.unmodifiable(_specialties);
  List<Doctor> get doctors => List.unmodifiable(_doctors);
  List<Patient> get patients => List.unmodifiable(_patients);
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<ConsultRecord> get consults => List.unmodifiable(_consults);
  List<Payment> get payments => List.unmodifiable(_payments);

  String? get error => _error;
  bool get usingApi => true;
  bool get isLoading => _loading;

  /// Inyecta el JWT tras el login (compatibilidad). La sesión real la maneja
  /// Firebase Auth, así que solo disparamos una recarga con el alcance correcto.
  void setAuthToken(String? token, {String? perfilTipo, String? perfilId}) {
    loadAll();
  }

  // ---- Carga inicial desde Firestore -------------------------------------
  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _uid = FirebaseAuth.instance.currentUser?.uid;
      _role = null;
      if (_uid != null) {
        final u = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_uid)
            .get();
        if (u.exists) _role = UserRole.fromApi(u.data()!['rol']?.toString() ?? '');
      }
      try {
        _apiToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {
        _apiToken = null;
      }

      await _loadEspecialidades();
      await _loadHorarios();
      await _loadMedicos();
      await _loadPacientes();

      // Las citas/consultas/pagos son privadas: solo se cargan con sesion.
      if (_uid != null) {
        await _loadCitas();
        await _loadConsultas();
        await _loadPagos();
      }

      if (_isMedico) _scopePatientsToMedico();
    } catch (e) {
      _error = 'No se pudo cargar la información. Revisa tu conexión.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  bool get _isMedico => _role == UserRole.medico && _uid != null;
  bool get _isPaciente => _role == UserRole.paciente && _uid != null;

  /// Carga el catálogo público (especialidades, horarios y médicos activos)
  /// sin requerir sesión. Fuente: API Express (Supabase).
  /// No incluye pacientes: el endpoint exige auth y la reserva usa el
  /// lookup por CI contra el backend.
  Future<void> loadPublicCatalog() async {
    if (_catalogLoaded) return;
    _catalogLoaded = true;
    _loading = true;
    notifyListeners();
    try {
      await _loadEspecialidades();
      await _loadHorarios();
      await _loadMedicos();
    } catch (e) {
      _error = 'No se pudo cargar el catálogo. Revisa tu conexión.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Carga los turnos ocupados de un médico en una fecha (API Supabase).
  /// Es mejor-esfuerzo: si falla, la regla de Firestore sigue impidiendo
  /// la doble reserva al intentar guardar.
  Future<void> loadAvailability(String medicoId, DateTime date) async {
    try {
      final f = _fmt(date);
      final res = await _api.getJson(
        '/horarios/disponibles',
        query: {'medico_id': medicoId, 'fecha': f},
      );
      if (res.isSuccess) {
        final data = res.data?['data'];
        if (data is List) {
          for (final d in data) {
            if (d is Map) {
              final h = (d['hora'] ?? '').toString();
              if (h.isNotEmpty) _occupied.add(_occKey(medicoId, f, h));
            }
          }
        }
      }
      notifyListeners();
    } catch (_) {
      // Silencioso: la disponibilidad es informativa; la regla lo garantiza.
    }
  }

  static String _occKey(String m, String f, String h) => '$m|$f|$h';
  bool _isOccupied(String m, String f, String h) => _occupied.contains(_occKey(m, f, h));

  Future<void> _loadEspecialidades() async {
    final res = await _api.getJson('/especialidades');
    if (!res.isSuccess) throw Exception(res.error);
    final data = res.data?['data'];
    _specialties
      ..clear()
      ..addAll((data as List? ?? [])
          .whereType<Map>()
          .map((e) => Specialty.fromApi(Map<String, dynamic>.from(e))));
  }

  Future<void> _loadHorarios() async {
    final res = await _api.getJson('/horarios');
    if (!res.isSuccess) throw Exception(res.error);
    final data = res.data?['data'];
    final byDoctor = <String, Map<String, List<String>>>{};
    for (final h in (data as List? ?? [])) {
      if (h is! Map) continue;
      final med = (h['medico_id'] ?? '').toString();
      final dia = _shortDay((h['dia_semana'] ?? '').toString());
      final slots = _expandSlots(
        (h['hora_inicio'] ?? '').toString(),
        (h['hora_fin'] ?? '').toString(),
      );
      byDoctor[med] ??= {};
      byDoctor[med]![dia] = [...(byDoctor[med]![dia] ?? []), ...slots];
    }
    _schedules
      ..clear()
      ..addAll(byDoctor.map((k, v) => MapEntry(k, DoctorSchedule(v))));
  }

  Future<void> _loadMedicos() async {
    final res = await _api.getJson('/medicos');
    if (!res.isSuccess) throw Exception(res.error);
    final data = res.data?['data'];
    _doctors.clear();
    for (final m in (data as List? ?? [])) {
      if (m is! Map) continue;
      final mm = Map<String, dynamic>.from(m);
      final sid = (mm['especialidad_id'] ?? '').toString();
      _doctors.add(Doctor.fromApi(
        mm,
        specialtyId: sid,
        schedule: _schedules[mm['id'].toString()] ?? const DoctorSchedule({}),
      ));
    }
  }

  /// Lista de pacientes. Fuente: API Supabase (requiere sesión del staff).
  /// Sin sesión no hay lista (el lookup por CI de la reserva usa el
  /// endpoint público /pacientes/buscar). El rol paciente conserva la
  /// lectura acotada en Firestore (su ficha, por uid).
  Future<void> _loadPacientes() async {
    if (_uid == null || _apiToken == null || _isPaciente) {
      if (_isPaciente) {
        final data = await _fs.getList(
          'pacientes',
          scopeField: 'uid',
          scopeValue: _uid,
        );
        _patients
          ..clear()
          ..addAll(data.map(Patient.fromApi));
      } else {
        _patients.clear();
      }
      return;
    }
    final res = await _api.getJson('/pacientes', token: _apiToken);
    if (!res.isSuccess) throw Exception(res.error);
    final data = res.data?['data'];
    _patients
      ..clear()
      ..addAll((data as List? ?? [])
          .whereType<Map>()
          .map((e) => Patient.fromApi(Map<String, dynamic>.from(e))));
  }

  // Un médico solo debe ver los pacientes que tienen citas o consultas a su nombre.
  void _scopePatientsToMedico() {
    final mine = <String>{
      for (final a in _appointments) a.patientId,
      for (final c in _consults) c.patientId,
    };
    _patients.removeWhere((p) => !mine.contains(p.id));
  }

  /// Token fresco para la API (usa el cacheado o lo pide a Firebase).
  Future<String?> _token() async {
    if (_apiToken != null) return _apiToken;
    try {
      _apiToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      _apiToken = null;
    }
    return _apiToken;
  }

  /// 401/403 = el backend no reconoce al usuario (aún no vinculado):
  /// se conserva el camino legacy en Firestore en vez de fallar.
  bool _esAuthError(ApiResult res) =>
      res.statusCode == 401 || res.statusCode == 403;

  /// Lista de citas desde la API. El staff ve todo; médico/paciente ven
  /// lo suyo vía /mis-citas (el backend resuelve el perfil desde el token).
  Future<void> _loadCitas() async {
    final token = await _token();
    if (_uid != null && token != null) {
      final path = (!_isMedico && !_isPaciente) ? '/citas' : '/citas/mis-citas';
      final res = await _api.getJson(path, token: token);
      if (res.isSuccess) {
        final data = res.data?['data'];
        final list = (data is Map ? data['citas'] : null) ?? data;
        _appointments
          ..clear()
          ..addAll((list as List? ?? [])
              .whereType<Map>()
              .map((e) => Appointment.fromApi(Map<String, dynamic>.from(e))));
        return;
      }
      if (!_esAuthError(res)) throw Exception(res.error);
    }
    final data = await _fs.getList(
      'citas',
      scopeField: _isMedico
          ? 'medico_id'
          : (_isPaciente ? 'paciente_id' : null),
      scopeValue: _isMedico || _isPaciente ? _uid : null,
      orderBy: 'fecha',
    );
    _appointments
      ..clear()
      ..addAll(data.map(Appointment.fromApi));
  }

  /// Historial clínico desde la API (el servidor acota al médico a lo suyo).
  Future<void> _loadConsultas() async {
    final token = await _token();
    if (_uid != null && token != null) {
      final res = await _api.getJson('/consultas', token: token);
      if (res.isSuccess) {
        final data = res.data?['data'];
        _consults
          ..clear()
          ..addAll((data as List? ?? [])
              .whereType<Map>()
              .map((e) => ConsultRecord.fromApi(Map<String, dynamic>.from(e))));
        return;
      }
      if (!_esAuthError(res)) throw Exception(res.error);
    }
    final data = await _fs.getList(
      'consultas',
      scopeField: _isMedico
          ? 'medico_id'
          : (_isPaciente ? 'paciente_id' : null),
      scopeValue: _isMedico || _isPaciente ? _uid : null,
      orderBy: 'fecha',
    );
    _consults
      ..clear()
      ..addAll(data.map(ConsultRecord.fromApi));
  }

  /// Pagos desde la API. `pagos` no tiene columna de médico: se enriquece
  /// el doctorId vía la cita vinculada (lo usa la pantalla de pagos).
  Future<void> _loadPagos() async {
    final token = await _token();
    if (_uid != null && token != null) {
      final res = await _api.getJson('/pagos', token: token);
      if (res.isSuccess) {
        final data = res.data?['data'];
        final medicoDeCita = {for (final a in _appointments) a.id: a.doctorId};
        _payments
          ..clear()
          ..addAll((data as List? ?? []).whereType<Map>().map((e) {
            final p = Payment.fromApi(Map<String, dynamic>.from(e));
            final d = medicoDeCita[p.appointmentId];
            return (d == null || d.isEmpty)
                ? p
                : p.copyWith(doctorId: d);
          }));
        return;
      }
      if (!_esAuthError(res)) throw Exception(res.error);
    }
    final data = await _fs.getList(
      'pagos',
      scopeField: _isMedico
          ? 'medico_id'
          : (_isPaciente ? 'paciente_id' : null),
      scopeValue: _isMedico || _isPaciente ? _uid : null,
      orderBy: 'fecha_pago',
    );
    _payments
      ..clear()
      ..addAll(data.map(Payment.fromApi));
  }

  final Map<String, DoctorSchedule> _schedules = {};

  static String _shortDay(String dia) {
    const map = {
      'lunes': 'Lun',
      'martes': 'Mar',
      'miércoles': 'Mié',
      'miercoles': 'Mié',
      'jueves': 'Jue',
      'viernes': 'Vie',
      'sábado': 'Sáb',
      'sabado': 'Sáb',
      'domingo': 'Dom',
    };
    return map[dia.toLowerCase()] ?? 'Lun';
  }

  static List<String> _expandSlots(String ini, String fin) {
    int? toMin(String t) {
      final p = t.split(':');
      if (p.length < 2) return null;
      final h = int.tryParse(p[0]);
      final mi = int.tryParse(p[1]);
      if (h == null || mi == null) return null;
      return h * 60 + mi;
    }

    final a = toMin(ini);
    final b = toMin(fin);
    if (a == null || b == null || b <= a) return const [];
    final out = <String>[];
    for (var m = a; m + 30 <= b; m += 30) {
      final hh = (m ~/ 60).toString().padLeft(2, '0');
      final mm = (m % 60).toString().padLeft(2, '0');
      out.add('$hh:$mm');
    }
    return out;
  }

  // ---- Helpers de resolución ----------------------------------------------
  Specialty specialtyById(String id) =>
      _specialties.firstWhere((s) => s.id == id, orElse: () => _specialties.first);

  Doctor doctorById(String id) =>
      _doctors.firstWhere((d) => d.id == id, orElse: () => _doctors.first);

  Patient patientById(String id) =>
      _patients.firstWhere((p) => p.id == id, orElse: () => _patients.first);

  String doctorName(String id) => doctorById(id).displayName;
  String patientName(String id) => patientById(id).fullName;

  List<Patient> searchPatients(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _patients;
    return _patients.where((p) {
      return p.fullName.toLowerCase().contains(q) ||
          p.ci.contains(q) ||
          p.phone.contains(q);
    }).toList();
  }

  String specialtyNameOf(String doctorId) =>
      specialtyById(doctorById(doctorId).specialtyId).name;

  List<Doctor> doctorsBySpecialty(String specialtyId) =>
      _doctors.where((d) => d.specialtyId == specialtyId).toList();

  Doctor? firstActiveDoctor(String specialtyId) {
    for (final d in _doctors) {
      if (d.specialtyId == specialtyId && d.active) return d;
    }
    return null;
  }

  List<Doctor> get activeDoctors => _doctors.where((d) => d.active).toList();

  List<Appointment> appointmentsOfDoctor(String doctorId) =>
      _appointments.where((a) => a.doctorId == doctorId).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  List<Appointment> appointmentsOfPatient(String patientId) =>
      _appointments.where((a) => a.patientId == patientId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Appointment> appointmentsOfDay(DateTime day) => _appointments
      .where((a) =>
          a.date.year == day.year &&
          a.date.month == day.month &&
          a.date.day == day.day)
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));

  List<ConsultRecord> historyOf(String patientId) => _consults
      .where((c) => c.patientId == patientId)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  /// Devuelve el pago vinculado a una cita, o null si no tiene.
  Payment? paymentOfAppointment(String appointmentId) {
    for (final p in _payments) {
      if (p.appointmentId == appointmentId) return p;
    }
    return null;
  }

  // ---- Disponibilidad ------------------------------------------------------
  bool isSlotAvailable({
    required String doctorId,
    required DateTime date,
    required String time,
    String? excludeAppointmentId,
  }) {
    final doctor = doctorById(doctorId);
    if (!doctor.active) return false;
    final dayName = _weekdayName(date.weekday);
    if (!doctor.schedule.forDay(dayName).contains(time)) return false;

    final occupied = _appointments.any((a) =>
        a.doctorId == doctorId &&
        a.date.year == date.year &&
        a.date.month == date.month &&
        a.date.day == date.day &&
        a.time == time &&
        a.status != AppointmentStatus.cancelada &&
        a.status != AppointmentStatus.noAsistio &&
        a.id != excludeAppointmentId);
    if (occupied) return false;
    if (_isOccupied(doctorId, _fmt(date), time)) return false;
    return true;
  }

  List<String> availableSlots(String doctorId, DateTime date) {
    final doctor = doctorById(doctorId);
    final dayName = _weekdayName(date.weekday);
    return kTimeSlots.where((t) {
      if (!doctor.schedule.forDay(dayName).contains(t)) return false;
      return isSlotAvailable(doctorId: doctorId, date: date, time: t);
    }).toList();
  }

  static String _weekdayName(int weekday) => switch (weekday) {
        1 => 'Lun',
        2 => 'Mar',
        3 => 'Mié',
        4 => 'Jue',
        5 => 'Vie',
        6 => 'Sáb',
        _ => 'Lun',
      };

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---- Mutaciones (pacientes, citas, consultas y pagos: API Supabase con
  // fallback Firestore ante 401/403; ver puentes legacy) --
  /// Cuerpo para POST/PUT /pacientes: el backend usa `contacto_emergencia`
  /// (`observaciones` es solo el campo equivalente en Firestore).
  Map<String, dynamic> _patientApiBody(Patient p) {
    final body = p.toApiJson();
    if (p.observaciones.isNotEmpty) {
      body['contacto_emergencia'] = p.observaciones;
    }
    return body;
  }

  Future<Patient?> addPatient(Patient p) async {
    try {
      if (_apiToken == null) throw Exception('Sin sesión');
      final res = await _api.postJson(
        '/pacientes',
        _patientApiBody(p),
        token: _apiToken,
      );
      if (!res.isSuccess) throw Exception(res.error);
      final created = Patient.fromApi(
        Map<String, dynamic>.from(res.data?['data'] as Map),
      );
      _patients.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> updatePatient(Patient p) async {
    try {
      if (_apiToken == null) throw Exception('Sin sesión');
      final res = await _api.putJson(
        '/pacientes/${p.id}',
        _patientApiBody(p),
        token: _apiToken,
      );
      if (!res.isSuccess) throw Exception(res.error);
      final updated = Patient.fromApi(
        Map<String, dynamic>.from(res.data?['data'] as Map),
      );
      final i = _patients.indexWhere((x) => x.id == p.id);
      if (i >= 0) _patients[i] = updated;
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  /// Guarda la foto del rostro en base64 en Firestore (puente legacy para el
  /// kiosco; Fase 3 no lo migra porque el flujo nuevo usa el pack facial
  /// del backend y PUT /pacientes no acepta `foto_base64`).
  Future<String?> setPatientFace(String patientId, String base64) async {
    try {
      await _fs.update('pacientes', patientId, {'foto_base64': base64});
      final i = _patients.indexWhere((x) => x.id == patientId);
      if (i >= 0) _patients[i] = _patients[i].copyWith(faceBase64: base64);
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  Future<Doctor?> addDoctor(Doctor d) async {
    final data = {
      'nombre': d.name.split(' ').first,
      'apellido': d.name.split(' ').skip(1).join(' '),
      'especialidad_id': d.specialtyId,
      'activo': d.active,
    };
    try {
      final id = await _fs.add('medicos', data);
      final created = Doctor(
        id: id,
        name: d.name,
        specialtyId: d.specialtyId,
        description: d.description,
        yearsExperience: d.yearsExperience,
        schedule: d.schedule,
        active: d.active,
        title: d.title,
      );
      _doctors.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> updateDoctor(Doctor d) async {
    final data = {
      'nombre': d.name.split(' ').first,
      'apellido': d.name.split(' ').skip(1).join(' '),
      'especialidad_id': d.specialtyId,
      'activo': d.active,
    };
    try {
      await _fs.update('medicos', d.id, data);
      final i = _doctors.indexWhere((x) => x.id == d.id);
      if (i >= 0) {
        _doctors[i] = Doctor(
          id: d.id,
          name: d.name,
          specialtyId: d.specialtyId,
          description: d.description,
          yearsExperience: d.yearsExperience,
          schedule: d.schedule,
          active: d.active,
          title: d.title,
        );
      }
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  Future<String?> toggleDoctorActive(String id) async {
    try {
      final target = doctorById(id);
      await _fs.update('medicos', id, {'activo': !target.active});
      final i = _doctors.indexWhere((x) => x.id == id);
      if (i >= 0) {
        _doctors[i] = _doctors[i].copyWith(active: !_doctors[i].active);
      }
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  Future<String?> bookAppointment({
    required String patientId,
    required String doctorId,
    required DateTime date,
    required String time,
    required String reason,
  }) async {
    final medicoId = _isMedico ? (_uid ?? doctorId) : doctorId;
    final fecha = _fmt(date);
    // Vía API (el servidor valida horario, evita duplicados con la BD y
    // fuerza el estado inicial). Sin sesión o sin vínculo en el backend
    // (401/403) se conserva el camino legacy en Firestore.
    final token = await _token();
    if (token != null) {
      final res = await _api.postJson(
        '/citas',
        {
          'paciente_id': patientId,
          'medico_id': medicoId,
          'fecha': fecha,
          'hora': time,
          'motivo': reason,
        },
        token: token,
      );
      if (res.isSuccess) {
        final cita = Appointment.fromApi(
          Map<String, dynamic>.from(res.data?['data'] as Map),
        );
        _appointments.add(cita);
        _occupied.add(_occKey(cita.doctorId, fecha, cita.time));
        notifyListeners();
        return null;
      }
      if (!_esAuthError(res)) {
        _error = res.error.toString();
        notifyListeners();
        return _error;
      }
    }
    final body = {
      'paciente_id': patientId,
      'medico_id': medicoId,
      'fecha': fecha,
      'hora': time,
      'motivo': reason,
      'estado': AppointmentStatus.pendiente.toApi(),
    };
    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      final citaRef = fs.collection('citas').doc();
      final citaId = citaRef.id;
      batch.set(citaRef, {...body, 'id': citaId});
      // Turno ocupado (id deterministico). La regla impide duplicados.
      final dispId = '${medicoId}__${fecha}__$time';
      batch.set(fs.collection('disponibilidad').doc(dispId), {
        'medico_id': medicoId,
        'fecha': fecha,
        'hora': time,
        'cita_id': citaId,
      });
      await batch.commit();
      _appointments.add(Appointment.fromApi({...body, 'id': citaId}));
      _occupied.add(_occKey(medicoId, fecha, time));
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  Future<String?> setAppointmentStatus(String id, AppointmentStatus status) async {
    final token = await _token();
    if (token != null) {
      final res = await _api.patchJson(
        '/citas/$id/estado',
        {'estado': status.toApi()},
        token: token,
      );
      if (res.isSuccess) {
        final updated = Appointment.fromApi(
          Map<String, dynamic>.from(res.data?['data'] as Map),
        );
        final i = _appointments.indexWhere((a) => a.id == id);
        if (i >= 0) _appointments[i] = updated;
        notifyListeners();
        return null;
      }
      if (!_esAuthError(res)) {
        _error = res.error.toString();
        notifyListeners();
        return _error;
      }
    }
    try {
      await _fs.update('citas', id, {'estado': status.toApi()});
      final i = _appointments.indexWhere((a) => a.id == id);
      if (i >= 0) {
        _appointments[i] = _appointments[i].copyWith(status: status);
      }
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  Future<String?> cancelAppointment(String id) async {
    final token = await _token();
    if (token != null) {
      final res = await _api.deleteJson('/citas/$id', token: token);
      if (res.isSuccess) {
        final updated = Appointment.fromApi(
          Map<String, dynamic>.from(res.data?['data'] as Map),
        );
        final i = _appointments.indexWhere((a) => a.id == id);
        if (i >= 0) {
          _occupied.remove(
              _occKey(updated.doctorId, _fmt(updated.date), updated.time));
          _appointments[i] = updated;
        }
        notifyListeners();
        return null;
      }
      if (!_esAuthError(res)) {
        _error = res.error.toString();
        notifyListeners();
        return _error;
      }
    }
    final i = _appointments.indexWhere((a) => a.id == id);
    final old = i >= 0 ? _appointments[i] : null;
    try {
      await _fs.update('citas', id, {'estado': AppointmentStatus.cancelada.toApi()});
      if (old != null) {
        final dispId = '${old.doctorId}__${_fmt(old.date)}__${old.time}';
        await FirebaseFirestore.instance
            .collection('disponibilidad')
            .doc(dispId)
            .delete()
            .catchError((_) {});
        _occupied.remove(_occKey(old.doctorId, _fmt(old.date), old.time));
      }
      if (i >= 0) {
        _appointments[i] =
            _appointments[i].copyWith(status: AppointmentStatus.cancelada);
      }
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  Future<String?> rescheduleAppointment(String id, DateTime date, String time) async {
    final i = _appointments.indexWhere((a) => a.id == id);
    final old = i >= 0 ? _appointments[i] : null;
    final medicoId = old?.doctorId ?? _uid ?? '';
    final nuevaFecha = _fmt(date);
    // Vía API (valida disponibilidad; si la cita estaba confirmada vuelve
    // a programada en el servidor, igual que abajo).
    final token = await _token();
    if (token != null) {
      final res = await _api.putJson(
        '/citas/$id',
        {'fecha': nuevaFecha, 'hora': time},
        token: token,
      );
      if (res.isSuccess) {
        final updated = Appointment.fromApi(
          Map<String, dynamic>.from(res.data?['data'] as Map),
        );
        if (old != null) {
          _occupied.remove(
              _occKey(old.doctorId, _fmt(old.date), old.time));
        }
        _occupied.add(
            _occKey(updated.doctorId, _fmt(updated.date), updated.time));
        if (i >= 0) _appointments[i] = updated;
        notifyListeners();
        return null;
      }
      if (!_esAuthError(res)) {
        _error = res.error.toString();
        notifyListeners();
        return _error;
      }
    }
    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      batch.update(fs.collection('citas').doc(id), {
        'fecha': nuevaFecha,
        'hora': time,
        'estado': AppointmentStatus.pendiente.toApi(),
      });
      if (old != null) {
        batch.delete(fs.collection('disponibilidad')
            .doc('${old.doctorId}__${_fmt(old.date)}__${old.time}'));
      }
      batch.set(fs.collection('disponibilidad').doc('${medicoId}__${nuevaFecha}__$time'), {
        'medico_id': medicoId,
        'fecha': nuevaFecha,
        'hora': time,
        'cita_id': id,
      });
      await batch.commit();
      if (old != null) {
        _occupied.remove(_occKey(old.doctorId, _fmt(old.date), old.time));
      }
      _occupied.add(_occKey(medicoId, nuevaFecha, time));
      if (i >= 0) {
        _appointments[i] = _appointments[i].copyWith(
            date: date, time: time, status: AppointmentStatus.pendiente);
      }
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  Future<String?> addConsult(ConsultRecord c) async {
    // Vía API (un médico archiva bajo su perfil en el servidor).
    final token = await _token();
    if (token != null) {
      final res = await _api.postJson('/consultas', c.toApiJson(), token: token);
      if (res.isSuccess) {
        _consults.add(ConsultRecord.fromApi(
          Map<String, dynamic>.from(res.data?['data'] as Map),
        ));
        notifyListeners();
        return null;
      }
      if (!_esAuthError(res)) {
        _error = res.error.toString();
        notifyListeners();
        return _error;
      }
    }
    try {
      final data = {...c.toApiJson()};
      if (_isMedico) data['medico_id'] = _uid;
      final id = await _fs.add('consultas', data);
      _consults.add(ConsultRecord.fromApi({...data, 'id': id}));
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  Future<String?> addPayment(Payment p) async {
    // Vía API (el servidor fuerza estado pagado y fecha actual; `pagos`
    // no tiene columna de médico: el doctorId se deriva de la cita).
    final token = await _token();
    if (token != null) {
      final res = await _api.postJson(
        '/pagos',
        {
          'paciente_id': p.patientId,
          'cita_id': p.appointmentId.isEmpty ? null : p.appointmentId,
          'monto': p.amount,
          'metodo_pago': p.method.toApi(),
        },
        token: token,
      );
      if (res.isSuccess) {
        var created = Payment.fromApi(
          Map<String, dynamic>.from(res.data?['data'] as Map),
        );
        for (final a in _appointments) {
          if (a.id == created.appointmentId && a.doctorId.isNotEmpty) {
            created = created.copyWith(doctorId: a.doctorId);
            break;
          }
        }
        _payments.add(created);
        notifyListeners();
        return null;
      }
      if (!_esAuthError(res)) {
        _error = res.error.toString();
        notifyListeners();
        return _error;
      }
    }
    final body = {
      'paciente_id': p.patientId,
      'cita_id': p.appointmentId,
      'monto': p.amount,
      'metodo_pago': p.method.toApi(),
      'estado': p.status.toApi(),
      'fecha_pago': _fmt(p.date),
      if (_isMedico) 'medico_id': _uid,
    };
    try {
      final id = await _fs.add('pagos', body);
      _payments.add(Payment.fromApi({...body, 'id': id}));
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  Future<String?> setPaymentStatus(String id, PaymentStatus status) async {
    final token = await _token();
    if (token != null) {
      final res = await _api.patchJson(
        '/pagos/$id/estado',
        {'estado': status.toApi()},
        token: token,
      );
      if (res.isSuccess) {
        final updated = Payment.fromApi(
          Map<String, dynamic>.from(res.data?['data'] as Map),
        );
        final i = _payments.indexWhere((x) => x.id == id);
        if (i >= 0) {
          final d = _payments[i].doctorId;
          _payments[i] =
              (d.isEmpty) ? updated : updated.copyWith(doctorId: d);
        }
        notifyListeners();
        return null;
      }
      if (!_esAuthError(res)) {
        _error = res.error.toString();
        notifyListeners();
        return _error;
      }
    }
    try {
      await _fs.update('pagos', id, {'estado': status.toApi()});
      final i = _payments.indexWhere((x) => x.id == id);
      if (i >= 0) _payments[i] = _payments[i].copyWith(status: status);
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error.toString();
    }
  }

  // ---- Estadísticas (Dashboard) -------------------------------------------
  int get totalPatients => _patients.length;
  int get totalDoctors => _doctors.length;
  int get activeDoctorCount => activeDoctors.length;
  int get appointmentsToday => appointmentsOfDay(DateTime.now()).length;
  int countByStatus(AppointmentStatus s) =>
      _appointments.where((a) => a.status == s).length;
  int countByStatusToday(AppointmentStatus s) =>
      appointmentsOfDay(DateTime.now()).where((a) => a.status == s).length;
  double get totalIncome => _payments
      .where((p) => p.status == PaymentStatus.pagado)
      .fold(0, (acc, p) => acc + p.amount);
  int get pendingPayments =>
      _payments.where((p) => p.status == PaymentStatus.pendiente).length;

  int citasEnRango(DateTime desde, DateTime hasta, {String? doctorId}) =>
      _appointments.where((a) {
        final inRange = !a.date.isBefore(desde) && !a.date.isAfter(hasta);
        if (!inRange) return false;
        if (doctorId != null && a.doctorId != doctorId) return false;
        return true;
      }).length;

  int citasPorEstadoEnRango(DateTime desde, DateTime hasta, AppointmentStatus s) =>
      _appointments
          .where((a) =>
              a.status == s &&
              !a.date.isBefore(desde) &&
              !a.date.isAfter(hasta))
          .length;

  double ingresosEnRango(DateTime desde, DateTime hasta) => _payments
      .where((p) =>
          p.status == PaymentStatus.pagado &&
          !p.date.isBefore(desde) &&
          !p.date.isAfter(hasta))
      .fold(0, (acc, p) => acc + p.amount);

  Map<Doctor, int> citasPorDoctorEnRango(DateTime desde, DateTime hasta) {
    final map = <Doctor, int>{};
    for (final d in _doctors) {
      map[d] = _appointments.where((a) =>
          a.doctorId == d.id &&
          !a.date.isBefore(desde) &&
          !a.date.isAfter(hasta)).length;
    }
    return map;
  }

  Map<String, int> citasPorEspecialidadEnRango(DateTime desde, DateTime hasta) {
    final map = <String, int>{};
    for (final s in _specialties) {
      final count = _appointments.where((a) {
        final inRange = !a.date.isBefore(desde) && !a.date.isAfter(hasta);
        if (!inRange) return false;
        return doctorById(a.doctorId).specialtyId == s.id;
      }).length;
      map[s.name] = count;
    }
    return map;
  }

  // ---- Utilidades ----------------------------------------------------------
  void _loadMock() {
    _specialties.addAll(MockData.specialties);
    _doctors.addAll(MockData.doctors);
    _patients.addAll(MockData.patients);
    _appointments.addAll(MockData.appointments);
    _consults.addAll(MockData.consults);
    _payments.addAll(MockData.payments);
  }

  void resetDemo() {
    _patients.clear();
    _doctors.clear();
    _specialties.clear();
    _appointments.clear();
    _consults.clear();
    _payments.clear();
    _loadMock();
    notifyListeners();
  }
}
