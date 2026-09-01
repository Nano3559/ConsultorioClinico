import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/hover_card.dart';
import '../../../../core/widgets/section_header.dart';

/// Sección de contacto con datos del consultorio y formulario.
class ContactSection extends StatelessWidget {
  const ContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: 80),
      child: Column(
        children: const [
          SectionHeader(
            label: 'CONTACTO',
            title: 'Estamos para ayudarte',
            subtitle: 'Escribinos o visitanos. Respondemos a la brevedad.',
          ),
          SizedBox(height: 40),
          _ContactBody(),
        ],
      ),
    );
  }
}

class _ContactBody extends StatelessWidget {
  const _ContactBody();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile) ...[
          const Expanded(child: _ContactInfo()),
          const SizedBox(width: 48),
        ],
        Expanded(child: _ContactForm()),
      ],
    );
  }
}

class _ContactInfo extends StatelessWidget {
  const _ContactInfo();

  static const _items = [
    (Icons.location_on_outlined, 'Dirección', AppInfo.address),
    (Icons.phone_outlined, 'Teléfono', AppInfo.phone),
    (Icons.chat_outlined, 'WhatsApp', AppInfo.whatsapp),
    (Icons.mail_outline, 'Correo', AppInfo.email),
    (Icons.schedule_outlined, 'Horarios', AppInfo.hours),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HoverCard(
          child: Column(
            children: [
              for (final (icon, label, value) in _items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, color: AppColors.primary, size: 48),
                SizedBox(height: 8),
                Text('Av. Principal #123, Ciudad', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Ver en el mapa', style: TextStyle(color: AppColors.primary, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialIcon(Icons.facebook),
            SizedBox(width: 12),
            _SocialIcon(Icons.camera_alt_outlined),
            SizedBox(width: 12),
            _SocialIcon(Icons.alternate_email),
          ],
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradientPrimary,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm();

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensaje enviado. Te contactaremos pronto.')),
    );
    _name.clear();
    _email.clear();
    _phone.clear();
    _message.clear();
  }

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Envíanos un mensaje', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.dark)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Correo no válido' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _message,
              decoration: const InputDecoration(labelText: 'Mensaje'),
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El mensaje es requerido' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Enviar mensaje'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}