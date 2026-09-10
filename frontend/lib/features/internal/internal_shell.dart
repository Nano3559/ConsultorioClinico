import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import 'shells/mobile_shell.dart';
import 'shells/web_shell.dart';

/// Caparazón del sistema interno. Despacha entre dos experiencias:
/// - Web (kIsWeb o pantalla >= 840px): sidebar con módulos agrupados.
/// - Móvil: barra superior + drawer con los módulos agrupados (sin barra inferior).
class InternalShell extends StatelessWidget {
  const InternalShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.currentUser == null) {
      // Redirección de seguridad si la sesión se pierde.
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const Scaffold(body: SizedBox.shrink());
    }
    final isWeb = kIsWeb || MediaQuery.sizeOf(context).width >= 840;
    // En web el botón "atrás" del navegador no debe sacar al usuario del
    // sistema y llevarlo al landing; se sale desde "Cerrar sesión".
    return PopScope(
      canPop: !isWeb,
      child: isWeb ? const WebShell() : const MobileShell(),
    );
  }
}