import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/public/landing/landing_page.dart';
import 'features/public/login_page.dart';
import 'features/public/request_appointment_page.dart';
import 'features/internal/internal_shell.dart';
import 'state/auth_provider.dart';
import 'state/clinic_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ClinicProvider()),
      ],
      child: const ConsultorioClinicoApp(),
    ),
  );
}

class ConsultorioClinicoApp extends StatelessWidget {
  const ConsultorioClinicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ConsultorioClínico',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/solicitar-cita',
      builder: (context, state) => RequestAppointmentPage(
        specialtyId: state.uri.queryParameters['especialidad'],
        doctorId: state.uri.queryParameters['medico'],
      ),
    ),
    GoRoute(
      path: '/app',
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        return auth.isLogged ? null : '/login';
      },
      builder: (context, state) => const InternalShell(),
    ),
  ],
);