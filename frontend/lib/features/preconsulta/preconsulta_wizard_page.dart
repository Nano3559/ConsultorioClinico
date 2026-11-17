import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../data/models/appointment.dart';
import '../../data/models/patient.dart';
import '../../data/models/preconsulta.dart';
import '../../data/models/user.dart';
import '../../state/auth_provider.dart';
import '../../state/clinic_provider.dart';
import '../../state/preconsulta_provider.dart';
import 'capture/captura_preconsulta.dart';
import 'widgets/preconsulta_ui.dart';

/// Asistente de PreConsulta IA: consentimiento -> paciente -> captura ->
/// cuestionario -> resultado explicable.
///
/// No modifica el kiosco existente: reutiliza la misma idea de cámara directa,
/// pero aquí el objetivo es una secuencia corta para estimar signos y
/// priorizar la atención, no verificar identidad.
class PreconsultaWizardPage extends StatefulWidget {
  const PreconsultaWizardPage({
    super.key,
    this.pacienteIdInicial,
    this.citaIdInicial,
  });

  final int? pacienteIdInicial;
  final int? citaIdInicial;

  @override
  State<PreconsultaWizardPage> createState() => _PreconsultaWizardPageState();
}

class _PreconsultaWizardPageState extends State<PreconsultaWizardPage> {
  static const List<String> _titulos = [
    'Consentimiento informado',
    'Paciente y contexto',
    'Captura facial',
    'Cuestionario clínico',
    'Resultado del triage',
  ];

  int _paso = 0;
  int? _pacienteId;
  Patient? _paciente;
  int? _citaId;

  bool _aceptaConsentimiento = false;
  bool _cargandoInicial = true;
  String? _errorInicial;

  int? _preconsultaId;
  bool _creando = false;
  String? _errorContexto;

  CamaraPreconsulta? _camara;
  bool _camaraLista = false;
  bool _iniciandoCamara = false;
  String? _errorCamara;
  bool _capturando = false;
  bool _analisisOk = false;
  int _cuentaAtras = 0;
  double _progresoCaptura = 0;
  String? _errorCaptura;

  final Map<String, dynamic> _respuestas = {};
  final Map<String, TextEditingController> _controles = {};
  final Map<String, String> _erroresCampos = {};
  bool _guardandoFinal = false;
  String? _errorFinal;

  bool get _esPaciente {
    final auth = context.read<AuthProvider>();
    return auth.role == UserRole.paciente;
  }

  String get _canal {
    if (!_esPaciente) return 'recepcion';
    return kIsWeb ? 'web' : 'android';
  }

  @override
  void initState() {
    super.initState();
    _pacienteId = widget.pacienteIdInicial;
    _citaId = widget.citaIdInicial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarInicial());
  }

  Future<void> _cargarInicial() async {
    final prov = context.read<PreconsultaProvider>();
    final auth = context.read<AuthProvider>();
    final clinic = context.read<ClinicProvider>();
    if (auth.role != UserRole.paciente && clinic.patients.isEmpty) {
      clinic.loadAll();
    }
    final ok = await prov.cargarCatalogo(pacienteId: _pacienteId);
    if (!mounted) return;
    setState(() {
      _cargandoInicial = false;
      if (!ok) {
        _errorInicial = prov.error ?? 'No se pudo cargar la preconsulta.';
      } else if (auth.role == UserRole.paciente) {
        _pacienteId = prov.catalogo?.pacienteId ?? _pacienteId;
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controles.values) {
      c.dispose();
    }
    _camara?.liberar();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Navegación entre pasos
  // --------------------------------------------------------------------------
  void _siguiente() {
    if (_paso < 4) setState(() => _paso += 1);
  }

  void _atras() {
    if (_paso == 0) {
      _salir();
      return;
    }
    if (_paso == 2) {
      _liberarCamara();
    }
    setState(() => _paso -= 1);
  }

  void _salir() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app');
    }
  }

  Future<void> _continuarDesdeContexto() async {
    final prov = context.read<PreconsultaProvider>();
    final catalogo = prov.catalogo;
    if (catalogo == null) return;
    if (_pacienteId == null) {
      setState(() => _errorContexto =
          'Selecciona el paciente al que pertenece esta preconsulta.');
      return;
    }
    setState(() {
      _creando = true;
      _errorContexto = null;
    });
    final id = await prov.crear(
      pacienteId: _pacienteId!,
      consentimientoVersion: catalogo.version,
      citaId: _citaId,
      canal: _canal,
    );
    if (!mounted) return;
    setState(() {
      _creando = false;
      if (id == null) {
        _errorContexto = prov.error ?? 'No se pudo crear la preconsulta.';
      } else {
        _preconsultaId = id;
        _paso = 2;
      }
    });
  }

  // --------------------------------------------------------------------------
  // Cámara
  // --------------------------------------------------------------------------
  Future<void> _iniciarCamara() async {
    if (_camaraLista || _iniciandoCamara) return;
    setState(() {
      _iniciandoCamara = true;
      _errorCamara = null;
    });
    final camara = _camara ??= CamaraPreconsulta();
    try {
      await camara.iniciar();
      if (!mounted) return;
      setState(() => _camaraLista = true);
    } on CapturaException catch (e) {
      if (!mounted) return;
      setState(() {
        _camaraLista = false;
        _errorCamara = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _camaraLista = false;
        _errorCamara = 'No se pudo abrir la cámara en este dispositivo.';
      });
    } finally {
      if (mounted) setState(() => _iniciandoCamara = false);
    }
  }

  Future<void> _liberarCamara() async {
    final camara = _camara;
    _camara = null;
    _camaraLista = false;
    if (camara != null) {
      await camara.liberar();
    }
  }

  Future<void> _capturarYAnalizar() async {
    final id = _preconsultaId;
    if (id == null || _capturando) return;
    if (!_camaraLista) {
      await _iniciarCamara();
      if (!mounted || !_camaraLista) return;
    }
    setState(() {
      _capturando = true;
      _progresoCaptura = 0;
      _errorCaptura = null;
      _cuentaAtras = 3;
    });
    try {
      for (var i = 3; i > 0; i--) {
        if (!mounted) return;
        setState(() => _cuentaAtras = i);
        await Future.delayed(const Duration(milliseconds: 750));
      }
      if (!mounted) return;
      setState(() => _cuentaAtras = 0);

      final camara = _camara;
      if (camara == null) {
        throw const CapturaException(
          CapturaErrorKind.unknown,
          'La cámara se cerró antes de capturar.',
        );
      }
      final resultado = await camara.capturar(
        duracion: const Duration(seconds: 20),
        progreso: (p) {
          if (mounted) setState(() => _progresoCaptura = p);
        },
      );
      if (!mounted) return;
      setState(() => _progresoCaptura = 1);
      await _liberarCamara();
      if (!mounted) return;

      final prov = context.read<PreconsultaProvider>();
      final ok = await prov.analizar(
        id: id,
        frames: resultado.frames,
        video: resultado.video,
        fps: resultado.fps > 0 ? resultado.fps : null,
        duracionSeg: resultado.duracionSeg,
        canal: _canal,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _errorCaptura =
            prov.error ?? 'No se pudo completar el análisis facial.');
        return;
      }
      setState(() {
        _analisisOk = true;
        _paso = 3;
      });
    } on CapturaException catch (e) {
      if (!mounted) return;
      setState(() => _errorCaptura = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorCaptura =
          'La captura falló. Puedes intentarlo de nuevo o continuar sin cámara.');
    } finally {
      if (mounted) setState(() => _capturando = false);
    }
  }

  Future<void> _omitirCaptura() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Continuar sin cámara'),
        content: const Text(
          'El triage se calculará solo con el cuestionario. La estimación de '
          'pulso, respiración y expresión facial no estará disponible y el '
          'resultado tendrá menor confianza.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuar sin cámara'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _liberarCamara();
    if (!mounted) return;
    setState(() {
      _analisisOk = false;
      _paso = 3;
    });
  }

  // --------------------------------------------------------------------------
  // Cuestionario
  // --------------------------------------------------------------------------
  Map<String, String> _validarCuestionario(PreconsultaCatalogo catalogo) {
    final errores = <String, String>{};
    for (final p in catalogo.preguntas) {
      if (!p.requerida) continue;
      final valor = _respuestas[p.codigo];
      final vacio = valor == null ||
          (valor is String && valor.trim().isEmpty) ||
          (valor is List && valor.isEmpty);
      if (vacio) errores[p.codigo] = 'Esta pregunta es obligatoria.';
    }
    return errores;
  }

  Future<void> _finalizarCuestionario() async {
    final prov = context.read<PreconsultaProvider>();
    final catalogo = prov.catalogo;
    final id = _preconsultaId;
    if (catalogo == null || id == null) return;
    final errores = _validarCuestionario(catalogo);
    if (errores.isNotEmpty) {
      setState(() {
        _erroresCampos
          ..clear()
          ..addAll(errores);
        _errorFinal =
            'Faltan ${errores.length} pregunta(s) obligatoria(s) por responder.';
      });
      return;
    }
    setState(() {
      _guardandoFinal = true;
      _errorFinal = null;
    });
    final respuestas = _respuestas.entries
        .where((e) => e.value != null)
        .map((e) => {'codigo': e.key, 'valor': e.value})
        .toList();
    final ok = _analisisOk
        ? await prov.guardarRespuestas(id: id, respuestas: respuestas)
        : await prov.finalizarSinCaptura(id: id, respuestas: respuestas);
    if (!mounted) return;
    setState(() {
      _guardandoFinal = false;
      if (!ok) {
        _errorFinal = prov.error ?? 'No se pudo guardar el cuestionario.';
      } else {
        _erroresCampos.clear();
        _paso = 4;
      }
    });
  }

  void _reiniciar() {
    for (final c in _controles.values) {
      c.dispose();
    }
    _controles.clear();
    _respuestas.clear();
    _erroresCampos.clear();
    setState(() {
      _paso = 0;
      _aceptaConsentimiento = false;
      _preconsultaId = null;
      _paciente = null;
      _citaId = null;
      _analisisOk = false;
      _errorCaptura = null;
      _errorFinal = null;
      _errorContexto = null;
      _progresoCaptura = 0;
    });
    context.read<PreconsultaProvider>().limpiarDetalle();
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PreconsultaProvider>();
    final ancho = MediaQuery.sizeOf(context).width;
    final escritorio = ancho >= 1100;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _BarraSuperior(paso: _paso, onSalir: _salir),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    escritorio ? 32 : 16,
                    8,
                    escritorio ? 32 : 16,
                    32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: escritorio
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 300,
                                  child: _PanelLateral(
                                    paso: _paso,
                                    titulos: _titulos,
                                    paciente: _paciente,
                                    esPaciente: _esPaciente,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(child: _contenido(prov)),
                              ],
                            )
                          : _contenido(prov),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido(PreconsultaProvider prov) {
    return PreconsultaCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CabeceraPaso(
            paso: _paso,
            total: _titulos.length,
            titulo: _titulos[_paso],
            onAtras: _atras,
          ),
          if (prov.error != null && _paso != 4)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: _Mensaje(
                texto: prov.error!,
                color: AppColors.danger,
                icono: Icons.error_outline,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              child: KeyedSubtree(
                key: ValueKey(_paso),
                child: _cuerpoPaso(prov),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuerpoPaso(PreconsultaProvider prov) {
    switch (_paso) {
      case 0:
        return _pasoConsentimiento(prov);
      case 1:
        return _pasoPaciente(prov);
      case 2:
        return _pasoCaptura(prov);
      case 3:
        return _pasoCuestionario(prov);
      default:
        return _pasoResultado(prov);
    }
  }

  // --------------------------------------------------------------------------
  // Paso 0: consentimiento
  // --------------------------------------------------------------------------
  Widget _pasoConsentimiento(PreconsultaProvider prov) {
    if (_cargandoInicial) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final catalogo = prov.catalogo;
    if (catalogo == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            _Mensaje(
              texto: _errorInicial ??
                  'No se pudo cargar el consentimiento. Verifica tu conexión.',
              color: AppColors.danger,
              icono: Icons.cloud_off_outlined,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _cargandoInicial = true);
                _cargarInicial();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final consentimiento = catalogo.consentimiento;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroPaso(
          icono: Icons.privacy_tip_outlined,
          titulo: consentimiento.titulo.isEmpty
              ? 'Antes de comenzar'
              : consentimiento.titulo,
          subtitulo: consentimiento.subtitulo,
          badge: 'Versión ${consentimiento.version}',
        ),
        const SizedBox(height: 16),
        if (consentimiento.resumen.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              consentimiento.resumen,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (catalogo.yaAceptado) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.verified_outlined,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ya aceptaste este consentimiento anteriormente'
                  '${catalogo.aceptadoEn != null ? ' (${fechaCorta(catalogo.aceptadoEn)})' : ''}. '
                  'Se registrará una nueva aceptación para esta preconsulta.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        for (final parrafo in consentimiento.parrafos)
          _ParrafoConsentimiento(titulo: parrafo.titulo, texto: parrafo.texto),
        if (consentimiento.datos.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ListaConsentimiento(
            titulo: 'Datos que se procesan',
            icono: Icons.dataset_outlined,
            items: consentimiento.datos,
          ),
        ],
        if (consentimiento.derechos.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ListaConsentimiento(
            titulo: 'Tus derechos',
            icono: Icons.gavel_outlined,
            items: consentimiento.derechos,
          ),
        ],
        if (consentimiento.retencion.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline,
                    size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    consentimiento.retencion,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const AvisoClinico(),
        const SizedBox(height: 16),
        // Material transparente: el CheckboxListTile pinta su tinta sobre el
        // Material más cercano; sin esto, la tarjeta blanca del paso la oculta
        // y Flutter lanza "ListTile background color or ink splashes may be
        // invisible" en modo debug.
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            value: _aceptaConsentimiento,
            onChanged: (v) =>
                setState(() => _aceptaConsentimiento = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Acepto el consentimiento informado y el procesamiento de mi '
              'rostro para estimar signos y priorizar la atención.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: consentimiento.contacto.isEmpty
                ? null
                : Text(
                    consentimiento.contacto,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _aceptaConsentimiento ? _siguiente : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Aceptar y continuar'),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Paso 1: paciente y contexto
  // --------------------------------------------------------------------------
  Widget _pasoPaciente(PreconsultaProvider prov) {
    final clinic = context.watch<ClinicProvider>();
    final auth = context.watch<AuthProvider>();
    final esPaciente = auth.role == UserRole.paciente;
    Patient? paciente = _paciente;
    if (paciente == null && esPaciente && _pacienteId != null) {
      for (final p in clinic.patients) {
        if (p.id == '$_pacienteId') {
          paciente = p;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroPaso(
          icono: Icons.person_search_outlined,
          titulo: esPaciente ? 'Tus datos' : 'Paciente y contexto',
          subtitulo: esPaciente
              ? 'Revisa que tus datos sean correctos antes de continuar.'
              : 'Selecciona a quién se realizará la preconsulta y, si aplica, la cita que la origina.',
        ),
        const SizedBox(height: 18),
        if (esPaciente)
          _TarjetaPaciente(
            nombre: paciente?.fullName ??
                auth.currentUser?.name ??
                'Paciente',
            cedula: paciente?.ci ?? '',
            edad: paciente == null ? null : _edad(paciente.birthDate),
          )
        else ...[
          _SelectorPaciente(
            paciente: _paciente,
            onSeleccionar: () => _abrirSelectorPaciente(clinic.patients),
            onLimpiar: () => setState(() {
              _paciente = null;
              _pacienteId = null;
              _citaId = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_paciente != null)
            _SelectorCita(
              key: ValueKey(_paciente!.id),
              citas: clinic
                  .appointmentsOfPatient(_paciente!.id)
                  .where((a) =>
                      !a.date.isBefore(DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day)) &&
                      a.status != AppointmentStatus.cancelada &&
                      a.status != AppointmentStatus.noAsistio)
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date)),
              citaId: _citaId,
              onCambiar: (id) => setState(() => _citaId = id),
              nombreMedico: clinic.doctorName,
            ),
        ],
        const SizedBox(height: 16),
        if (_errorContexto != null)
          _Mensaje(
            texto: _errorContexto!,
            color: AppColors.danger,
            icono: Icons.error_outline,
          ),
        const SizedBox(height: 16),
        const AvisoClinico(compact: true),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _creando ? null : _atras,
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _creando ? null : _continuarDesdeContexto,
                icon: _creando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.videocam_outlined),
                label: Text(_creando ? 'Preparando…' : 'Continuar a la captura'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _abrirSelectorPaciente(List<Patient> pacientes) async {
    final seleccionado = await showModalBottomSheet<Patient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PacientePicker(pacientes: pacientes),
    );
    if (seleccionado == null || !mounted) return;
    setState(() {
      _paciente = seleccionado;
      _pacienteId = int.tryParse(seleccionado.id);
      _citaId = null;
    });
  }

  // --------------------------------------------------------------------------
  // Paso 2: captura
  // --------------------------------------------------------------------------
  Widget _pasoCaptura(PreconsultaProvider prov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroPaso(
          icono: Icons.face_retouching_natural_outlined,
          titulo: 'Captura facial',
          subtitulo:
              'Mira de frente a la cámara, con buena luz y sin moverte. Duración aproximada: 20 segundos.',
        ),
        const SizedBox(height: 16),
        const _InstruccionesCaptura(),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: const Color(0xFF0B3B37),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_camaraLista && _camara != null)
                    _camara!.vistaPrevia()
                  else if (_iniciandoCamara)
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text('Abriendo cámara…',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    )
                  else if (_errorCamara != null)
                    _CamaraNoDisponible(mensaje: _errorCamara!)
                  else
                    _CamaraInvitacion(
                      onActivar: _iniciarCamara,
                      deshabilitado: _capturando,
                    ),
                  // Guía de encuadre.
                  if (_camaraLista)
                    IgnorePointer(
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.52,
                          heightFactor: 0.78,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_cuentaAtras > 0)
                    Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Text(
                        '$_cuentaAtras',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 84,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  if (_capturando && _cuentaAtras == 0)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: _progresoCaptura,
                              minHeight: 8,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryLight),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Capturando… ${(_progresoCaptura * 100).round()}%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_errorCaptura != null) ...[
          const SizedBox(height: 14),
          _Mensaje(
            texto: _errorCaptura!,
            color: AppColors.danger,
            icono: Icons.warning_amber_outlined,
          ),
        ],
        const SizedBox(height: 16),
        const AvisoClinico(compact: true),
        const SizedBox(height: 16),
        if (_errorCaptura != null)
          FilledButton.icon(
            onPressed: _capturando ? null : _capturarYAnalizar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar análisis'),
          )
        else
          FilledButton.icon(
            onPressed: _capturando || !_camaraLista ? null : _capturarYAnalizar,
            icon: _capturando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(
              _capturando ? 'Analizando…' : 'Iniciar captura y análisis',
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _capturando ? null : _atras,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Atrás'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _capturando ? null : _omitirCaptura,
                icon: const Icon(Icons.skip_next_outlined, size: 18),
                label: const Text('Continuar sin cámara'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Paso 3: cuestionario
  // --------------------------------------------------------------------------
  Widget _pasoCuestionario(PreconsultaProvider prov) {
    final catalogo = prov.catalogo;
    if (catalogo == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final respondidas = _respuestas.values
        .where((v) =>
            v != null &&
            !(v is String && v.trim().isEmpty) &&
            !(v is List && v.isEmpty))
        .length;
    final requeridas = catalogo.preguntas.where((p) => p.requerida).toList();
    final obligatoriasRespondidas = requeridas.where((p) {
      final v = _respuestas[p.codigo];
      return v != null &&
          !(v is String && v.trim().isEmpty) &&
          !(v is List && v.isEmpty);
    }).length;
    final total = requeridas.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroPaso(
          icono: Icons.assignment_outlined,
          titulo: 'Cuestionario clínico',
          subtitulo:
              'Responde con calma. Estas respuestas se combinan con la captura para explicar el nivel de prioridad.',
          badge: '$respondidas respuestas',
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : obligatoriasRespondidas / total,
            minHeight: 7,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Obligatorias: $obligatoriasRespondidas de $total',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        for (final seccion in catalogo.secciones) ...[
          _SeccionCuestionario(
            seccion: seccion,
            preguntas: catalogo.preguntasDe(seccion.clave),
            respuestas: _respuestas,
            errores: _erroresCampos,
            controlPara: _controlPara,
            onCambio: (codigo, valor) {
              setState(() {
                _respuestas[codigo] = valor;
                _erroresCampos.remove(codigo);
                _errorFinal = null;
              });
            },
          ),
          const SizedBox(height: 14),
        ],
        if (_errorFinal != null)
          _Mensaje(
            texto: _errorFinal!,
            color: AppColors.danger,
            icono: Icons.error_outline,
          ),
        const SizedBox(height: 8),
        const AvisoClinico(compact: true),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _guardandoFinal ? null : _atras,
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _guardandoFinal ? null : _finalizarCuestionario,
                icon: _guardandoFinal
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _guardandoFinal
                      ? 'Calculando triage…'
                      : 'Finalizar y ver resultado',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextEditingController _controlPara(PreconsultaPregunta pregunta) {
    return _controles.putIfAbsent(pregunta.codigo, () {
      final c = TextEditingController();
      c.addListener(() {
        _respuestas[pregunta.codigo] = c.text;
      });
      if (_respuestas[pregunta.codigo] is String) {
        c.text = _respuestas[pregunta.codigo] as String;
      }
      return c;
    });
  }

  // --------------------------------------------------------------------------
  // Paso 4: resultado
  // --------------------------------------------------------------------------
  Widget _pasoResultado(PreconsultaProvider prov) {
    final detalle = prov.detalle;
    final triage = detalle?.triage;
    final nivel = triage?.nivelEfectivo;
    final color = nivelColor(nivel);
    final motivosOrdenados = <MotivoTriage>[
      ...(triage?.motivos ?? const <MotivoTriage>[]),
    ]..sort((a, b) => b.peso.compareTo(a.peso));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.14),
                color.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      nivel?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Text(
                      'NIVEL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (triage?.nivelEtiqueta?.isNotEmpty ?? false)
                          ? triage!.nivelEtiqueta!
                          : nivelEtiqueta(nivel),
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      triage?.resumen.isNotEmpty == true
                          ? triage!.resumen
                          : 'Triaje calculado. Confirma el nivel con el personal clínico.',
                      style: const TextStyle(
                          color: AppColors.dark, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MiniChip(
                          icono: Icons.timer_outlined,
                          texto: nivelTiempo(nivel),
                          color: color,
                        ),
                        _MiniChip(
                          icono: Icons.insights_outlined,
                          texto:
                              'Confianza ${porcentaje(triage?.confianza)}',
                          color: AppColors.muted,
                        ),
                        if (triage?.revisado == true)
                          const _MiniChip(
                            icono: Icons.verified_outlined,
                            texto: 'Revisado por personal',
                            color: AppColors.success,
                          )
                        else
                          const _MiniChip(
                            icono: Icons.rate_review_outlined,
                            texto: 'Requiere revisión humana',
                            color: AppColors.info,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (triage != null && triage.banderas.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final bandera in triage.banderas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Mensaje(
                texto: bandera.texto,
                color: bandera.critica ? AppColors.danger : AppColors.warning,
                icono: bandera.critica
                    ? Icons.priority_high
                    : Icons.flag_outlined,
              ),
            ),
        ],
        const SizedBox(height: 18),
        SeccionTitulo(
          icono: Icons.monitor_heart_outlined,
          titulo: 'Signos estimados por cámara',
          subtitulo: detalle?.captura.rostroDetectado == true
              ? 'Estimación óptica (rPPG): no sustituye un oxímetro ni un tensiómetro.'
              : 'No se detectó rostro suficiente. Solo se usó el cuestionario.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth >= 720
                ? 4
                : constraints.maxWidth >= 420
                    ? 2
                    : 1;
            final anchoItem =
                (constraints.maxWidth - (columnas - 1) * 12) / columnas;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: anchoItem,
                  child: MetricaTile(
                    icon: Icons.favorite_outline,
                    etiqueta: 'Frecuencia cardíaca',
                    valor: decimal(detalle?.vitales.hrBpm, decimales: 0),
                    unidad: 'lpm',
                    color: AppColors.danger,
                    confianza: detalle?.vitales.hrConfianza,
                  ),
                ),
                SizedBox(
                  width: anchoItem,
                  child: MetricaTile(
                    icon: Icons.ssid_chart_outlined,
                    etiqueta: 'HRV (RMSSD)',
                    valor: decimal(detalle?.vitales.rmssdMs, decimales: 0),
                    unidad: 'ms',
                    color: AppColors.purple,
                    confianza: detalle?.vitales.hrvConfianza,
                  ),
                ),
                SizedBox(
                  width: anchoItem,
                  child: MetricaTile(
                    icon: Icons.air_outlined,
                    etiqueta: 'Respiración',
                    valor: decimal(detalle?.vitales.respiracionesRpm),
                    unidad: 'rpm',
                    color: AppColors.info,
                    nota: 'Apoyo de baja confianza (no es un espirómetro).',
                  ),
                ),
                SizedBox(
                  width: anchoItem,
                  child: MetricaTile(
                    icon: Icons.center_focus_strong_outlined,
                    etiqueta: 'Calidad de captura',
                    valor: decimal(detalle?.captura.calidad, decimales: 0),
                    unidad: '/100',
                    color: AppColors.primary,
                    confianza: detalle?.captura.calidad == null
                        ? null
                        : (detalle!.captura.calidad! / 100),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        SeccionTitulo(
          icono: Icons.psychology_outlined,
          titulo: 'Expresión facial',
          subtitulo: 'Indicadores de apoyo; nunca se usan como diagnóstico.',
        ),
        const SizedBox(height: 12),
        PreconsultaCard(
          padding: const EdgeInsets.all(16),
          color: AppColors.background,
          borderColor: AppColors.border,
          child: Column(
            children: [
              ScoreBar(
                etiqueta: 'Dolor facial estimado',
                valor: detalle?.rostro.painScore,
                color: AppColors.danger,
                max: 10,
                sufijo: '/10',
              ),
              const SizedBox(height: 14),
              ScoreBar(
                etiqueta: 'Estrés',
                valor: detalle?.rostro.stressScore,
                color: AppColors.warning,
              ),
              const SizedBox(height: 14),
              ScoreBar(
                etiqueta: 'Fatiga',
                valor: detalle?.rostro.fatigueScore,
                color: AppColors.info,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Expresión dominante',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    detalle?.rostro.expresionEtiqueta ?? 'Sin dato',
                    style: const TextStyle(
                      color: AppColors.dark,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SeccionTitulo(
          icono: Icons.account_tree_outlined,
          titulo: 'Por qué este nivel',
          subtitulo:
              'Cada factor tiene un peso y una fuente. Todo es auditable y revisable.',
        ),
        const SizedBox(height: 12),
        if (triage == null || triage.motivos.isEmpty)
          const _Mensaje(
            texto: 'No hay factores registrados para explicar el nivel.',
            color: AppColors.muted,
            icono: Icons.info_outline,
          )
        else
          for (final motivo in motivosOrdenados)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MotivoTile(motivo: motivo),
            ),
        if (triage != null && triage.recomendaciones.isNotEmpty) ...[
          const SizedBox(height: 16),
          SeccionTitulo(
            icono: Icons.tips_and_updates_outlined,
            titulo: 'Recomendaciones',
            iconColor: AppColors.warning,
          ),
          const SizedBox(height: 10),
          for (final r in triage.recomendaciones)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.check_circle_outline,
                        size: 15, color: AppColors.success),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r,
                      style: const TextStyle(
                          color: AppColors.dark, fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        const AvisoClinico(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reiniciar,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva preconsulta'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: detalle == null
                    ? null
                    : () => context.push('/preconsulta/${detalle.id}'),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ver detalle completo'),
              ),
            ),
          ],
        ),
        if (!_esPaciente) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.go('/app'),
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: const Text('Volver al panel'),
          ),
        ],
      ],
    );
  }

  int? _edad(DateTime nacimiento) {
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad -= 1;
    }
    return edad >= 0 && edad < 130 ? edad : null;
  }
}

// ============================================================================
// Widgets del asistente
// ============================================================================
class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({required this.paso, required this.onSalir});

  final int paso;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.gradientPrimary,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PreConsulta IA',
                  style: TextStyle(
                    color: AppColors.dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Triage asistido y explicable',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Paso ${paso + 1} de 5',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Salir',
            onPressed: onSalir,
            icon: const Icon(Icons.close, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PanelLateral extends StatelessWidget {
  const _PanelLateral({
    required this.paso,
    required this.titulos,
    required this.paciente,
    required this.esPaciente,
  });

  final int paso;
  final List<String> titulos;
  final Patient? paciente;
  final bool esPaciente;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PreconsultaCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ruta de la evaluación',
                style: TextStyle(
                  color: AppColors.dark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < titulos.length; i++)
                _PasoLateral(
                  numero: i + 1,
                  titulo: titulos[i],
                  activo: i == paso,
                  completado: i < paso,
                  ultimo: i == titulos.length - 1,
                ),
            ],
          ),
        ),
        if (paciente != null) ...[
          const SizedBox(height: 14),
          PreconsultaCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryBg,
                  child: Text(
                    _iniciales(paciente!.fullName),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paciente!.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.dark,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (paciente!.ci.isNotEmpty)
                        Text(
                          'CI ${paciente!.ci}',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        PreconsultaCard(
          padding: const EdgeInsets.all(16),
          color: AppColors.primaryDark,
          borderColor: AppColors.primaryDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Privacidad',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'El video y las imágenes se procesan en memoria y no se '
                'almacenan. Solo se guardan los valores estimados, tus '
                'respuestas y la aceptación del consentimiento.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes[1][0]}'.toUpperCase();
  }
}

class _PasoLateral extends StatelessWidget {
  const _PasoLateral({
    required this.numero,
    required this.titulo,
    required this.activo,
    required this.completado,
    required this.ultimo,
  });

  final int numero;
  final String titulo;
  final bool activo;
  final bool completado;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final color = completado
        ? AppColors.success
        : activo
            ? AppColors.primary
            : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completado || activo ? color : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: completado
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '$numero',
                        style: TextStyle(
                          color: activo ? Colors.white : AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              if (!ultimo)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: completado ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 14),
              child: Text(
                titulo,
                style: TextStyle(
                  color: activo ? AppColors.dark : AppColors.muted,
                  fontSize: 12,
                  fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CabeceraPaso extends StatelessWidget {
  const _CabeceraPaso({
    required this.paso,
    required this.total,
    required this.titulo,
    required this.onAtras,
  });

  final int paso;
  final int total;
  final String titulo;
  final VoidCallback onAtras;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onAtras,
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: 'Atrás',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= paso ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (i < total - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPaso extends StatelessWidget {
  const _HeroPaso({
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.badge,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.gradientPrimary,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icono, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        color: AppColors.dark,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitulo != null && subtitulo!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo!,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12.5, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParrafoConsentimiento extends StatelessWidget {
  const _ParrafoConsentimiento({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            texto,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ListaConsentimiento extends StatelessWidget {
  const _ListaConsentimiento({
    required this.titulo,
    required this.icono,
    required this.items,
  });

  final String titulo;
  final IconData icono;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 16, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: const TextStyle(
                  color: AppColors.dark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 5, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TarjetaPaciente extends StatelessWidget {
  const _TarjetaPaciente({
    required this.nombre,
    required this.cedula,
    required this.edad,
  });

  final String nombre;
  final String cedula;
  final int? edad;

  @override
  Widget build(BuildContext context) {
    return PreconsultaCard(
      color: AppColors.primaryBg.withValues(alpha: 0.4),
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (cedula.isNotEmpty) 'CI $cedula',
                    if (edad != null) '$edad años',
                    'Paciente',
                  ].join(' · '),
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_user_outlined,
              color: AppColors.primaryDark, size: 22),
        ],
      ),
    );
  }
}

class _SelectorPaciente extends StatelessWidget {
  const _SelectorPaciente({
    required this.paciente,
    required this.onSeleccionar,
    required this.onLimpiar,
  });

  final Patient? paciente;
  final VoidCallback onSeleccionar;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSeleccionar,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: paciente == null ? AppColors.border : AppColors.primary,
            width: paciente == null ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_search_outlined,
                  color: AppColors.primaryDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paciente',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paciente?.fullName ?? 'Seleccionar paciente',
                    style: TextStyle(
                      color:
                          paciente == null ? AppColors.muted : AppColors.dark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (paciente != null && paciente!.ci.isNotEmpty)
                    Text(
                      'CI ${paciente!.ci}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (paciente != null)
              IconButton(
                tooltip: 'Cambiar paciente',
                onPressed: onLimpiar,
                icon: const Icon(Icons.close, size: 18),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SelectorCita extends StatelessWidget {
  const _SelectorCita({
    super.key,
    required this.citas,
    required this.citaId,
    required this.onCambiar,
    required this.nombreMedico,
  });

  final List<Appointment> citas;
  final int? citaId;
  final ValueChanged<int?> onCambiar;
  final String Function(String) nombreMedico;

  @override
  Widget build(BuildContext context) {
    if (citas.isEmpty) {
      return const _Mensaje(
        texto: 'El paciente no tiene citas próximas. La preconsulta quedará '
            'sin cita asociada (es válido).',
        color: AppColors.muted,
        icono: Icons.event_busy_outlined,
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: citaId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Cita asociada (opcional)',
        prefixIcon: Icon(Icons.event_available_outlined),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: 0,
          child: Text('Sin cita asociada'),
        ),
        for (final cita in citas)
          DropdownMenuItem<int>(
            value: int.tryParse(cita.id),
            child: Text(
              '${DateFormat('d MMM', 'es').format(cita.date)} ${cita.time} · '
              '${nombreMedico(cita.doctorId)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => onCambiar(v == 0 ? null : v),
    );
  }
}

class _PacientePicker extends StatefulWidget {
  const _PacientePicker({required this.pacientes});

  final List<Patient> pacientes;

  @override
  State<_PacientePicker> createState() => _PacientePickerState();
}

class _PacientePickerState extends State<_PacientePicker> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final q = _filtro.trim().toLowerCase();
    final lista = widget.pacientes.where((p) {
      if (q.isEmpty) return true;
      return p.fullName.toLowerCase().contains(q) ||
          p.ci.toLowerCase().contains(q);
    }).toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        // Material (en vez de Container con color) para que los ListTile de la
        // lista pinten su fondo y su tinta sin la assertion de Flutter en debug.
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Seleccionar paciente',
                        style: TextStyle(
                          color: AppColors.dark,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre o cédula',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _filtro = v),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: lista.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin coincidencias.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = lista[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryBg,
                              child: Text(
                                p.fullName.isEmpty
                                    ? '?'
                                    : p.fullName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              p.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (p.ci.isNotEmpty) 'CI ${p.ci}',
                                if (p.phone.isNotEmpty) p.phone,
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeccionCuestionario extends StatelessWidget {
  const _SeccionCuestionario({
    required this.seccion,
    required this.preguntas,
    required this.respuestas,
    required this.errores,
    required this.controlPara,
    required this.onCambio,
  });

  final PreconsultaSeccion seccion;
  final List<PreconsultaPregunta> preguntas;
  final Map<String, dynamic> respuestas;
  final Map<String, String> errores;
  final TextEditingController Function(PreconsultaPregunta) controlPara;
  final void Function(String codigo, dynamic valor) onCambio;

  @override
  Widget build(BuildContext context) {
    if (preguntas.isEmpty) return const SizedBox.shrink();
    return PreconsultaCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      borderColor: AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            seccion.titulo,
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (seccion.descripcion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              seccion.descripcion,
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 14),
          for (final pregunta in preguntas)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _CampoCuestionario(
                pregunta: pregunta,
                valor: respuestas[pregunta.codigo],
                error: errores[pregunta.codigo],
                control: controlPara(pregunta),
                onCambio: (v) => onCambio(pregunta.codigo, v),
              ),
            ),
        ],
      ),
    );
  }
}

class _CampoCuestionario extends StatelessWidget {
  const _CampoCuestionario({
    required this.pregunta,
    required this.valor,
    required this.error,
    required this.control,
    required this.onCambio,
  });

  final PreconsultaPregunta pregunta;
  final dynamic valor;
  final String? error;
  final TextEditingController control;
  final ValueChanged<dynamic> onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(text: pregunta.pregunta),
              if (pregunta.requerida)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.danger),
                ),
            ],
          ),
        ),
        if (pregunta.ayuda.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            pregunta.ayuda,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
        const SizedBox(height: 8),
        _control(),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: const TextStyle(color: AppColors.danger, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _control() {
    switch (pregunta.tipo) {
      case 'escala':
        final min = pregunta.min ?? 0;
        final max = pregunta.max ?? 10;
        final actual = valor is num ? valor!.toDouble() : null;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null ? AppColors.danger : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 10),
                  Text(
                    '$min',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11),
                  ),
                  Expanded(
                    child: Slider(
                      value: actual ?? min.toDouble(),
                      min: min.toDouble(),
                      max: max.toDouble(),
                      divisions: (max - min).clamp(1, 20),
                      label: actual == null
                          ? 'Sin responder'
                          : actual.toStringAsFixed(0),
                      onChanged: (v) => onCambio(v.round()),
                    ),
                  ),
                  Text(
                    '$max',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  actual == null
                      ? 'Desliza para indicar la intensidad'
                      : 'Intensidad: ${actual.toStringAsFixed(0)} / $max',
                  style: TextStyle(
                    color: actual == null ? AppColors.muted : AppColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'si_no':
        return _PildoraSiNo(
          valor: valor is bool ? valor as bool : null,
          onCambio: onCambio,
        );
      case 'opcion':
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opcion in pregunta.opciones)
              ChoiceChip(
                label: Text(opcion.etiqueta),
                selected: valor == opcion.valor,
                onSelected: (_) => onCambio(opcion.valor),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valor == opcion.valor
                      ? AppColors.primaryDark
                      : AppColors.muted,
                ),
                selectedColor: AppColors.primaryBg,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: valor == opcion.valor
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
          ],
        );
      case 'multiopcion':
        final seleccion = valor is List
            ? (valor as List).map((e) => e.toString()).toList()
            : <String>[];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opcion in pregunta.opciones)
              FilterChip(
                label: Text(opcion.etiqueta),
                selected: seleccion.contains(opcion.valor),
                onSelected: (marcado) {
                  final nueva = List<String>.from(seleccion);
                  if (marcado) {
                    if (opcion.valor == 'ninguna') {
                      nueva
                        ..clear()
                        ..add(opcion.valor);
                    } else {
                      nueva
                        ..remove('ninguna')
                        ..add(opcion.valor);
                    }
                  } else {
                    nueva.remove(opcion.valor);
                  }
                  onCambio(nueva);
                },
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: seleccion.contains(opcion.valor)
                      ? AppColors.primaryDark
                      : AppColors.muted,
                ),
                selectedColor: AppColors.primaryBg,
                backgroundColor: AppColors.surface,
                checkmarkColor: AppColors.primary,
                side: BorderSide(
                  color: seleccion.contains(opcion.valor)
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
          ],
        );
      default:
        return TextField(
          controller: control,
          maxLength: 280,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Escribe aquí…',
            counterText: '',
            errorText: null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: error != null ? AppColors.danger : AppColors.border,
              ),
            ),
          ),
          onChanged: (v) => onCambio(v),
        );
    }
  }
}

class _PildoraSiNo extends StatelessWidget {
  const _PildoraSiNo({required this.valor, required this.onCambio});

  final bool? valor;
  final ValueChanged<dynamic> onCambio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OpcionSiNo(
            texto: 'Sí',
            icono: Icons.check,
            activo: valor == true,
            color: AppColors.success,
            onTap: () => onCambio(true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OpcionSiNo(
            texto: 'No',
            icono: Icons.close,
            activo: valor == false,
            color: AppColors.muted,
            onTap: () => onCambio(false),
          ),
        ),
      ],
    );
  }
}

class _OpcionSiNo extends StatelessWidget {
  const _OpcionSiNo({
    required this.texto,
    required this.icono,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  final String texto;
  final IconData icono;
  final bool activo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: activo ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? color : AppColors.border,
            width: activo ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 16, color: activo ? color : AppColors.muted),
            const SizedBox(width: 6),
            Text(
              texto,
              style: TextStyle(
                color: activo ? color : AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstruccionesCaptura extends StatelessWidget {
  const _InstruccionesCaptura();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.light_mode_outlined, 'Buena iluminación de frente'),
      (Icons.face_outlined, 'Rostro completo y sin gafas oscuras'),
      (Icons.self_improvement_outlined, 'Respira normal y mantente quieto'),
      (Icons.timer_outlined, 'La captura dura unos 20 segundos'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  item.$2,
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CamaraInvitacion extends StatelessWidget {
  const _CamaraInvitacion({
    required this.onActivar,
    required this.deshabilitado,
  });

  final VoidCallback onActivar;
  final bool deshabilitado;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_outlined, size: 44, color: Colors.white70),
            const SizedBox(height: 10),
            const Text(
              'La cámara se abrirá solo para esta captura.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: deshabilitado ? null : onActivar,
              icon: const Icon(Icons.videocam, size: 18),
              label: const Text('Activar cámara'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CamaraNoDisponible extends StatelessWidget {
  const _CamaraNoDisponible({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                size: 42, color: Colors.orangeAccent),
            const SizedBox(height: 10),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'Puedes continuar sin cámara; el triage usará solo el cuestionario.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _MotivoTile extends StatelessWidget {
  const _MotivoTile({required this.motivo});

  final MotivoTriage motivo;

  @override
  Widget build(BuildContext context) {
    final color = switch (motivo.fuente) {
      'cuestionario' => AppColors.primary,
      'signos' => AppColors.danger,
      'facial' => AppColors.purple,
      'contexto' => AppColors.warning,
      _ => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              motivo.fuenteEtiqueta,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  motivo.etiqueta,
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (motivo.detalle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    motivo.detalle,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11.5, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${motivo.peso.toStringAsFixed(1)}',
            style: TextStyle(
              color: motivo.peso >= 0 ? color : AppColors.success,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icono,
    required this.texto,
    required this.color,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.texto,
    required this.color,
    required this.icono,
  });

  final String texto;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: color, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
