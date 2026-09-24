import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import 'kiosk_camera_service.dart';
import 'kiosk_service.dart';

/// Modo kiosco del consultorio: pantalla de auto-check-in por rostro.
///
/// Flujo completo (KIO-03 → KIO-09 → KIO-12 → KIO-15 → KIO-21):
/// 1. La tablet muestra "Bienvenido, por favor mire a la cámara".
/// 2. La cámara frontal inicia la vista previa y un conteo automático.
/// 3. Al capturar, la foto (base64) se envía a
///    `POST /api/kiosco/verificar-rostro` (KioskService).
/// 4. Si se reconoce el rostro y el paciente tiene cita HOY, se confirma el
///    check-in en `POST /api/kiosco/confirmar-cita`.
/// 5. Si no se reconoce (o no hay cita/servicio), el kiosco ofrece reintentar
///    o pasar a recepción.
class KioskPage extends StatefulWidget {
  const KioskPage({super.key});

  @override
  State<KioskPage> createState() => _KioskPageState();
}

/// Etapa del flujo de auto-check-in.
enum _KioskStage { idle, verifying, success, noCita, unrecognized, error }

class _KioskPageState extends State<KioskPage> {
  static const int _countdownFrom = 4;

  final KioskCameraService _camera = KioskCameraService(frontPreference: true);
  final KioskService _service = KioskService();

  bool _initializing = true;
  KioskCameraException? _error;
  Timer? _countdownTimer;
  int _countdown = _countdownFrom;
  bool _extraBusy = false;
  KioskPhoto? _photo;

  _KioskStage _stage = _KioskStage.idle;
  KioskVerificacion? _verificacion;
  String? _resultadoMensaje;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
      _photo = null;
      _stage = _KioskStage.idle;
      _verificacion = null;
      _resultadoMensaje = null;
      _stopCountdown();
    });
    try {
      await _camera.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
      _startCountdown();
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = e;
      });
    }
  }

  /// Reinicia el kiosco para recibir al siguiente paciente.
  void _reiniciar() {
    _stopCountdown();
    _camera.dispose();
    _initCamera();
  }

  void _startCountdown() {
    _stopCountdown();
    if (_photo != null || _error != null || _extraBusy || _stage != _KioskStage.idle) return;
    setState(() => _countdown = _countdownFrom);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _countdown -= 1);
      if (_countdown <= 0) {
        timer.cancel();
        _captureNow(auto: true);
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> _captureNow({bool auto = false}) async {
    if (_extraBusy) return;
    _stopCountdown();
    setState(() => _extraBusy = auto);
    try {
      final photo = await _camera.capture();
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _extraBusy = false;
      });
      await _verifyPhoto(photo);
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _extraBusy = false;
      });
    }
  }

  /// Envía la foto al backend y, si el rostro se reconoce con cita de hoy,
  /// confirma el check-in (KIO-09/KIO-12/KIO-15/KIO-21).
  Future<void> _verifyPhoto(KioskPhoto photo) async {
    setState(() {
      _stage = _KioskStage.verifying;
      _resultadoMensaje = null;
    });

    final KioskVerificacion verificacion;
    try {
      verificacion = await _service.verificarRostro(photo.base64);
    } on KioskServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _resultadoMensaje = e.message;
        _stage = _esFalloRostro(e.message)
            ? _KioskStage.unrecognized
            : _KioskStage.error;
      });
      return;
    }

    if (!mounted) return;
    _verificacion = verificacion;

    // Sin cita hoy: el paciente pasa a recepción para orientación.
    if (!verificacion.cita.existe) {
      setState(() => _stage = _KioskStage.noCita);
      return;
    }

    try {
      await _service.confirmarCita(
        pacienteId: verificacion.pacienteId,
        citaId: verificacion.cita.id,
      );
    } on KioskServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _resultadoMensaje = e.message;
        _stage = _KioskStage.error;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _stage = _KioskStage.success);
  }

  bool _esFalloRostro(String mensaje) {
    return RegExp(r'no reconocid|no se pudo reconocer', caseSensitive: false)
        .hasMatch(mensaje);
  }

  void _retry() {
    _stopCountdown();
    _initCamera();
  }

  void _resetPhoto() {
    setState(() {
      _photo = null;
      _stage = _KioskStage.idle;
      _verificacion = null;
      _resultadoMensaje = null;
      _countdown = _countdownFrom;
    });
    _startCountdown();
  }

  /// El usuario decide pasar a recepción para confirmación manual.
  void _passToReception() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.support_agent, color: AppColors.primary, size: 52),
        title: const Text('Pase a recepción'),
        content: const Text(
          'Nuestro personal del consultorio lo atenderá y confirmará su turno '
          'manualmente. ¡Gracias por su paciencia!',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _reiniciar();
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopCountdown();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 940;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: isWide
              ? Row(
                  children: [
                    Expanded(flex: 5, child: _brandPanel()),
                    Expanded(flex: 6, child: _kioskColumn(wide: true)),
                  ],
                )
              : Column(
                  children: [
                    _topBar(),
                    Expanded(child: _kioskColumn(wide: false)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          _brandMark(),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ConsultorioClínico',
                  style: TextStyle(
                    color: AppColors.dark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Auto check-in',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _reiniciar,
            icon: const Icon(Icons.close, size: 20),
            label: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  Widget _brandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradientSidebar,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _brandMark(inverse: true),
            const SizedBox(height: 28),
            const Text(
              'Bienvenido',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Este consultorio usa el auto check-in con '
              'reconocimiento facial para agilizar su turno.',
              style: TextStyle(
                color: Color(0xFFCCFBF1),
                fontSize: 17,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _stepRow(icon: Icons.face_retouching_natural, step: '1', label: 'Mire a la cámara'),
            const SizedBox(height: 16),
            _stepRow(icon: Icons.verified_user_outlined, step: '2', label: 'Espere la confirmación'),
            const SizedBox(height: 16),
            _stepRow(icon: Icons.event_seat_outlined, step: '3', label: 'Pase a sala de espera'),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, color: Color(0xFF99F6E4), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sus datos biométricos se procesan de forma local y '
                      'solo se usan para su check-in del día.',
                      style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow({required IconData icon, required String step, required String label}) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 18),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          step,
          style: const TextStyle(
            color: Color(0xFF99F6E4),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _brandMark({bool inverse = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: inverse
                ? const LinearGradient(colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)])
                : const LinearGradient(colors: AppColors.gradientPrimary),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowStrong,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.local_hospital,
            color: inverse ? AppColors.primaryDark : Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'ConsultorioClínico',
          style: TextStyle(
            color: inverse ? Colors.white : AppColors.dark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _kioskColumn({required bool wide}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 520 : 460),
          child: FadeSlide(
            child: _panel(wide),
          ),
        ),
      ),
    );
  }

  Widget _panel(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!wide) ...[
          const SizedBox(height: 4),
          const Text(
            'Bienvenido, por favor mire a la cámara',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.dark),
          ),
          const SizedBox(height: 6),
          const Text(
            'El check-in tarda solo unos segundos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
        ],
        _viewfinder(),
        const SizedBox(height: 18),
        if (wide) ...[
          const Text(
            'Bienvenido, por favor mire a la cámara',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.dark),
          ),
          const SizedBox(height: 6),
          const Text(
            'El check-in tarda solo unos segundos y no requiere hacer más pasos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
        ],
        _controls(),
        const SizedBox(height: 14),
        if (_stage != _KioskStage.idle && _stage != _KioskStage.verifying) _resultadoCard(),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _passToReception,
              icon: const Icon(Icons.support_agent, size: 18),
              label: Text(_stage == _KioskStage.idle
                  ? '¿Problemas? Pase a recepción'
                  : 'Pase a recepción'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _viewfinder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth >= 380 ? 340.0 : constraints.maxWidth;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: _viewfinderStack(side),
          ),
        );
      },
    );
  }

  Widget _viewfinderStack(double side) {
    final ready = _camera.isInitialized && _error == null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _previewLayer(ready),
          if (_photo == null && ready) _pulseFaceGuide(side),
          if (_photo == null) _cornerBrackets(side),
          if (_initializing) _loadingLayer(),
          if (_stage == _KioskStage.verifying) _verifyingLayer(),
          Positioned(top: 12, left: 12, right: 12, child: _statusChip()),
          if (_photo == null && ready && !_extraBusy)
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Center(child: _tipPill()),
            ),
        ],
      ),
    );
  }

  Widget _previewLayer(bool ready) {
    if (_photo != null) {
      return Image.memory(_photo!.bytes, fit: BoxFit.cover);
    }
    if (ready) {
      return Container(
        color: const Color(0xFF0B3B37),
        child: _camera.controller == null
            ? const SizedBox.shrink()
            : CameraPreview(_camera.controller!),
      );
    }
    // Sin cámara todavía o con error: fondo de marca.
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF14B8A6)],
        ),
      ),
      child: SizedBox.expand(),
    );
  }

  Widget _loadingLayer() {
    return Container(
      color: const Color(0x660B3B37),
      child: Center(
        child: SizedBox(
          width: 96,
          height: 96,
          child: Lottie.asset('assets/lottie/Heartbeat Lottie Animation.json'),
        ),
      ),
    );
  }

  /// Capa de "verificando identidad" sobre la foto capturada mientras se
  /// consulta el microservicio de visión.
  Widget _verifyingLayer() {
    return Container(
      color: const Color(0xB30B3B37),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.shadowStrong, blurRadius: 18)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Verificando identidad…',
                style: TextStyle(
                  color: AppColors.dark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Guía facial: óvalo teal que indica dónde acomodar el rostro. La animación
  /// suave invita a mirar a la cámara mientras transcurre el conteo.
  Widget _pulseFaceGuide(double side) {
    final inner = side * 0.46;
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1.0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, t, child) => Transform.scale(
            scale: t,
            child: Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(alpha: 0.18),
                border: Border.all(color: AppColors.primaryLight, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.35),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: inner * 0.72,
                  height: inner * 0.72,
                  child: Lottie.asset('assets/lottie/Heartbeat Lottie Animation.json'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cornerBrackets(double side) {
    final len = side * 0.18;
    final pads = 18.0;
    return IgnorePointer(
      child: Stack(
        children: [
          _corner(alignment: Alignment.topLeft, length: len, pads: pads, flipped: false),
          _corner(alignment: Alignment.topRight, length: len, pads: pads, flipped: true),
          _corner(alignment: Alignment.bottomLeft, length: len, pads: pads, flipped: true),
          _corner(alignment: Alignment.bottomRight, length: len, pads: pads, flipped: false),
        ],
      ),
    );
  }

  Widget _corner({
    required Alignment alignment,
    required double length,
    required double pads,
    required bool flipped,
  }) {
    final borderStyle = Border(
      top: const BorderSide(color: AppColors.primaryLight, width: 3),
      left: const BorderSide(color: AppColors.primaryLight, width: 3),
    );
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.all(pads),
          child: Container(
            width: length,
            height: length,
            decoration: BoxDecoration(
              border: flipped
                  ? Border(
                      bottom: borderStyle.bottom,
                      right: borderStyle.top,
                    )
                  : borderStyle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip() {
    final (icon, label, color, bg) = _statusData();
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String, Color, Color) _statusData() {
    if (_error != null) {
      return (Icons.error_outline, _error!.message, AppColors.danger, AppColors.dangerBg);
    }
    if (_stage == _KioskStage.verifying) {
      return (Icons.verified_user_outlined, 'Verificando…', AppColors.info, AppColors.infoBg);
    }
    if (_stage == _KioskStage.success) {
      return (Icons.check_circle, 'Check-in confirmado', AppColors.success, AppColors.successBg);
    }
    if (_stage == _KioskStage.unrecognized) {
      return (Icons.face_retouching_off, 'Rostro no reconocido', AppColors.warning, AppColors.warningBg);
    }
    if (_stage == _KioskStage.noCita) {
      return (Icons.event_busy, 'Sin cita hoy', AppColors.warning, AppColors.warningBg);
    }
    if (_stage == _KioskStage.error) {
      return (Icons.error_outline, 'Error en el check-in', AppColors.danger, AppColors.dangerBg);
    }
    if (_photo != null) {
      return (Icons.check_circle, 'Foto tomada', AppColors.success, AppColors.successBg);
    }
    if (_initializing) {
      return (Icons.camera_roll_outlined, 'Iniciando cámara…', AppColors.info, AppColors.infoBg);
    }
    if (_extraBusy) {
      return (Icons.photo_camera, 'Capturando…', AppColors.warning, AppColors.warningBg);
    }
    return (
      Icons.face_retouching_natural,
      'Mire a la cámara · ${_countdown > 1 ? 'en $_countdown' : 'ahora'}',
      AppColors.success,
      AppColors.successBg,
    );
  }

  Widget _tipPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dark.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'Manténgase dentro del recuadro y mire fijamente',
        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _controls() {
    if (_error != null) {
      return Column(
        children: [
          FilledButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }
    switch (_stage) {
      case _KioskStage.verifying:
        return FilledButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          label: const Text('Verificando identidad…'),
        );
      case _KioskStage.success:
        return FilledButton.icon(
          onPressed: _reiniciar,
          icon: const Icon(Icons.check_circle),
          label: const Text('Siguiente paciente'),
        );
      case _KioskStage.noCita:
      case _KioskStage.unrecognized:
      case _KioskStage.error:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _passToReception,
                icon: const Icon(Icons.support_agent),
                label: const Text('Pase a recepción'),
              ),
            ),
          ],
        );
      case _KioskStage.idle:
        break;
    }
    if (_photo != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _resetPhoto,
              icon: const Icon(Icons.replay),
              label: const Text('Repetir'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => _verifyPhoto(_photo!),
              icon: const Icon(Icons.verified_user),
              label: const Text('Continuar'),
            ),
          ),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: (_initializing || _extraBusy) ? null : _captureNow,
      icon: const Icon(Icons.photo_camera),
      label: Text(_extraBusy ? 'Capturando…' : 'Capturar ahora'),
    );
  }

  Widget _resultadoCard() {
    final (icon, color, bg, titulo, detalle) = _resultadoData();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color, String, String) _resultadoData() {
    final v = _verificacion;
    final nombre = v?.nombre ?? '';
    switch (_stage) {
      case _KioskStage.success:
        final cita = v!.cita;
        return (
          Icons.check_circle,
          AppColors.success,
          AppColors.successBg,
          'Check-in confirmado',
          '$nombre, ya puede pasar a la sala de espera. '
              'Su cita de hoy es a las ${cita.hora}.',
        );
      case _KioskStage.noCita:
        return (
          Icons.event_busy,
          AppColors.warning,
          AppColors.warningBg,
          'Bienvenido, $nombre',
          'Hoy no tiene una cita registrada en el consultorio. '
              'Nuestro personal de recepción podrá ayudarle.',
        );
      case _KioskStage.unrecognized:
        return (
          Icons.face_retouching_off,
          AppColors.warning,
          AppColors.warningBg,
          'No se reconoció su rostro',
          'Asegúrese de estar frente a la cámara con buena iluminación '
              'o pase a recepción para confirmar su turno.',
        );
      case _KioskStage.error:
        return (
          Icons.cloud_off,
          AppColors.danger,
          AppColors.dangerBg,
          'No fue posible confirmar su check-in',
          _resultadoMensaje ?? 'Intente de nuevo en unos momentos o pase a recepción.',
        );
      case _KioskStage.verifying:
      case _KioskStage.idle:
        return (Icons.info, AppColors.info, AppColors.infoBg, '', '');
    }
  }
}