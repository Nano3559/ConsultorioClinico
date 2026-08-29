import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_row.dart';
import '../../../data/models/appointment.dart';
import '../../../data/models/consult_record.dart';
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
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final all = clinic.appointments.toList()..sort((a, b) => b.date.compareTo(a.date));
    final list = all.where((a) {
      if (_statusFilter != null && a.status != _statusFilter) return false;
      if (_doctorFilter != null && a.doctorId != _doctorFilter) return false;
      final q = _search.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final hay = '${clinic.patientName(a.patientId)} ${a.reason} ${clinic.doctorName(a.doctorId)}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      children: [
        PageHeader(
          title: 'Citas',
          subtitle: 'Gestiona las citas del consultorio.',
          icon: Icons.event_note_outlined,
          count: clinic.appointments.length,
          actions: [
            FilledButton.icon(
              onPressed: () => context.push('/solicitar-cita'),
              icon: const Icon(Icons.add),
              label: const Text('Nueva cita'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Buscar paciente, médico o motivo',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
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
            headers: const ['Fecha', 'Hora', 'Paciente', 'Médico', 'Motivo', 'Tratamiento', 'Estado', ''],
            rows: [
              for (final a in list) _appointmentRow(context, clinic, a),
            ],
          )
        else
          for (final a in list) _AppointmentTile(appointment: a),
      ],
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment});

  final dynamic appointment;

  @override
  Widget build(BuildContext context) {
    final clinic = context.read<ClinicProvider>();
    final a = appointment;
    final consulta = _consultaDe(clinic, a);
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(name: clinic.patientName(a.patientId), radius: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.patientName(a.patientId),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.dark, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${clinic.doctorName(a.doctorId)} · ${a.reason}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${AppFormatters.shortDate(a.date)} · ${a.time}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppStatusBadge(status: a.status),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.muted),
                  onPressed: () => showAppointmentActions(context, clinic, a),
                ),
              ],
            ),
            if (consulta != null) _treatmentBlock(consulta),
          ],
        ),
      ),
    );
  }
}

/// Busca la consulta enlazada a una cita (por cita_id o por coincidencia
/// paciente+médico+fecha como fallback para consultas antiguas).
ConsultRecord? _consultaDe(ClinicProvider clinic, Appointment a) {
  for (final c in clinic.consults) {
    if (c.citaId == a.id) return c;
  }
  for (final c in clinic.consults) {
    if (c.patientId == a.patientId &&
        c.doctorId == a.doctorId &&
        c.date.year == a.date.year &&
        c.date.month == a.date.month &&
        c.date.day == a.date.day) {
      return c;
    }
  }
  return null;
}

List<Widget> _appointmentRow(BuildContext context, ClinicProvider clinic, Appointment a) {
  final c = _consultaDe(clinic, a);
  return [
    TableText(AppFormatters.shortDate(a.date)),
    TableText(a.time, bold: true),
    TableText(clinic.patientName(a.patientId)),
    TableText(clinic.doctorName(a.doctorId)),
    TableText(a.reason),
    TableText(c != null ? '${c.diagnostico} — ${c.tratamiento}' : '—'),
    AppStatusBadge(status: a.status),
    IconButton(
      icon: const Icon(Icons.more_vert, color: AppColors.muted),
      onPressed: () => showAppointmentActions(context, clinic, a),
    ),
  ];
}

Widget _treatmentBlock(ConsultRecord c) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tratamiento indicado',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
        ),
        const SizedBox(height: 4),
        Text('Diagnóstico: ${c.diagnostico}', style: const TextStyle(fontSize: 13, height: 1.4)),
        Text('Tratamiento: ${c.tratamiento}', style: const TextStyle(fontSize: 13, height: 1.4)),
        if (c.observaciones.isNotEmpty)
          Text('Observaciones: ${c.observaciones}', style: const TextStyle(fontSize: 13, height: 1.4)),
      ],
    ),
  );
}
