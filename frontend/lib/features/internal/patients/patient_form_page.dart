import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/app_validators.dart';
import '../../../data/models/patient.dart';
import '../../../state/clinic_provider.dart';

/// Formulario de registro/edición de pacientes.
class PatientFormPage extends StatefulWidget {
  const PatientFormPage({super.key, this.patient});

  final Patient? patient;

  @override
  State<PatientFormPage> createState() => _PatientFormPageState();
}

class _PatientFormPageState extends State<PatientFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _lastName;
  late final TextEditingController _ci;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _antecedentes;
  late final TextEditingController _alergias;
  late final TextEditingController _observaciones;
  DateTime? _birthDate;

  bool _guardando = false;

  bool get _isEdit => widget.patient != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.patient?.firstName ?? '');
    _lastName = TextEditingController(text: widget.patient?.lastName ?? '');
    _ci = TextEditingController(text: widget.patient?.ci ?? '');
    _phone = TextEditingController(text: widget.patient?.phone ?? '');
    _email = TextEditingController(text: widget.patient?.email ?? '');
    _antecedentes = TextEditingController(
      text: widget.patient?.antecedentes ?? '',
    );
    _alergias = TextEditingController(text: widget.patient?.alergias ?? '');
    _observaciones = TextEditingController(
      text: widget.patient?.observaciones ?? '',
    );
    _birthDate = widget.patient?.birthDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    _ci.dispose();
    _phone.dispose();
    _email.dispose();
    _antecedentes.dispose();
    _alergias.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final clinic = context.read<ClinicProvider>();
    bool exito = false;
    String? mensaje;

    try {
      if (_isEdit) {
        final errorUpdate = await clinic.updatePatient(
          widget.patient!.copyWith(
            firstName: _name.text.trim(),
            lastName: _lastName.text.trim(),
            ci: _ci.text.trim(),
            birthDate: _birthDate!,
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            antecedentes: _antecedentes.text.trim(),
            alergias: _alergias.text.trim(),
            observaciones: _observaciones.text.trim(),
          ),
        );
        exito = errorUpdate == null;
        mensaje = errorUpdate;
      } else {
        final creado = await clinic.addPatient(
          Patient(
            id: 'p${DateTime.now().millisecondsSinceEpoch}',
            firstName: _name.text.trim(),
            lastName: _lastName.text.trim(),
            ci: _ci.text.trim(),
            birthDate: _birthDate!,
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            antecedentes: _antecedentes.text.trim(),
            alergias: _alergias.text.trim(),
            observaciones: _observaciones.text.trim(),
          ),
        );
        exito = creado != null;
        mensaje = exito ? null : clinic.error;
      }
    } catch (e) {
      mensaje = e.toString();
    }

    if (!mounted) return;
    setState(() => _guardando = false);

    if (exito) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje ?? 'No se pudo guardar el paciente'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Cerrar',
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar paciente' : 'Registrar paciente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _field(_name, 'Nombre', AppValidators.required),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _lastName,
                          'Apellido',
                          AppValidators.required,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _field(_ci, 'CI', AppValidators.ci)),
                      const SizedBox(width: 12),
                      Expanded(child: _birthField()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _field(_phone, 'Teléfono', AppValidators.phone),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(_email, 'Correo', AppValidators.email),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _field(_antecedentes, 'Antecedentes', null),
                  const SizedBox(height: 14),
                  _field(_alergias, 'Alergias', null),
                  const SizedBox(height: 14),
                  _field(_observaciones, 'Observaciones', null),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _guardando ? null : _save,
                      child: _guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEdit
                                  ? 'Guardar cambios'
                                  : 'Registrar paciente',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String? Function(String?)? validator,
  ) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  Widget _birthField() {
    return TextFormField(
      controller: TextEditingController(
        text: _birthDate == null ? '' : AppFormatters.shortDate(_birthDate!),
      ),
      readOnly: true,
      decoration: const InputDecoration(labelText: 'Fecha de nacimiento'),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _birthDate ?? DateTime(now.year - 25),
          firstDate: DateTime(now.year - 100),
          lastDate: now,
        );
        if (picked != null) setState(() => _birthDate = picked);
      },
      validator: (_) => _birthDate == null ? 'Fecha requerida' : null,
    );
  }
}
