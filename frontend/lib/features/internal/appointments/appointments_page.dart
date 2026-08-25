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

/// Gestión general de citas (Ejercicio 8): crear, confirmar, cancelar, etc.
class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  AppointmentStatus? _statusFilter;
  String? _doctorFilter;

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final all = clinic.appointments.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final list = all.where((a) {
      if (_statusFilter != null && a.status != _statusFilter) return false;
      if (_doctorFilter != null && a.doctorId != _doctorFilter) return false;
      return true;
    }).toList();

    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      children: [
        ResponsiveRow(
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _doctorFilter,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Médico'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final d in clinic.doctors)
                  DropdownMenuItem(value: d.id, child: Text(d.displayName)),
              ],
              onChanged: (v) => setState(() => _doctorFilter = v),
            ),
            DropdownButtonFormField<AppointmentStatus?>(
              initialValue: _statusFilter,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final s in AppointmentStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _statusFilter = v),
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
            child: AppEmptyState(icon: Icons.event_note_outlined, title: 'Sin citas con esos filtros'),
          )
        else if (isWide)
          AppTable(
            headers: const ['Fecha', 'Hora', 'Paciente', 'Médico', 'Motivo', 'Estado', ''],
            rows: [
              for (final a in list)
                [
                  TableText(AppFormatters.shortDate(a.date)),
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
                leading: AppStatusBadge(status: a.status),
                title: Text(
                  clinic.patientName(a.patientId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark, fontSize: isMobile ? 14 : 16),
                ),
                subtitle: Text(
                  '${AppFormatters.shortDate(a.date)} · ${a.time} · ${clinic.doctorName(a.doctorId)}\n${a.reason}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.muted),
                  onPressed: () => showAppointmentActions(context, clinic, a),
                ),
              ),
            ),
      ],
    );
  }
}