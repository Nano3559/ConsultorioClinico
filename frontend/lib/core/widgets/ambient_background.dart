import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Fondo ambiental con gradiente suave y "blobs" de color que se desplazan
/// lentamente. Da profundidad sin costo alto (sin blur; solo gradientes y
/// transformaciones).
///
/// Es la base visual "3D" de páginas públicas y del área de contenido.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child, this.blobs = true});

  final Widget child;

  /// Muestra o no las manchas de color animadas.
  final bool blobs;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 36),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradientBackground,
        ),
      ),
      child: Stack(
        children: [
          if (!reduceMotion && widget.blobs)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value * 2 * math.pi;
                return Stack(
                  children: [
                    _blob(
                      Alignment(-0.9, -0.7),
                      radius: 0.45,
                      phase: t,
                      color: AppColors.primaryLight,
                    ),
                    _blob(
                      Alignment(0.95, -0.25),
                      radius: 0.38,
                      phase: t + math.pi * 0.66,
                      color: AppColors.info.withValues(alpha: 0.5),
                    ),
                    _blob(
                      Alignment(0.4, 1.0),
                      radius: 0.42,
                      phase: t + math.pi * 1.33,
                      color: AppColors.purple.withValues(alpha: 0.4),
                    ),
                  ],
                );
              },
            ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }

  Widget _blob(Alignment base, {required double radius, required double phase, required Color color}) {
    final dx = math.sin(phase) * 0.12;
    final dy = math.cos(phase) * 0.10;
    return Align(
      alignment: base,
      child: FractionalTranslation(
        translation: Offset(dx, dy),
        child: Container(
          width: (MediaQuery.sizeOf(context).shortestSide * radius) * 2,
          height: (MediaQuery.sizeOf(context).shortestSide * radius) * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrada suave para un widget: aparece con un leve deslizamiento hacia arriba.
/// Seguro de usar en reconstrucciones: solo anima la primera vez.
class FadeSlide extends StatelessWidget {
  const FadeSlide({
    super.key,
    required this.child,
    this.offset = const Offset(0, 0.05),
    this.duration = const Duration(milliseconds: 520),
  });

  final Widget child;
  final Offset offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(offset.dx * (1 - value), offset.dy * 120 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
