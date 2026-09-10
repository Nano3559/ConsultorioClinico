import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Tarjeta "3D" con relieve multicapa y elevación al pasar el cursor.
/// En móvil permanece estática (sin hover, toque normal).
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 20,
    this.accent = AppColors.primary,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color accent;

  /// Fondo opcional; por defecto un gradiente blanco sutil.
  final Gradient? gradient;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(0.0, _hover ? -5.0 : 0.0)
          ..scale(_hover ? 1.012 : 1.0),
        transformAlignment: Alignment.center,
        padding: widget.padding,
        decoration: BoxDecoration(
          gradient: widget.gradient ??
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surface, const Color(0xFFF8FAFC)],
              ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: Colors.white, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: _hover ? 30 : 16,
              offset: Offset(0, _hover ? 12 : 5),
            ),
            BoxShadow(
              color: widget.accent.withValues(alpha: _hover ? 0.18 : 0.07),
              blurRadius: _hover ? 44 : 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Chip de ícono con gradiente y resplandor (para tarjetas y listas).
class GradientIconChip extends StatelessWidget {
  const GradientIconChip({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 26,
    this.radius = 14,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(radius * 0.9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.22)!],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.38),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}
