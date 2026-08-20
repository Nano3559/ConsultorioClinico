import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../data/models/appointment.dart';
import '../../data/models/patient.dart';
import '../../state/auth_provider.dart';
import '../../state/clinic_provider.dart';

/// Vista del paciente: sus citas y cancelación según reglas.
class PatientMyAppointmentsPage extends StatelessWidget {
  const PatientMyAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final clinic = context.watch<ClinicProvider>();
    final user = auth.currentUser;

    // El usuario paciente se asocia por correo al paciente ficticio.
    Patient? patient;
    for (final p in clinic.patients) {
      if (p.email == user?.email) {
        patient = p;
        break;
      }
    }
    if (patient == null && clinic.patients.isNotEmpty) patient = clinic.patients.first;
    final List<Appointment> list =
        patient == null ? const [] : clinic.appointmentsOfPatient(patient.id);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Mis citas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.dark)),
        const SizedBox(height: 4),
        const Text('Consulta y gestiona tus turnos.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        if (patient == null)
          const AppEmptyState(icon: Icons.person_off_outlined, title: 'Paciente no encontrado')
        else if (list.isEmpty)
          const AppEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No tienes citas',
            subtitle: 'Solicita una cita para empezar.',
            action: null,
          )
        else
          for (final a in list)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(a.time, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                      Text('${a.date.day}/${a.date.month}', style: const TextStyle(fontSize: 11, color: AppColors.primaryDark)),
                    ],
                  ),
                ),
                title: Text(clinic.doctorName(a.doctorId), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
                subtitle: Text(a.reason),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppStatusBadge(status: a.status),
                    if (a.status == AppointmentStatus.pendiente ||
                        a.status == AppointmentStatus.confirmada)
                      TextButton(
                        onPressed: () => _confirmCancel(context, clinic, a.id),
                        child: const Text('Cancelar', style: TextStyle(color: AppColors.danger)),
                      ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.push('/solicitar-cita'),
          icon: const Icon(Icons.add),
          label: const Text('Solicitar nueva cita'),
        ),
      ],
    );
  }

  void _confirmCancel(BuildContext context, ClinicProvider clinic, String id) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: const Text('¿Deseas cancelar esta cita? El horario quedará disponible para otros pacientes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              clinic.cancelAppointment(id);
            },
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }
}