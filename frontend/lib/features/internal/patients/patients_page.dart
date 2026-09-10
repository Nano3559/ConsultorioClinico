import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/page_header.dart';
import '../../../data/models/patient.dart';
import '../../../state/clinic_provider.dart';
import 'patient_form_page.dart';
import 'patient_detail_page.dart';

/// Gestión de pacientes (Ejercicio 5).
class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final patients = clinic.searchPatients(_search.text);
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      children: [
        PageHeader(
          title: 'Pacientes',
          subtitle: 'Directorio de personas atendidas en el consultorio.',
          icon: Icons.group_outlined,
          count: clinic.patients.length,
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PatientFormPage()),
              ),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Registrar'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Buscar paciente',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (patients.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: AppEmptyState(
              icon: Icons.group_off_outlined,
              title: 'Sin resultados',
              subtitle: 'No se encontraron pacientes.',
            ),
          )
        else if (isWide)
          AppTable(
            headers: const ['Paciente', 'CI', 'Teléfono', 'Última cita', ''],
            rows: [
              for (final p in patients)
                [
                  TableText(p.fullName, bold: true),
                  TableText(p.ci),
                  TableText(p.phone),
                  TableText(_lastAppointmentOf(clinic, p.id)),
                  IconButton(
                    tooltip: 'Ver detalle',
                    icon: const Icon(Icons.chevron_right, color: AppColors.muted),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PatientDetailPage(patientId: p.id)),
                    ),
                  ),
                ],
            ],
          )
        else
          for (final p in patients) _PatientTile(patient: p),
      ],
    );
  }

  String _lastAppointmentOf(ClinicProvider clinic, String patientId) {
    final appts = clinic.appointmentsOfPatient(patientId);
    return appts.isEmpty ? 'Sin citas' : AppFormatters.shortDate(appts.first.date);
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final clinic = context.read<ClinicProvider>();
    final appts = clinic.appointmentsOfPatient(patient.id);
    final last = appts.isEmpty ? 'Sin citas' : AppFormatters.shortDate(appts.first.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: AppAvatar(name: patient.fullName, radius: 22),
        title: Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
        subtitle: Text(
          'CI ${patient.ci} · ${patient.phone}\nÚltima cita: $last',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Ver detalle',
          icon: const Icon(Icons.chevron_right, color: AppColors.muted),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PatientDetailPage(patientId: patient.id)),
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PatientDetailPage(patientId: patient.id)),
        ),
      ),
    );
  }
}
