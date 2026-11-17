/// Implementación no-web/no-móvil de la captura (stub).
///
/// Permite compilar tests y escritorio donde la cámara de video no está
/// disponible. La UI muestra un mensaje claro y ofrece el modo sin cámara.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'captura_preconsulta_tipos.dart';

class CamaraPreconsulta {
  bool get activa => false;

  Future<void> iniciar() async {
    throw const CapturaException(
      CapturaErrorKind.notSupported,
      'La cámara de la preconsulta solo está disponible en el navegador o en la app móvil.',
    );
  }

  Widget vistaPrevia() => const SizedBox.shrink();

  Future<ResultadoCaptura> capturar({
    required Duration duracion,
    void Function(double progreso)? progreso,
  }) async {
    throw const CapturaException(
      CapturaErrorKind.notSupported,
      'La cámara de la preconsulta solo está disponible en el navegador o en la app móvil.',
    );
  }

  Future<void> liberar() async {}
}
