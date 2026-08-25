import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../data/models/appointment.dart';
import '../../state/auth_provider.dart';
import '../../state/clinic_provider.dart';
import 'patients/patient_detail_page.dart';
import 'clinical/consult_form_page.dart';

/// Panel del médico: citas de hoy + acceso a información clínica (Ejercicio 9).
class DoctorPanelPage extends StatelessWidget {
  const DoctorPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final clinic = context.watch<ClinicProvider>();
    final doctorId = auth.currentUser?.doctorId;
    if (doctorId == null) {
      return const Center(child: Text('Sin médico asignado'));
    }
    final doctor = clinic.doctorById(doctorId);
    final today = clinic
        .appointmentsOfDoctor(doctorId)
        .where((a) =>
            a.date.year == DateTime.now().year &&
            a.date.month == DateTime.now().month &&
            a.date.day == DateTime.now().day &&
            a.status != AppointmentStatus.cancelada)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryLight]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(Icons.medical_services_outlined, color: AppColors.primaryDark, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bienvenido/a', style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 13)),
                    Text(
                      doctor.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Tienes ${today.length} cita(s) hoy',
                      style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Citas de hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.dark)),
        const SizedBox(height: 12),
        if (today.isEmpty)
          const AppEmptyState(
            icon: Icons.event_available_outlined,
            title: 'No tienes citas hoy',
            subtitle: 'Disfruta el descanso o revisa tus pacientes.',
          )
        else
          for (final a in today) _AppointmentCard(appointment: a),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final patient = clinic.patientById(appointment.patientId);
    final hasPendingConsult = !clinic
        .historyOf(patient.id)
        .any((c) =>
            c.doctorId == appointment.doctorId &&
            c.date.year == appointment.date.year &&
            c.date.month == appointment.date.month &&
            c.date.day == appointment.date.day);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    appointment.time,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
                      Text(appointment.reason, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                AppStatusBadge(status: appointment.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PatientDetailPage(patientId: patient.id),
                      ),
                    ),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Historia clínica'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: hasPendingConsult
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConsultFormPage(patientId: patient.id),
                              ),
                            )
                        : null,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Registrar consulta'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}