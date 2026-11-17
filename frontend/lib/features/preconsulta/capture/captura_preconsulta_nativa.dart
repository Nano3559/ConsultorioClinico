/// Captura de cámara para Android/escritorio con el plugin `camera`.
///
/// Se toman fotogramas con [CameraController.takePicture] y se reescalan a
/// 288 px de ancho con JPEG de calidad 55 antes de enviarlos. Así el payload
/// se mantiene pequeño y el contrato es el mismo que en web (lista de frames).
library;

import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import 'captura_preconsulta_tipos.dart';

class CamaraPreconsulta {
  CameraController? _controller;

  bool get activa => _controller?.value.isInitialized ?? false;

  Future<void> iniciar() async {
    if (_controller != null && _controller!.value.isInitialized) return;
    List<CameraDescription> camaras;
    try {
      camaras = await availableCameras().timeout(const Duration(seconds: 25));
    } on CameraException catch (e) {
      throw _mapear(e.code, e.description);
    } on TimeoutException {
      throw const CapturaException(
        CapturaErrorKind.unknown,
        'La cámara no respondió. Revisa el permiso e intenta de nuevo.',
      );
    } catch (_) {
      throw const CapturaException(
        CapturaErrorKind.notSupported,
        'Este equipo no permite usar la cámara desde aquí.',
      );
    }
    if (camaras.isEmpty) {
      throw const CapturaException(
        CapturaErrorKind.noCamera,
        'No se detectó ninguna cámara en el dispositivo.',
      );
    }
    final frontal = camaras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => camaras.first,
    );
    final controller = CameraController(
      frontal,
      ResolutionPreset.low,
      enableAudio: false,
    );
    try {
      await controller.initialize().timeout(const Duration(seconds: 30));
    } catch (e) {
      try {
        await controller.dispose();
      } catch (_) {}
      if (e is CameraException) throw _mapear(e.code, e.description);
      throw const CapturaException(
        CapturaErrorKind.notSupported,
        'No se pudo iniciar la cámara de la preconsulta.',
      );
    }
    _controller = controller;
  }

  CapturaException _mapear(String code, String? detail) {
    final d = (detail ?? '').toLowerCase();
    if (code == 'CameraAccessDenied' ||
        code == 'NotAllowedError' ||
        d.contains('permission') ||
        d.contains('denied')) {
      return const CapturaException(
        CapturaErrorKind.denied,
        'Permiso de cámara denegado. Actívalo en los ajustes del sistema y reintenta.',
      );
    }
    if (code == 'NotFoundError' || code == 'OverconstrainedError') {
      return const CapturaException(
        CapturaErrorKind.noCamera,
        'No se encontró ninguna cámara en este dispositivo.',
      );
    }
    if (code == 'NotReadableError' || d.contains('busy') || d.contains('in use')) {
      return const CapturaException(
        CapturaErrorKind.busy,
        'La cámara está ocupada por otra app. Ciérrala y reintenta.',
      );
    }
    return CapturaException(
      CapturaErrorKind.notSupported,
      'No se pudo acceder a la cámara${code.isEmpty ? '' : ' ($code)'}.',
    );
  }

  Widget vistaPrevia() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  /// Captura frames durante [duracion], tan rápido como el dispositivo lo
  /// permita (normalmente 5-10 fps). El fps real se devuelve para que el
  /// servicio de visión calibre la estimación de pulso.
  Future<ResultadoCaptura> capturar({
    required Duration duracion,
    void Function(double progreso)? progreso,
  }) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CapturaException(
        CapturaErrorKind.unknown,
        'La cámara aún no está lista.',
      );
    }
    final frames = <String>[];
    var acumulado = 0;
    const presupuesto = 3600000;
    final reloj = Stopwatch()..start();
    final totalMs = duracion.inMilliseconds;

    while (reloj.elapsedMilliseconds < totalMs) {
      try {
        final archivo = await controller
            .takePicture()
            .timeout(const Duration(seconds: 8));
        final bytes = await archivo.readAsBytes();
        final original = img.decodeImage(bytes);
        if (original != null) {
          final chica = img.copyResize(original, width: 288);
          final jpg = img.encodeJpg(chica, quality: 55);
          frames.add(base64Encode(jpg));
          acumulado += jpg.length;
        }
      } catch (_) {
        // Un frame perdido no invalida la captura.
      }
      progreso?.call(
        (reloj.elapsedMilliseconds / totalMs).clamp(0.0, 1.0),
      );
      if (acumulado >= presupuesto) break;
      await Future.delayed(const Duration(milliseconds: 20));
    }
    reloj.stop();
    progreso?.call(1);

    if (frames.length < 60) {
      throw const CapturaException(
        CapturaErrorKind.unknown,
        'No se pudieron capturar suficientes fotogramas. Mantén el rostro frente a la cámara e inténtalo de nuevo.',
      );
    }
    final segundos = reloj.elapsedMilliseconds / 1000.0;
    final fps = segundos > 0 ? frames.length / segundos : 8.0;
    return ResultadoCaptura(frames: frames, fps: fps, duracionSeg: segundos);
  }

  Future<void> liberar() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }
}
