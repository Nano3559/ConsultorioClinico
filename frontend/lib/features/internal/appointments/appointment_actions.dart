import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../data/models/appointment.dart';
import '../../../state/clinic_provider.dart';
import '../clinical/consult_form_page.dart';

/// Acciones disponibles para una cita según su estado (Ejercicio 8).
void showAppointmentActions(
  BuildContext context,
  ClinicProvider clinic,
  Appointment a,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final alreadyDone = a.status == AppointmentStatus.atendida ||
          a.status == AppointmentStatus.cancelada ||
          a.status == AppointmentStatus.noAsistio;
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.event, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${clinic.patientName(a.patientId)} · ${a.time}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.dark),
                        ),
                        Text(
                          '${clinic.doctorName(a.doctorId)} — ${AppFormatters.shortDate(a.date)}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  AppStatusBadge(status: a.status),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!alreadyDone) ...[
              ListTile(
                leading: const Icon(Icons.event_available, color: AppColors.info),
                title: const Text('Confirmar cita'),
                onTap: () {
                  Navigator.pop(ctx);
                  clinic.setAppointmentStatus(a.id, AppointmentStatus.confirmada);
                },
              ),
              ListTile(
                leading: const Icon(Icons.task_alt, color: AppColors.success),
                title: const Text('Marcar como atendida'),
                onTap: () {
                  Navigator.pop(ctx);
                  clinic.setAppointmentStatus(a.id, AppointmentStatus.atendida);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.medical_services_outlined, color: AppColors.primary),
              title: const Text('Registrar consulta'),
              subtitle: const Text('Abre la historia clínica y registra la consulta.'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConsultFormPage(patientId: a.patientId),
                  ),
                );
              },
            ),
            if (!alreadyDone) ...[
              ListTile(
                leading: const Icon(Icons.schedule_outlined, color: AppColors.warning),
                title: const Text('Reprogramar cita'),
                onTap: () {
                  Navigator.pop(ctx);
                  _reschedule(ctx, clinic, a);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                title: const Text('Cancelar cita'),
                subtitle: const Text('El horario quedará disponible nuevamente.'),
                onTap: () {
                  Navigator.pop(ctx);
                  clinic.cancelAppointment(a.id);
                },
              ),
            ],
            if (a.status == AppointmentStatus.cancelada ||
                a.status == AppointmentStatus.noAsistio) ...[
              ListTile(
                leading: const Icon(Icons.undo, color: AppColors.primary),
                title: const Text('Restaurar a pendiente'),
                onTap: () {
                  Navigator.pop(ctx);
                  clinic.setAppointmentStatus(a.id, AppointmentStatus.pendiente);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  },
);
}

void _reschedule(BuildContext context, ClinicProvider clinic, Appointment a) {
  var newDate = a.date;
  var newTime = a.time;
  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final slots = clinic.availableSlots(
          a.doctorId,
          newDate,
        );
        return AlertDialog(
          title: const Text('Reprogramar cita'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: newDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) setState(() => newDate = picked);
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(AppFormatters.shortDate(newDate)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in slots)
                    ChoiceChip(
                      label: Text(t),
                      selected: newTime == t,
                      onSelected: (_) => setState(() => newTime = t),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final err = await clinic.rescheduleAppointment(a.id, newDate, newTime);
                Navigator.pop(ctx);
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    ),
  );
}