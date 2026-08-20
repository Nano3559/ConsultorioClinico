import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/responsive_row.dart';
import '../../../data/models/doctor.dart';
import '../../../state/clinic_provider.dart';
import 'doctor_form_page.dart';

/// Gestión de médicos (Ejercicio 7).
class DoctorsPage extends StatelessWidget {
  const DoctorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ResponsiveRow(
          children: [
            const Text(
              'Profesionales del consultorio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.dark),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DoctorFormPage()),
              ),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Registrar médico'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (clinic.doctors.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: AppEmptyState(icon: Icons.medical_services_outlined, title: 'Sin médicos registrados'),
          )
        else if (isWide)
          AppTable(
            headers: const ['Médico', 'Especialidad', 'Experiencia', 'Horario', 'Estado', ''],
            rows: [
              for (final d in clinic.doctors)
                [
                  TableText(d.displayName, bold: true),
                  TableText(clinic.specialtyById(d.specialtyId).name),
                  TableText('${d.yearsExperience} años'),
                  TableText(_scheduleSummary(d)),
                  TableText(
                    d.active ? 'Activo' : 'Inactivo',
                    bold: true,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: d.active,
                        onChanged: (_) => clinic.toggleDoctorActive(d.id),
                      ),
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined, color: AppColors.muted),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => DoctorFormPage(doctor: d)),
                        ),
                      ),
                    ],
                  ),
                ],
            ],
          )
        else
          for (final d in clinic.doctors) _DoctorTile(doctor: d),
      ],
    );
  }

  String _scheduleSummary(Doctor d) {
    final days = d.schedule.byDay.values;
    if (days.isEmpty) return 'Sin horario';
    return days.map((t) => '${t.first}-${t.last}').join(' · ');
  }
}

class _DoctorTile extends StatelessWidget {
  const _DoctorTile({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final clinic = context.read<ClinicProvider>();
    final specialty = clinic.specialtyById(doctor.specialtyId);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(name: doctor.name, radius: 26, backgroundColor: specialty.color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.displayName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
                      Text(specialty.name, style: TextStyle(color: specialty.color, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${doctor.yearsExperience} años de experiencia', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                if (!isMobile)
                  Text(
                    doctor.active ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      color: doctor.active ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                Switch(
                  value: doctor.active,
                  onChanged: (_) => clinic.toggleDoctorActive(doctor.id),
                ),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined, color: AppColors.muted),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DoctorFormPage(doctor: doctor)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Text(
                  doctor.active ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    color: doctor.active ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.only(left: isMobile ? 52 : 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in doctor.schedule.byDay.entries)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${e.key} ${e.value.first}-${e.value.last}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}