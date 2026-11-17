import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_stat_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/preconsulta.dart';
import '../../state/preconsulta_provider.dart';
import 'widgets/preconsulta_ui.dart';

/// Panel de métricas agregadas de la PreConsulta IA para dirección y
/// coordinación clínica: volumen, distribución de niveles, tiempos, motivos
/// y banderas más frecuentes.
class PreconsultaMetricsPage extends StatefulWidget {
  const PreconsultaMetricsPage({super.key});

  @override
  State<PreconsultaMetricsPage> createState() => _PreconsultaMetricsPageState();
}

class _PreconsultaMetricsPageState extends State<PreconsultaMetricsPage> {
  int _dias = 30;
  bool _cargado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final prov = context.read<PreconsultaProvider>();
    await prov.cargarMetricas(dias: _dias);
    if (mounted) setState(() => _cargado = true);
  }

  Future<void> _cambiarPeriodo(int dias) async {
    if (_dias == dias) return;
    setState(() => _dias = dias);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PreconsultaProvider>();
    final m = prov.metricas;
    final ancho = MediaQuery.sizeOf(context).width;
    final compacto = ancho < 720;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PageHeader(
            title: 'Métricas de PreConsulta IA',
            subtitle:
                'Volumen, prioridad y trazabilidad del triage asistido. Datos agregados, sin imágenes.',
            icon: Icons.insights_outlined,
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Periodo:',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final dias in const [7, 30, 90])
                _PeriodoChip(
                  etiqueta: '$dias días',
                  activo: _dias == dias,
                  onTap: () => _cambiarPeriodo(dias),
                ),
              if (m != null)
                Text(
                  '${_fechaCorta(m.desde)} — ${_fechaCorta(m.hasta)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_cargado && prov.cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (prov.error != null && m == null)
            PreconsultaCard(
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined,
                      size: 40, color: AppColors.danger),
                  const SizedBox(height: 10),
                  Text(
                    prov.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _cargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else if (m == null)
            const PreconsultaCard(
              child: AppEmptyState(
                icon: Icons.insights_outlined,
                title: 'Sin métricas todavía',
                subtitle: 'No hay datos agregados para el periodo seleccionado.',
              ),
            )
          else
            _contenido(m, compacto, ancho),
        ],
      ),
    );
  }

  Widget _contenido(MetricasPreconsulta m, bool compacto, double ancho) {
    final anchoStat = compacto ? (ancho - 52) / 2 : 236.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatTile(
              width: anchoStat,
              child: AppStatCard(
                label: 'Preconsultas',
                value: '${m.total}',
                icon: Icons.assignment_outlined,
                color: AppColors.primary,
              ),
            ),
            _StatTile(
              width: anchoStat,
              child: AppStatCard(
                label: 'Completadas',
                value: '${m.completadas}',
                icon: Icons.task_alt_outlined,
                color: AppColors.success,
              ),
            ),
            _StatTile(
              width: anchoStat,
              child: AppStatCard(
                label: 'Críticas (N1-N2)',
                value: '${m.criticas}',
                icon: Icons.priority_high,
                color: AppColors.danger,
              ),
            ),
            _StatTile(
              width: anchoStat,
              child: AppStatCard(
                label: 'Revisadas por personal',
                value: '${m.tasaRevision.toStringAsFixed(1)}%',
                icon: Icons.fact_check_outlined,
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DosColumnas(
          izquierda: _Distribucion(m: m),
          derecha: _SerieDiaria(m: m),
        ),
        const SizedBox(height: 14),
        _DosColumnas(
          izquierda: _ListaFrecuentes(
            titulo: 'Motivos más frecuentes',
            subtitulo: 'Factores del cuestionario y de la captura.',
            icono: Icons.list_alt_outlined,
            color: AppColors.primary,
            items: m.topMotivos,
            vacio: 'Sin motivos registrados en el periodo.',
          ),
          derecha: _ListaFrecuentes(
            titulo: 'Banderas clínicas',
            subtitulo: 'Señales que dispararon alertas.',
            icono: Icons.flag_outlined,
            color: AppColors.warning,
            items: m.topBanderas,
            vacio: 'Sin banderas clínicas en el periodo.',
          ),
        ),
        const SizedBox(height: 14),
        _ResumenOperativo(m: m),
        const SizedBox(height: 14),
        const AvisoClinico(compact: true),
      ],
    );
  }

  String _fechaCorta(String valor) {
    final fecha = DateTime.tryParse(valor);
    if (fecha == null) return valor;
    return DateFormat('d MMM yyyy', 'es').format(fecha);
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

class _PeriodoChip extends StatelessWidget {
  const _PeriodoChip({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? AppColors.primary : AppColors.border,
          ),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          etiqueta,
          style: TextStyle(
            color: activo ? Colors.white : AppColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

class _Distribucion extends StatelessWidget {
  const _Distribucion({required this.m});

  final MetricasPreconsulta m;

  @override
  Widget build(BuildContext context) {
    final dist = m.distribucion.where((d) => d.nivel >= 1 && d.nivel <= 5).toList()
      ..sort((a, b) => a.nivel.compareTo(b.nivel));
    final maxY = dist.isEmpty
        ? 4.0
        : dist
                .map((d) => d.total.toDouble())
                .reduce((a, b) => a > b ? a : b) *
            1.25;
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.stacked_bar_chart_outlined,
            titulo: 'Distribución por nivel',
            subtitulo: 'Cuántas preconsultas quedaron en cada prioridad.',
          ),
          const SizedBox(height: 16),
          if (m.total == 0)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'Sin datos de nivel en el periodo.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: maxY <= 0 ? 4 : maxY,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
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
                        reservedSize: 26,
                        interval: (maxY / 4).ceilToDouble().clamp(1, 9999).toDouble(),
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
                        reservedSize: 44,
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i >= dist.length) {
                            return const SizedBox.shrink();
                          }
                          final d = dist[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: nivelColor(d.nivel),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${d.nivel}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.total}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final d = dist[group.x];
                        return BarTooltipItem(
                          'Nivel ${d.nivel} · ${d.etiqueta}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${d.total} preconsultas · ${d.porcentaje.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < dist.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: dist[i].total.toDouble(),
                            width: 26,
                            borderRadius: BorderRadius.circular(6),
                            color: nivelColor(dist[i].nivel),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY <= 0 ? 4 : maxY,
                              color: AppColors.background,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          for (final d in dist)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: nivelColor(d.nivel),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Nivel ${d.nivel} · ${d.etiqueta}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11),
                    ),
                  ),
                  Text(
                    '${d.porcentaje.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppColors.dark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

class _SerieDiaria extends StatelessWidget {
  const _SerieDiaria({required this.m});

  final MetricasPreconsulta m;

  @override
  Widget build(BuildContext context) {
    final serie = m.serieDiaria;
    final maxY = serie.isEmpty
        ? 4.0
        : serie.map((d) => d.total.toDouble()).reduce((a, b) => a > b ? a : b);
    final tope = maxY <= 0 ? 4.0 : maxY * 1.2;
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.show_chart_outlined,
            titulo: 'Actividad diaria',
            subtitulo: 'Volumen de preconsultas y cuántas resultaron críticas.',
            iconColor: AppColors.info,
          ),
          const SizedBox(height: 16),
          if (serie.isEmpty)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'Sin actividad en el periodo.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (serie.length - 1).toDouble().clamp(1, 999),
                  minY: 0,
                  maxY: tope,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
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
                        reservedSize: 26,
                        interval: (tope / 4).ceilToDouble().clamp(1, 9999).toDouble(),
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
                        interval: (serie.length / 4)
                            .ceilToDouble()
                            .clamp(1, 999)
                            .toDouble(),
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i >= serie.length) {
                            return const SizedBox.shrink();
                          }
                          final fecha = DateTime.tryParse(serie[i].fecha);
                          return Text(
                            fecha == null
                                ? serie[i].fecha
                                : '${fecha.day}/${fecha.month}',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 9),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((spot) {
                        final i = spot.x.round();
                        if (i < 0 || i >= serie.length) return null;
                        final d = serie[i];
                        return LineTooltipItem(
                          '${d.fecha}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${d.total} total · ${d.completadas} completadas\n${d.criticas} críticas · ${d.revisadas} revisadas',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < serie.length; i++)
                          FlSpot(i.toDouble(), serie[i].total.toDouble()),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.22,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < serie.length; i++)
                          FlSpot(i.toDouble(), serie[i].criticas.toDouble()),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.22,
                      color: AppColors.danger,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: const [
              _Leyenda(color: AppColors.primary, texto: 'Total'),
              _Leyenda(color: AppColors.danger, texto: 'Críticas (N1-N2)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          texto,
          style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _ListaFrecuentes extends StatelessWidget {
  const _ListaFrecuentes({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.items,
    required this.vacio,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final List<MotivoFrecuente> items;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final maximo = items.isEmpty
        ? 1
        : items.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeccionTitulo(
            icono: icono,
            titulo: titulo,
            subtitulo: subtitulo,
            iconColor: color,
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              vacio,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            )
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.etiqueta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.dark,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.total}',
                          style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: maximo == 0 ? 0 : item.total / maximo,
                        minHeight: 5,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
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

class _ResumenOperativo extends StatelessWidget {
  const _ResumenOperativo({required this.m});

  final MetricasPreconsulta m;

  @override
  Widget build(BuildContext context) {
    final canal = m.porCanal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return PreconsultaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionTitulo(
            icono: Icons.analytics_outlined,
            titulo: 'Indicadores operativos',
            subtitulo:
                'Calidad de captura, confianza del triage y tiempos del análisis.',
            iconColor: AppColors.purple,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Indicador(
                etiqueta: 'Nivel medio',
                valor: m.promedioNivel == null
                    ? '—'
                    : m.promedioNivel!.toStringAsFixed(2),
                icono: Icons.speed_outlined,
                color: AppColors.primary,
              ),
              _Indicador(
                etiqueta: 'Calidad media',
                valor: m.promedioCalidad == null
                    ? '—'
                    : '${m.promedioCalidad!.toStringAsFixed(0)}/100',
                icono: Icons.center_focus_strong_outlined,
                color: AppColors.info,
              ),
              _Indicador(
                etiqueta: 'Confianza media',
                valor: m.promedioConfianza == null
                    ? '—'
                    : '${(m.promedioConfianza! * 100).toStringAsFixed(0)}%',
                icono: Icons.verified_outlined,
                color: AppColors.purple,
              ),
              _Indicador(
                etiqueta: 'Tiempo de análisis',
                valor: m.tiempoPromedioAnalisisSeg == null
                    ? '—'
                    : '${m.tiempoPromedioAnalisisSeg!.toStringAsFixed(1)} s',
                icono: Icons.timer_outlined,
                color: AppColors.warning,
              ),
              _Indicador(
                etiqueta: 'Sin revisar',
                valor: '${m.sinRevision}',
                icono: Icons.rate_review_outlined,
                color: m.sinRevision > 0 ? AppColors.danger : AppColors.success,
              ),
              _Indicador(
                etiqueta: 'Con banderas',
                valor: '${m.conBanderas}',
                icono: Icons.flag_outlined,
                color: AppColors.warning,
              ),
            ],
          ),
          if (canal.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Origen de las preconsultas',
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in canal)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconoCanal(c.key),
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          '${_etiquetaCanal(c.key)}: ${c.value}',
                          style: const TextStyle(
                            color: AppColors.dark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _etiquetaCanal(String canal) {
    switch (canal) {
      case 'web':
        return 'Navegador';
      case 'android':
        return 'App Android';
      case 'recepcion':
        return 'Recepción';
      case 'tablet':
        return 'Tablet';
      default:
        return canal;
    }
  }

  static IconData _iconoCanal(String canal) {
    switch (canal) {
      case 'android':
        return Icons.phone_android_outlined;
      case 'recepcion':
        return Icons.support_agent_outlined;
      case 'tablet':
        return Icons.tablet_android_outlined;
      default:
        return Icons.language_outlined;
    }
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.color,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, size: 15, color: color),
          ),
          const SizedBox(width: 8),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
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
