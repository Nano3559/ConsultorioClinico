import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/section_header.dart';

const _services = [
  (Icons.group_outlined, 'Gestión de pacientes', 'Registra, busca y administra la información de tus pacientes.'),
  (Icons.calendar_month_outlined, 'Citas médicas', 'Agenda, reprograma y notifica citas automáticamente.'),
  (Icons.folder_shared_outlined, 'Historial clínico', 'Historiales, diagnósticos y notas médicas seguras.'),
  (Icons.medication_outlined, 'Recetas digitales', 'Genera y envía recetas a farmacias aliadas.'),
  (Icons.bar_chart_outlined, 'Reportes', 'Métricas del consultorio y decisiones basadas en datos.'),
  (Icons.security_outlined, 'Datos protegidos', 'Cifrado y cumplimiento de normativas de salud.'),
];

/// Sección de servicios del consultorio.
class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 80),
      child: Column(
        children: [
          const SectionHeader(
            label: 'SERVICIOS',
            title: 'Todo lo que tu consultorio necesita',
            subtitle: 'Una plataforma completa para digitalizar tu práctica médica.',
          ),
          const SizedBox(height: 40),
          if (isMobile)
            for (final s in _services) Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ServiceTile(icon: s.$1, title: s.$2, desc: s.$3),
            )
          else
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _services)
                  SizedBox(
                    width: (width - 96 - 48) / 3,
                    child: _ServiceTile(icon: s.$1, title: s.$2, desc: s.$3),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.icon, required this.title, required this.desc});

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.dark)),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(color: AppColors.muted, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección de horarios de atención del consultorio.
class HoursSection extends StatelessWidget {
  const HoursSection({super.key});

  static const _days = [
    ('Lunes', '08:00 - 12:00 / 14:00 - 18:00'),
    ('Martes', '08:00 - 12:00 / 14:00 - 18:00'),
    ('Miércoles', '08:00 - 12:00 / 14:00 - 18:00'),
    ('Jueves', '08:00 - 12:00 / 14:00 - 18:00'),
    ('Viernes', '08:00 - 12:00 / 14:00 - 18:00'),
    ('Sábado', '08:00 - 12:00'),
    ('Domingo', 'Cerrado'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      width: double.infinity,
      color: AppColors.dark,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 80),
      child: Column(
        children: [
          const SectionHeader(
            label: 'HORARIOS',
            title: 'Horarios de atención',
            subtitle: 'Te esperamos de lunes a sábado.',
            light: true,
          ),
          const SizedBox(height: 40),
          Container(
            width: isMobile ? double.infinity : 520,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (final (day, hours) in _days)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          day,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          hours,
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => context.push('/solicitar-cita'),
                  icon: const Icon(Icons.event_available),
                  label: const Text('Solicitar cita'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección "Nosotros".
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 80),
      child: Row(
        children: [
          if (!isMobile) ...[
            Expanded(
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  color: AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.medical_services, color: AppColors.primary, size: 120),
              ),
            ),
            const SizedBox(width: 48),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOSOTROS', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(
                  'Cuidamos la salud de tu consultorio',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.dark),
                ),
                SizedBox(height: 16),
                Text(
                  'ConsultorioClínico nace con la misión de modernizar la gestión médica, reduciendo tiempos de espera y mejorando la experiencia tanto para profesionales de la salud como para pacientes.',
                  style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.6),
                ),
                SizedBox(height: 16),
                Text(
                  'Nuestro equipo combina tecnología y medicina para ofrecer una plataforma confiable, segura y fácil de usar.',
                  style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección de testimonios.
class TestimonialsSection extends StatelessWidget {
  const TestimonialsSection({super.key});

  static const _testimonials = [
    ('Dra. Ana Gómez', 'Médica general', 'Reduje los tiempos de espera en mi consultorio a la mitad. La gestión de citas es espectacular.'),
    ('Dr. Luis Rojas', 'Pediatra', 'El historial clínico digital me permite atender mejor a mis pacientes.'),
    ('Lic. María López', 'Administradora clínica', 'Los reportes automáticos me ahorran horas de trabajo cada semana.'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      width: double.infinity,
      color: const Color(0xFFF1F5F9),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 80),
      child: Column(
        children: [
          const SectionHeader(
            label: 'TESTIMONIOS',
            title: 'Lo que dicen nuestros clientes',
          ),
          const SizedBox(height: 40),
          if (isMobile)
            for (final t in _testimonials)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TestimonialCard(name: t.$1, role: t.$2, text: t.$3),
              )
          else
            Row(
              children: [
                for (final t in _testimonials)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _TestimonialCard(name: t.$1, role: t.$2, text: t.$3),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.name, required this.role, required this.text});

  final String name;
  final String role;
  final String text;

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
          const Icon(Icons.format_quote, color: AppColors.primary, size: 32),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.dark, height: 1.5, fontSize: 15)),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  name.split(' ').map((p) => p[0]).take(2).join(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
                    Text(role, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}