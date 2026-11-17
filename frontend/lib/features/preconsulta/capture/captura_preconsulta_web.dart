/// Captura de cámara para web (frames JPEG) sin el plugin `camera`.
///
/// Una sola apertura de `getUserMedia` -> `<video>` en vivo -> `<canvas>` para
/// extraer frames escalados a JPEG. Se envían como secuencia para que el
/// servicio de visión estime pulso, respiración y expresión facial. Nada se
/// guarda en disco.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import 'captura_preconsulta_tipos.dart';

class CamaraPreconsulta {
  web.HTMLVideoElement? _video;
  String? _viewType;
  static int _seq = 0;

  bool get activa => _video != null;

  Future<void> iniciar() async {
    if (_video != null) return;
    if (!web.window.isSecureContext) {
      throw const CapturaException(
        CapturaErrorKind.denied,
        'Abre la página con HTTPS (candado en la barra). Sin conexión segura el navegador bloquea la cámara.',
      );
    }
    web.MediaStream? stream;
    try {
      try {
        stream = await _abrir({'facingMode': 'user'});
      } catch (e) {
        final name = _domErrorName(e);
        if (name == 'OverconstrainedError' || name == 'NotFoundError') {
          stream = await _abrir(null);
        } else {
          rethrow;
        }
      }
      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';
      video.srcObject = stream;
      await video.play().toDart.timeout(const Duration(seconds: 10));
      _video = video;
      _viewType = 'preconsulta-camara-${_seq++}';
      ui_web.platformViewRegistry.registerViewFactory(_viewType!, (int _) {
        final wrap = web.HTMLDivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'hidden'
          // Espejo solo visual (selfie): los frames se capturan sin espejar.
          ..style.transform = 'scaleX(-1)'
          ..append(video);
        return wrap;
      });
    } on TimeoutException {
      await _cerrarStream(stream);
      throw const CapturaException(
        CapturaErrorKind.denied,
        'No respondiste al permiso de cámara. Permítela en el navegador y reintenta.',
      );
    } on CapturaException {
      rethrow;
    } catch (e) {
      await _cerrarStream(stream);
      final nombre = _domErrorName(e);
      if (nombre.isNotEmpty) throw _mapearDom(nombre);
      throw const CapturaException(
        CapturaErrorKind.notSupported,
        'Este navegador no permite usar la cámara. Prueba en Chrome.',
      );
    }
  }

  /// Extrae el `name` de un DOMException sin hacer un chequeo de tipo JS
  /// interop (que el analizador marca como inconsistente entre plataformas).
  String _domErrorName(Object error) {
    try {
      final dynamic dom = error;
      final dynamic nombre = dom.name;
      return nombre is String ? nombre : '';
    } catch (_) {
      return '';
    }
  }

  Future<web.MediaStream> _abrir(Map<String, Object>? videoOpts) async {
    final JSAny videoConstr =
        videoOpts == null ? true.toJS : videoOpts.jsify() as JSAny;
    final constraints = web.MediaStreamConstraints(
      video: videoConstr,
      audio: false.toJS,
    );
    try {
      return await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart
          .timeout(const Duration(seconds: 40));
    } on TimeoutException {
      throw const CapturaException(
        CapturaErrorKind.denied,
        'No respondiste al permiso de cámara. Permítela en el navegador y reintenta.',
      );
    }
  }

  CapturaException _mapearDom(String name) {
    if (name == 'NotAllowedError') {
      return const CapturaException(
        CapturaErrorKind.denied,
        'Permiso de cámara denegado. Toca el candado de la barra, permite la cámara y reintenta.',
      );
    }
    if (name == 'NotFoundError' || name == 'OverconstrainedError') {
      return const CapturaException(
        CapturaErrorKind.noCamera,
        'No se encontró ninguna cámara en este dispositivo.',
      );
    }
    if (name == 'NotReadableError') {
      return const CapturaException(
        CapturaErrorKind.busy,
        'La cámara está ocupada por otra app o pestaña. Ciérralas y reintenta.',
      );
    }
    return CapturaException(
      CapturaErrorKind.notSupported,
      'No se pudo abrir la cámara ($name). Prueba en Chrome.',
    );
  }

  Widget vistaPrevia() {
    final t = _viewType;
    if (t == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return HtmlElementView(viewType: t);
  }

  /// Captura una secuencia de frames JPEG durante [duracion].
  ///
  /// Se apunta a ~12 fps con ancho 288 px y calidad 0.5: suficiente para
  /// rPPG y dentro del presupuesto de payload de Vercel (~4 MB). Si el
  /// presupuesto se agota antes de tiempo, se corta la captura y se devuelve
  /// lo obtenido (el backend exige un mínimo de 60 frames y 10 s).
  Future<ResultadoCaptura> capturar({
    required Duration duracion,
    void Function(double progreso)? progreso,
  }) async {
    final video = _video;
    if (video == null) {
      throw const CapturaException(
        CapturaErrorKind.unknown,
        'La cámara aún no está lista.',
      );
    }
    final anchoVideo = video.videoWidth;
    final altoVideo = video.videoHeight;
    if (anchoVideo == 0 || altoVideo == 0) {
      throw const CapturaException(
        CapturaErrorKind.unknown,
        'La cámara aún no está lista.',
      );
    }

    const ancho = 288;
    const presupuesto = 3600000; // caracteres base64
    const intervaloMs = 80; // ~12.5 fps
    final alto = (altoVideo * ancho / anchoVideo).round().clamp(144, 420);

    final canvas = web.HTMLCanvasElement()
      ..width = ancho
      ..height = alto;
    final ctx = canvas.context2D;
    final frames = <String>[];
    var acumulado = 0;
    final reloj = Stopwatch()..start();
    final totalMs = duracion.inMilliseconds;

    while (reloj.elapsedMilliseconds < totalMs) {
      try {
        ctx.drawImage(video, 0, 0, ancho, alto);
        final url = canvas.toDataURL('image/jpeg', 0.5.toJS);
        final b64 = url.split(',').last;
        if (b64.isNotEmpty) {
          frames.add(b64);
          acumulado += b64.length;
        }
      } catch (_) {
        // Un frame perdido no invalida la captura.
      }
      final progresoActual =
          (reloj.elapsedMilliseconds / totalMs).clamp(0.0, 1.0);
      progreso?.call(progresoActual);
      if (acumulado >= presupuesto) break;

      final objetivoMs = frames.length * intervaloMs;
      final espera = objetivoMs - reloj.elapsedMilliseconds;
      await Future.delayed(
        Duration(milliseconds: espera > 0 ? espera : 5),
      );
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
    final fps = segundos > 0 ? frames.length / segundos : 12.0;
    return ResultadoCaptura(frames: frames, fps: fps, duracionSeg: segundos);
  }

  Future<void> _cerrarStream(web.MediaStream? stream) async {
    try {
      if (stream != null) {
        for (final track in stream.getTracks().toDart) {
          track.stop();
        }
      }
    } catch (_) {}
  }

  Future<void> liberar() async {
    try {
      final dynamic src = _video?.srcObject;
      _video?.srcObject = null;
      if (src != null) {
        final stream = src as web.MediaStream;
        for (final track in stream.getTracks().toDart) {
          track.stop();
        }
      }
    } catch (_) {}
    _video = null;
    _viewType = null;
  }
}
