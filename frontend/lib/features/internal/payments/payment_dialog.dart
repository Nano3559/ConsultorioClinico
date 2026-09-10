import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../data/models/appointment.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/user.dart';
import '../../../data/mock/mock_data.dart';
import '../../../state/auth_provider.dart';
import '../../../state/clinic_provider.dart';

/// Abre el diálogo para registrar un pago.
///
/// Si se pasa [appointment], el pago queda vinculado a esa cita y los campos
/// de paciente/médico/monto se precargan y bloquean (cobro en recepción antes
/// de atender).
Future<void> showRegisterPaymentDialog(
  BuildContext context,
  ClinicProvider clinic, {
  Appointment? appointment,
}) async {
  final auth = context.read<AuthProvider>();
  final isMedico = auth.currentUser?.role == UserRole.medico;
  final locked = appointment != null;

  String? patientId = appointment?.patientId;
  String? doctorId =
      appointment?.doctorId ?? (isMedico ? auth.currentUser?.doctorId : null);
  String? citaId = appointment?.id;
  final amountCtrl =
      TextEditingController(text: MockData.consultPrice.toStringAsFixed(2));
  PaymentMethod method = PaymentMethod.efectivo;
  final formKey = GlobalKey<FormState>();

  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final citasDelPaciente = patientId == null
            ? <Appointment>[]
            : clinic.appointments.where((a) => a.patientId == patientId).toList();

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          title: Row(
            children: const [
              Icon(Icons.payments_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Registrar pago', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    value: patientId,
                    decoration: const InputDecoration(
                      labelText: 'Paciente',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    hint: const Text('Selecciona un paciente'),
                    items: [
                      for (final p in clinic.patients)
                        DropdownMenuItem(value: p.id, child: Text(p.fullName)),
                    ],
                    onChanged: locked ? null : (v) => setState(() => patientId = v),
                    validator: (v) => v == null ? 'Selecciona un paciente' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    value: doctorId,
                    decoration: InputDecoration(
                      labelText: 'Médico',
                      prefixIcon: const Icon(Icons.medical_services_outlined),
                      helperText: isMedico ? 'Se registrará a tu nombre' : null,
                    ),
                    items: [
                      for (final d in clinic.activeDoctors)
                        DropdownMenuItem(value: d.id, child: Text(d.displayName)),
                    ],
                    onChanged: (locked || isMedico)
                        ? null
                        : (v) => setState(() => doctorId = v),
                    validator: (v) => v == null ? 'Selecciona un médico' : null,
                  ),
                  if (!locked) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      value: citaId,
                      decoration: const InputDecoration(
                        labelText: 'Cita (opcional)',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      hint: const Text('Sin cita específica'),
                      items: [
                        for (final a in citasDelPaciente)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              '${AppFormatters.shortDate(a.date)} · ${a.time} — ${clinic.doctorName(a.doctorId)}',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        citaId = v;
                        if (v != null) {
                          final a =
                              clinic.appointments.firstWhere((x) => x.id == v);
                          doctorId = a.doctorId;
                          amountCtrl.text = MockData.consultPrice.toStringAsFixed(2);
                        }
                      }),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      prefixIcon: const Icon(Icons.attach_money),
                      helperText:
                          'Precio de consulta: ${AppFormatters.money(MockData.consultPrice)}',
                      hintText: '0.00',
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Monto inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Método de pago',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in PaymentMethod.values)
                        ChoiceChip(
                          selected: method == m,
                          onSelected: (_) => setState(() => method = m),
                          avatar: Icon(
                            m.icon,
                            size: 18,
                            color: method == m ? Colors.white : AppColors.muted,
                          ),
                          label: Text(m.label),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: method == m ? Colors.white : AppColors.dark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (isMedico && doctorId == null) return;
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                clinic.addPayment(Payment(
                  id: 'pay${DateTime.now().millisecondsSinceEpoch}',
                  patientId: patientId!,
                  doctorId: doctorId!,
                  appointmentId: citaId ?? '',
                  amount: amount,
                  date: DateTime.now(),
                  method: method,
                  status: PaymentStatus.pagado,
                ));
                Navigator.pop(ctx);
              },
              label: const Text('Guardar pago'),
            ),
          ],
        );
      },
    ),
  );
}
