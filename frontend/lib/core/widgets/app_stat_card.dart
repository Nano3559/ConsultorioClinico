import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Tarjeta con resumen numérico para dashboards.
///
/// Estilo "3D": chip de ícono con gradiente, sombra multicapa y elevación al
/// pasar el cursor (solo web; en móvil se mantiene estática).
class AppStatCard extends StatefulWidget {
  const AppStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Versión reducida para pantallas pequeñas.
  final bool compact;

  @override
  State<AppStatCard> createState() => _AppStatCardState();
}

class _AppStatCardState extends State<AppStatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.compact ? 12.0 : 18.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, _hover ? -4.0 : 0.0)
          ..scale(_hover ? 1.015 : 1.0),
        transformAlignment: Alignment.center,
        padding: EdgeInsets.all(p),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _hover
                ? [AppColors.surface, const Color(0xFFF1F5F9), widget.color.withValues(alpha: 0.08)]
                : [AppColors.surface, const Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(widget.compact ? 14 : 18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: _hover ? 26.0 : 14.0,
              offset: Offset(0, _hover ? 8.0 : 4.0),
            ),
            BoxShadow(
              color: widget.color.withValues(alpha: 0.10),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(widget.compact ? 8 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [widget.color, Color.lerp(widget.color, Colors.black, 0.18)!],
                ),
                borderRadius: BorderRadius.circular(widget.compact ? 10 : 14),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: widget.compact ? 20 : 26),
            ),
            SizedBox(width: widget.compact ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: widget.compact ? 18 : 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: widget.compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
