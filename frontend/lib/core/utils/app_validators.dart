/// Validadores reutilizables para formularios.
class AppValidators {
  AppValidators._();

  static String? required(String? v, {String label = 'Este campo'}) {
    if (v == null || v.trim().isEmpty) return '$label es requerido';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'El correo es requerido';
    final ok = RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(v.trim());
    return ok ? null : 'Correo no válido';
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'El teléfono es requerido';
    final ok = RegExp(r'^\+?[\d\s\-]{7,15}$').hasMatch(v.trim());
    return ok ? null : 'Teléfono no válido';
  }

  static String? ci(String? v) {
    if (v == null || v.trim().isEmpty) return 'El CI es requerido';
    final ok = RegExp(r'^\d{4,10}$').hasMatch(v.trim());
    return ok ? null : 'CI debe tener entre 4 y 10 dígitos';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'La contraseña es requerida';
    if (v.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
    final ok = RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(v);
    return ok ? null : 'La contraseña debe incluir letras y números';
  }
}