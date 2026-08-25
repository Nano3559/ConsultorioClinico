import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_validators.dart';
import '../../../data/models/doctor.dart';
import '../../../state/clinic_provider.dart';

/// Formulario de registro/edición de médicos con horarios de atención.
class DoctorFormPage extends StatefulWidget {
  const DoctorFormPage({super.key, this.doctor});

  final Doctor? doctor;

  @override
  State<DoctorFormPage> createState() => _DoctorFormPageState();
}

class _DoctorFormPageState extends State<DoctorFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _experience;
  String? _specialtyId;
  bool _active = true;

  // Horarios: día → rango [inicio, fin] seleccionados.
  late Map<String, List<String>> _ranges;

  bool get _isEdit => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.doctor?.name ?? '');
    _title = TextEditingController(text: widget.doctor?.title ?? 'Dr.');
    _description = TextEditingController(text: widget.doctor?.description ?? '');
    _experience = TextEditingController(text: '${widget.doctor?.yearsExperience ?? 1}');
    _specialtyId = widget.doctor?.specialtyId;
    _active = widget.doctor?.active ?? true;
    _ranges = {};
    final initial = widget.doctor?.schedule.byDay;
    for (final day in kDays) {
      final slots = initial?[day] ?? const [];
      _ranges[day] = slots.isEmpty ? ['08:00', '12:00'] : [slots.first, slots.last];
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _description.dispose();
    _experience.dispose();
    super.dispose();
  }

  List<String> _slotsBetween(String start, String end) {
    final s = kTimeSlots.indexOf(start);
    final e = kTimeSlots.indexOf(end);
    if (s < 0 || e < s) return const [];
    return kTimeSlots.sublist(s, e + 1);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_specialtyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una especialidad')));
      return;
    }
    final schedule = DoctorSchedule({
      for (final day in kDays)
        if (_ranges[day]![1] != '--') day: _slotsBetween(_ranges[day]![0], _ranges[day]![1]),
    });
    final clinic = context.read<ClinicProvider>();
    if (_isEdit) {
      await clinic.updateDoctor(widget.doctor!.copyWith(
        name: _name.text.trim(),
        title: _title.text.trim().isEmpty ? 'Dr.' : _title.text.trim(),
        specialtyId: _specialtyId,
        description: _description.text.trim(),
        yearsExperience: int.tryParse(_experience.text) ?? 1,
        schedule: schedule,
        active: _active,
      ));
    } else {
      await clinic.addDoctor(Doctor(
        id: 'd${DateTime.now().millisecondsSinceEpoch}',
        name: _name.text.trim(),
        title: _title.text.trim().isEmpty ? 'Dr.' : _title.text.trim(),
        specialtyId: _specialtyId!,
        description: _description.text.trim(),
        yearsExperience: int.tryParse(_experience.text) ?? 1,
        schedule: schedule,
        active: _active,
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Editar médico' : 'Registrar médico')),
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
                  Row(
                    children: [
                      SizedBox(width: 90, child: _field(_title, 'Título', null)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_name, 'Nombre completo', AppValidators.required)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _specialtyId,
                    decoration: const InputDecoration(labelText: 'Especialidad'),
                    items: [
                      for (final s in clinic.specialties)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => _specialtyId = v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _experience,
                    decoration: const InputDecoration(labelText: 'Años de experiencia'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || int.tryParse(v) == null) ? 'Valor numérico' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'Descripción / perfil'),
                    maxLines: 3,
                    validator: AppValidators.required,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Médico activo', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
                      const Spacer(),
                      Switch(
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text('Horarios de atención', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.dark)),
                  const SizedBox(height: 8),
                  const Text('Desactiva el día seleccionando "Sin atención".', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  for (final day in kDays)
                    _DayScheduleRow(
                      day: day,
                      range: _ranges[day]!,
                      onChanged: (r) => setState(() => _ranges[day] = r),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(_isEdit ? 'Guardar cambios' : 'Registrar médico'),
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

  Widget _field(TextEditingController c, String label, String? Function(String?)? validator) {
    return TextFormField(controller: c, decoration: InputDecoration(labelText: label), validator: validator);
  }
}

class _DayScheduleRow extends StatefulWidget {
  const _DayScheduleRow({required this.day, required this.range, required this.onChanged});

  final String day;
  final List<String> range;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_DayScheduleRow> createState() => _DayScheduleRowState();
}

class _DayScheduleRowState extends State<_DayScheduleRow> {
  @override
  Widget build(BuildContext context) {
    final start = widget.range[0];
    final end = widget.range[1];
    final disabled = end == '--';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(widget.day, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark))),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: disabled ? null : start,
              hint: const Text('Inicio'),
              isDense: true,
              items: [
                for (final t in kTimeSlots) DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: disabled
                  ? null
                  : (v) {
                      widget.onChanged([v!, end == '--' ? v : end]);
                    },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: end == '--' ? null : end,
              hint: const Text('Fin / sin atención'),
              isDense: true,
              items: [
                for (final t in kTimeSlots) DropdownMenuItem(value: t, child: Text(t)),
                const DropdownMenuItem(value: '--', child: Text('Sin atención')),
              ],
              onChanged: (v) => widget.onChanged([start, v!]),
            ),
          ),
        ],
      ),
    );
  }
}