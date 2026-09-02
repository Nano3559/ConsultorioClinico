import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../data/models/appointment.dart';
import '../../../../data/models/user.dart';
import '../../../../state/auth_provider.dart';
import '../../../../state/clinic_provider.dart';

/// Sección hero: portada con mensaje principal y tarjeta de próxima cita.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key, this.onViewDoctors});

  /// Será invocado cuando se pulse "Ver médicos" (scroll a la sección).
  final VoidCallback? onViewDoctors;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primaryLight],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.28),
                    AppColors.primaryLight.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FadeSlide(child: _HeroText()),
                const SizedBox(height: 32),
                FadeSlide(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: onViewDoctors,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        ),
                        child: const Text('Ver médicos'),
                      ),
                      const SizedBox(height: 16),
                      const _HeroCard(),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FadeSlide(child: _HeroText()),
                      const SizedBox(height: 12),
                      FadeSlide(
                        child: OutlinedButton.icon(
                          onPressed: onViewDoctors,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                          ),
                          icon: const Icon(Icons.people_outline),
                          label: const Text('Ver médicos'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                const Expanded(child: FadeSlide(child: _HeroCard())),
              ],
            ),
        ],
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Lottie.asset('assets/lottie/Heartbeat Lottie Animation.json', repeat: false),
        ),
        const SizedBox(height: 16),
        Text(
          'El control médico y clínico de tu consultorio, en un solo lugar',
          style: TextStyle(
            fontSize: isMobile ? 26 : 40,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Gestiona pacientes, citas médicas, historiales clínicos y recetas de forma rápida, segura y accesible desde cualquier dispositivo.',
          style: TextStyle(fontSize: 18, color: Color(0xFFD1FAE5), height: 1.5),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: () => context.push('/solicitar-cita'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              ),
              child: const Text('Solicitar cita'),
            ),
            TextButton(
              onPressed: () => context.push('/login'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Ingresar al sistema'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tarjeta de "Próxima cita": muestra la cita real del usuario logueado
/// (paciente -> su cita; médico -> su agenda; admin/recepción -> la próxima
/// del consultorio). Si no hay sesión o no hay citas, muestra un CTA.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final clinic = context.watch<ClinicProvider>();
    final isMedico = auth.currentUser?.role == UserRole.medico;

    Appointment? next;
    if (auth.isLogged && clinic.appointments.isNotEmpty) {
      final startOfToday = () {
        final t = DateTime.now();
        return DateTime(t.year, t.month, t.day);
      }();
      final upcoming = clinic.appointments.where((a) {
        if (a.status == AppointmentStatus.cancelada || a.status == AppointmentStatus.noAsistio) {
          return false;
        }
        return !a.date.isBefore(startOfToday);
      }).toList()
        ..sort((a, b) {
          final d = a.date.compareTo(b.date);
          if (d != 0) return d;
          return a.time.compareTo(b.time);
        });
      if (upcoming.isNotEmpty) next = upcoming.first;
    }

    if (next == null) {
      return _CardBox(
        children: [
          const _TitleRow(),
          const SizedBox(height: 16),
          Text(
            auth.isLogged
                ? 'No tienes citas próximas. Agenda una nueva cuando quieras.'
                : 'Tu próxima cita te espera. Agenda en segundos y recibe confirmación al instante.',
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/solicitar-cita'),
              child: Text(auth.isLogged ? 'Agendar cita' : 'Solicitar cita'),
            ),
          ),
          if (!auth.isLogged)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Ingresar al sistema'),
            ),
        ],
      );
    }

    final doctor = clinic.doctorById(next!.doctorId);
    final specialty = clinic.specialtyById(doctor.specialtyId);
    final mainLine = isMedico ? clinic.patientName(next!.patientId) : doctor.displayName;
    final subLine = isMedico ? 'Paciente' : '${specialty.name} · ${doctor.displayName}';

    return _CardBox(
      children: [
        Row(
          children: [
            const Icon(Icons.event_available, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Próxima cita',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            AppStatusBadge(status: next!.status),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mainLine, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark), overflow: TextOverflow.ellipsis),
                  Text(subLine, style: const TextStyle(color: AppColors.muted, fontSize: 13), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${AppFormatters.shortDate(next!.date)} · ${next!.time}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark),
                ),
              ),
              Icon(isMedico ? Icons.person : Icons.videocam, color: AppColors.primary, size: 22),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.push('/app'),
            child: const Text('Ver mis citas'),
          ),
        ),
      ],
    );
  }
}

class _CardBox extends StatelessWidget {
  const _CardBox({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 64,
            offset: const Offset(0, 26),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.event_available, color: AppColors.primary, size: 28),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Próxima cita',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
