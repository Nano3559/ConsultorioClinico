import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_stat_card.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../state/clinic_provider.dart';

/// Panel administrativo con resumen del consultorio (Ejercicio 10).
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final today = clinic.appointmentsOfDay(DateTime.now());
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;
    final columns = isMobile ? 2 : 4;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      children: [
        Text(
          'Resumen del día',
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        SizedBox(height: isMobile ? 2 : 4),
        Text(
          'Estado general del consultorio en tiempo real.',
          style: TextStyle(color: AppColors.muted, fontSize: isMobile ? 13 : 14),
        ),
        SizedBox(height: isMobile ? 12 : 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardW = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Pacientes registrados', value: '${clinic.totalPatients}', icon: Icons.group_outlined, compact: isMobile),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Citas hoy', value: '${clinic.appointmentsToday}', icon: Icons.event_available_outlined, color: AppColors.info, compact: isMobile),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Pendientes', value: '${clinic.countByStatusToday(AppointmentStatus.pendiente)}', icon: Icons.pending_outlined, color: AppColors.warning, compact: isMobile),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Atendidas', value: '${clinic.countByStatusToday(AppointmentStatus.atendida)}', icon: Icons.task_alt_outlined, color: AppColors.success, compact: isMobile),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Canceladas', value: '${clinic.countByStatus(AppointmentStatus.cancelada)}', icon: Icons.cancel_outlined, color: AppColors.danger, compact: isMobile),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Médicos activos', value: '${clinic.activeDoctorCount}', icon: Icons.medical_services_outlined, color: AppColors.purple, compact: isMobile),
                ),
              ],
            );
          },
        ),
        SizedBox(height: isMobile ? 12 : 24),
        _TodayAppointments(today: today),
      ],
    );
  }
}

class _TodayAppointments extends StatelessWidget {
  const _TodayAppointments({required this.today});

  final List<dynamic> today;

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Citas de hoy',
            style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w800, color: AppColors.dark),
          ),
          const SizedBox(height: 12),
          if (today.isEmpty)
            const AppEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Sin citas para hoy',
              subtitle: 'Cuando se agenden citas aparecerán aquí.',
            )
          else if (isMobile)
            for (final a in today)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  leading: Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a.time,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontSize: 12),
                    ),
                  ),
                  title: Text(clinic.patientName(a.patientId), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark, fontSize: 14)),
                  subtitle: Text('${clinic.doctorName(a.doctorId)} · ${a.reason}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  trailing: AppStatusBadge(status: a.status),
                ),
              )
          else
            Table(
              columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2), 4: FlexColumnWidth(1.4)},
              border: const TableBorder(horizontalInside: BorderSide(color: AppColors.border)),
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: AppColors.background),
                  children: [
                    _THeader('Hora'),
                    _THeader('Paciente'),
                    _THeader('Médico'),
                    _THeader('Motivo'),
                    _THeader('Estado'),
                  ],
                ),
                for (final a in today)
                  TableRow(
                    children: [
                      _TCell(Text(a.time, style: const TextStyle(fontWeight: FontWeight.w700))),
                      _TCell(Text(clinic.patientName(a.patientId))),
                      _TCell(Text(clinic.doctorName(a.doctorId))),
                      _TCell(Text(a.reason, maxLines: 2, overflow: TextOverflow.ellipsis)),
                      _TCell(AppStatusBadge(status: a.status)),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _THeader extends StatelessWidget {
  const _THeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(10),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.dark, fontSize: 13)),
      );
}

class _TCell extends StatelessWidget {
  const _TCell(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(10),
        child: child,
      );
}