import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
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
    final list = clinic.appointmentsOfDay(_date).where((a) {
      if (_doctorFilter != null && a.doctorId != _doctorFilter) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _changeDate(-1),
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.dark),
                          ),
                          Text(
                            '${_date.day}/${_date.month}/${_date.year}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeDate(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const SizedBox(width: 8),
                  if (_date.day != DateTime.now().day ||
                      _date.month != DateTime.now().month)
                    TextButton(
                      onPressed: () => setState(() => _date = DateTime.now()),
                      child: const Text('Hoy'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _doctorFilter,
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'Filtrar por médico'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos los médicos')),
                        for (final d in clinic.activeDoctors)
                          DropdownMenuItem(value: d.id, child: Text(d.displayName)),
                      ],
                      onChanged: (v) => setState(() => _doctorFilter = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/solicitar-cita'),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva cita'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const AppEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'Sin citas este día',
                  subtitle: 'Usa "Nueva cita" para agendar un turno.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          width: 64,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                a.time,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                        ),
                        title: Text(clinic.patientName(a.patientId), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
                        subtitle: Text('${clinic.doctorName(a.doctorId)} — ${a.reason}'),
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
                    );
                  },
                ),
        ),
      ],
    );
  }
}