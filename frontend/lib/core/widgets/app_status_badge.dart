import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Estado de una cita/consulta con su etiqueta y colores.
enum AppointmentStatus {
  pendiente('Pendiente', AppColors.warning, AppColors.warningBg),
  confirmada('Confirmada', AppColors.info, AppColors.infoBg),
  atendida('Completada', AppColors.success, AppColors.successBg),
  cancelada('Cancelada', AppColors.danger, AppColors.dangerBg),
  noAsistio('No asistió', AppColors.purple, AppColors.purpleBg);

  const AppointmentStatus(this.label, this.color, this.bg);
  final String label;
  final Color color;
  final Color bg;

  /// Estado esperado por el backend (Supabase: citas.estado).
  String toApi() {
    switch (this) {
      case AppointmentStatus.pendiente:
        return 'programada';
      case AppointmentStatus.confirmada:
        return 'confirmada';
      case AppointmentStatus.atendida:
        return 'completada';
      case AppointmentStatus.cancelada:
        return 'cancelada';
      case AppointmentStatus.noAsistio:
        return 'no_show';
    }
  }

  /// Convierte el estado del backend al enum local.
  static AppointmentStatus fromApi(String? value) {
    switch (value) {
      case 'programada':
        return AppointmentStatus.pendiente;
      case 'confirmada':
      case 'en_curso':
        return AppointmentStatus.confirmada;
      case 'completada':
        return AppointmentStatus.atendida;
      case 'cancelada':
        return AppointmentStatus.cancelada;
      case 'no_show':
        return AppointmentStatus.noAsistio;
      default:
        return AppointmentStatus.pendiente;
    }
  }
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