import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../data/models/preconsulta.dart';
import '../../state/auth_provider.dart';
import '../../state/preconsulta_provider.dart';
import 'widgets/preconsulta_ui.dart';

/// Página de inicio de la PreConsulta IA para el paciente.
///
/// Explica qué es, cómo se protegen sus datos y le permite iniciar la
/// evaluación. Muestra además su historial de niveles y su última estimación.
class PreconsultaPacientePage extends StatefulWidget {
  const PreconsultaPacientePage({super.key});

  @override
  State<PreconsultaPacientePage> createState() => _PreconsultaPacientePageState();
}

class _PreconsultaPacientePageState extends State<PreconsultaPacientePage> {
  bool _cargando = true;
  String? _error;
  int? _pacienteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final prov = context.read<PreconsultaProvider>();
    final auth = context.read<AuthProvider>();
    setState(() {
      _cargando = true;
      _error = null;
    });

    var id = int.tryParse(auth.perfilId ?? '');
    if (id == null) {
      await prov.cargarCatalogo();
      id = prov.catalogo?.pacienteId ?? _pacienteId;
      _pacienteId = id;
    } else {
      // El catálogo también trae el id resuelto y el estado del
      // consentimiento; se aprovecha la misma llamada.
      await prov.cargarCatalogo(pacienteId: id);
      id = prov.catalogo?.pacienteId ?? id;
      _pacienteId = id;
    }

    if (!mounted) return;
    if (id != null) {
      await prov.cargarTendencias(id, limite: 10);
    }
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = prov.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PreconsultaProvider>();
    final ancho = MediaQuery.sizeOf(context).width;
    final compacto = ancho < 760;
    final tendencias = prov.tendencias;
    final puntos = tendencias?.puntos ?? const <PuntoTendencia>[];
    final ultimo = puntos.isNotEmpty ? puntos.first : null;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Hero(
            habilitado: prov.catalogo?.habilitado ?? true,
            yaAceptado: prov.catalogo?.yaAceptado ?? false,
            onIniciar: () => context.push('/preconsulta'),
          ),
          const SizedBox(height: 16),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_error != null && puntos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PreconsultaCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No pudimos cargar tu historial ahora mismo. Puedes '
                          'iniciar una preconsulta igualmente. ($_error)',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (ultimo != null) ...[
              _UltimaEvaluacion(punto: ultimo),
              const SizedBox(height: 14),
            ],
            _DosColumnas(
              izquierda: _ComoFunciona(compacto: compacto),
              derecha: _Privacidad(compacto: compacto),
            ),
            const SizedBox(height: 14),
            _Historial(puntos: puntos, pacienteId: _pacienteId),
            const SizedBox(height: 14),
            const AvisoClinico(),
          ],
        ],
      ),
    );
  }
}

class _DosColumnas extends StatelessWidget {
  const _DosColumnas({required this.izquierda, required this.derecha});

  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              izquierda,
              const SizedBox(height: 14),
              derecha,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: izquierda),
            const SizedBox(width: 14),
            Expanded(child: derecha),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.habilitado,
    required this.yaAceptado,
    required this.onIniciar,
  });

  final bool habilitado;
  final bool yaAceptado;
  final VoidCallback onIniciar;

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.sizeOf(context).width < 700;
    return Container(
      padding: EdgeInsets.all(compacto ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradientSidebar,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'PreConsulta IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              if (!habilitado)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Temporalmente no disponible',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Cuéntanos cómo te sientes antes de tu cita. En unos 30 segundos '
            'estimamos tu pulso y respiración con la cámara, registramos tus '
            'síntomas y calculamos un nivel de prioridad que el personal clínico '
            'revisará.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: compacto ? 13 : 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ChipHero(
                icono: Icons.timer_outlined,
                texto: '20-30 segundos',
              ),
              _ChipHero(
                icono: Icons.videocam_outlined,
                texto: 'Cámara frontal',
              ),
              _ChipHero(
                icono: Icons.lock_outline,
                texto: 'Sin guardar video',
              ),
              _ChipHero(
                icono: Icons.medical_services_outlined,
                texto: 'Revisión humana',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton.icon(
                onPressed: habilitado ? onIniciar : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 16),
                ),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(
                  yaAceptado ? 'Iniciar nueva preconsulta' : 'Comenzar ahora',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipHero extends StatelessWidget {
  const _ChipHero({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UltimaEvaluacion extends StatelessWidget {
  const _UltimaEvaluacion({required this.punto});

  final PuntoTendencia punto;

  @override
  Widget build(BuildContext context) {
    final nivel = punto.triageNivel;
    final color = nivelColor(nivel);
    final compacto = MediaQuery.sizeOf(context).width < 620;
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.assignment_turned_in_outlined,
            titulo: 'Tu última preconsulta',
            subtitulo: 'Nivel sugerido y estimaciones de esa evaluación.',
          ),
          const SizedBox(height: 14),
          if (compacto)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NivelGrande(nivel: nivel, color: color, fecha: punto.fecha),
                const SizedBox(height: 12),
                _SignosUltimos(punto: punto),
              ],
            )
          else
            Row(
              children: [
                _NivelGrande(nivel: nivel, color: color, fecha: punto.fecha),
                const SizedBox(width: 16),
                Expanded(child: _SignosUltimos(punto: punto)),
              ],
            ),
          if (punto.resumen.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Text(
                punto.resumen,
                style: const TextStyle(
                    color: AppColors.dark, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NivelGrande extends StatelessWidget {
  const _NivelGrande({
    required this.nivel,
    required this.color,
    required this.fecha,
  });

  final int? nivel;
  final Color color;
  final DateTime? fecha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            nivel?.toString() ?? '—',
            style: TextStyle(
              color: color,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            nivelEtiqueta(nivel),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fecha == null
                ? 'Sin fecha'
                : DateFormat('d MMM yyyy', 'es').format(fecha!),
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SignosUltimos extends StatelessWidget {
  const _SignosUltimos({required this.punto});

  final PuntoTendencia punto;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MiniMetrica(
          icono: Icons.favorite_outline,
          etiqueta: 'Pulso',
          valor: punto.hrBpm == null
              ? '—'
              : '${punto.hrBpm!.toStringAsFixed(0)} lpm',
          color: AppColors.danger,
        ),
        _MiniMetrica(
          icono: Icons.ssid_chart_outlined,
          etiqueta: 'HRV',
          valor: punto.rmssdMs == null
              ? '—'
              : '${punto.rmssdMs!.toStringAsFixed(0)} ms',
          color: AppColors.purple,
        ),
        _MiniMetrica(
          icono: Icons.sentiment_dissatisfied_outlined,
          etiqueta: 'Dolor facial',
          valor: punto.painScore == null
              ? '—'
              : '${punto.painScore!.toStringAsFixed(1)}/10',
          color: AppColors.warning,
        ),
        _MiniMetrica(
          icono: Icons.psychology_outlined,
          etiqueta: 'Estrés',
          valor: punto.stressScore == null
              ? '—'
              : punto.stressScore!.toStringAsFixed(0),
          color: AppColors.info,
        ),
      ],
    );
  }
}

class _MiniMetrica extends StatelessWidget {
  const _MiniMetrica({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icono, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
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

class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona({required this.compacto});

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    const pasos = [
      (
        Icons.verified_user_outlined,
        'Aceptas el consentimiento',
        'Te explicamos qué datos se usan y puedes decidir libremente.'
      ),
      (
        Icons.videocam_outlined,
        'Captura breve con la cámara',
        'Mira de frente durante 20-30 segundos con buena luz. Nada se guarda.'
      ),
      (
        Icons.assignment_outlined,
        'Respondes unas preguntas',
        'Motivo de consulta, síntomas y antecedentes relevantes.'
      ),
      (
        Icons.insights_outlined,
        'Recibes un nivel de prioridad',
        'El personal clínico lo revisa y confirma antes de atenderte.'
      ),
    ];
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.route_outlined,
            titulo: 'Cómo funciona',
            subtitulo: 'Cuatro pasos, menos de dos minutos.',
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < pasos.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == pasos.length - 1 ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: AppColors.gradientPrimary,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(pasos[i].$1,
                                size: 14, color: AppColors.primaryDark),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                pasos[i].$2,
                                style: const TextStyle(
                                  color: AppColors.dark,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pasos[i].$3,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
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

class _Privacidad extends StatelessWidget {
  const _Privacidad({required this.compacto});

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    const puntos = [
      'El video y las imágenes se procesan en memoria y se descartan al terminar.',
      'Solo se guardan los valores estimados, tus respuestas y la aceptación del consentimiento.',
      'Puedes continuar sin cámara: el triage usará únicamente el cuestionario.',
      'Un profesional revisa y puede ajustar el nivel sugerido por la IA.',
    ];
    return PreconsultaCard(
      color: AppColors.primaryBg.withValues(alpha: 0.35),
      borderColor: AppColors.primary.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.shield_outlined,
            titulo: 'Tus datos, protegidos',
            subtitulo: 'Diseñado con privacidad desde el inicio.',
            iconColor: AppColors.primaryDark,
          ),
          const SizedBox(height: 12),
          for (final p in puntos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.check_circle,
                        size: 14, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.health_and_safety_outlined,
                    size: 15, color: AppColors.info),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'La PreConsulta IA no diagnostica ni reemplaza una consulta médica.',
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
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

class _Historial extends StatelessWidget {
  const _Historial({required this.puntos, required this.pacienteId});

  final List<PuntoTendencia> puntos;
  final int? pacienteId;

  @override
  Widget build(BuildContext context) {
    if (puntos.isEmpty) {
      return PreconsultaCard(
        child: AppEmptyState(
          icon: Icons.history_outlined,
          title: 'Aún no tienes preconsultas',
          subtitle:
              'Cuando completes tu primera evaluación, aquí verás tu nivel y la evolución en el tiempo.',
          action: FilledButton.icon(
            onPressed: () => context.push('/preconsulta'),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Iniciar preconsulta'),
          ),
        ),
      );
    }
    final ordenados = [...puntos]
      ..sort((a, b) => (a.fecha ?? DateTime(0))
          .compareTo(b.fecha ?? DateTime(0)));
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.timeline_outlined,
            titulo: 'Tu evolución',
            subtitulo: 'Nivel sugerido en tus últimas preconsultas.',
            iconColor: AppColors.purple,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 1,
                maxY: 5,
                minX: 0,
                maxX: (ordenados.length - 1).toDouble().clamp(1, 999),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
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
                      reservedSize: 22,
                      interval: (ordenados.length / 4)
                          .ceilToDouble()
                          .clamp(1, 999)
                          .toDouble(),
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (i < 0 || i >= ordenados.length) {
                          return const SizedBox.shrink();
                        }
                        final fecha = ordenados[i].fecha;
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
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < ordenados.length; i++)
                        FlSpot(
                          i.toDouble(),
                          (ordenados[i].triageNivel ?? 3).toDouble(),
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
          const SizedBox(height: 12),
          for (final p in puntos.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: nivelColor(p.triageNivel),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      p.triageNivel?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      p.resumen.isNotEmpty
                          ? p.resumen
                          : nivelEtiqueta(p.triageNivel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.dark, fontSize: 11.5),
                    ),
                  ),
                  Text(
                    p.fecha == null
                        ? '—'
                        : DateFormat('d MMM', 'es').format(p.fecha!),
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
