import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';

/// Utilidades visuales compartidas por las pantallas de PreConsulta IA.

const List<Color> _coloresNivel = [
  Color(0xFFDC2626), // 1 inmediato
  Color(0xFFEA580C), // 2 urgente
  Color(0xFFD97706), // 3 prioritario
  Color(0xFF2563EB), // 4 programado
  Color(0xFF16A34A), // 5 no urgente
];

Color nivelColor(int? nivel) {
  if (nivel == null || nivel < 1 || nivel > 5) return AppColors.muted;
  return _coloresNivel[nivel - 1];
}

Color nivelBg(int? nivel) {
  if (nivel == null || nivel < 1 || nivel > 5) return AppColors.background;
  return nivelColor(nivel).withValues(alpha: 0.12);
}

String nivelEtiqueta(int? nivel) {
  switch (nivel) {
    case 1:
      return 'Atención inmediata';
    case 2:
      return 'Urgente';
    case 3:
      return 'Prioritario';
    case 4:
      return 'Programado';
    case 5:
      return 'No urgente';
    default:
      return 'Sin clasificar';
  }
}

String nivelTiempo(int? nivel) {
  switch (nivel) {
    case 1:
      return 'Ahora';
    case 2:
      return '≤ 30 min';
    case 3:
      return '≤ 2 h';
    case 4:
      return '≤ 4 h';
    case 5:
      return 'Sin límite';
    default:
      return '—';
  }
}

String estadoEtiqueta(String estado) {
  switch (estado) {
    case 'pendiente':
      return 'Pendiente';
    case 'completada':
      return 'Completada';
    case 'revisada':
      return 'Revisada';
    case 'cancelada':
      return 'Cancelada';
    default:
      return estado;
  }
}

Color estadoColor(String estado) {
  switch (estado) {
    case 'pendiente':
      return AppColors.warning;
    case 'completada':
      return AppColors.info;
    case 'revisada':
      return AppColors.success;
    case 'cancelada':
      return AppColors.danger;
    default:
      return AppColors.muted;
  }
}

String fechaCorta(DateTime? fecha) {
  if (fecha == null) return '—';
  return DateFormat("d 'de' MMM, HH:mm", 'es').format(fecha);
}

String horaCorta(DateTime? fecha) {
  if (fecha == null) return '—';
  return DateFormat('HH:mm').format(fecha);
}

String porcentaje(double? valor) {
  if (valor == null) return '—';
  return '${(valor * 100).round()}%';
}

String decimal(double? valor, {int decimales = 1, String sufijo = ''}) {
  if (valor == null) return '—';
  return '${valor.toStringAsFixed(decimales)}$sufijo';
}

/// Tarjeta base de la preconsulta (blanca, borde suave y sombra 3D).
class PreconsultaCard extends StatelessWidget {
  const PreconsultaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Insignia del nivel de triage con color, número y etiqueta.
class TriageBadge extends StatelessWidget {
  const TriageBadge({
    super.key,
    required this.nivel,
    this.etiqueta,
    this.compact = false,
  });

  final int? nivel;
  final String? etiqueta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = nivelColor(nivel);
    final texto = etiqueta ?? nivelEtiqueta(nivel);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 20 : 26,
            height: compact ? 20 : 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              nivel?.toString() ?? '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 11 : 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de estado (pendiente/completada/revisada...).
class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.estado, this.compact = false});

  final String estado;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = estadoColor(estado);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estadoEtiqueta(estado),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }
}

/// Métrica con icono, valor grande y etiqueta. Si [confianza] existe, muestra
/// una barra que comunica la calidad de la estimación (rPPG nunca es exacto).
class MetricaTile extends StatelessWidget {
  const MetricaTile({
    super.key,
    required this.icon,
    required this.etiqueta,
    required this.valor,
    this.unidad,
    this.color = AppColors.primary,
    this.confianza,
    this.nota,
    this.compact = false,
  });

  final IconData icon;
  final String etiqueta;
  final String valor;
  final String? unidad;
  final Color color;
  final double? confianza;
  final String? nota;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: compact ? 16 : 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.dark,
                    fontSize: compact ? 20 : 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (unidad != null) ...[
                const SizedBox(width: 4),
                Text(
                  unidad!,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (confianza != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: confianza!.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  confianza! >= 0.6
                      ? color
                      : confianza! >= 0.35
                          ? AppColors.warning
                          : AppColors.danger,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Confianza ${porcentaje(confianza)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
          ],
          if (nota != null) ...[
            const SizedBox(height: 6),
            Text(
              nota!,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

/// Barra con etiqueta y valor (0-100) para estrés, fatiga o dolor.
class ScoreBar extends StatelessWidget {
  const ScoreBar({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.color,
    this.max = 100,
    this.sufijo = '/100',
  });

  final String etiqueta;
  final double? valor;
  final Color color;
  final double max;
  final String sufijo;

  @override
  Widget build(BuildContext context) {
    final v = (valor ?? 0).clamp(0.0, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                etiqueta,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              valor == null ? '—' : '${v.toStringAsFixed(max > 10 ? 0 : 1)}$sufijo',
              style: const TextStyle(
                color: AppColors.dark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: valor == null ? 0 : v / max,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// Título de sección con línea decorativa.
class SeccionTitulo extends StatelessWidget {
  const SeccionTitulo({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.iconColor = AppColors.primary,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: AppColors.dark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitulo!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Aviso clínico obligatorio: la IA apoya el triage, no diagnostica.
class AvisoClinico extends StatelessWidget {
  const AvisoClinico({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.infoBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_outlined,
              size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta evaluación apoya la priorización de la atención. No es un '
              'diagnóstico ni sustituye la valoración de un profesional de la '
              'salud. El nivel sugerido debe ser confirmado por el personal clínico.',
              style: TextStyle(
                color: AppColors.info,
                fontSize: compact ? 11 : 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
