import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../data/models/preconsulta.dart';
import '../../data/models/user.dart';
import '../../state/auth_provider.dart';
import '../../state/preconsulta_provider.dart';
import 'widgets/preconsulta_ui.dart';

/// Detalle clínico de una preconsulta: signos, expresión, explicación del
/// triage, respuestas, revisión humana, auditoría y tendencias del paciente.
class PreconsultaDetailPage extends StatefulWidget {
  const PreconsultaDetailPage({super.key, required this.id});

  final int id;

  @override
  State<PreconsultaDetailPage> createState() => _PreconsultaDetailPageState();
}

class _PreconsultaDetailPageState extends State<PreconsultaDetailPage> {
  final TextEditingController _nota = TextEditingController();
  int? _nivelSeleccionado;
  bool _guardandoRevision = false;
  bool _eventosCargados = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final prov = context.read<PreconsultaProvider>();
    final ok = await prov.cargarDetalle(widget.id);
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final esStaff = auth.role != UserRole.paciente;
    final detalle = prov.detalle;
    if (detalle != null) {
      setState(() {
        _nivelSeleccionado =
            detalle.triage.nivelEfectivo ?? detalle.triage.nivel ?? 3;
        _nota.text = detalle.triage.notaRevision;
      });
      final pacienteId = _pacienteId(detalle);
      if (pacienteId != null) {
        await prov.cargarTendencias(pacienteId, limite: 8);
      }
    }
    if (ok && esStaff) {
      await prov.cargarEventos(widget.id);
      if (mounted) setState(() => _eventosCargados = true);
    }
  }

  int? _pacienteId(PreconsultaDetalle detalle) {
    final valor = detalle.paciente?['id'];
    if (valor is int) return valor;
    return int.tryParse('$valor');
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardarRevision() async {
    final nivel = _nivelSeleccionado;
    if (nivel == null) return;
    setState(() => _guardandoRevision = true);
    final prov = context.read<PreconsultaProvider>();
    final ok = await prov.revisar(
      id: widget.id,
      nivelRevisado: nivel,
      nota: _nota.text.trim(),
    );
    if (!mounted) return;
    setState(() => _guardandoRevision = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Triage revisado: nivel $nivel.'
              : (prov.error ?? 'No se pudo guardar la revisión.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PreconsultaProvider>();
    final auth = context.watch<AuthProvider>();
    final detalle = prov.detalle;
    final esStaff = auth.role != UserRole.paciente;
    return Scaffold(
      body: AmbientBackground(
        blobs: false,
        child: SafeArea(
          child: Column(
            children: [
              _Barra(
                id: widget.id,
                estado: detalle?.estado,
                onAtras: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/app');
                  }
                },
                onRecargar: _cargar,
              ),
              Expanded(
                child: detalle == null
                    ? _estadoVacio(prov)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Hero(detalle: detalle),
                                const SizedBox(height: 14),
                                _GridSignos(detalle: detalle),
                                const SizedBox(height: 14),
                                _Explicabilidad(detalle: detalle),
                                const SizedBox(height: 14),
                                _Respuestas(detalle: detalle),
                                if (esStaff) ...[
                                  const SizedBox(height: 14),
                                  _Revision(
                                    detalle: detalle,
                                    nivel: _nivelSeleccionado,
                                    nota: _nota,
                                    guardando: _guardandoRevision,
                                    onNivel: (n) =>
                                        setState(() => _nivelSeleccionado = n),
                                    onGuardar: _guardarRevision,
                                  ),
                                  const SizedBox(height: 14),
                                  _Auditoria(
                                    eventos: prov.eventos,
                                    cargado: _eventosCargados,
                                  ),
                                ],
                                const SizedBox(height: 14),
                                _Tendencias(
                                  tendencias: prov.tendencias,
                                  pacienteId: _pacienteId(detalle),
                                ),
                                const SizedBox(height: 16),
                                const AvisoClinico(),
                              ],
                            ),
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

  Widget _estadoVacio(PreconsultaProvider prov) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prov.cargando)
              const CircularProgressIndicator()
            else ...[
              const Icon(Icons.search_off_outlined,
                  size: 48, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(
                prov.error ?? 'No se pudo cargar la preconsulta.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.id,
    required this.estado,
    required this.onAtras,
    required this.onRecargar,
  });

  final int id;
  final String? estado;
  final VoidCallback onAtras;
  final VoidCallback onRecargar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Atrás',
            onPressed: onAtras,
            icon: const Icon(Icons.arrow_back),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.gradientPrimary,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PreConsulta #$id',
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Detalle clínico y trazabilidad del triage',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (estado != null) EstadoChip(estado: estado!),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Recargar',
            onPressed: onRecargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detalle});

  final PreconsultaDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final triage = detalle.triage;
    final nivel = triage.nivelEfectivo;
    final color = nivelColor(nivel);
    final paciente = detalle.paciente ?? const <String, dynamic>{};
    final nombre = detalle.pacienteNombre;
    final meta = <String>[
      if (detalle.pacienteCedula.isNotEmpty) 'CI ${detalle.pacienteCedula}',
      if (detalle.pacienteEdad != null) '${detalle.pacienteEdad} años',
      if ((paciente['sexo'] ?? '').toString().isNotEmpty)
        _sexo(paciente['sexo']),
      if ((paciente['telefono'] ?? '').toString().isNotEmpty)
        '${paciente['telefono']}',
    ];
    return PreconsultaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Text(
                  _iniciales(nombre),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.isEmpty ? 'Sin datos demográficos' : meta.join(' · '),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notes_outlined,
                              size: 15, color: AppColors.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              detalle.motivo.isNotEmpty
                                  ? detalle.motivo
                                  : 'Motivo registrado en el cuestionario',
                              style: const TextStyle(
                                color: AppColors.dark,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _Meta(
                          icono: Icons.calendar_today_outlined,
                          texto: fechaCorta(detalle.creadoEn),
                        ),
                        _Meta(
                          icono: Icons.devices_outlined,
                          texto: 'Canal: ${detalle.canal}',
                        ),
                        if (detalle.medico != null)
                          _Meta(
                            icono: Icons.medical_services_outlined,
                            texto:
                                '${detalle.medico!['nombre'] ?? 'Médico'}',
                          ),
                        if (detalle.cita != null)
                          _Meta(
                            icono: Icons.event_available_outlined,
                            texto:
                                'Cita ${detalle.cita!['hora'] ?? ''}'.trim(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 104,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Text(
                      nivel?.toString() ?? '—',
                      style: TextStyle(
                        color: color,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nivelEtiqueta(nivel),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nivelTiempo(nivel),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (triage.confianza ?? 0).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  triage.resumen.isNotEmpty
                      ? triage.resumen
                      : 'Triaje sin resumen.',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11.5, height: 1.35),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Confianza ${porcentaje(triage.confianza)}',
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 10.5),
              ),
            ],
          ),
          if (triage.revisado) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Revisado por personal${triage.nivelRevisado != null ? ' · nivel ${triage.nivelRevisado}' : ''}'
                    '${triage.revisadoEn != null ? ' · ${fechaCorta(triage.revisadoEn)}' : ''}'
                    '${triage.notaRevision.isNotEmpty ? ' · ${triage.notaRevision}' : ''}',
                    style: const TextStyle(
                        color: AppColors.success, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _sexo(dynamic valor) {
    switch (valor.toString().toLowerCase()) {
      case 'm':
      case 'masculino':
        return 'Masculino';
      case 'f':
      case 'femenino':
        return 'Femenino';
      default:
        return valor.toString();
    }
  }

  static String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes[1][0]}'.toUpperCase();
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 12, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _GridSignos extends StatelessWidget {
  const _GridSignos({required this.detalle});

  final PreconsultaDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final v = detalle.vitales;
    final r = detalle.rostro;
    final captura = detalle.captura;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeccionTitulo(
          icono: Icons.monitor_heart_outlined,
          titulo: 'Signos y expresión estimados',
          subtitulo: captura.rostroDetectado
              ? 'Ópticos (rPPG). No equivalen a mediciones clínicas certificadas.'
              : 'Captura omitida o rostro no detectado: solo cuestionario.',
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth >= 860
                ? 4
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            final ancho = (constraints.maxWidth - (columnas - 1) * 10) / columnas;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: ancho,
                  child: MetricaTile(
                    icon: Icons.favorite_outline,
                    etiqueta: 'Frecuencia cardíaca',
                    valor: decimal(v.hrBpm, decimales: 0),
                    unidad: 'lpm',
                    color: AppColors.danger,
                    confianza: v.hrConfianza,
                  ),
                ),
                SizedBox(
                  width: ancho,
                  child: MetricaTile(
                    icon: Icons.ssid_chart_outlined,
                    etiqueta: 'HRV · RMSSD',
                    valor: decimal(v.rmssdMs, decimales: 0),
                    unidad: 'ms',
                    color: AppColors.purple,
                    confianza: v.hrvConfianza,
                  ),
                ),
                SizedBox(
                  width: ancho,
                  child: MetricaTile(
                    icon: Icons.air_outlined,
                    etiqueta: 'Respiración',
                    valor: decimal(v.respiracionesRpm),
                    unidad: 'rpm',
                    color: AppColors.info,
                    nota: 'Apoyo de baja confianza.',
                  ),
                ),
                SizedBox(
                  width: ancho,
                  child: MetricaTile(
                    icon: Icons.center_focus_strong_outlined,
                    etiqueta: 'Calidad de captura',
                    valor: decimal(captura.calidad, decimales: 0),
                    unidad: '/100',
                    color: AppColors.primary,
                    nota: captura.frames != null
                        ? '${captura.frames} fotogramas'
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        PreconsultaCard(
          padding: const EdgeInsets.all(16),
          color: AppColors.background,
          borderColor: AppColors.border,
          child: Column(
            children: [
              ScoreBar(
                etiqueta: 'Dolor facial estimado',
                valor: r.painScore,
                color: AppColors.danger,
                max: 10,
                sufijo: '/10',
              ),
              const SizedBox(height: 14),
              ScoreBar(
                etiqueta: 'Estrés',
                valor: r.stressScore,
                color: AppColors.warning,
              ),
              const SizedBox(height: 14),
              ScoreBar(
                etiqueta: 'Fatiga',
                valor: r.fatigueScore,
                color: AppColors.info,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Meta(
                    icono: Icons.visibility_outlined,
                    texto:
                        'Parpadeos: ${decimal(r.blinkRate, decimales: 0, sufijo: '/min')}',
                  ),
                  const SizedBox(width: 16),
                  _Meta(
                    icono: Icons.mood_outlined,
                    texto: 'Expresión: ${r.expresionEtiqueta}',
                  ),
                  const SizedBox(width: 16),
                  _Meta(
                    icono: Icons.screen_rotation_outlined,
                    texto:
                        'Estabilidad: ${porcentaje(r.poseEstabilidad)}',
                  ),
                ],
              ),
              if (detalle.identidad != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      detalle.identidad!.coincide
                          ? Icons.verified_user_outlined
                          : Icons.person_off_outlined,
                      size: 15,
                      color: detalle.identidad!.coincide
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      detalle.identidad!.coincide
                          ? 'Identidad verificada · similitud ${porcentaje(detalle.identidad!.similitud)}'
                          : 'Identidad no verificada · similitud ${porcentaje(detalle.identidad!.similitud)}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Explicabilidad extends StatelessWidget {
  const _Explicabilidad({required this.detalle});

  final PreconsultaDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final triage = detalle.triage;
    final motivos = [...triage.motivos]..sort(
        (a, b) => b.peso.abs().compareTo(a.peso.abs()),
      );
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.account_tree_outlined,
            titulo: 'Explicación del nivel',
            subtitulo:
                'Pesos y fuentes auditables. El nivel sugerido no es un diagnóstico.',
          ),
          if (triage.banderas.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final b in triage.banderas)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (b.critica ? AppColors.danger : AppColors.warning)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (b.critica ? AppColors.danger : AppColors.warning)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        b.critica
                            ? Icons.priority_high
                            : Icons.flag_outlined,
                        size: 17,
                        color:
                            b.critica ? AppColors.danger : AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b.texto,
                          style: TextStyle(
                            color:
                                b.critica ? AppColors.danger : AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 4),
          if (motivos.isEmpty)
            const Text(
              'Sin factores registrados.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            )
          else
            for (final m in motivos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Motivo(motivo: m),
              ),
          if (triage.recomendaciones.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Recomendaciones',
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            for (final r in triage.recomendaciones)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.check_circle_outline,
                          size: 14, color: AppColors.success),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        r,
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Motivo extends StatelessWidget {
  const _Motivo({required this.motivo});

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
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              motivo.fuenteEtiqueta,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  motivo.etiqueta,
                  style: const TextStyle(
                      color: AppColors.dark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
                if (motivo.detalle.isNotEmpty)
                  Text(
                    motivo.detalle,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11, height: 1.3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${motivo.peso >= 0 ? '+' : ''}${motivo.peso.toStringAsFixed(1)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Respuestas extends StatelessWidget {
  const _Respuestas({required this.detalle});

  final PreconsultaDetalle detalle;

  static const _orden = ['motivo', 'sintomas', 'contexto', 'otras'];
  static const _titulos = {
    'motivo': 'Motivo de consulta',
    'sintomas': 'Síntomas actuales',
    'contexto': 'Contexto clínico',
    'otras': 'Otras respuestas',
  };

  @override
  Widget build(BuildContext context) {
    final porSeccion = <String, List<RespuestaPreconsulta>>{};
    for (final r in detalle.respuestas) {
      porSeccion.putIfAbsent(r.seccion, () => []).add(r);
    }
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.assignment_outlined,
            titulo: 'Cuestionario respondido',
            subtitulo: 'Lo que el paciente reportó, sin interpretaciones.',
          ),
          const SizedBox(height: 8),
          if (detalle.respuestas.isEmpty)
            const Text(
              'No hay respuestas registradas.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            )
          else
            for (final clave in _orden)
              if (porSeccion.containsKey(clave)) ...[
                const SizedBox(height: 8),
                Text(
                  _titulos[clave] ?? clave,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                for (final r in porSeccion[clave]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            r.pregunta.isNotEmpty ? r.pregunta : r.codigo,
                            style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                height: 1.3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Text(
                            r.etiqueta.isNotEmpty
                                ? r.etiqueta
                                : '${r.valor ?? ''}',
                            style: const TextStyle(
                              color: AppColors.dark,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
        ],
      ),
    );
  }
}

class _Revision extends StatelessWidget {
  const _Revision({
    required this.detalle,
    required this.nivel,
    required this.nota,
    required this.guardando,
    required this.onNivel,
    required this.onGuardar,
  });

  final PreconsultaDetalle detalle;
  final int? nivel;
  final TextEditingController nota;
  final bool guardando;
  final ValueChanged<int> onNivel;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.rate_review_outlined,
            titulo: 'Revisión clínica',
            subtitulo:
                'Confirma o ajusta el nivel. Queda registrado quién y cuándo.',
            iconColor: AppColors.info,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 1; n <= 5; n++)
                InkWell(
                  onTap: guardando ? null : () => onNivel(n),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 112,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: nivel == n
                          ? nivelColor(n).withValues(alpha: 0.14)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: nivel == n
                            ? nivelColor(n)
                            : AppColors.border,
                        width: nivel == n ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: nivelColor(n),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            nivelEtiqueta(n),
                            maxLines: 2,
                            style: TextStyle(
                              color: nivel == n
                                  ? nivelColor(n)
                                  : AppColors.muted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nota,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Nota de revisión (opcional)',
              hintText: 'Ej.: confirmado por teléfono, paciente en sala…',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  detalle.triage.revisado
                      ? 'Última revisión: ${fechaCorta(detalle.triage.revisadoEn)}'
                      : 'Pendiente de revisión humana',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11),
                ),
              ),
              FilledButton.icon(
                onPressed: guardando || nivel == null ? null : onGuardar,
                icon: guardando
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 17),
                label: Text(guardando ? 'Guardando…' : 'Guardar revisión'),
              ),
            ],
          ),
          if (detalle.revisiones.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 4),
            const Text(
              'Historial de revisiones',
              style: TextStyle(
                  color: AppColors.dark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final r in detalle.revisiones.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Icon(Icons.history,
                        size: 13, color: nivelColor(r.nivelNuevo)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${r.nivelAnterior ?? '—'} → ${r.nivelNuevo}'
                        '${r.nota.isNotEmpty ? ' · ${r.nota}' : ''}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11),
                      ),
                    ),
                    Text(
                      fechaCorta(r.creadoEn),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Auditoria extends StatelessWidget {
  const _Auditoria({required this.eventos, required this.cargado});

  final List<EventoPreconsulta> eventos;
  final bool cargado;

  static const _etiquetas = {
    'creada': 'Preconsulta creada',
    'analizada': 'Análisis facial completado',
    'respuestas_guardadas': 'Cuestionario guardado',
    'finalizada_sin_captura': 'Finalizada sin captura',
    'revisada': 'Triage revisado',
  };

  @override
  Widget build(BuildContext context) {
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.history_outlined,
            titulo: 'Auditoría',
            subtitulo: 'Eventos del flujo, sin imágenes ni video.',
          ),
          const SizedBox(height: 8),
          if (!cargado)
            const Text('Cargando eventos…',
                style: TextStyle(color: AppColors.muted, fontSize: 11))
          else if (eventos.isEmpty)
            const Text('Sin eventos registrados.',
                style: TextStyle(color: AppColors.muted, fontSize: 11))
          else
            for (final e in eventos)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(Icons.circle,
                        size: 6, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _etiquetas[e.tipo] ?? e.tipo,
                        style: const TextStyle(
                            color: AppColors.dark, fontSize: 11.5),
                      ),
                    ),
                    Text(
                      fechaCorta(e.creadoEn),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Tendencias extends StatelessWidget {
  const _Tendencias({required this.tendencias, required this.pacienteId});

  final TendenciasPaciente? tendencias;
  final int? pacienteId;

  @override
  Widget build(BuildContext context) {
    final t = tendencias;
    if (t == null || pacienteId == null || t.pacienteId != pacienteId) {
      return const SizedBox.shrink();
    }
    if (t.puntos.isEmpty) return const SizedBox.shrink();
    final puntos = t.puntos;
    final maxY = 5.0;
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.trending_up_outlined,
            titulo: 'Tendencias del paciente',
            subtitulo: 'Evolución del nivel de triage en sus últimas preconsultas.',
            iconColor: AppColors.purple,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 1,
                maxY: maxY,
                minX: 0,
                maxX: (puntos.length - 1).toDouble().clamp(1, 999),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (i < 0 || i >= puntos.length) {
                          return const SizedBox.shrink();
                        }
                        final fecha = puntos[i].fecha;
                        return Text(
                          fecha == null
                              ? '—'
                              : '${fecha.day}/${fecha.month}',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 9),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < puntos.length; i++)
                        FlSpot(
                          i.toDouble(),
                          (puntos[i].triageNivel ?? 3).toDouble(),
                        ),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: nivelColor(spot.y.round()),
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Resumen(
                  etiqueta: 'Promedio nivel',
                  valor: decimal(t.promedioNivel)),
              _Resumen(
                  etiqueta: 'FC media',
                  valor: decimal(t.promedioHr, decimales: 0, sufijo: ' lpm')),
              _Resumen(
                  etiqueta: 'Dolor facial medio',
                  valor: decimal(t.promedioDolor, sufijo: '/10')),
              _Resumen(
                  etiqueta: 'Estrés medio',
                  valor: decimal(t.promedioEstres)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11),
        children: [
          TextSpan(
            text: '$etiqueta: ',
            style: const TextStyle(color: AppColors.muted),
          ),
          TextSpan(
            text: valor,
            style: const TextStyle(
                color: AppColors.dark, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
