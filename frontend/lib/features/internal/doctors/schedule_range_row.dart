import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Fila de edición de un día del horario: inicio, fin o "Sin atención".
class DayScheduleRow extends StatefulWidget {
  const DayScheduleRow({
    super.key,
    required this.day,
    required this.range,
    required this.onChanged,
  });

  final String day;
  final List<String> range;
  final ValueChanged<List<String>> onChanged;

  @override
  State<DayScheduleRow> createState() => _DayScheduleRowState();
}

class _DayScheduleRowState extends State<DayScheduleRow> {
  @override
  Widget build(BuildContext context) {
    final start = widget.range[0];
    final end = widget.range[1];
    final disabled = end == '--';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              widget.day,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: disabled ? null : start,
              hint: const Text('Inicio'),
              isDense: true,
              items: [
                for (final t in kTimeSlots)
                  DropdownMenuItem(value: t, child: Text(t)),
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
                for (final t in kTimeSlots)
                  DropdownMenuItem(value: t, child: Text(t)),
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
