import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/page_header.dart';
import '../../../data/models/doctor.dart';
import '../../../state/auth_provider.dart';
import '../../../state/clinic_provider.dart';
import 'doctors/schedule_range_row.dart';

/// El médico gestiona sus propios días y franjas de atención:
/// marca "Sin atención" en los días que no trabaja y define las horas
/// de inicio y fin (hasta las 23:00).
class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});

  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage> {
  final Map<String, List<String>> _ranges = {};
  String? _medicoId;
  bool _init = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    final auth = context.read<AuthProvider>();
    final clinic = context.read<ClinicProvider>();
    final id = auth.currentUser?.doctorId;
    if (id == null || clinic.doctors.isEmpty) return;
    final doctor = clinic.doctorById(id);
    // Id real de la fila en la BD: perfilId legacy puede ser el uid de Firebase.
    _medicoId = doctor.id;
    final initial = doctor.schedule.byDay;
    for (final day in kDays) {
      final slots = initial[day] ?? const [];
      if (slots.isNotEmpty) {
        _ranges[day] = [slots.first, slots.last];
      } else if (initial.isEmpty) {
        _ranges[day] = ['08:00', '12:00'];
      } else {
        _ranges[day] = ['--', '--'];
      }
    }
    _init = true;
  }

  List<String> _slotsBetween(String start, String end) {
    final s = kTimeSlots.indexOf(start);
    final e = kTimeSlots.indexOf(end);
    if (s < 0 || e < s) return const [];
    return kTimeSlots.sublist(s, e + 1);
  }

  Future<void> _save() async {
    if (_medicoId == null) return;
    final schedule = DoctorSchedule({
      for (final day in kDays)
        if (_ranges[day]![1] != '--') day: _slotsBetween(_ranges[day]![0], _ranges[day]![1]),
    });
    if (schedule.byDay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un día de atención')),
      );
      return;
    }
    setState(() => _saving = true);
    final clinic = context.read<ClinicProvider>();
    final error = await clinic.updateMySchedule(_medicoId!, schedule);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Horario actualizado')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_medicoId == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          AppEmptyState(
            icon: Icons.schedule_outlined,
            title: 'Sin médico asignado',
            subtitle: 'Tu perfil todavía no está vinculado a un médico.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeader(
          title: 'Mis horarios',
          subtitle: 'Define los días que trabajas y tu hora de atención (hasta las 23:00).',
          icon: Icons.schedule_outlined,
        ),
        const SizedBox(height: 8),
        const Text(
          'Selecciona "Sin atención" en los días que no trabajas.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        for (final day in kDays)
          DayScheduleRow(
            day: day,
            range: _ranges[day]!,
            onChanged: (r) => setState(() => _ranges[day] = r),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando...' : 'Guardar horario'),
          ),
        ),
      ],
    );
  }
}
