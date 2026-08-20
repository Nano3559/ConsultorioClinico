/// Constantes globales del consultorio.
class AppInfo {
  AppInfo._();

  static const String name = 'ConsultorioClínico';
  static const String tagline = 'Tu salud, en buenas manos';
  static const String address = 'Av. Principal #123, Ciudad';
  static const String phone = '+595 981 234 567';
  static const String whatsapp = '+595 981 234 567';
  static const String email = 'contacto@consultorioclinico.com';
  static const String hours = 'Lun a Vie · 08:00 - 18:00 | Sáb · 08:00 - 12:00';
}

/// Días de atención en orden.
const List<String> kDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

/// Franjas horarias disponibles (30 min).
const List<String> kTimeSlots = [
  '08:00',
  '08:30',
  '09:00',
  '09:30',
  '10:00',
  '10:30',
  '11:00',
  '11:30',
  '12:00',
  '14:00',
  '14:30',
  '15:00',
  '15:30',
  '16:00',
  '16:30',
  '17:00',
  '17:30',
];