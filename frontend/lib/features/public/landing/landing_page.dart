import 'package:flutter/material.dart';
import '../../../core/widgets/ambient_background.dart';
import 'landing_navbar.dart';
import 'landing_footer.dart';
import 'sections/hero_section.dart';
import 'sections/specialties_section.dart';
import 'sections/doctors_section.dart';
import 'sections/info_sections.dart';
import 'sections/contact_section.dart';

/// Página pública: página de inicio del consultorio con todas las secciones.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();
  final _heroKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _specialtiesKey = GlobalKey();
  final _doctorsKey = GlobalKey();
  final _servicesKey = GlobalKey();
  final _hoursKey = GlobalKey();
  final _contactKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _goTo(String label) {
    switch (label) {
      case 'Inicio':
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      case 'Nosotros':
        _scrollTo(_aboutKey);
      case 'Especialidades':
        _scrollTo(_specialtiesKey);
      case 'Médicos':
        _scrollTo(_doctorsKey);
      case 'Servicios':
        _scrollTo(_servicesKey);
      case 'Horarios':
        _scrollTo(_hoursKey);
      case 'Contacto':
        _scrollTo(_contactKey);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        blobs: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              LandingNavbar(
                onNavigate: _goTo,
                onRequest: () => _scrollTo(_heroKey),
              ),
              HeroSection(key: _heroKey),
              SpecialtiesSection(key: _specialtiesKey),
              DoctorsSection(key: _doctorsKey),
              ServicesSection(key: _servicesKey),
              HoursSection(key: _hoursKey),
              AboutSection(key: _aboutKey),
              TestimonialsSection(),
              ContactSection(key: _contactKey),
              LandingFooter(),
            ],
          ),
        ),
      ),
    );
  }
}