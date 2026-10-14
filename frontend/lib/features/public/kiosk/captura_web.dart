import 'dart:async';
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import 'kiosk_camera_service.dart';

/// Captura de cámara directa para web (sin pasar por el plugin `camera`).
///
/// El plugin en web abre/cierra el dispositivo varias veces seguidas
/// (permiso + enumeración + un stream por cámara + preview) y en varios
/// celulares eso deja el dispositivo ocupado y el siguiente `open` muere.
/// Aquí hay UNA sola apertura: getUserMedia con facingMode -> <video> a
/// pantalla -> capturar por <canvas>. Nada más.
///
/// Solo se instancia cuando `kIsWeb` es true (`dart:ui_web` solo funciona
/// en navegador; en el resto de plataformas este archivo ni se usa).
class CapturaWebDirecta {
  web.HTMLVideoElement? _video;
  String? _viewType;
  static int _seq = 0;

  bool get activa => _video != null;

  /// Abre la cámara frontal (o la que haya) y la deja reproduciendo.
  /// Lanza [KioskCameraException] con mensaje accionable si algo falla.
  Future<void> iniciar() async {
    if (_video != null) return;
    if (!web.window.isSecureContext) {
      throw const KioskCameraException(
        KioskCameraError.denied,
        'Abre la página con HTTPS (candado en la barra). Sin conexión segura el navegador bloquea la cámara.',
      );
    }
    web.MediaStream? stream;
    try {
      // 1) Intento frontal (selfies). 2) Cualquier cámara disponible.
      try {
        stream = await _abrir({'facingMode': 'user'});
      } on web.DOMException catch (e) {
        if (e.name == 'OverconstrainedError' || e.name == 'NotFoundError') {
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
      _viewType = 'camara-web-${_seq++}';
      ui_web.platformViewRegistry.registerViewFactory(_viewType!, (int _) {
        final wrap = web.HTMLDivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'hidden'
          // Espejo solo visual (selfie); la captura sale sin espejar,
          // igual que antes, para no romper la medición de giros.
          ..style.transform = 'scaleX(-1)'
          ..append(video);
        return wrap;
      });
    } on web.DOMException catch (e) {
      await _cerrarStream(stream);
      throw _mapearDom(e.name);
    } on TimeoutException {
      await _cerrarStream(stream);
      throw const KioskCameraException(
        KioskCameraError.denied,
        'No respondiste al permiso de cámara. Permítela en el navegador y reintenta.',
      );
    } on KioskCameraException {
      rethrow;
    } catch (_) {
      await _cerrarStream(stream);
      throw const KioskCameraException(
        KioskCameraError.notSupported,
        'Este navegador no permite usar la cámara. Prueba en Chrome.',
      );
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
      throw const KioskCameraException(
        KioskCameraError.denied,
        'No respondiste al permiso de cámara. Permítela en el navegador y reintenta.',
      );
    }
  }

  KioskCameraException _mapearDom(String name) {
    if (name == 'NotAllowedError') {
      return const KioskCameraException(
        KioskCameraError.denied,
        'Permiso de cámara denegado. Toca el candado de la barra del navegador, permite la cámara y reintenta.',
      );
    }
    if (name == 'NotFoundError' || name == 'OverconstrainedError') {
      return const KioskCameraException(
        KioskCameraError.noCamera,
        'No se encontró ninguna cámara en este dispositivo.',
      );
    }
    if (name == 'NotReadableError') {
      return const KioskCameraException(
        KioskCameraError.busy,
        'La cámara está ocupada por otra app o pestaña. Ciérralas y reintenta.',
      );
    }
    return KioskCameraException(
      KioskCameraError.notSupported,
      'No se pudo abrir la cámara ($name). Prueba en Chrome.',
    );
  }

  /// Widget con el video en vivo (ocupa todo el espacio disponible).
  Widget vistaPrevia() {
    final t = _viewType;
    if (t == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return HtmlElementView(viewType: t);
  }

  /// Congela el frame actual a JPEG en memoria.
  Future<KioskPhoto> capturarFoto() async {
    final video = _video;
    if (video == null) {
      throw const KioskCameraException(
        KioskCameraError.unknown,
        'La cámara aún no está lista.',
      );
    }
    try {
      final w = video.videoWidth;
      final h = video.videoHeight;
      if (w == 0 || h == 0) {
        throw const KioskCameraException(
          KioskCameraError.unknown,
          'La cámara aún no está lista.',
        );
      }
      final canvas = web.HTMLCanvasElement()..width = w..height = h;
      canvas.context2D.drawImage(video, 0, 0);
      final url = canvas.toDataURL('image/jpeg', 0.85.toJS);
      final b64 = url.split(',').last;
      final bytes = base64Decode(b64);
      if (bytes.isEmpty) {
        throw const KioskCameraException(
          KioskCameraError.unknown,
          'La foto salió vacía. Intenta de nuevo.',
        );
      }
      return KioskPhoto(bytes: bytes);
    } on KioskCameraException {
      rethrow;
    } catch (_) {
      throw const KioskCameraException(
        KioskCameraError.unknown,
        'No se pudo capturar la foto.',
      );
    }
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

  /// Libera la cámara.
  Future<void> liberar() async {
    try {
      final src = _video?.srcObject;
      _video?.srcObject = null;
      if (src is web.MediaStream) {
        for (final track in src.getTracks().toDart) {
          track.stop();
        }
      }
    } catch (_) {}
    _video = null;
    _viewType = null;
  }
}
