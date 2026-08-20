import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/responsive_row.dart';
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: ResponsiveRow(
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar paciente',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PatientFormPage()),
                ),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Registrar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: patients.isEmpty
              ? const AppEmptyState(
                  icon: Icons.group_off_outlined,
                  title: 'Sin resultados',
                  subtitle: 'No se encontraron pacientes.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: patients.length,
                  itemBuilder: (context, i) => _PatientTile(patient: patients[i]),
                ),
        ),
      ],
    );
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