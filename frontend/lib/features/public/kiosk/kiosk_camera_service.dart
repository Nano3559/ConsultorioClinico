import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

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

    if (!kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw const KioskCameraException(
          KioskCameraError.denied,
          'Acceso a la cámara denegado. Habilítalo e intenta de nuevo.',
        );
      }
    }

    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException {
      throw const KioskCameraException(
        KioskCameraError.notSupported,
        'No se pudo acceder a la cámara en este equipo.',
      );
    }

    if (cameras.isEmpty) {
      throw const KioskCameraException(
        KioskCameraError.noCamera,
        'No se detectó ninguna cámara en el dispositivo.',
      );
    }

    CameraDescription selected;
    try {
      if (frontPreference) {
        selected = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
      } else {
        throw const _NotFound();
      }
    } on _NotFound {
      selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
    }

    _controller = CameraController(
      selected,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await _controller!.initialize();
    } on CameraException {
      throw const KioskCameraException(
        KioskCameraError.notSupported,
        'No se pudo iniciar la vista previa de la cámara.',
      );
    }
  }

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

class _NotFound implements Exception {
  const _NotFound();
}