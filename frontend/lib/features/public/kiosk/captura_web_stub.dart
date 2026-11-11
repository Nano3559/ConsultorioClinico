import 'package:flutter/widgets.dart';

import 'kiosk_camera_service.dart';

/// Implementación no-web de `CapturaWebDirecta`.
///
/// `captura_web.dart` importa `package:web`, que no compila en la VM de Dart
/// (tests y escritorio). Este stub permite importar el archivo de forma
/// condicional y mantener el resto del flujo intacto.
class CapturaWebDirecta {
  Future<void> iniciar() async {
    throw UnsupportedError('La captura web solo está disponible en el navegador.');
  }

  Widget vistaPrevia() => const SizedBox.shrink();

  Future<KioskPhoto> capturarFoto() async {
    throw UnsupportedError('La captura web solo está disponible en el navegador.');
  }

  Future<void> liberar() async {}
}
