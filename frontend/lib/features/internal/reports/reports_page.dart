import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/responsive_row.dart';
import '../../../data/models/payment.dart';
import '../../../state/clinic_provider.dart';

/// Reportes y estadísticas con filtros (Ejercicio 12).
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now().add(const Duration(days: 7));
  String? _doctorFilter;
  String? _specialtyFilter;
  AppointmentStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final filtered = clinic.appointments.where((a) {
      if (a.date.isBefore(DateTime(_desde.year, _desde.month, _desde.day))) return false;
      if (a.date.isAfter(DateTime(_hasta.year, _hasta.month, _hasta.day).add(const Duration(days: 1)))) return false;
      if (_doctorFilter != null && a.doctorId != _doctorFilter) return false;
      if (_specialtyFilter != null && clinic.doctorById(a.doctorId).specialtyId != _specialtyFilter) return false;
      if (_statusFilter != null && a.status != _statusFilter) return false;
      return true;
    }).toList();

    final ingresos = clinic.payments.where((p) {
      if (p.status != PaymentStatus.pagado) return false;
      if (p.date.isBefore(_desde) || p.date.isAfter(_hasta)) return false;
      return true;
    }).fold<double>(0, (s, p) => s + p.amount);

    final byDay = <DateTime, int>{};
    for (final a in filtered) {
      final day = DateTime(a.date.year, a.date.month, a.date.day);
      byDay[day] = (byDay[day] ?? 0) + 1;
    }
    final byDoctor = <String, int>{};
    for (final a in filtered) {
      byDoctor[clinic.doctorName(a.doctorId)] = (byDoctor[clinic.doctorName(a.doctorId)] ?? 0) + 1;
    }
    final bySpecialty = <String, int>{};
    for (final a in filtered) {
      final name = clinic.specialtyById(clinic.doctorById(a.doctorId).specialtyId).name;
      bySpecialty[name] = (bySpecialty[name] ?? 0) + 1;
    }
    final byStatus = <AppointmentStatus, int>{};
    for (final a in filtered) {
      byStatus[a.status] = (byStatus[a.status] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Reportes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.dark)),
        const SizedBox(height: 4),
        const Text('Citas, ingresos y tendencias con filtros.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        _Filters(
          desde: _desde,
          hasta: _hasta,
          onRange: (d, h) => setState(() {
            _desde = d;
            _hasta = h;
          }),
          onDoctor: (v) => setState(() => _doctorFilter = v),
          onSpecialty: (v) => setState(() => _specialtyFilter = v),
          onStatus: (v) => setState(() => _statusFilter = v),
        ),
        const SizedBox(height: 16),
        ResponsiveRow(
          children: [
            _MetricCard(label: 'Citas en el rango', value: '${filtered.length}', icon: Icons.event_note_outlined, color: AppColors.info),
            _MetricCard(label: 'Ingresos cobrados', value: AppFormatters.money(ingresos), icon: Icons.payments_outlined, color: AppColors.success),
          ],
        ),
        const SizedBox(height: 20),
        _ChartCard(
          title: 'Citas por día',
          child: SizedBox(
            height: 240,
            child: byDay.isEmpty
                ? const Center(child: Text('Sin datos en el rango', style: TextStyle(color: AppColors.muted)))
                : BarChart(
                    BarChartData(
                      maxY: (byDay.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                      barGroups: [
                        for (final e in byDay.entries)
                          BarChartGroupData(
                            x: e.key.millisecondsSinceEpoch ~/ 86400000,
                            barRods: [
                              BarChartRodData(
                                toY: e.value.toDouble(),
                                color: AppColors.primary,
                                width: 18,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              final d = DateTime.fromMillisecondsSinceEpoch((v * 86400000).round());
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${d.day}/${d.month}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        ResponsiveRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChartCard(
              title: 'Citas por médico',
              child: SizedBox(
                height: 220,
                child: byDoctor.isEmpty
                    ? const Center(child: Text('Sin datos', style: TextStyle(color: AppColors.muted)))
                    : ListView.builder(
                        itemCount: byDoctor.length,
                        itemBuilder: (ctx, i) {
                          final e = byDoctor.entries.elementAt(i);
                          final max = byDoctor.values.reduce((a, b) => a > b ? a : b);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(width: 90, child: Text(e.key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(height: 18, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6))),
                                      FractionallySizedBox(
                                        widthFactor: e.value / max,
                                        child: Container(height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6))),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            _ChartCard(
              title: 'Citas por especialidad',
              child: SizedBox(
                height: 220,
                child: bySpecialty.isEmpty
                    ? const Center(child: Text('Sin datos', style: TextStyle(color: AppColors.muted)))
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: [
                            for (var i = 0; i < bySpecialty.entries.length; i++)
                              PieChartSectionData(
                                value: bySpecialty.entries.elementAt(i).value.toDouble(),
                                title: bySpecialty.entries.elementAt(i).key,
                                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                color: AppColors.accentPool[i % AppColors.accentPool.length],
                                radius: 46,
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ChartCard(
          title: 'Distribución por estado',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in byStatus.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: e.key.bg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key.label, style: TextStyle(color: e.key.color, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.dark)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.desde,
    required this.hasta,
    required this.onRange,
    required this.onDoctor,
    required this.onSpecialty,
    required this.onStatus,
  });

  final DateTime desde;
  final DateTime hasta;
  final void Function(DateTime, DateTime) onRange;
  final ValueChanged<String?> onDoctor;
  final ValueChanged<String?> onSpecialty;
  final ValueChanged<AppointmentStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ResponsiveRow(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: desde,
                    firstDate: DateTime(2015),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) onRange(d, hasta);
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text('Desde: ${AppFormatters.shortDate(desde)}'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: hasta,
                    firstDate: DateTime(2015),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) onRange(desde, d);
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text('Hasta: ${AppFormatters.shortDate(hasta)}'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ResponsiveRow(
            children: [
              DropdownButtonFormField<String?>(
                initialValue: null,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Médico'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final d in clinic.doctors)
                    DropdownMenuItem(value: d.id, child: Text(d.displayName)),
                ],
                onChanged: (v) => onDoctor(v),
              ),
              DropdownButtonFormField<String?>(
                initialValue: null,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Especialidad'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final s in clinic.specialties)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => onSpecialty(v),
              ),
              DropdownButtonFormField<AppointmentStatus?>(
                initialValue: null,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final s in AppointmentStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => onStatus(v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.dark)),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.dark)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}