import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

/// Sección hero: portada con mensaje principal y tarjeta de próxima cita.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

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
      child: isMobile
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroText(),
                SizedBox(height: 32),
                _HeroCard(),
              ],
            )
          : const Row(
              children: [
                Expanded(child: _HeroText()),
                SizedBox(width: 48),
                Expanded(child: _HeroCard()),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available, color: AppColors.primary, size: 28),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Próxima cita',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Spacer(),
              _Badge(text: 'Confirmada'),
            ],
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dra. Ana Gómez', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark), overflow: TextOverflow.ellipsis),
                    Text('Medicina general', style: TextStyle(color: AppColors.muted, fontSize: 13), overflow: TextOverflow.ellipsis),
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
                const Expanded(child: Text('Hoy · 10:30 AM', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark))),
                const Icon(Icons.videocam, color: AppColors.primary, size: 22),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/solicitar-cita'),
              child: const Text('Agendar cita'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.primaryDark, fontSize: 12)),
    );
  }
}