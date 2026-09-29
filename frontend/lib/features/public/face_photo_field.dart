import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'kiosk/kiosk_camera_service.dart';

/// Campo de foto del rostro, OBLIGATORIO al agendar una cita.
///
/// La foto se guarda SIN procesar (el reconocimiento OpenCV vive solo en el
/// kiosco Windows). Intenta usar la cámara del equipo (web/móvil) y, si no hay
/// cámara disponible (escritorio), permite elegir un archivo de imagen.
class FacePhotoField extends StatefulWidget {
  const FacePhotoField({
    super.key,
    required this.onChanged,
    this.initialBytes,
  });

  final ValueChanged<Uint8List?> onChanged;
  final Uint8List? initialBytes;

  @override
  State<FacePhotoField> createState() => _FacePhotoFieldState();
}

class _FacePhotoFieldState extends State<FacePhotoField> {
  Uint8List? _bytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
  }

  Future<void> _takePhoto() async {
    setState(() => _busy = true);
    try {
      final service = KioskCameraService();
      var cameraOk = false;
      try {
        await service.initialize();
        cameraOk = true;
      } catch (_) {
        // Cualquier fallo de cámara (permiso, sin cámara, navegador)
        // cae al selector de archivo.
        cameraOk = false;
      }
      if (!cameraOk) {
        await service.dispose();
        if (mounted) await _pickFile();
        return;
      }
      if (!mounted) {
        await service.dispose();
        return;
      }
      Uint8List? bytes;
      try {
        bytes = await showDialog<Uint8List>(
          context: context,
          builder: (ctx) => _CameraDialog(service: service),
        );
      } catch (_) {
        bytes = null;
      }
      await service.dispose();
      if (!mounted) return;
      if (bytes != null) {
        setState(() => _bytes = bytes);
        widget.onChanged(bytes);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (!mounted) return;
      final bytes = res?.files.single.bytes;
      if (bytes != null) {
        setState(() {
          _bytes = bytes;
          _busy = false;
        });
        widget.onChanged(bytes);
      } else {
        setState(() => _busy = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo de imagen')),
      );
    }
  }

  void _clear() {
    setState(() => _bytes = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 96,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _bytes == null ? AppColors.danger : AppColors.success,
                  width: 1.6,
                ),
              ),
              child: _bytes == null
                  ? const Icon(Icons.face_outlined, color: AppColors.muted, size: 44)
                  : Image.memory(_bytes!, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foto del rostro *',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Obligatoria. Se usa solo en el kiosco del consultorio para reconocerte.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _takePhoto,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(_bytes == null ? 'Tomar foto' : 'Repetir foto'),
                      ),
                      if (_bytes != null)
                        TextButton(
                          onPressed: _clear,
                          child: const Text('Quitar'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_bytes == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Debes registrar tu foto para completar la solicitud.',
              style: TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

/// Diálogo con vista previa de la cámara y botón de captura.
class _CameraDialog extends StatefulWidget {
  const _CameraDialog({required this.service});

  final KioskCameraService service;

  @override
  State<_CameraDialog> createState() => _CameraDialogState();
}

class _CameraDialogState extends State<_CameraDialog> {
  bool _capturing = false;

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      final photo = await widget.service.capture();
      if (!mounted) return;
      Navigator.of(context).pop(photo.bytes);
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.service.controller;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Text('Foto del rostro', style: TextStyle(fontWeight: FontWeight.w800)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mira a la cámara de frente, con buena luz y sin lentes oscuros.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: controller == null
                    ? const ColoredBox(
                        color: AppColors.background,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : CameraPreview(controller),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _capturing ? null : _capture,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Capturar'),
        ),
      ],
    );
  }
}
