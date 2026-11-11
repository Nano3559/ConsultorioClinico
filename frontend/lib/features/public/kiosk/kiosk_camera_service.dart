import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';

/// Motivo por el que la cámara del kiosco no está disponible.
enum KioskCameraError {
  denied,
  noCamera,
  busy,
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

/// Acceso a la cámara para el kiosco y la reserva online.
///
/// Regla de oro: la cámara se abre UNA sola vez por inicialización. Abrir y
/// cerrar streams en ráfaga (sondeo previo, enumeraciones repetidas) deja el
/// dispositivo ocupado en varios celulares y el siguiente open falla con
/// NotReadableError. Por eso aquí no hay sondas ni pre-aperturas: se enumera,
/// se elige y se abre, una vez.
class KioskCameraService {
  KioskCameraService({this.frontPreference = true});

  /// Prefiere la cámara frontal (el paciente se mira a sí mismo en la tablet).
  final bool frontPreference;

  CameraController? _controller;

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  double? get aspectRatio => _controller?.value.aspectRatio;

  /// Inicializa la cámara frontal si existe (trasera como respaldo).
  /// Nunca deja la pantalla colgada: todo fallo termina en
  /// [KioskCameraException] con mensaje accionable.
  Future<void> initialize() async {
    if (_controller != null) {
      if (_controller!.value.isInitialized) return;
      await _cerrarSilencioso();
    }

    final cameras = await _camarasDisponibles();

    final preferred =
        frontPreference ? CameraLensDirection.front : CameraLensDirection.back;
    final opposite =
        frontPreference ? CameraLensDirection.back : CameraLensDirection.front;
    final selected = cameras.firstWhere(
      (c) => c.lensDirection == preferred,
      orElse: () => cameras.firstWhere(
        (c) => c.lensDirection == opposite,
        orElse: () => cameras.first,
      ),
    );

    // Primer intento en calidad media; si el equipo no la soporta (o el
    // permiso se revocó en el medio), un reintento en baja antes de rendirse.
    for (final preset in [ResolutionPreset.medium, ResolutionPreset.low]) {
      _controller = CameraController(
        selected,
        preset,
        enableAudio: false,
      );
      try {
        await _controller!.initialize();
        return;
      } catch (_) {
        await _cerrarSilencioso();
      }
    }
    throw const KioskCameraException(
      KioskCameraError.notSupported,
      'No se pudo iniciar la vista previa de la cámara.',
    );
  }

  /// Enumera las cámaras mapeando cada error DOM a su causa real.
  Future<List<CameraDescription>> _camarasDisponibles() async {
    late final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras()
          .timeout(const Duration(seconds: 25));
    } on CameraException catch (e) {
      throw _mapearErrorCamara(e.code, e.description);
    } on TimeoutException {
      throw const KioskCameraException(
        KioskCameraError.unknown,
        'La cámara no respondió. Revisa el permiso e intenta de nuevo.',
      );
    } catch (_) {
      throw const KioskCameraException(
        KioskCameraError.notSupported,
        'Este equipo no permite usar la cámara desde aquí. Prueba en Chrome.',
      );
    }
    if (cameras.isEmpty) {
      throw const KioskCameraException(
        KioskCameraError.noCamera,
        'No se detectó ninguna cámara en el dispositivo.',
      );
    }
    return cameras;
  }

  /// Traduce el código de error a causa + acción para el usuario.
  KioskCameraException _mapearErrorCamara(String code, String? detail) {
    final d = (detail ?? '').toLowerCase();
    if (code == 'CameraAccessDenied' ||
        code == 'NotAllowedError' ||
        d.contains('permission') ||
        d.contains('denied') ||
        d.contains('notallowed')) {
      return const KioskCameraException(
        KioskCameraError.denied,
        'Permiso de cámara denegado. Toca el candado de la barra del navegador, permite la cámara y reintenta.',
      );
    }
    if (code == 'NotFoundError' || code == 'OverconstrainedError') {
      return const KioskCameraException(
        KioskCameraError.noCamera,
        'No se encontró ninguna cámara en este dispositivo.',
      );
    }
    if (code == 'NotReadableError' || d.contains('busy') || d.contains('in use')) {
      return const KioskCameraException(
        KioskCameraError.busy,
        'La cámara está ocupada por otra app o pestaña. Ciérralas y reintenta.',
      );
    }
    if (code == 'SecurityError' || d.contains('secure') || d.contains('https')) {
      return const KioskCameraException(
        KioskCameraError.denied,
        'Abre la página con HTTPS (candado en la barra). Sin conexión segura el navegador bloquea la cámara.',
      );
    }
    return KioskCameraException(
      KioskCameraError.notSupported,
      'No se pudo acceder a la cámara en este equipo${code.isEmpty ? '' : ' ($code)'}.',
    );
  }

  /// Alterna entre la cámara frontal y la trasera en caliente.
  Future<void> switchCamera() async {
    if (_controller == null) return;
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras().timeout(const Duration(seconds: 15));
    } catch (_) {
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
    await previous?.dispose().catchError((_) {});
    await initialize();
  }

  /// Si la cámara actual es frontal (para etiquetar el botón de la UI).
  bool get isFrontFacing =>
      _controller?.description.lensDirection == CameraLensDirection.front;

  /// Toma una foto y la devuelve en memoria (bytes + base64).
  /// Con timeout propio: un stream trabado no congela a quien llama.
  Future<KioskPhoto> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const KioskCameraException(
        KioskCameraError.unknown,
        'La cámara aún no está lista.',
      );
    }
    try {
      final file = await controller
          .takePicture()
          .timeout(const Duration(seconds: 15));
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const KioskCameraException(
          KioskCameraError.unknown,
          'La foto salió vacía. Intenta de nuevo.',
        );
      }
      return KioskPhoto(bytes: bytes);
    } on KioskCameraException {
      rethrow;
    } on TimeoutException {
      throw const KioskCameraException(
        KioskCameraError.unknown,
        'La cámara no respondió al capturar. Intenta de nuevo.',
      );
    } catch (_) {
      throw const KioskCameraException(
        KioskCameraError.unknown,
        'No se pudo capturar la foto.',
      );
    }
  }

  Future<void> dispose() async {
    await _cerrarSilencioso();
  }

  Future<void> _cerrarSilencioso() async {
    try {
      await _controller?.dispose();
    } catch (_) {
      // Liberar nunca debe romper el flujo.
    }
    _controller = null;
  }
}
