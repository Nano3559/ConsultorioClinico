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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [specialty.color, Color.lerp(specialty.color, Colors.black, 0.28)!],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.22),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 18, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: _DoctorPhoto(doctor: doctor, specialty: specialty, size: 72),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.displayName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    shadows: [Shadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 3))],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    specialty.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statRow(clinic, specialty),
                      const SizedBox(height: 20),
                      const Text(
                        'Sobre el médico',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        doctor.description.isEmpty
                            ? 'Médico del equipo del consultorio, dedicado a la atención y cuidado de sus pacientes.'
                            : doctor.description,
                        style: const TextStyle(color: AppColors.muted, height: 1.6),
                      ),
                      if (doctor.phone.isNotEmpty || doctor.email.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Contacto',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark),
                        ),
                        const SizedBox(height: 10),
                        if (doctor.phone.isNotEmpty)
                          _infoRow(Icons.phone_outlined, 'Teléfono', doctor.phone),
                        if (doctor.email.isNotEmpty)
                          _infoRow(Icons.mail_outline, 'Correo', doctor.email),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Horarios de atención',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in doctor.schedule.byDay.entries)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                '${e.key}  ${e.value.first}-${e.value.last}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.dark, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          context.push('/solicitar-cita?medico=${doctor.id}');
                        },
                        icon: const Icon(Icons.event_available),
                        label: const Text('Solicitar cita con este médico'),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statRow(ClinicProvider clinic, Specialty specialty) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            Icons.work_history_outlined,
            '${doctor.yearsExperience}',
            'años de\n experiencia',
            AppColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            Icons.stars_outlined,
            specialty.name,
            'especialidad',
            specialty.color,
            small: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            Icons.verified_outlined,
            'Activo',
            'en consulta',
            AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color, {bool small = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: small ? 11 : 16,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted, height: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}