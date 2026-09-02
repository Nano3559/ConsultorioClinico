import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/hover_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/models/doctor.dart';
import '../../../../data/models/specialty.dart';
import '../../../../state/clinic_provider.dart';

/// Sección de médicos del consultorio.
class DoctorsSection extends StatelessWidget {
  const DoctorsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final doctors = clinic.activeDoctors;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      width: double.infinity,
      color: const Color(0xFFF1F5F9),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 80),
      child: Column(
        children: [
          const SectionHeader(
            label: 'NUESTRO EQUIPO',
            title: 'Médicos especialistas',
            subtitle: 'Profesionales comprometidos con tu salud.',
          ),
          const SizedBox(height: 40),
          if (isMobile)
            for (final d in doctors)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DoctorCard(doctor: d),
              )
          else
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                for (final d in doctors)
                  SizedBox(width: (width - 96 - 48) / 3, child: _DoctorCard(doctor: d)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Fotografía del médico: si hay foto_url la muestra; si no, avatar con iniciales.
class _DoctorPhoto extends StatelessWidget {
  const _DoctorPhoto({required this.doctor, required this.specialty, this.size = 58});

  final Doctor doctor;
  final Specialty specialty;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = AppAvatar(name: doctor.name, radius: size / 2, backgroundColor: specialty.color);
    if (doctor.photoUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        doctor.photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final clinic = context.read<ClinicProvider>();
    final specialty = clinic.specialtyById(doctor.specialtyId);
    return HoverCard(
      padding: const EdgeInsets.all(20),
      accent: specialty.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [specialty.color, specialty.color.withValues(alpha: 0.35)],
                  ),
                  boxShadow: [
                    BoxShadow(color: specialty.color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: _DoctorPhoto(doctor: doctor, specialty: specialty),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.displayName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.dark),
                    ),
                    Text(
                      specialty.name,
                      style: TextStyle(fontSize: 13, color: specialty.color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            doctor.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.work_history_outlined, color: AppColors.muted, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${doctor.yearsExperience} años de experiencia',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Horarios de atención',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark),
          ),
          const SizedBox(height: 6),
          Wrap(
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showProfile(context, clinic),
                  child: const Text('Ver perfil'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      context.push('/solicitar-cita?medico=${doctor.id}'),
                  child: const Text('Solicitar cita'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProfile(BuildContext context, ClinicProvider clinic) {
    final specialty = clinic.specialtyById(doctor.specialtyId);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [specialty.color, specialty.color.withValues(alpha: 0.35)],
                      ),
                    ),
                    child: _DoctorPhoto(doctor: doctor, specialty: specialty, size: 66),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctor.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.dark)),
                        Text(specialty.name, style: TextStyle(color: specialty.color, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(doctor.description, style: const TextStyle(color: AppColors.muted, height: 1.5)),
              const SizedBox(height: 16),
              Text('${doctor.yearsExperience} años de experiencia', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 16),
              const Text('Horarios de atención', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
              const SizedBox(height: 8),
              for (final e in doctor.schedule.byDay.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 70, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('${e.value.first} - ${e.value.last}', style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/solicitar-cita?medico=${doctor.id}');
                  },
                  child: const Text('Solicitar cita con este médico'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}