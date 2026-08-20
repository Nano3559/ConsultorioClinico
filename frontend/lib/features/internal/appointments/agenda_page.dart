import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/responsive_row.dart';
import '../../../state/clinic_provider.dart';
import 'appointment_actions.dart';

/// Agenda médica diaria (Ejercicio 4).
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  DateTime _date = DateTime.now();
  String? _doctorFilter;

  void _changeDate(int days) {
    setState(() => _date = _date.add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final list = clinic.appointmentsOfDay(_date).where((a) {
      if (_doctorFilter != null && a.doctorId != _doctorFilter) return false;
      return true;
    }).toList();

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _changeDate(-1),
              visualDensity: VisualDensity.compact,
              iconSize: isMobile ? 22 : 24,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: Column(
                  children: [
                    Text(
                      AppFormatters.day(_date),
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                    Text(
                      '${_date.day}/${_date.month}/${_date.year}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: () => _changeDate(1),
              visualDensity: VisualDensity.compact,
              iconSize: isMobile ? 22 : 24,
              icon: const Icon(Icons.chevron_right),
            ),
            if (_date.day != DateTime.now().day ||
                _date.month != DateTime.now().month)
              TextButton(
                onPressed: () => setState(() => _date = DateTime.now()),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Hoy'),
              ),
          ],
        ),
        SizedBox(height: isMobile ? 6 : 8),
        ResponsiveRow(
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _doctorFilter,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Filtrar por médico'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos los médicos')),
                for (final d in clinic.activeDoctors)
                  DropdownMenuItem(value: d.id, child: Text(d.displayName)),
              ],
              onChanged: (v) => setState(() => _doctorFilter = v),
            ),
            FilledButton.icon(
              onPressed: () => context.push('/solicitar-cita'),
              icon: const Icon(Icons.add),
              label: const Text('Nueva cita'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: AppEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Sin citas este día',
              subtitle: 'Usa "Nueva cita" para agendar un turno.',
            ),
          )
        else if (MediaQuery.sizeOf(context).width >= 840)
          AppTable(
            headers: const ['Hora', 'Paciente', 'Médico', 'Motivo', 'Estado', ''],
            rows: [
              for (final a in list)
                [
                  TableText(a.time, bold: true),
                  TableText(clinic.patientName(a.patientId)),
                  TableText(clinic.doctorName(a.doctorId)),
                  TableText(a.reason),
                  AppStatusBadge(status: a.status),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.muted),
                    onPressed: () => showAppointmentActions(context, clinic, a),
                  ),
                ],
            ],
          )
        else
          for (final a in list)
            Card(
              margin: EdgeInsets.only(bottom: isMobile ? 6 : 10),
              child: ListTile(
                dense: isMobile,
                contentPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 10, vertical: 2) : null,
                leading: Container(
                  width: isMobile ? 46 : 64,
                  height: isMobile ? 32 : 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a.time,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      fontSize: isMobile ? 12 : 13,
                    ),
                  ),
                ),
                title: Text(
                  clinic.patientName(a.patientId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark, fontSize: isMobile ? 14 : 16),
                ),
                subtitle: Text(
                  '${clinic.doctorName(a.doctorId)} — ${a.reason}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppStatusBadge(status: a.status),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: AppColors.muted),
                      onPressed: () => showAppointmentActions(context, clinic, a),
                    ),
                  ],
                ),
                onTap: () => showAppointmentActions(context, clinic, a),
              ),
            ),
      ],
    );
  }
}