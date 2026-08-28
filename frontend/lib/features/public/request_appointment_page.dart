import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/app_validators.dart';
import '../../data/models/patient.dart';
import '../../data/models/user.dart';
import '../../state/auth_provider.dart';
import '../../state/clinic_provider.dart';

/// Formulario público para solicitar una cita (Ejercicio 3).
class RequestAppointmentPage extends StatefulWidget {
  const RequestAppointmentPage({super.key, this.specialtyId, this.doctorId});

  final String? specialtyId;
  final String? doctorId;

  @override
  State<RequestAppointmentPage> createState() => _RequestAppointmentPageState();
}

class _RequestAppointmentPageState extends State<RequestAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _lastName = TextEditingController();
  late final TextEditingController _ci = TextEditingController();
  late final TextEditingController _birth = TextEditingController();
  late final TextEditingController _phone = TextEditingController();
  late final TextEditingController _email = TextEditingController();
  late final TextEditingController _reason = TextEditingController();

  DateTime? _birthDate;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _specialtyId;
  String? _doctorId;
  String? _time;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final isMedico = auth.currentUser?.role == UserRole.medico;
    _specialtyId = widget.specialtyId;
    // Un médico solo puede agendar citas para sí mismo (se ignora el param ?medico=).
    _doctorId = isMedico ? auth.currentUser?.doctorId : widget.doctorId;
  }

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    _ci.dispose();
    _birth.dispose();
    _phone.dispose();
    _email.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final auth = context.watch<AuthProvider>();
    final isMedico = auth.currentUser?.role == UserRole.medico;
    final doctors = isMedico
        ? clinic.doctors.where((d) => d.id == _doctorId).toList()
        : clinic.doctors
            .where((d) =>
                d.active &&
                (_specialtyId == null || d.specialtyId == _specialtyId))
            .toList();
    // Mantener el médico seleccionado coherente con la especialidad.
    if (!isMedico && _doctorId != null && !doctors.any((d) => d.id == _doctorId)) {
      _doctorId = null;
    }
    final slots = _doctorId == null ? const <String>[] : clinic.availableSlots(_doctorId!, _date);
    if (_time != null && !slots.contains(_time)) _time = null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar cita'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Datos del paciente', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.dark)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _field(_name, 'Nombre', AppValidators.required)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_lastName, 'Apellido', AppValidators.required)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(flex: 1, child: _field(_ci, 'CI', AppValidators.ci)),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _field(_phone, 'Teléfono', AppValidators.phone)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _birthField()),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_email, 'Correo', AppValidators.email)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text('Datos de la cita', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.dark)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _specialtyId,
                    decoration: const InputDecoration(labelText: 'Especialidad'),
                    items: [
                      for (final s in clinic.specialties)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() {
                      _specialtyId = v;
                      _doctorId = null;
                      _time = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _doctorId,
                    decoration: InputDecoration(
                      labelText: 'Médico',
                      helperText: isMedico ? 'Solo puedes agendar citas para ti.' : null,
                    ),
                    items: [
                      for (final d in doctors)
                        DropdownMenuItem(value: d.id, child: Text(d.displayName)),
                    ],
                    onChanged: isMedico
                        ? null
                        : (v) => setState(() {
                              _doctorId = v;
                              _time = null;
                            }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _dateField()),
                      const SizedBox(width: 12),
                      Expanded(child: _timeField(slots)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _field(_reason, 'Motivo de consulta', AppValidators.required),
                  const SizedBox(height: 8),
                  if (_doctorId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Horario: ${AppFormatters.day(_date)}, ${_date.day}/${_date.month} · ${_doctorName(clinic)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? 'Verificando disponibilidad...' : 'Solicitar cita'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Al confirmar, el horario queda reservado y aparecerá en la agenda del consultorio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9), fontSize: 12),
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
    String? Function(String?) validator,
  ) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  Widget _birthField() {
    return TextFormField(
      controller: _birth,
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
        if (picked != null) {
          setState(() {
            _birthDate = picked;
            _birth.text = AppFormatters.shortDate(picked);
          });
        }
      },
      validator: (v) => _birthDate == null ? 'Fecha de nacimiento requerida' : null,
    );
  }

  Widget _dateField() {
    return TextFormField(
      readOnly: true,
      decoration: const InputDecoration(labelText: 'Fecha de la cita'),
      controller: TextEditingController(text: AppFormatters.shortDate(_date)),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 60)),
        );
        if (picked != null) {
          setState(() {
            _date = picked;
            _time = null;
          });
        }
      },
      validator: (_) => _date.isBefore(DateTime.now()) ? 'Fecha no válida' : null,
    );
  }

  Widget _timeField(List<String> slots) {
    return DropdownButtonFormField<String>(
      initialValue: _time,
      decoration: const InputDecoration(labelText: 'Hora'),
      items: [
        for (final t in slots) DropdownMenuItem(value: t, child: Text(t)),
      ],
      hint: const Text('Seleccionar'),
      onChanged: slots.isEmpty
          ? null
          : (v) => setState(() => _time = v),
    );
  }

  String _doctorName(ClinicProvider clinic) =>
      _doctorId == null ? '' : clinic.doctorById(_doctorId!).displayName;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un médico')));
      return;
    }
    if (_time == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un horario disponible')));
      return;
    }
    final clinic = context.read<ClinicProvider>();
    setState(() => _submitting = true);

    // Pequeña pausa simulando la verificación en el servidor.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    // Buscar o registrar al paciente por CI.
    Patient? existing;
    for (final p in clinic.patients) {
      if (p.ci == _ci.text.trim()) {
        existing = p;
        break;
      }
    }
    var patient = existing;
    if (patient == null) {
      patient = Patient(
        id: 'p${DateTime.now().millisecondsSinceEpoch}',
        firstName: _name.text.trim(),
        lastName: _lastName.text.trim(),
        ci: _ci.text.trim(),
        birthDate: _birthDate!,
        phone: _phone.text.trim(),
        email: _email.text.trim(),
      );
      final created = await clinic.addPatient(patient);
      if (created != null) patient = created;
    }

    final error = await clinic.bookAppointment(
      patientId: patient.id,
      doctorId: _doctorId!,
      date: _date,
      time: _time!,
      reason: _reason.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _showSuccess(patient);
  }

  void _showSuccess(Patient patient) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.success, size: 56),
        title: const Text('¡Cita registrada!', textAlign: TextAlign.center),
        content: Text(
          '${patient.fullName}, tu cita quedó reservada. '
          'La recepción confirmará el turno. El horario ya no está disponible para otros pacientes.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/');
            },
            child: const Text('Volver al inicio'),
          ),
        ],
      ),
    );
  }
}