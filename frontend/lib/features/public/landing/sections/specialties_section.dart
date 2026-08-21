import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/models/specialty.dart';
import '../../../../data/models/doctor.dart';
import '../../../../state/clinic_provider.dart';

/// Sección de especialidades con su médico asociado y horarios.
class SpecialtiesSection extends StatelessWidget {
  const SpecialtiesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final width = MediaQuery.of(context).size.width;
    final columns = width < 1000 ? 1 : (width < 1300 ? 2 : 3);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1000;
        final padding = isMobile ? 24.0 : 48.0;
        final avail = constraints.maxWidth - padding * 2;
        final cardWidth = columns == 1 ? avail : (avail - (columns - 1) * 24) / columns;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 80),
          child: Column(
            children: [
              const SectionHeader(
                label: 'ESPECIALIDADES',
                title: 'Atención especializada',
                subtitle: 'Conoce las especialidades disponibles en nuestro consultorio.',
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  for (final sp in clinic.specialties)
                    SizedBox(
                      width: cardWidth,
                      child: _SpecialtyCard(
                        specialty: sp,
                        doctor: clinic.firstActiveDoctor(sp.id),
                        onRequest: () => context.push(
                          '/solicitar-cita?especialidad=${sp.id}',
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({required this.specialty, required this.doctor, required this.onRequest});

  final Specialty specialty;
  final Doctor? doctor;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: specialty.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(specialty.icon, color: specialty.color, size: 28),
              ),
              const Spacer(),
              if (doctor != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      doctor!.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            specialty.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark),
          ),
          const SizedBox(height: 8),
          Text(
            specialty.description,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          if (doctor != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Horarios disponibles',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in doctor!.schedule.byDay.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.key} ${entry.value.first}-${entry.value.last}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRequest,
              child: const Text('Solicitar cita'),
            ),
          ),
        ],
      ),
    );
  }
}