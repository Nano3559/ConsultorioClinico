import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Motivo por el que la cámara del kiosco no está disponible.
enum KioskCameraError {
  denied,
  noCamera,
  notSupported,
  unknown,
}

class KioskCameraException implements Exception {
  const KioskCameraException(this.kind, this.message);

  final KioskCameraError kind;
  final String message;

  @override
  String toString() => message;
}

/// Foto tomada por el kiosco, lista para enviarse al backend.
class KioskPhoto {
  const KioskPhoto({required this.bytes});

  final Uint8List bytes;

  /// Representación base64 (payload de `POST /api/kiosco/verificar-rostro`).
  String get base64 => base64Encode(bytes);
}

/// Encapsula el plugin `camera` (web + Android/CameraX) para el kiosco de
/// auto-check-in: pide el permiso, elige la cámara frontal por defecto,
/// inicializa la vista previa y captura la foto en memoria.
class KioskCameraService {
  KioskCameraService({this.frontPreference = true});

  /// Prefiere la cámara frontal (el paciente se mira a sí mismo en la tablet).
  final bool frontPreference;

  CameraController? _controller;

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  double? get aspectRatio => _controller?.value.aspectRatio;

  /// Solicita el permiso en móvil (en web el navegador lo pide al crear el
  /// stream) e inicializa la cámara frontal si existe.
  Future<void> initialize() async {
    if (_controller != null) {
      if (_controller!.value.isInitialized) return;
      await _controller!.dispose();
      _controller = null;
    }

    // En web se pide el permiso ANTES de enumerar: varios navegadores
    // móviles fallan en enumerateDevices sin permiso previo y el error que
    // sale no es CameraException (quedaba como "equipo incompatible").
    if (kIsWeb) await _pedirPermisoWeb();

    // NOTA: no se usa permission_handler (su plugin nativo de Windows no
    // compila con VS2026 y rompía el build del kiosco). En móvil el SO pide
    // el permiso al inicializar la cámara; si se deniega, el CameraException
    // de abajo lo reporta como KioskCameraError.denied.
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      final denied = e.code == 'CameraAccessDenied' ||
          e.description?.toLowerCase().contains('permission') == true;
      throw KioskCameraException(
        denied ? KioskCameraError.denied : KioskCameraError.notSupported,
        denied
            ? 'Acceso a la cámara denegado. Habilítalo e intenta de nuevo.'
            : 'No se pudo acceder a la cámara en este equipo.',
      );
    }

    if (cameras.isEmpty) {
      throw const KioskCameraException(
        KioskCameraError.noCamera,
        'No se detectó ninguna cámara en el dispositivo.',
      );
    }

    // Se elige siempre con `orElse`: `firstWhere` sin él lanza StateError, que
    // no es una CameraException y por tanto se escapaba del `on` de abajo.
    // En equipos sin cámara frontal (kioscos con solo cámara trasera, webcams
    // que reportan lente unspecified) eso abortaba la inicialización.
    final preferred = frontPreference
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final opposite = frontPreference
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    final selected = cameras.firstWhere(
      (c) => c.lensDirection == preferred,
      orElse: () => cameras.firstWhere(
        (c) => c.lensDirection == opposite,
        orElse: () => cameras.first,
      ),
    );

    _controller = CameraController(
      selected,
      // `low` en móvil reduce mucho el peso de la foto (LBPH no necesita alta
      // resolución) y evita el 413 de Vercel en el body base64.
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await _controller!.initialize();
    } on CameraException {
      // Puede fallar por resolución no soportada o por permission revocada
      // entre availableCameras() e initialize(): se reintenta una vez con
      // `low` antes de rendirse.
      try {
        _controller = CameraController(
          selected,
          ResolutionPreset.low,
          enableAudio: false,
        );
        await _controller!.initialize();
      } on CameraException {
        await _controller?.dispose();
        _controller = null;
        throw const KioskCameraException(
          KioskCameraError.notSupported,
          'No se pudo iniciar la vista previa de la cámara.',
        );
      }
    }
  }

  /// Pide permiso de cámara al navegador con getUserMedia directo y mapea el
  /// error DOM real a un mensaje útil (denegado / sin cámara / no soportado).
  /// Sin esto, en varios navegadores móviles el fallo salía como error
  /// genérico aunque el equipo sí tiene cámara.
  Future<void> _pedirPermisoWeb() async {
    try {
      // Sin contexto seguro (HTTPS) el navegador ni expone la cámara.
      if (!web.window.isSecureContext) {
        throw const KioskCameraException(
          KioskCameraError.denied,
          'Abre la página con HTTPS (candado en la barra). Sin conexión segura el navegador bloquea la cámara.',
        );
      }
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(
            video: true.toJS,
            audio: false.toJS,
          ))
          .toDart
          .timeout(const Duration(seconds: 30));
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
    } on web.DOMException catch (e) {
      final name = e.name;
      if (name == 'NotAllowedError') {
        throw const KioskCameraException(
          KioskCameraError.denied,
          'Permiso de cámara denegado. Toca el candado de la barra del navegador, permite la cámara y reintenta.',
        );
      }
      if (name == 'NotFoundError' || name == 'OverconstrainedError') {
        throw const KioskCameraException(
          KioskCameraError.noCamera,
          'No se encontró ninguna cámara en este dispositivo.',
        );
      }
      throw KioskCameraException(
        KioskCameraError.notSupported,
        'No se pudo usar la cámara ($name). Prueba en Chrome.',
      );
    } on TimeoutException {
      throw const KioskCameraException(
        KioskCameraError.denied,
        'No respondiste al permiso de cámara. Permítela en el navegador y reintenta.',
      );
    } on KioskCameraException {
      rethrow;
    } catch (_) {
      throw const KioskCameraException(
        KioskCameraError.notSupported,
        'Este navegador no permite usar la cámara. Prueba en Chrome.',
      );
    }
  }

  /// Alterna entre la cámara frontal y la trasera en caliente.
  ///
  /// Necesario en el kiosco: muchoséfonos traen varias cámaras y la frontal
  /// puede fallar al inicializar (ocupada por otra app, sin permisos en
  /// runtime, hardware incompatible). Permite al operador recuperar el
  /// servicio sin reiniciar la app.
  Future<void> switchCamera() async {
    if (_controller == null) return;
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException {
      return;
    }
    if (cameras.length < 2) return;

    final current = _controller!.description;
    final target = cameras.firstWhere(
      (c) =>
          c.name != current.name &&
          c.lensDirection != current.lensDirection,
      orElse: () => cameras.firstWhere(
        (c) => c.name != current.name,
        orElse: () => current,
      ),
    );
    if (target.name == current.name) return;

    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    await initialize();
  }

  /// Si la cámara actual es frontal (para etiquetar el botón de la UI).
  bool get isFrontFacing =>
      _controller?.description.lensDirection == CameraLensDirection.front;

  /// Toma una foto y la devuelve en memoria (bytes + base64).
  Future<KioskPhoto> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const KioskCameraException(
        KioskCameraError.unknown,
        'La cámara aún no está lista.',
      );
    }
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      return KioskPhoto(bytes: bytes);
    } on CameraException {
      throw const KioskCameraException(
        KioskCameraError.unknown,
        'No se pudo capturar la foto.',
      );
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}