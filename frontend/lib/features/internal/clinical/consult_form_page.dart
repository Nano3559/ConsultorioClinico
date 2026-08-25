import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/app_validators.dart';
import '../../../data/models/consult_record.dart';
import '../../../state/auth_provider.dart';
import '../../../state/clinic_provider.dart';

/// Formulario para registrar una consulta médica (Ejercicio 6).
class ConsultFormPage extends StatefulWidget {
  const ConsultFormPage({super.key, required this.patientId});

  final String patientId;

  @override
  State<ConsultFormPage> createState() => _ConsultFormPageState();
}

class _ConsultFormPageState extends State<ConsultFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  final _observaciones = TextEditingController();
  final _diagnostico = TextEditingController();
  final _tratamiento = TextEditingController();
  DateTime? _proximoControl;
  String? _doctorId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final clinic = context.read<ClinicProvider>();
    String? fallback;
    if (clinic.activeDoctors.isNotEmpty) fallback = clinic.activeDoctors.first.id;
    _doctorId = auth.currentUser?.doctorId ?? fallback;
  }

  @override
  void dispose() {
    _motivo.dispose();
    _observaciones.dispose();
    _diagnostico.dispose();
    _tratamiento.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona el médico que realizó la consulta')));
      return;
    }
    final clinic = context.read<ClinicProvider>();
    await clinic.addConsult(ConsultRecord(
      id: 'h${DateTime.now().millisecondsSinceEpoch}',
      patientId: widget.patientId,
      doctorId: _doctorId!,
      date: DateTime.now(),
      motivo: _motivo.text.trim(),
      observaciones: _observaciones.text.trim(),
      diagnostico: _diagnostico.text.trim(),
      tratamiento: _tratamiento.text.trim(),
      proximoControl: _proximoControl,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar consulta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paciente: ${clinic.patientName(widget.patientId)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _doctorId,
                    decoration: const InputDecoration(labelText: 'Médico'),
                    items: [
                      for (final d in clinic.activeDoctors)
                        DropdownMenuItem(value: d.id, child: Text(d.displayName)),
                    ],
                    onChanged: (v) => setState(() => _doctorId = v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _motivo,
                    decoration: const InputDecoration(labelText: 'Motivo de consulta'),
                    validator: AppValidators.required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _observaciones,
                    decoration: const InputDecoration(labelText: 'Observaciones'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _diagnostico,
                    decoration: const InputDecoration(labelText: 'Diagnóstico'),
                    validator: AppValidators.required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _tratamiento,
                    decoration: const InputDecoration(labelText: 'Tratamiento / indicaciones'),
                    maxLines: 3,
                    validator: AppValidators.required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: _proximoControl == null ? '' : AppFormatters.shortDate(_proximoControl!),
                    ),
                    decoration: const InputDecoration(labelText: 'Próximo control (opcional)'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _proximoControl ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _proximoControl = picked);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar consulta'),
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
}