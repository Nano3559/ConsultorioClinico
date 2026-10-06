import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'kiosk/auto_captura_service.dart';
import 'kiosk/kiosk_camera_service.dart';

/// Una foto del pack facial con su pose.
class MuestraFacial {
  const MuestraFacial({required this.bytes, required this.pose});

  /// Bytes JPEG originales de la cámara (se comprimen al enviar).
  final Uint8List bytes;

  /// Una de: frontal, izquierda, derecha, arriba, abajo.
  final String pose;
}

/// Pasos de la captura guiada estilo Binance: el paciente mueve la cabeza
/// (no basta una foto fija: una imagen impresa no gira ni parpadea).
const _poses = <String, String>{
  'frontal': 'Mire de frente a la cámara',
  'izquierda': 'Gire el rostro a SU izquierda',
  'derecha': 'Gire el rostro a SU derecha',
  'arriba': 'Levante apenas el mentón',
  'abajo': 'Baje apenas el mentón y parpadee',
};

/// Campo de fotos del rostro, OBLIGATORIO al agendar (salvo registro vigente).
///
/// Solo cámara (sin selector de archivos a propósito): el pack multi-pose
/// exige ángulos reales del rostro en vivo. Si la cámara falla, se muestra
/// el error con botón Reintentar en vez de un camino silencioso.
class FacePhotoField extends StatefulWidget {
  const FacePhotoField({super.key, required this.onChanged});

  /// Se emite con la lista completa (5 poses) o null si se quita.
  final ValueChanged<List<MuestraFacial>?> onChanged;

  @override
  State<FacePhotoField> createState() => _FacePhotoFieldState();
}

class _FacePhotoFieldState extends State<FacePhotoField> {
  List<MuestraFacial> _muestras = [];
  bool _busy = false;

  bool get _completo => _muestras.length >= _poses.length;

  Future<void> _abrirGuia() async {
    setState(() => _busy = true);
    final resultado = await showDialog<List<MuestraFacial>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _GuiaCapturaDialog(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (resultado != null && resultado.isNotEmpty) {
      setState(() => _muestras = resultado);
      widget.onChanged(resultado);
    }
    // Si canceló el diálogo no se muestra nada (no es un error).
  }

  void _clear() {
    setState(() => _muestras = []);
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
                  color: _completo ? AppColors.success : AppColors.danger,
                  width: 1.6,
                ),
              ),
              child: _muestras.isEmpty
                  ? const Icon(Icons.face_outlined,
                      color: AppColors.muted, size: 44)
                  : Image.memory(_muestras.first.bytes, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foto del rostro *',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.dark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _completo
                        ? 'Pack completo (${_muestras.length}/${_poses.length} poses). Se usa solo en el kiosco para reconocerte.'
                        : 'Obligatoria: 5 fotos guiadas (frente, lados, arriba, abajo). Se usa solo en el kiosco para reconocerte.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _abrirGuia,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(_muestras.isEmpty
                            ? 'Tomar fotos'
                            : 'Repetir fotos'),
                      ),
                      if (_muestras.isNotEmpty)
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
        if (!_completo)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Completa las 5 fotos guiadas para continuar.',
              style: TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

/// Diálogo de captura guiada: vista previa + óvalo guía + instrucciones por
/// pose + miniaturas. Sin selector de archivos: todo es cámara en vivo.
class _GuiaCapturaDialog extends StatefulWidget {
  const _GuiaCapturaDialog();

  @override
  State<_GuiaCapturaDialog> createState() => _GuiaCapturaDialogState();
}

class _GuiaCapturaDialogState extends State<_GuiaCapturaDialog> {
  final _camera = KioskCameraService(frontPreference: true);
  final _auto = AutoCapturaService();
  final List<MuestraFacial> _muestras = [];

  bool _initializing = true;
  bool _ocupado = false;
  bool _enviando = false;
  KioskCameraException? _error;

  /// Sondeo automático estilo Binance: cada ~1s se prueba el encuadre y la
  /// foto se toma sola cuando es óptima (sin botón Capturar).
  Timer? _sonda;
  String _mensajeGuia = 'Ubica tu rostro dentro del óvalo';
  DateTime _poseDesde = DateTime.now();
  bool _manual = false;

  /// Última evaluación (para la checklist en vivo).
  EvaluacionFoto? _ultEv;

  /// Si el auto no lo logra en este tiempo, se ofrece captura manual.
  static const _limiteManual = Duration(seconds: 25);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sonda?.cancel();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      await _camera.initialize();
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = e;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _initializing = false);
    _iniciarSonda();
  }

  /// (Re)inicia el sondeo para la pose actual.
  void _iniciarSonda() {
    _sonda?.cancel();
    _auto.nuevaPose();
    _poseDesde = DateTime.now();
    setState(() {
      _mensajeGuia = 'Ubica tu rostro dentro del óvalo';
      _manual = false;
      _ultEv = null;
    });
    _sonda = Timer.periodic(const Duration(milliseconds: 900), (_) {
      _sondear();
    });
  }

  /// Un intento de captura automática: si el encuadre es óptimo dos frames
  /// seguidos, esos mismos bytes quedan como muestra de la pose.
  Future<void> _sondear() async {
    if (!mounted ||
        _initializing ||
        _error != null ||
        _completo ||
        _ocupado) {
      return;
    }
    _ocupado = true;
    try {
      final photo = await _camera.capture();
      if (!mounted || _completo) return;
      final pose = _poseActual;
      final ev = _auto.evaluar(photo.bytes, pose: pose);
      setState(() {
        _mensajeGuia = ev.mensaje;
        _ultEv = ev;
        _manual =
            DateTime.now().difference(_poseDesde) > _limiteManual;
      });
      if (!ev.lista) return;
      if (!mounted) return;
      if (pose == 'frontal') _auto.fijarReferenciaFrontal(photo.bytes);
      setState(() {
        _muestras.add(MuestraFacial(bytes: photo.bytes, pose: pose));
        _ocupado = false;
      });
      if (_completo) {
        _sonda?.cancel();
        return;
      }
      _iniciarSonda();
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajeGuia = e.message;
        _manual = true;
      });
    } finally {
      _ocupado = false;
    }
  }

  /// Respaldo manual (solo aparece si el auto no lo logra): conserva el
  /// gesto pedido pero lo dispara el paciente.
  Future<void> _capturaManual() async {
    if (_ocupado || _completo) return;
    _ocupado = true;
    try {
      final photo = await _camera.capture();
      if (!mounted) return;
      final pose = _poseActual;
      if (pose == 'frontal') _auto.fijarReferenciaFrontal(photo.bytes);
      setState(() {
        _muestras.add(MuestraFacial(bytes: photo.bytes, pose: pose));
      });
      if (_completo) {
        _sonda?.cancel();
        return;
      }
      _iniciarSonda();
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      _ocupado = false;
    }
  }

  String get _poseActual => _poses.keys.elementAt(_muestras.length);
  String get _instruccion => _poses.values.elementAt(_muestras.length);
  bool get _completo => _muestras.length >= _poses.length;

  void _quitarUltima() {
    if (_muestras.isEmpty) return;
    setState(() => _muestras.removeLast());
    if (_muestras.isEmpty) {
      _auto.reiniciar();
    }
    _iniciarSonda();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Text('Fotos del rostro',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _initializing
            ? const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? _panelError()
                : _panelCaptura(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (_error == null)
          FilledButton.icon(
            onPressed: (_enviando || !_completo) ? null : () {
              setState(() => _enviando = true);
              Navigator.of(context).pop(List.of(_muestras));
            },
            icon: const Icon(Icons.check),
            label: const Text('Usar estas fotos'),
          ),
      ],
    );
  }

  /// Error de cámara VISIBLE con reintento (antes caía en silencio al
  /// selector de archivos). Incluye ayuda según el motivo.
  Widget _panelError() {
    final e = _error!;
    final ayuda = e.kind == KioskCameraError.denied
        ? 'Toca el ícono de cámara en la barra del navegador y permite el acceso, o habilítalo en Ajustes del teléfono.'
        : 'Revisa que ninguna otra app esté usando la cámara.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_off_outlined,
            size: 56, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(e.message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(ayuda,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _init,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }

  Widget _panelCaptura() {
    final controller = _camera.controller;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
            child: Text(
              _completo
                  ? 'Pack completo. Revisa y confirma.'
                  : 'Foto ${_muestras.length + 1}/${_poses.length}: $_instruccion\n(Mantén la posición: la foto se toma sola)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          // Aspecto real del sensor (sin recorte): lo que ves es lo que se
          // captura. Un aspecto fijo cortaba los bordes del rostro.
          child: AspectRatio(
            aspectRatio:
                controller == null || !_camera.isInitialized
                    ? 4 / 3
                    : controller.value.aspectRatio,
            child: controller == null || !_camera.isInitialized
                ? const ColoredBox(
                    color: AppColors.background,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(controller),
                      const CustomPaint(painter: _OvaloGuia()),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _poses.length; i++)
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _muestras.length
                      ? AppColors.success
                      : AppColors.surface,
                ),
                child: Center(
                  child: i < _muestras.length
                      ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
                      : Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                ),
              ),
            if (_muestras.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Quitar la última foto',
                onPressed: _quitarUltima,
                icon: const Icon(Icons.undo),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (!_completo && _ultEv != null)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _checkChip('Rostro', _ultEv!.tieneRostro),
              _checkChip('Centro', _ultEv!.centrado),
              _checkChip('Luz', _ultEv!.iluminacionOk),
              _checkChip('Nitidez', _ultEv!.nitida),
              if (_poseActual != 'frontal')
                _checkChip('Giro', _ultEv!.gestoOk),
            ],
          ),
        if (!_completo && _ultEv != null) const SizedBox(height: 8),
        if (!_completo)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _mensajeGuia,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        // Respaldo manual: solo aparece si el auto no lo logra en ~25s
        // (mala luz, cámara lenta). En el flujo normal nunca se ve.
        if (!_completo && _manual)
          TextButton.icon(
            onPressed: _ocupado ? null : _capturaManual,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Capturar manualmente'),
          ),
        if (_muestras.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _muestras.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_muestras[i].bytes,
                    width: 56, height: 56, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pastilla de la checklist en vivo: verde cuando el requisito se cumple.
Widget _checkChip(String texto, bool ok) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: ok
          ? AppColors.success.withValues(alpha: 0.14)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: ok ? AppColors.success : AppColors.muted.withValues(alpha: 0.4),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: ok ? AppColors.success : AppColors.muted,
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ok ? AppColors.success : AppColors.muted,
          ),
        ),
      ],
    ),
  );
}

/// Óvalo guía estilo Binance sobre la vista previa.
class _OvaloGuia extends CustomPainter {
  const _OvaloGuia();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.52,
      height: size.height * 0.72,
    );
    canvas.drawOval(rect, paint);
    // Sombra fuera del óvalo para enfocar la atención.
    final sombra = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addOval(rect)
        ..fillType = PathFillType.evenOdd,
      sombra,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
