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
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Resumen del día', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.dark)),
        const SizedBox(height: 4),
        const Text('Estado general del consultorio en tiempo real.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardW = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Pacientes registrados', value: '${clinic.totalPatients}', icon: Icons.group_outlined),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Citas hoy', value: '${clinic.appointmentsToday}', icon: Icons.event_available_outlined, color: AppColors.info),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Pendientes', value: '${clinic.countByStatusToday(AppointmentStatus.pendiente)}', icon: Icons.pending_outlined, color: AppColors.warning),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Atendidas', value: '${clinic.countByStatusToday(AppointmentStatus.atendida)}', icon: Icons.task_alt_outlined, color: AppColors.success),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Canceladas', value: '${clinic.countByStatus(AppointmentStatus.cancelada)}', icon: Icons.cancel_outlined, color: AppColors.danger),
                ),
                SizedBox(
                  width: cardW,
                  child: AppStatCard(label: 'Médicos activos', value: '${clinic.activeDoctorCount}', icon: Icons.medical_services_outlined, color: AppColors.purple),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Citas de hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.dark)),
          const SizedBox(height: 12),
          if (today.isEmpty)
            const AppEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Sin citas para hoy',
              subtitle: 'Cuando se agenden citas aparecerán aquí.',
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