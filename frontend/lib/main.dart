import 'package:flutter/material.dart';

void main() {
  runApp(const ConsultorioClinicoApp());
}

class ConsultorioClinicoApp extends StatelessWidget {
  const ConsultorioClinicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConsultorioClínico',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488),
          primary: const Color(0xFF0D9488),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Roboto',
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _NavBar(),
            _HeroSection(),
            _FeaturesSection(),
            _StatsSection(),
            _AboutSection(),
            _TestimonialsSection(),
            _CallToAction(),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

const Color _primary = Color(0xFF0D9488);
const Color _primaryDark = Color(0xFF0F766E);
const Color _dark = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: _primary, size: 32),
          const SizedBox(width: 10),
          const Text(
            'ConsultorioClínico',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            for (final item in const ['Inicio', 'Servicios', 'Nosotros', 'Contacto'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(foregroundColor: _muted),
                  child: Text(item),
                ),
              ),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(backgroundColor: _primary),
              child: const Text('Agendar cita'),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.menu, color: _dark),
              onPressed: () {},
            ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

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
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'El control médico y clínico de tu consultorio, en un solo lugar',
          style: TextStyle(
            fontSize: 40,
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
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              ),
              child: const Text('Comenzar ahora'),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Ver demo'),
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
          Row(
            children: [
              const Icon(Icons.event_available, color: _primary, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Próxima cita',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Confirmada', style: TextStyle(color: _primaryDark, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dra. Ana Gómez', style: TextStyle(fontWeight: FontWeight.w600, color: _dark)),
                  Text('Medicina general', style: TextStyle(color: _muted, fontSize: 13)),
                ],
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
            child: const Row(
              children: [
                Icon(Icons.calendar_month, color: _primary, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Hoy · 10:30 AM', style: TextStyle(fontWeight: FontWeight.w600, color: _dark)),
                ),
                Icon(Icons.videocam, color: _primary, size: 22),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Agendar cita'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  static const _features = [
    (Icons.group, 'Gestión de pacientes', 'Registra, busca y administra la información completa de tus pacientes en segundos.'),
    (Icons.calendar_month, 'Citas médicas', 'Agenda, reprograma y notifica citas automáticamente para ti y tus pacientes.'),
    (Icons.folder_shared, 'Historial clínico', 'Accede a historiales clínicos, diagnósticos y notas médicas de forma segura.'),
    (Icons.medication, 'Recetas digitales', 'Genera y envía recetas electrónicas directamente a farmacias aliadas.'),
    (Icons.bar_chart, 'Reportes y estadísticas', 'Visualiza métricas de tu consultorio y toma decisiones basadas en datos.'),
    (Icons.security, 'Datos protegidos', 'Cifrado de extremo a extremo y cumplimiento de normativas de salud.'),
  ];

  @override
  Widget build(BuildContext context) {
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
              const Text('Servicios', style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Todo lo que tu consultorio necesita',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _dark),
              ),
              const SizedBox(height: 16),
              const Text(
                'Una plataforma completa para digitalizar tu práctica médica.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: _muted),
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  for (final (icon, title, desc) in _features)
                    SizedBox(
                      width: cardWidth,
                      child: _FeatureCard(icon: icon, title: title, description: desc),
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: _muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 64),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 32,
        runSpacing: 24,
        children: const [
          _StatItem(value: '10K+', label: 'Pacientes gestionados'),
          _StatItem(value: '120+', label: 'Consultorios activos'),
          _StatItem(value: '99.9%', label: 'Disponibilidad'),
          _StatItem(value: '24/7', label: 'Soporte técnico'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2DD4BF),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

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
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.medical_services, color: _primary, size: 120),
              ),
            ),
            const SizedBox(width: 48),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nosotros', style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(
                  'Cuidamos la salud de tu consultorio',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _dark),
                ),
                SizedBox(height: 16),
                Text(
                  'ConsultorioClínico nace con la misión de modernizar la gestión médica, reduciendo tiempos de espera y mejorando la experiencia tanto para profesionales de la salud como para pacientes.',
                  style: TextStyle(color: _muted, fontSize: 16, height: 1.6),
                ),
                SizedBox(height: 16),
                Text(
                  'Nuestro equipo combina tecnología y medicina para ofrecer una plataforma confiable, segura y fácil de usar.',
                  style: TextStyle(color: _muted, fontSize: 16, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection();

  static const _testimonials = [
    ('Dra. Ana Gómez', 'Médica general', 'Reduje los tiempos de espera en mi consultorio a la mitad. La gestión de citas es espectacular.'),
    ('Dr. Luis Rojas', 'Pediatra', 'El historial clínico digital me permite atender mejor a mis pacientes. Una herramienta indispensable.'),
    ('Lic. María López', 'Administradora clínica', 'Los reportes automáticos me ahorran horas de trabajo cada semana. Súper recomendado.'),
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
          const Text('Testimonios', style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Lo que dicen nuestros clientes',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _dark),
          ),
          const SizedBox(height: 40),
          if (isMobile)
            for (final t in _testimonials) Padding(
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote, color: _primary, size: 32),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: _dark, height: 1.5, fontSize: 15)),
          const SizedBox(height: 20),
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: _primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: _dark),
                    ),
                    Text(role, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 13)),
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

class _CallToAction extends StatelessWidget {
  const _CallToAction();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 80),
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Text(
              '¿Listo para digitalizar tu consultorio?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Únete a más de 120 consultorios que ya confían en nosotros.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 16),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Solicitar una demo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 48),
      child: Column(
        children: [
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_hospital, color: Color(0xFF2DD4BF), size: 28),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'ConsultorioClínico',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
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
                  ),
                ),
                const Expanded(
                  child: _FooterColumn(
                    title: 'Producto',
                    items: ['Servicios', 'Precios', 'Demo', 'Preguntas frecuentes'],
                  ),
                ),
                const Expanded(
                  child: _FooterColumn(
                    title: 'Compañía',
                    items: ['Nosotros', 'Blog', 'Contacto', 'Empleo'],
                  ),
                ),
                const Expanded(
                  child: _FooterColumn(
                    title: 'Legal',
                    items: ['Privacidad', 'Términos', 'Cookies'],
                  ),
                ),
              ],
            )
          else ...[
            const _FooterColumn(title: 'Producto', items: ['Servicios', 'Precios', 'Demo']),
            const SizedBox(height: 24),
            const _FooterColumn(title: 'Compañía', items: ['Nosotros', 'Blog', 'Contacto']),
          ],
          const SizedBox(height: 32),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 16),
          const Text(
            '© 2026 ConsultorioClínico. Todos los derechos reservados.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
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