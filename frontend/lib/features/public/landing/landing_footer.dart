import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Pie de página de la página pública.
class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF0B3B37)],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 48),
      child: Column(
        children: [
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(
                  flex: 2,
                  child: _FooterAbout(),
                ),
                Expanded(child: _FooterColumn(title: 'Consultorio', items: ['Nosotros', 'Especialidades', 'Médicos', 'Horarios'])),
                Expanded(child: _FooterColumn(title: 'Pacientes', items: ['Solicitar cita', 'Servicios', 'Contacto'])),
                Expanded(child: _FooterColumn(title: 'Legal', items: ['Privacidad', 'Términos', 'Cookies'])),
              ],
            )
          else ...[
            const _FooterAbout(),
            const SizedBox(height: 24),
            const _FooterColumn(title: 'Consultorio', items: ['Nosotros', 'Especialidades', 'Médicos']),
            const SizedBox(height: 16),
            const _FooterColumn(title: 'Pacientes', items: ['Solicitar cita', 'Contacto']),
          ],
          const SizedBox(height: 32),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 16),
          Text(
            '© ${DateTime.now().year} ${AppInfo.name}. Todos los derechos reservados.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FooterAbout extends StatelessWidget {
  const _FooterAbout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_hospital, color: AppColors.primaryLight, size: 28),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                AppInfo.name,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          'Plataforma de control médico y clínico para consultorios modernos.',
          style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
        ),
      ],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(item, style: const TextStyle(color: Color(0xFF94A3B8))),
          ),
      ],
    );
  }
}