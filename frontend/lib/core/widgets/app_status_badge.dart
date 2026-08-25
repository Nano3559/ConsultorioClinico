import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Estado de una cita/consulta con su etiqueta y colores.
enum AppointmentStatus {
  pendiente('Pendiente', AppColors.warning, AppColors.warningBg),
  confirmada('Confirmada', AppColors.info, AppColors.infoBg),
  atendida('Atendida', AppColors.success, AppColors.successBg),
  cancelada('Cancelada', AppColors.danger, AppColors.dangerBg),
  noAsistio('No asistió', AppColors.purple, AppColors.purpleBg);

  const AppointmentStatus(this.label, this.color, this.bg);
  final String label;
  final Color color;
  final Color bg;
}

/// Insignia de estado reutilizable.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({super.key, required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}