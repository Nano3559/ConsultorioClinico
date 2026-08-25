import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/public/landing/landing_page.dart';
import 'features/public/login_page.dart';
import 'features/public/request_appointment_page.dart';
import 'features/internal/internal_shell.dart';
import 'state/auth_provider.dart';
import 'state/clinic_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');
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
      builder: (context, child) => EntranceLayer(child: child!),
      routerConfig: _router,
    );
  }
}

/// Animación de entrada de la app: muestra el Lottie del hospital una sola
/// vez al abrir la app (arranque en frío). No se repite al volver de segundo
/// plano porque [initState] solo se ejecuta una vez por ciclo de vida.
class EntranceLayer extends StatefulWidget {
  final Widget child;
  const EntranceLayer({super.key, required this.child});

  @override
  State<EntranceLayer> createState() => _EntranceLayerState();
}

class _EntranceLayerState extends State<EntranceLayer> with WidgetsBindingObserver {
  final _overlayKey = GlobalKey<OverlayState>();
  bool _entranceShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowEntrance());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // La animación solo va en el arranque en frío; al volver de segundo
    // plano no se vuelve a mostrar.
  }

  void _maybeShowEntrance() {
    if (_entranceShown) return;
    _entranceShown = true;
    final overlay = _overlayKey.currentState;
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        ignoring: true,
        child: Container(
          color: Colors.white,
          child: Center(
            child: Lottie.asset('assets/lottie/hospital.json', repeat: false),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 3000), () => entry.remove());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      key: _overlayKey,
      initialEntries: [
        OverlayEntry(builder: (_) => widget.child),
      ],
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