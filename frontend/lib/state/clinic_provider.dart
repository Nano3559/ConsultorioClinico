import 'package:flutter/material.dart';
import '../data/models/specialty.dart';
import '../data/models/doctor.dart';
import '../data/models/patient.dart';
import '../data/models/appointment.dart';
import '../data/models/consult_record.dart';
import '../data/models/payment.dart';
import '../data/mock/mock_data.dart';
import '../core/constants/app_constants.dart';
import '../core/widgets/app_status_badge.dart';
import '../services/api_client.dart';

/// Proveedor principal de la clínica.
///
/// Antes usaba datos mock en memoria. Ahora se apoya en el backend REST
/// (Node/Express + Supabase) como fuente de verdad: al iniciar sesión se llama
/// a [loadAll] para poblar las listas desde la BD, y cada mutación (crear,
/// editar, cancelar, etc.) persiste vía API y luego actualiza la caché local
/// (actualización optimista) para no bloquear la UI.
class ClinicProvider extends ChangeNotifier {
  ClinicProvider({ApiClient? api}) : _api = api ?? ApiClient() {
    // Carga inicial: si el backend responde, usa la BD; si no, cae en mock.
    loadAll();
  }

  final ApiClient _api;

  final List<Specialty> _specialties = [];
  final List<Doctor> _doctors = [];
  final List<Patient> _patients = [];
  final List<Appointment> _appointments = [];
  final List<ConsultRecord> _consults = [];
  final List<Payment> _payments = [];

  String? _token;
  String? _perfilId;
  String? _error;
  bool _usingApi = false;
  bool _loading = false;

  // ---- Getters inmutables ------------------------------------------------
  List<Specialty> get specialties => List.unmodifiable(_specialties);
  List<Doctor> get doctors => List.unmodifiable(_doctors);
  List<Patient> get patients => List.unmodifiable(_patients);
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<ConsultRecord> get consults => List.unmodifiable(_consults);
  List<Payment> get payments => List.unmodifiable(_payments);

  String? get error => _error;
  bool get usingApi => _usingApi;
  bool get isLoading => _loading;
  String? get perfilId => _perfilId;

  /// Inyecta el JWT tras el login para autenticar las llamadas a la API.
  void setAuthToken(String? token, {String? perfilTipo, String? perfilId}) {
    _token = token;
    _perfilId = perfilId;
  }

  // ---- Carga inicial desde el backend -------------------------------------
  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadEspecialidades();
      await _loadMedicos();
      await _loadPacientes();
      await _loadCitas();
      await _loadConsultas();
      await _loadPagos();
      _usingApi = true;
    } catch (e) {
      // Si no hay backend disponible, caemos en datos de demostración para
      // que la app siga usable en desarrollo.
      if (_specialties.isEmpty && _doctors.isEmpty) {
        _loadMock();
        _usingApi = false;
      }
      _error = 'No se pudo cargar la información del servidor';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadEspecialidades() async {
    final res = await _api.getJson('/especialidades', token: _token);
    final data = _asList(res);
    _specialties
      ..clear()
      ..addAll(data.map((e) => Specialty.fromApi(e)));
  }

  Future<void> _loadMedicos() async {
    final res = await _api.getJson('/medicos', token: _token);
    final data = _asList(res);
    _doctors.clear();
    for (final m in data) {
      final schedule = await _loadHorarios(m['id']);
      final especialidad = (m['especialidad'] ?? '').toString();
      final specialtyId = _resolveSpecialtyId(especialidad);
      _doctors.add(Doctor.fromApi(m, specialtyId: specialtyId, schedule: schedule));
    }
  }

  Future<DoctorSchedule> _loadHorarios(dynamic medicoId) async {
    try {
      final res = await _api.getJson('/medicos/$medicoId/horarios', token: _token);
      final data = _asList(res);
      final byDay = <String, List<String>>{};
      for (final h in data) {
        final dia = _shortDay((h['dia_semana'] ?? '').toString());
        final ini = (h['hora_inicio'] ?? '').toString();
        final fin = (h['hora_fin'] ?? '').toString();
        final slots = _expandSlots(ini, fin);
        byDay[dia] = [...(byDay[dia] ?? []), ...slots];
      }
      return DoctorSchedule(byDay);
    } catch (_) {
      return const DoctorSchedule({});
    }
  }

  Future<void> _loadPacientes() async {
    final res = await _api.getJson('/pacientes', token: _token);
    final data = _asList(res);
    _patients
      ..clear()
      ..addAll(data.map((e) => Patient.fromApi(e)));
  }

  Future<void> _loadCitas() async {
    final res = await _api.getJson('/citas', token: _token);
    final data = _asList(res);
    _appointments
      ..clear()
      ..addAll(data.map((e) => Appointment.fromApi(e)));
  }

  Future<void> _loadConsultas() async {
    final res = await _api.getJson('/consultas', token: _token);
    final data = _asList(res);
    _consults
      ..clear()
      ..addAll(data.map((e) => ConsultRecord.fromApi(e)));
  }

  Future<void> _loadPagos() async {
    final res = await _api.getJson('/pagos', token: _token);
    final data = _asList(res);
    _payments
      ..clear()
      ..addAll(data.map((e) => Payment.fromApi(e)));
  }

  List<Map<String, dynamic>> _asList(ApiResult<Map<String, dynamic>> res) {
    if (!res.isSuccess) return const [];
    final payload = res.data!['data'];
    if (payload is List) return payload.cast<Map<String, dynamic>>();
    return const [];
  }

  String _resolveSpecialtyId(String nombre) {
    final n = nombre.toLowerCase();
    for (final s in _specialties) {
      if (s.name.toLowerCase() == n) return s.id;
    }
    // Especialidad no catalogada: la creamos sobre la marcha para no romper
    // los helpers de resolución por id.
    final id = 'sp_${nombre.replaceAll(' ', '_').toLowerCase()}';
    if (_specialties.every((s) => s.id != id)) {
      _specialties.add(Specialty(
        id: id,
        name: nombre,
        description: '',
        icon: Specialty.iconForName(nombre),
        color: const Color(0xFF0D9488),
      ));
    }
    return id;
  }

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

  Payment paymentOfAppointment(String appointmentId) => _payments.firstWhere(
      (p) => p.appointmentId == appointmentId,
      orElse: () => _payments.first);

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
    return !occupied;
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

  // ---- Mutaciones (persisten en la BD vía API) ----------------------------
  Future<Patient?> addPatient(Patient p) async {
    final res = await _api.postJson('/pacientes', p.toApiJson(), token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return null;
    }
    final created = Patient.fromApi(res.data!['data'] as Map<String, dynamic>);
    _patients.add(created);
    notifyListeners();
    return created;
  }

  Future<String?> updatePatient(Patient p) async {
    final res = await _api.putJson('/pacientes/${p.id}', p.toApiJson(), token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    final updated = Patient.fromApi(res.data!['data'] as Map<String, dynamic>);
    final i = _patients.indexWhere((x) => x.id == p.id);
    if (i >= 0) _patients[i] = updated;
    notifyListeners();
    return null;
  }

  Future<Doctor?> addDoctor(Doctor d) async {
    final especialidad = specialtyById(d.specialtyId).name;
    final res = await _api.postJson('/medicos', d.toApiJson(especialidad: especialidad),
        token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return null;
    }
    final created = Doctor.fromApi(res.data!['data'] as Map<String, dynamic>,
        specialtyId: d.specialtyId);
    _doctors.add(created);
    notifyListeners();
    return created;
  }

  Future<String?> updateDoctor(Doctor d) async {
    final especialidad = specialtyById(d.specialtyId).name;
    final res = await _api.putJson('/medicos/${d.id}', d.toApiJson(especialidad: especialidad),
        token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    final updated = Doctor.fromApi(res.data!['data'] as Map<String, dynamic>,
        specialtyId: d.specialtyId);
    final i = _doctors.indexWhere((x) => x.id == d.id);
    if (i >= 0) _doctors[i] = updated;
    notifyListeners();
    return null;
  }

  Future<String?> toggleDoctorActive(String id) async {
    final res = await _api.patchJson('/medicos/$id/estado', {}, token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    final updated = Doctor.fromApi(res.data!['data'] as Map<String, dynamic>,
        specialtyId: doctorById(id).specialtyId);
    final i = _doctors.indexWhere((x) => x.id == id);
    if (i >= 0) _doctors[i] = updated;
    notifyListeners();
    return null;
  }

  Future<String?> bookAppointment({
    required String patientId,
    required String doctorId,
    required DateTime date,
    required String time,
    required String reason,
  }) async {
    final body = {
      'paciente_id': int.tryParse(patientId) ?? patientId,
      'medico_id': int.tryParse(doctorId) ?? doctorId,
      'fecha': _fmt(date),
      'hora': time,
      'motivo': reason,
    };
    final res = await _api.postJson('/citas', body, token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    _appointments
        .add(Appointment.fromApi(res.data!['data'] as Map<String, dynamic>));
    notifyListeners();
    return null;
  }

  Future<String?> setAppointmentStatus(String id, AppointmentStatus status) async {
    final res = await _api.patchJson('/citas/$id/estado', {'estado': status.toApi()},
        token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    final i = _appointments.indexWhere((a) => a.id == id);
    if (i >= 0) {
      _appointments[i] = _appointments[i].copyWith(status: status);
    }
    notifyListeners();
    return null;
  }

  Future<String?> cancelAppointment(String id) async {
    final res = await _api.deleteJson('/citas/$id', token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    final i = _appointments.indexWhere((a) => a.id == id);
    if (i >= 0) {
      _appointments[i] = _appointments[i].copyWith(status: AppointmentStatus.cancelada);
    }
    notifyListeners();
    return null;
  }

  Future<String?> rescheduleAppointment(String id, DateTime date, String time) async {
    final res = await _api.putJson('/citas/$id', {'fecha': _fmt(date), 'hora': time},
        token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    final i = _appointments.indexWhere((a) => a.id == id);
    if (i >= 0) {
      _appointments[i] = _appointments[i].copyWith(
          date: date, time: time, status: AppointmentStatus.pendiente);
    }
    notifyListeners();
    return null;
  }

  Future<String?> addConsult(ConsultRecord c) async {
    final res = await _api.postJson('/consultas', c.toApiJson(), token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    _consults.add(ConsultRecord.fromApi(res.data!['data'] as Map<String, dynamic>));
    notifyListeners();
    return null;
  }

  Future<String?> addPayment(Payment p) async {
    final body = {
      'paciente_id': int.tryParse(p.patientId) ?? p.patientId,
      'cita_id': p.appointmentId.isNotEmpty ? (int.tryParse(p.appointmentId) ?? p.appointmentId) : null,
      'monto': p.amount,
      'metodo_pago': p.method.toApi(),
      'descripcion': '',
    };
    final res = await _api.postJson('/pagos', body, token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    _payments.add(Payment.fromApi(res.data!['data'] as Map<String, dynamic>));
    notifyListeners();
    return null;
  }

  Future<String?> setPaymentStatus(String id, PaymentStatus status) async {
    final res = await _api.patchJson('/pagos/$id/estado', {'estado': status.toApi()},
        token: _token);
    if (!res.isSuccess) {
      _error = res.error;
      notifyListeners();
      return res.error;
    }
    final i = _payments.indexWhere((x) => x.id == id);
    if (i >= 0) _payments[i] = _payments[i].copyWith(status: status);
    notifyListeners();
    return null;
  }

  // ---- Estadísticas (Dashboard) -------------------------------------------
  int get totalPatients => _patients.length;
  int get totalDoctors => _doctors.length;
  int get activeDoctorCount => activeDoctors.length;
  int get appointmentsToday => appointmentsOfDay(DateTime.now()).length;
  int countByStatus(AppointmentStatus s) => _appointments.where((a) => a.status == s).length;
  int countByStatusToday(AppointmentStatus s) =>
      appointmentsOfDay(DateTime.now()).where((a) => a.status == s).length;
  double get totalIncome => _payments
      .where((p) => p.status == PaymentStatus.pagado)
      .fold(0, (sum, p) => sum + p.amount);
  int get pendingPayments => _payments.where((p) => p.status == PaymentStatus.pendiente).length;

  int citasEnRango(DateTime desde, DateTime hasta, {String? doctorId}) => _appointments
      .where((a) {
        final inRange = !a.date.isBefore(desde) && !a.date.isAfter(hasta);
        if (!inRange) return false;
        if (doctorId != null && a.doctorId != doctorId) return false;
        return true;
      })
      .length;

  int citasPorEstadoEnRango(DateTime desde, DateTime hasta, AppointmentStatus s) => _appointments
      .where((a) =>
          a.status == s && !a.date.isBefore(desde) && !a.date.isAfter(hasta))
      .length;

  double ingresosEnRango(DateTime desde, DateTime hasta) => _payments
      .where((p) =>
          p.status == PaymentStatus.pagado &&
          !p.date.isBefore(desde) &&
          !p.date.isAfter(hasta))
      .fold(0, (sum, p) => sum + p.amount);

  Map<Doctor, int> citasPorDoctorEnRango(DateTime desde, DateTime hasta) {
    final map = <Doctor, int>{};
    for (final d in _doctors) {
      map[d] = _appointments.where((a) =>
          a.doctorId == d.id && !a.date.isBefore(desde) && !a.date.isAfter(hasta)).length;
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
