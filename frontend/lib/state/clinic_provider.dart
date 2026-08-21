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

/// Proveedor principal de la clínica: mantiene todos los datos en memoria y
/// concentra las reglas de negocio. Al conectar el backend, cada método podrá
/// delegar a la API manteniendo la misma firma.
class ClinicProvider extends ChangeNotifier {
  ClinicProvider() {
    _loadMock();
  }

  final List<Specialty> _specialties = [];
  final List<Doctor> _doctors = [];
  final List<Patient> _patients = [];
  final List<Appointment> _appointments = [];
  final List<ConsultRecord> _consults = [];
  final List<Payment> _payments = [];

  // ---- Getters inmutables ------------------------------------------------
  List<Specialty> get specialties => List.unmodifiable(_specialties);
  List<Doctor> get doctors => List.unmodifiable(_doctors);
  List<Patient> get patients => List.unmodifiable(_patients);
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<ConsultRecord> get consults => List.unmodifiable(_consults);
  List<Payment> get payments => List.unmodifiable(_payments);

  // ---- Helpers de resolución ----------------------------------------------
  Specialty specialtyById(String id) =>
      _specialties.firstWhere((s) => s.id == id, orElse: () => _specialties.first);

  Doctor doctorById(String id) =>
      _doctors.firstWhere((d) => d.id == id, orElse: () => _doctors.first);

  Patient patientById(String id) =>
      _patients.firstWhere((p) => p.id == id, orElse: () => _patients.first);

  String doctorName(String id) => doctorById(id).displayName;
  String patientName(String id) => patientById(id).fullName;
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

  List<Doctor> get activeDoctors =>
      _doctors.where((d) => d.active).toList();

  List<Appointment> appointmentsOfDoctor(String doctorId) =>
      _appointments
          .where((a) => a.doctorId == doctorId)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  List<Appointment> appointmentsOfPatient(String patientId) =>
      _appointments
          .where((a) => a.patientId == patientId)
          .toList()
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

  Payment paymentOfAppointment(String appointmentId) => _payments
      .firstWhere((p) => p.appointmentId == appointmentId, orElse: () => _payments.first);

  // ---- Regla clave: disponibilidad de un horario ---------------------------
  /// Un horario está disponible si el médico lo tiene en su agenda semanal y
  /// no existe otra cita activa (pendiente/confirmada) en ese mismo horario.
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

  /// Franjas libres del médico para una fecha concreta.
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

  // ---- CRUD: Pacientes ------------------------------------------------------
  void addPatient(Patient p) {
    _patients.add(p);
    notifyListeners();
  }

  void updatePatient(Patient p) {
    final i = _patients.indexWhere((x) => x.id == p.id);
    if (i >= 0) _patients[i] = p;
    notifyListeners();
  }

  List<Patient> searchPatients(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _patients;
    return _patients.where((p) {
      return p.fullName.toLowerCase().contains(q) ||
          p.ci.contains(q) ||
          p.phone.contains(q);
    }).toList();
  }

  // ---- CRUD: Médicos ----------------------------------------------------------
  void addDoctor(Doctor d) {
    _doctors.add(d);
    notifyListeners();
  }

  void updateDoctor(Doctor d) {
    final i = _doctors.indexWhere((x) => x.id == d.id);
    if (i >= 0) _doctors[i] = d;
    notifyListeners();
  }

  void toggleDoctorActive(String id) {
    final i = _doctors.indexWhere((x) => x.id == id);
    if (i >= 0) {
      _doctors[i] = _doctors[i].copyWith(active: !_doctors[i].active);
      notifyListeners();
    }
  }

  // ---- CRUD: Citas ------------------------------------------------------------
  /// Retorna null si se creó correctamente o el motivo del error.
  String? bookAppointment({
    required String patientId,
    required String doctorId,
    required DateTime date,
    required String time,
    required String reason,
  }) {
    if (!isSlotAvailable(doctorId: doctorId, date: date, time: time)) {
      return 'El horario seleccionado ya no está disponible';
    }
    _appointments.add(Appointment(
      id: _newId('c'),
      patientId: patientId,
      doctorId: doctorId,
      date: date,
      time: time,
      reason: reason,
    ));
    notifyListeners();
    return null;
  }

  void setAppointmentStatus(String id, AppointmentStatus status) {
    final i = _appointments.indexWhere((a) => a.id == id);
    if (i >= 0) {
      _appointments[i] = _appointments[i].copyWith(status: status);
      notifyListeners();
    }
  }

  /// Cancela una cita y libera el horario automáticamente (regla de negocio).
  void cancelAppointment(String id) {
    final i = _appointments.indexWhere((a) => a.id == id);
    if (i >= 0) {
      _appointments[i] =
          _appointments[i].copyWith(status: AppointmentStatus.cancelada);
      notifyListeners();
    }
  }

  /// Reprograma la cita a otra fecha/hora, validando disponibilidad.
  String? rescheduleAppointment(String id, DateTime date, String time) {
    final i = _appointments.indexWhere((a) => a.id == id);
    if (i < 0) return 'Cita no encontrada';
    final current = _appointments[i];
    final err = isSlotAvailable(
      doctorId: current.doctorId,
      date: date,
      time: time,
      excludeAppointmentId: id,
    );
    if (!err) return 'El nuevo horario no está disponible';
    _appointments[i] =
        current.copyWith(date: date, time: time, status: AppointmentStatus.pendiente);
    notifyListeners();
    return null;
  }

  // ---- Historia clínica ---------------------------------------------------------
  void addConsult(ConsultRecord c) {
    _consults.add(c);
    final cita = _appointments.where((a) =>
        a.patientId == c.patientId &&
        a.doctorId == c.doctorId &&
        a.date.year == c.date.year &&
        a.date.month == c.date.month &&
        a.date.day == c.date.day);
    for (final a in cita) {
      if (a.status != AppointmentStatus.cancelada) {
        setAppointmentStatus(a.id, AppointmentStatus.atendida);
      }
    }
    notifyListeners();
  }

  // ---- Pagos ----------------------------------------------------------------------
  void addPayment(Payment p) {
    _payments.add(p);
    notifyListeners();
  }

  void setPaymentStatus(String id, PaymentStatus status) {
    final i = _payments.indexWhere((p) => p.id == id);
    if (i >= 0) {
      _payments[i] = _payments[i].copyWith(status: status);
      notifyListeners();
    }
  }

  // ---- Estadísticas (Dashboard) -----------------------------------------------------
  int get totalPatients => _patients.length;
  int get totalDoctors => _doctors.length;
  int get activeDoctorCount => activeDoctors.length;

  int get appointmentsToday => appointmentsOfDay(DateTime.now()).length;

  int countByStatus(AppointmentStatus s) =>
      _appointments.where((a) => a.status == s).length;

  int countByStatusToday(AppointmentStatus s) =>
      appointmentsOfDay(DateTime.now()).where((a) => a.status == s).length;

  double get totalIncome =>
      _payments.where((p) => p.status == PaymentStatus.pagado).fold(
            0,
            (sum, p) => sum + p.amount,
          );

  int get pendingPayments =>
      _payments.where((p) => p.status == PaymentStatus.pendiente).length;

  // ---- Reportes ------------------------------------------------------------------------
  int citasEnRango(DateTime desde, DateTime hasta, {String? doctorId}) {
    return _appointments.where((a) {
      final inRange = !a.date.isBefore(desde) && !a.date.isAfter(hasta);
      if (!inRange) return false;
      if (doctorId != null && a.doctorId != doctorId) return false;
      return true;
    }).length;
  }

  int pacientesNuevosEnRango(DateTime desde, DateTime hasta) => _patients
      .where((p) => !p.id.startsWith('p') || true)
      .length; // con mock no hay fechas de alta; se usa el total.

  int citasPorEstadoEnRango(DateTime desde, DateTime hasta, AppointmentStatus s) {
    return _appointments.where((a) =>
        a.status == s && !a.date.isBefore(desde) && !a.date.isAfter(hasta)).length;
  }

  double ingresosEnRango(DateTime desde, DateTime hasta) {
    return _payments
        .where((p) =>
            p.status == PaymentStatus.pagado &&
            !p.date.isBefore(desde) &&
            !p.date.isAfter(hasta))
        .fold(0, (sum, p) => sum + p.amount);
  }

  /// Conteo de citas agrupadas por médico en un rango (para gráficos).
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

  // ---- Utilidades -------------------------------------------------------------------------
  static String _newId(String prefix) =>
      '$prefix${DateTime.now().millisecondsSinceEpoch}';

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