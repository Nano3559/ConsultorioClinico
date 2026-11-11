import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/foto_utils.dart';
import '../../../state/auth_provider.dart';
import '../../public/kiosk/kiosk_camera_service.dart';
import '../../public/kiosk/vision_service.dart';

/// Registro facial de un paciente desde recepción.
///
/// Captura el pack multi-pose estilo Binance (frente, izquierda, derecha,
/// arriba, abajo — 3 fotos por pose) y lo envía en un solo lote a
/// `POST /api/vision/registrar-rostro/:id`. El microservicio (InsightFace)
/// mide calidad por muestra, genera los embeddings 512-d y guarda las fotos
/// livianas en la carpeta `rostros/{cedula}_{nombre}/` de la nube.
/// Sin varias poses y ángulos el reconocimiento no es fiable: una sola
/// captura no basta.
class PatientFaceRegisterPage extends StatefulWidget {
  const PatientFaceRegisterPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final int patientId;
  final String patientName;

  @override
  State<PatientFaceRegisterPage> createState() => _PatientFaceRegisterPageState();
}

class _PatientFaceRegisterPageState extends State<PatientFaceRegisterPage> {
  /// Poses del registro guiado (3 fotos por pose = 15 muestras).
  static const List<(_Pose, String)> _poses = [
    (_Pose.frontal, 'Mire de frente a la cámara'),
    (_Pose.izquierda, 'Gire el rostro a SU izquierda'),
    (_Pose.derecha, 'Gire el rostro a SU derecha'),
    (_Pose.arriba, 'Levante apenas el mentón'),
    (_Pose.abajo, 'Baje apenas el mentón'),
  ];
  static const int _porPose = 3;

  /// Muestras mínimas para un registro fiable. Coincide con poses × 3.
  static const int _objetivoMuestras = 15;

  final KioskCameraService _camera = KioskCameraService(frontPreference: true);
  final VisionService _vision = VisionService();

  final List<_Muestra> _muestras = [];

  bool _initializing = true;
  bool _enviando = false;
  KioskCameraException? _camaraError;
  String? _mensaje;
  bool _ok = false;
  RostroEstado? _estado;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _initializing = true;
      _camaraError = null;
      _mensaje = null;
      _ok = false;
    });
    try {
      await _camera.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
      await _consultarEstado();
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _camaraError = e;
      });
    }
  }

  Future<void> _consultarEstado() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final estado = await _vision.consultarRostro(
        pacienteId: widget.patientId,
        token: token,
      );
      if (!mounted) return;
      setState(() => _estado = estado);
    } on VisionException {
      // El estado es informativo: si falla, no bloquea la captura.
    }
  }

  /// Pose actual según cuántas fotos lleva (3 por pose, en orden).
  _Pose get _poseActual {
    final idx = (_muestras.length ~/ _porPose).clamp(0, _poses.length - 1);
    return _poses[idx].$1;
  }

  String get _instruccionActual {
    final idx = (_muestras.length ~/ _porPose).clamp(0, _poses.length - 1);
    return _poses[idx].$2;
  }

  int _conteoPose(_Pose pose) =>
      _muestras.where((m) => m.pose == pose).length;

  Future<void> _capturar() async {
    if (_enviando) return;
    setState(() => _mensaje = null);
    try {
      final photo = await _camera.capture();
      if (!mounted) return;
      setState(() {
        _muestras.add(_Muestra(photo: photo, pose: _poseActual));
        _ok = false;
      });
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      setState(() => _mensaje = e.message);
    }
  }

  /// Elimina la última muestra: si una foto sale borrosa o mal iluminada, es
  /// más fácil retocar la pila que reiniciar la captura entera.
  void _quitarUltima() {
    if (_muestras.isEmpty) return;
    setState(() {
      _muestras.removeLast();
      _ok = false;
      _mensaje = null;
    });
  }

  Future<void> _enviar() async {
    if (_muestras.isEmpty || _enviando) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() => _mensaje = 'Sesión expirada. Vuelve a iniciar sesión.');
      return;
    }

    setState(() {
      _enviando = true;
      _mensaje = null;
    });
    try {
      // Fotos livianas (JPEG ~800px q80): el pack viaja y se guarda liviano.
      final muestras = <Map<String, String>>[];
      for (final m in _muestras) {
        final b64 = FotoUtils.aBase64Liviano(m.photo.bytes);
        if (b64 == null) continue;
        muestras.add({'imagen': b64, 'pose': m.pose.nombre});
      }
      if (muestras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _enviando = false;
          _mensaje = 'No se pudo procesar ninguna foto. Reintente la captura.';
        });
        return;
      }
      final resultado = await _vision.registrarRostro(
        pacienteId: widget.patientId,
        muestras: muestras,
        token: token,
      );
      if (!mounted) return;
      final rechazadas = resultado.rechazadas;
      final detalleRechazo = rechazadas.isEmpty
          ? ''
          : ' Repetir poses: ${rechazadas.entries.map((e) => '${e.key} (${e.value})').join(', ')}.';
      setState(() {
        _enviando = false;
        _ok = resultado.registrado;
        _mensaje = resultado.registrado
            ? 'Rostro registrado: ${resultado.imagenesGuardadas} muestras '
                'multi-pose guardadas en la nube.$detalleRechazo'
            : 'Las muestras se recibieron, pero la calidad no alcanzó para '
                'generar la plantilla. Repita las poses con mejor luz.$detalleRechazo';
      });
      await _consultarEstado();
    } on VisionException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _ok = false;
        _mensaje = e.message;
      });
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suficiente = _muestras.length >= _objetivoMuestras;
    return Scaffold(
      appBar: AppBar(
        title: Text('Rostro de ${widget.patientName}'),
        actions: [
          if (_muestras.isNotEmpty)
            IconButton(
              tooltip: 'Quitar la última foto',
              onPressed: _enviando ? null : _quitarUltima,
              icon: const Icon(Icons.undo),
            ),
          IconButton(
            tooltip: 'Cambiar de cámara',
            onPressed: _enviando ? null : _cambiarCamara,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _camaraError != null
              ? _ErrorCamara(error: _camaraError!, onRetry: _init)
              : _buildCaptura(suficiente),
    );
  }

  Widget _buildCaptura(bool suficiente) {
    final controller = _camera.controller;
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: controller == null || !_camera.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.previewSize?.height ?? 1,
                        height: controller.value.previewSize?.width ?? 1,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
          ),
        ),
        _barraEstado(suficiente),
      ],
    );
  }

  Widget _barraEstado(bool suficiente) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_estado != null) _chipEstado(_estado!),
            if (_mensaje != null) ...[
              const SizedBox(height: 12),
              Text(
                _mensaje!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ok ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Guía de la pose actual estilo Binance: el paciente sabe
            // exactamente qué ángulo poner en cada paso.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                suficiente ? 'Pack completo. Revise y registre.' : 'Paso ${_muestras.length + 1}/$_objetivoMuestras: $_instruccionActual',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final p in _PatientFaceRegisterPageState._poses)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${p.$1.corto} ${_conteoPose(p.$1)}/3',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: _conteoPose(p.$1) >= 3
                          ? AppColors.success.withValues(alpha: 0.15)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Muestras: ${_muestras.length} / $_objetivoMuestras'
              '${suficiente ? ' — listo para registrar' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_muestras.length / _objetivoMuestras).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _enviando ? null : _capturar,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Tomar foto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_enviando || !suficiente) ? null : _enviar,
                    icon: _enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_enviando ? 'Registrando...' : 'Registrar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipEstado(RostroEstado estado) {
    return Center(
      child: Chip(
        avatar: Icon(
          estado.registrado ? Icons.verified_user : Icons.person_off_outlined,
          size: 18,
          color: estado.registrado ? AppColors.success : AppColors.muted,
        ),
        label: Text(
          estado.registrado
              ? 'Rostro registrado (${estado.dimensiones} dims)'
              : 'Sin rostro registrado',
        ),
      ),
    );
  }

  Future<void> _cambiarCamara() async {
    setState(() => _mensaje = null);
    try {
      await _camera.switchCamera();
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      setState(() => _mensaje = e.message);
    }
  }
}

/// Poses del registro guiado multi-pose.
enum _Pose {
  frontal('frontal', 'Frente'),
  izquierda('izquierda', 'Izq.'),
  derecha('derecha', 'Der.'),
  arriba('arriba', 'Arriba'),
  abajo('abajo', 'Abajo');

  const _Pose(this.nombre, this.corto);

  /// Nombre que viaja al backend (`pose` de la muestra).
  final String nombre;

  /// Etiqueta corta para la UI.
  final String corto;
}

/// Una captura etiquetada con su pose.
class _Muestra {
  const _Muestra({required this.photo, required this.pose});

  final KioskPhoto photo;
  final _Pose pose;
}

class _ErrorCamara extends StatelessWidget {
  const _ErrorCamara({required this.error, required this.onRetry});

  final KioskCameraException error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error.kind == KioskCameraError.denied
                  ? Icons.no_photography_outlined
                  : Icons.videocam_off_outlined,
              size: 56,
              color: AppColors.muted,
            ),
            const SizedBox(height: 16),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
