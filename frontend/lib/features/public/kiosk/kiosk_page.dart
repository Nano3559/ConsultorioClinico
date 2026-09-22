import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../data/models/kiosk_verification.dart';
import '../../../services/api_client.dart';
import 'kiosk_camera_service.dart';

/// Modo kiosco del consultorio: pantalla de bienvenida del auto-check-in.
///
/// Flujo (KIO-03 → KIO-09):
/// 1. La tablet muestra "Bienvenido, por favor mire a la cámara".
/// 2. La cámara frontal inicia la vista previa y un conteo automático.
/// 3. Al capturar, se entrega la foto (base64) vía [onPhotoCaptured] para que
///    una etapa posterior la envíe a `POST /api/kiosco/verificar-rostro`.
/// 4. Si no se reconoce el rostro, el kiosco redirige a recepción.
class KioskPage extends StatefulWidget {
  const KioskPage({super.key, this.onPhotoCaptured, this.onFallback});

  /// Recibe la foto capturada (base64) cuando el integrante confirma el check-in.
  final void Function(String base64)? onPhotoCaptured;

  /// Se invoca cuando el paciente elige pasar a recepción.
  final VoidCallback? onFallback;

  @override
  State<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  static const int _countdownFrom = 4;

  final KioskCameraService _camera = KioskCameraService(frontPreference: true);

  bool _initializing = true;
  KioskCameraException? _error;
  Timer? _countdownTimer;
  int _countdown = _countdownFrom;
  bool _extraBusy = false;
  KioskPhoto? _photo;

  // KIO-09: estado de la verificación contra el backend (visión facial).
  bool _verifying = false;
  KioskVerification? _result;
  String? _verifyError;
  final ApiClient _api = ApiClient();

  // KIO-15: confirmación del check-in contra la cita del día.
  bool _confirming = false;
  bool _confirmed = false;
  String? _confirmError;
  String? _horaCheckin;

  // KIO-21: ticket manual cuando el rostro no se reconoce.
  bool _manualSent = false;
  String? _manualTicket;
  String? _manualNombre;
  final _manualFormKey = GlobalKey<FormState>();
  final _manualNombreCtrl = TextEditingController();
  final _manualCiCtrl = TextEditingController();
  final _manualTelCtrl = TextEditingController();

  // KIO-12: auto-retorno a captura para modo kiosco desatendido (tablet).
  Timer? _autoResetTimer;
  int _autoResetIn = 0;

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
      _result = null;
      _verifyError = null;
      _verifying = false;
      _confirming = false;
      _confirmed = false;
      _confirmError = null;
      _horaCheckin = null;
      _manualSent = false;
      _manualTicket = null;
      _manualNombre = null;
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

  void _startCountdown() {
    _stopCountdown();
    if (_photo != null || _error != null || _extraBusy) return;
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
    } on KioskCameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _extraBusy = false;
      });
    }
  }

  void _retry() {
    _stopCountdown();
    _initCamera();
  }

  void _resetPhoto() {
    _cancelAutoReset();
    setState(() {
      _photo = null;
      _result = null;
      _verifyError = null;
      _verifying = false;
      _confirming = false;
      _confirmed = false;
      _confirmError = null;
      _horaCheckin = null;
      _manualSent = false;
      _manualTicket = null;
      _manualNombre = null;
      _countdown = _countdownFrom;
    });
    _manualNombreCtrl.clear();
    _manualCiCtrl.clear();
    _manualTelCtrl.clear();
    _startCountdown();
  }

  void _cancelAutoReset() {
    _autoResetTimer?.cancel();
    _autoResetTimer = null;
    _autoResetIn = 0;
  }

  /// KIO-12: en modo kiosco desatendido la pantalla de resultado vuelve
  /// sola a captura tras [seconds] para el siguiente paciente.
  void _startAutoReset({int seconds = 15}) {
    _cancelAutoReset();
    setState(() => _autoResetIn = seconds);
    _autoResetTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_autoResetIn <= 1) {
        t.cancel();
        _resetPhoto();
        return;
      }
      setState(() => _autoResetIn -= 1);
    });
  }

  /// KIO-09 (17/09): envía la foto en base64 a
  /// `POST /api/kiosco/verificar-rostro` y muestra el resultado
  /// (paciente reconocido + cita del día o mensaje de no reconocido).
  ///
  /// Mantiene compatibilidad con [KioskPage.onPhotoCaptured]: si el padre
  /// inyecta el callback (tests / integración externa), se delega en él;
  /// en caso contrario se llama al backend directamente.
  Future<void> _confirmVerification() async {
    final photo = _photo;
    if (photo == null || _verifying) return;
    final callback = widget.onPhotoCaptured;
    if (callback != null) {
      callback(photo.base64);
      setState(() {
        _photo = null;
        _result = null;
        _verifyError = null;
        _countdown = _countdownFrom;
      });
      _startCountdown();
      return;
    }
    _stopCountdown();
    setState(() {
      _verifying = true;
      _verifyError = null;
      _result = null;
    });
    final res = await _api.verificarRostro(photo.base64);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _confirming = false;
      _confirmed = false;
      _confirmError = null;
      _horaCheckin = null;
      if (res.isSuccess && res.data != null) {
        _result = res.data;
        // El backend devuelve success:false cuando no reconoce el rostro;
        // se conserva el mensaje para mostrar el fallback a recepción.
        if (!res.data!.success) {
          _verifyError = res.data!.message;
        }
      } else {
        _verifyError = res.error ?? 'Sin conexión con el servidor';
      }
    });
    // KIO-12/15: auto-retorno. Si hay cita para confirmar se da más tiempo
    // (60s) para que el paciente pulse "Confirmar"; si es fallo, 20s.
    if (mounted && (_result != null || _verifyError != null)) {
      final esperaConfirmacion =
          _result != null && _result!.tieneCitaHoy && !_confirmed;
      _startAutoReset(seconds: esperaConfirmacion ? 60 : 20);
    }
  }

  /// KIO-15 (21/09): confirma el check-in de la cita del día:
  /// `POST /api/kiosco/confirmar-cita { paciente_id, cita_id }`
  /// -> estado `confirmada` + `confirmada_por_kiosco=true` + `hora_checkin`.
  Future<void> _confirmarCheckin() async {
    final result = _result;
    final cita = result?.cita;
    if (result == null || cita == null || _confirming || _confirmed) return;
    _cancelAutoReset();
    setState(() {
      _confirming = true;
      _confirmError = null;
    });
    final res = await _api.confirmarCitaKiosco(
      pacienteId: result.pacienteId,
      citaId: cita.id,
    );
    if (!mounted) return;
    setState(() {
      _confirming = false;
      if (res.isSuccess) {
        _confirmed = true;
        final data = res.data?['data'];
        if (data is Map<String, dynamic>) {
          _horaCheckin = (data['hora_checkin'] ?? data['horaCheckin'])?.toString();
        }
        _horaCheckin ??= TimeOfDay.now().format(context);
      } else {
        // Si ya estaba confirmada por kiosco, se trata como éxito (idempotente).
        final msg = (res.error ?? '').toLowerCase();
        if (msg.contains('ya fue confirmada')) {
          _confirmed = true;
          _horaCheckin ??= TimeOfDay.now().format(context);
        } else {
          _confirmError = res.error ?? 'No se pudo confirmar la cita';
        }
      }
    });
    if (mounted) _startAutoReset(seconds: 15);
  }

  void _passToReception() {
    widget.onFallback?.call();
    _showManualFallback();
  }

  /// KIO-21 (23/09): fallback manual — si el rostro no se reconoce, el
  /// paciente deja nombre + CI (+ teléfono opcional) y recepción lo atiende.
  /// Genera un ticket local `KIO-YYYYMMDD-HHMMSS` para el llamado en sala.
  Future<void> _showManualFallback() async {
    _cancelAutoReset();
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _manualFallbackSheet(ctx),
    );
    if (!mounted) return;
    if (sent == true) {
      // Ticket creado: se muestra confirmación y auto-retorno en 20s.
      _startAutoReset(seconds: 20);
    } else if (_result == null && _verifyError == null && !_manualSent) {
      // Cerró sin enviar: retoma el conteo de captura.
      _startCountdown();
    }
  }

  Widget _manualFallbackSheet(BuildContext ctx) {
    final bottom = MediaQuery.of(ctx).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _manualFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.support_agent, color: AppColors.primaryDark),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Atención manual en recepción',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Deje sus datos y lo llamaremos por su nombre. No necesita hacer fila en el kiosco.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _manualNombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre y apellido *',
                    hintText: 'Ej. María Pérez',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final err = AppValidators.required(v, label: 'El nombre');
                    if (err != null) return err;
                    if (v!.trim().length < 3) return 'Escriba su nombre completo';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _manualCiCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Cédula / CI *',
                    hintText: 'Ej. 1234567',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: AppValidators.ci,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _manualTelCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    hintText: 'Ej. 0981122334',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return AppValidators.phone(v);
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _submitManual(ctx),
                    icon: const Icon(Icons.send_outlined, size: 20),
                    label: const Text('Solicitar atención', style: TextStyle(fontSize: 17)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Volver al kiosco'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitManual(BuildContext sheetCtx) {
    if (!(_manualFormKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now();
    final ticket =
        'KIO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    Navigator.of(sheetCtx).pop(true);
    setState(() {
      _manualSent = true;
      _manualTicket = ticket;
      _manualNombre = _manualNombreCtrl.text.trim();
      _photo = null;
      _result = null;
      _verifyError = null;
      _verifying = false;
    });
  }

  @override
  void dispose() {
    _stopCountdown();
    _cancelAutoReset();
    _camera.dispose();
    _api.dispose();
    _manualNombreCtrl.dispose();
    _manualCiCtrl.dispose();
    _manualTelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 940;
    // KIO-18: tablet = lado corto >= 600 (portrait 600x960, landscape 960x600).
    final isTablet = size.shortestSide >= 600;
    final activeStep = _confirmed
        ? 3
        : (_verifying || _confirming || _result != null ? 2 : 1);
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: isWide
              ? Row(
                  children: [
                    Expanded(flex: isTablet ? 5 : 5, child: _brandPanel(activeStep: activeStep, isTablet: isTablet)),
                    Expanded(flex: isTablet ? 7 : 6, child: _kioskColumn(wide: true, isTablet: isTablet)),
                  ],
                )
              : Column(
                  children: [
                    _topBar(isTablet: isTablet),
                    Expanded(child: _kioskColumn(wide: false, isTablet: isTablet)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _topBar({bool isTablet = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isTablet ? 16 : 12, 8, 0),
      child: Row(
        children: [
          _brandMark(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ConsultorioClínico',
                  style: TextStyle(
                    color: AppColors.dark,
                    fontSize: isTablet ? 19 : 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Auto check-in · Tablet recepción',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Salir del kiosco',
            child: TextButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.close, size: 20),
              label: const Text('Salir'),
              style: TextButton.styleFrom(
                minimumSize: const Size(88, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // KIO-18: panel de marca modo tablet — pasos con estado activo,
  // fecha legible a distancia, insignia "Tablet" y nota de privacidad.
  Widget _brandPanel({required int activeStep, bool isTablet = true}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradientSidebar,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 44 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                _brandMark(inverse: true),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tablet_mac,
                          color: Color(0xFF99F6E4), size: 16),
                      SizedBox(width: 6),
                      Text('Tablet',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Bienvenido',
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 46 : 42,
                fontWeight: FontWeight.w800,
                height: 1.1,
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
            _stepRow(icon: Icons.face_retouching_natural, step: '1', label: 'Mire a la cámara', active: activeStep == 1, done: activeStep > 1),
            const SizedBox(height: 12),
            _stepRow(icon: Icons.verified_user_outlined, step: '2', label: 'Confirme su cita', active: activeStep == 2, done: activeStep > 2),
            const SizedBox(height: 12),
            _stepRow(icon: Icons.event_seat_outlined, step: '3', label: 'Pase a sala de espera', active: activeStep == 3, done: false),
            const SizedBox(height: 32),
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
                      'Sus datos biométricos solo se usan para su check-in '
                      'del día y nunca salen del consultorio sin su permiso.',
                      style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Modo tablet · Recepción · Toque con el dedo, sin teclado',
              style: TextStyle(color: Color(0xFF99F6E4), fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  // KIO-18: fila de paso con estado (activo = resaltado, hecho = check).
  Widget _stepRow({required IconData icon, required String step, required String label, bool active = false, bool done = false}) {
    final bg = done
        ? Colors.white
        : active
            ? AppColors.primaryLight
            : Colors.white.withValues(alpha: 0.14);
    final fg = done || active ? AppColors.primaryDark : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Icon(done ? Icons.check : icon, color: fg, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            step,
            style: TextStyle(
              color: active
                  ? Colors.white
                  : const Color(0xFF99F6E4).withValues(alpha: 0.7),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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

  Widget _kioskColumn({required bool wide, bool isTablet = false}) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(wide ? 28 : 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 560 : (isTablet ? 520 : 460)),
          child: FadeSlide(
            child: _panel(wide, isTablet: isTablet),
          ),
        ),
      ),
    );
  }

  Widget _panel(bool wide, {bool isTablet = false}) {
    // KIO-21: ticket manual tiene prioridad (recepción lo llamará).
    if (_manualSent && _manualTicket != null) {
      return _manualSuccessScreen();
    }
    // KIO-12: pantallas dedicadas de éxito / fallo (legibles a 1m en tablet).
    if (!_verifying && _result != null && _result!.reconocido) {
      return _successScreen(_result!);
    }
    final failureMsg = !_verifying
        ? (_verifyError ??
            ((_result != null && !_result!.reconocido)
                ? (_result!.message.isEmpty
                    ? 'Rostro no reconocido. Pase a recepción.'
                    : _result!.message)
                : null))
        : null;
    if (failureMsg != null) {
      return _failureScreen(failureMsg);
    }
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
        _viewfinder(isTablet: isTablet),
        const SizedBox(height: 18),
        if (wide) ...[
          Text(
            'Bienvenido, por favor mire a la cámara',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: isTablet ? 26 : 24, fontWeight: FontWeight.w800, color: AppColors.dark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toque Capturar, mire al frente y confirme su cita.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
        ],
        _controls(),
        const SizedBox(height: 14),
        // KIO-09: estado de verificación en curso.
        if (_verifying) _verifyingCard(),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _passToReception,
              icon: const Icon(Icons.support_agent, size: 18),
              label: const Text('¿Problemas? Pase a recepción'),
            ),
          ],
        ),
      ],
    );
  }

  // ---- KIO-12 + KIO-15: pantalla de éxito ----------------------------------
  // Flujo: reconocido -> muestra cita del día + "Confirmar mi llegada"
  //   -> POST /kiosco/confirmar-cita -> "Check-in confirmado, pase a sala".
  // Alto contraste, táctil grande, auto-retorno para el siguiente paciente.
  Widget _successScreen(KioskVerification result) {
    final cita = result.cita;
    final confirmado = _confirmed;
    return Semantics(
      label: confirmado
          ? 'Check-in confirmado, pase a sala de espera'
          : 'Rostro reconocido, confirme su cita',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: confirmado ? AppColors.success : AppColors.primaryDark,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    confirmado ? Icons.check : Icons.verified_user,
                    color: confirmado ? AppColors.success : AppColors.primaryDark,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  confirmado ? '¡Check-in confirmado!' : '¡Hola de nuevo!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  confirmado
                      ? 'Hola, ${result.nombre ?? 'paciente'}\nPase a sala de espera${_horaCheckin != null ? ' · $_horaCheckin' : ''}'
                      : 'Hola, ${result.nombre ?? 'paciente'}\n¿Es esta su cita de hoy?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (cita != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _citaRow(Icons.calendar_today, 'Fecha', cita.fecha),
                  const SizedBox(height: 8),
                  _citaRow(Icons.access_time, 'Hora', cita.hora),
                  if (cita.medicoNombre != null) ...[
                    const SizedBox(height: 8),
                    _citaRow(Icons.person_outline, 'Médico', cita.medicoNombre!),
                  ],
                  if (cita.especialidad != null) ...[
                    const SizedBox(height: 8),
                    _citaRow(Icons.medical_services_outlined, 'Especialidad',
                        cita.especialidad!),
                  ],
                  if (result.confianza != null) ...[
                    const SizedBox(height: 8),
                    _citaRow(Icons.face_retouching_natural, 'Confianza',
                        '${result.confianza}'),
                  ],
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35)),
              ),
              child: const Text(
                'Rostro reconocido, pero no se encontró cita para hoy. '
                'Pase a recepción para agendar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          if (_confirmError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(_confirmError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 14),
          if (cita != null && !confirmado)
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: _confirming ? null : _confirmarCheckin,
                icon: _confirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.done_all, size: 22),
                label: Text(
                  _confirming ? 'Confirmando…' : 'Sí, soy yo — Confirmar',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
          if (cita != null && !confirmado) const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: cita != null && !confirmado
                ? OutlinedButton.icon(
                    onPressed: _confirming ? null : _resetPhoto,
                    icon: const Icon(Icons.close),
                    label: Text(
                      _autoResetIn > 0
                          ? 'No soy yo ($_autoResetIn s)'
                          : 'No soy yo',
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _resetPhoto,
                    icon: const Icon(Icons.done_all, size: 22),
                    label: Text(
                      _autoResetIn > 0
                          ? 'Finalizar ($_autoResetIn s)'
                          : 'Finalizar',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Volvemos al inicio automáticamente para el siguiente paciente.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _citaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryDark, size: 20),
        const SizedBox(width: 10),
        Text('$label: ',
            style: const TextStyle(color: AppColors.muted, fontSize: 14)),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
  }

  // ---- KIO-12: pantalla de fallo --------------------------------------------
  // "Por favor, pase a recepción" — sin culpar al usuario, con reintento
  // grande y salida clara. Cumple KIO-21 parcial (fallback manual básico).
  Widget _failureScreen(String message) {
    final isConnection = message.toLowerCase().contains('conexi') ||
        message.toLowerCase().contains('servidor') ||
        message.toLowerCase().contains('visi');
    return Semantics(
      label: 'No se reconoció el rostro, pase a recepción',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.support_agent,
                      color: AppColors.warning, size: 44),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Pase a recepción',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  isConnection
                      ? 'No pudimos verificar su identidad en este momento.\nNuestro personal lo atenderá manualmente.'
                      : message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFCBD5E1), fontSize: 15, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _resetPhoto,
              icon: const Icon(Icons.refresh, size: 22),
              label: Text(
                _autoResetIn > 0
                    ? 'Reintentar ($_autoResetIn s)'
                    : 'Reintentar',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _showManualFallback,
              icon: const Icon(Icons.edit_note, size: 22),
              label: const Text('Dejar mis datos',
                  style: TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _resetPhoto,
              icon: const Icon(Icons.refresh),
              label: Text('Reintentar cámara${_autoResetIn > 0 ? ' ($_autoResetIn s)' : ''}',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // KIO-21: confirmación de ticket manual (recepción lo llamará por nombre).
  Widget _manualSuccessScreen() {
    return Semantics(
      label: 'Ticket manual creado, recepción lo atenderá',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.confirmation_number_outlined,
                      color: AppColors.primaryDark, size: 44),
                ),
                const SizedBox(height: 14),
                const Text(
                  '¡Ticket creado!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hola, ${_manualNombre ?? 'paciente'}\nTome asiento, recepción lo llamará',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number,
                    color: AppColors.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _manualTicket ?? '',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _resetPhoto,
              icon: const Icon(Icons.done_all, size: 22),
              label: Text(
                _autoResetIn > 0
                    ? 'Finalizar ($_autoResetIn s)'
                    : 'Finalizar',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // KIO-18: visor más grande en tablet (380px) para encuadre a 50-80cm.
  Widget _viewfinder({bool isTablet = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = isTablet ? 400.0 : 340.0;
        final side = constraints.maxWidth >= 380 ? maxSide : constraints.maxWidth;
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

  /// Guía facial: óvalo teal que indica dónde acomodar el rostro. La animación
  /// suave invita a mirar a la cámara mientras transcurre el conteo.
  /// KIO-18: respeta "reducir movimiento" (accesibilidad tablet).
  Widget _pulseFaceGuide(double side) {
    final inner = side * 0.46;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    Widget guide = Container(
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
          child: reduceMotion
              ? const Icon(Icons.face_retouching_natural,
                  color: AppColors.primaryLight, size: 48)
              : Lottie.asset('assets/lottie/Heartbeat Lottie Animation.json'),
        ),
      ),
    );
    if (reduceMotion) {
      return IgnorePointer(child: Center(child: guide));
    }
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1.0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, t, child) => Transform.scale(
            scale: t,
            child: guide,
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
    if (_verifying) {
      return (Icons.face_retouching_natural, 'Verificando identidad…', AppColors.info, AppColors.infoBg);
    }
    if (_result != null && _result!.reconocido) {
      return (Icons.check_circle, 'Rostro reconocido', AppColors.success, AppColors.successBg);
    }
    if (_verifyError != null || _error != null) {
      final msg = _verifyError ?? _error!.message;
      return (Icons.error_outline, msg, AppColors.danger, AppColors.dangerBg);
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
    if (_verifying) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
        ),
        label: const Text('Verificando identidad…'),
      );
    }
    if (_result != null || _verifyError != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _resetPhoto,
              icon: const Icon(Icons.replay),
              label: const Text('Nuevo check-in'),
            ),
          ),
        ],
      );
    }
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
              onPressed: _confirmVerification,
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

  // ---- KIO-09: tarjeta de verificación en curso ---------------------------
  Widget _verifyingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Comparando su rostro con la base de pacientes…',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}