import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/hover_card.dart';
import '../../../state/auth_provider.dart';
import '../../../state/clinic_provider.dart';

/// Alta de médico por el administrador: crea la cuenta de Firebase Auth y envía
/// un correo de confirmación para que el médico fije su contraseña.
class DoctorInviteDialog extends StatefulWidget {
  const DoctorInviteDialog({super.key});

  @override
  State<DoctorInviteDialog> createState() => _DoctorInviteDialogState();
}

class _DoctorInviteDialogState extends State<DoctorInviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _ci = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  String? _especialidadId;
  bool _sending = false;

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _ci.dispose();
    _email.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_especialidadId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona una especialidad')));
      return;
    }
    setState(() => _sending = true);
    final auth = context.read<AuthProvider>();
    final clinic = context.read<ClinicProvider>();
    final medicoData = {
      'nombre': _nombre.text.trim(),
      'apellido': _apellido.text.trim(),
      'cedula': _ci.text.trim(),
      'especialidad_id': _especialidadId,
      'telefono': _telefono.text.trim(),
    };
    final (error, tempPassword) = await auth.registerDoctor(
      email: _email.text.trim(),
      nombre: '${_nombre.text.trim()} ${_apellido.text.trim()}',
      medicoData: medicoData,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await clinic.loadAll();
    if (!mounted) return;
    Navigator.of(context).pop();
    _showSuccess(tempPassword ?? '');
  }

  void _showSuccess(String tempPassword) {
    final email = _email.text.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        icon: const Icon(Icons.mark_email_read_outlined, color: AppColors.success, size: 52),
        title: const Text('Médico registrado', textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Se envió un correo de confirmación a\n$email\ncon el enlace para fijar su contraseña.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF0FDFA), Color(0xFFE0F2FE)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Contraseña inicial del médico',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      tempPassword,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: tempPassword));
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Contraseña copiada')),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copiar'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'El correo llega de noreply@consultorioclinico-2026.firebaseapp.com.\n'
                'Si no aparece en Recibidos: revisa Promociones/Spam y márcalo como "No es spam".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      title: Row(
        children: const [
          GradientIconChip(
            icon: Icons.medical_services_outlined,
            color: AppColors.primary,
            size: 24,
            radius: 12,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text('Registrar médico', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombre,
                        decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline)),
                        validator: AppValidators.required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _apellido,
                        decoration: const InputDecoration(labelText: 'Apellido'),
                        validator: AppValidators.required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ci,
                        decoration: const InputDecoration(labelText: 'Carnet de identidad', prefixIcon: Icon(Icons.badge_outlined)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _telefono,
                        decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined)),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _especialidadId,
                  decoration: const InputDecoration(labelText: 'Especialidad', prefixIcon: Icon(Icons.stars_outlined)),
                  items: [
                    for (final s in clinic.specialties)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _especialidadId = v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline)),
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.email,
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1_outlined),
          onPressed: _sending ? null : _submit,
          label: Text(_sending ? 'Registrando...' : 'Registrar médico'),
        ),
      ],
    );
  }
}
