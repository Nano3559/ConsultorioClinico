import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_validators.dart';
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
    final error = await auth.registerDoctor(
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined, color: AppColors.success, size: 48),
        title: const Text('Médico registrado'),
        content: Text(
          'Se envió un correo de confirmación a ${_email.text.trim()}. '
          'El médico debe abrirlo para crear su contraseña e ingresar al sistema.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Entendido')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    return AlertDialog(
      title: const Text('Registrar médico'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: AppValidators.required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apellido,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: AppValidators.required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ci,
                decoration: const InputDecoration(labelText: 'Carnet de identidad'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _especialidadId,
                decoration: const InputDecoration(labelText: 'Especialidad'),
                items: [
                  for (final s in clinic.specialties)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _especialidadId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Correo electrónico'),
                keyboardType: TextInputType.emailAddress,
                validator: AppValidators.email,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: Text(_sending ? 'Enviando...' : 'Registrar y enviar correo'),
        ),
      ],
    );
  }
}
