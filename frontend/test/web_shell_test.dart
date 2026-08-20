import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:consultorio_clinico/main.dart';
import 'package:consultorio_clinico/core/widgets/app_table.dart';
import 'package:consultorio_clinico/state/auth_provider.dart';
import 'package:consultorio_clinico/state/clinic_provider.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es';
    await initializeDateFormatting('es');
  });

  testWidgets('admin flow in web shell (sidebar with groups)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ClinicProvider()),
        ],
        child: const ConsultorioClinicoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ingresar al sistema'));
    await tester.tap(find.text('Ingresar al sistema'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Administrador'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Administrador'));
    await tester.pump();

    await tester.ensureVisible(find.text('Ingresar'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Ingresar'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Resumen del día'), findsOneWidget);
    // En web no hay barra de navegación inferior.
    expect(find.byType(NavigationBar), findsNothing);
    // Los grupos del sidebar aparecen.
    for (final group in ['CLÍNICO', 'PERSONAS', 'FINANZAS', 'ANÁLISIS', 'SISTEMA']) {
      expect(find.text(group), findsOneWidget);
    }

    const modules = ['Agenda', 'Citas', 'Pacientes', 'Médicos', 'Pagos', 'Reportes', 'Configuración', 'Consulta'];
    for (final module in modules) {
      await tester.scrollUntilVisible(
        find.text(module),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(module));
      await tester.pumpAndSettle();
    }

    // El módulo de pacientes muestra tabla en web.
    await tester.tap(find.text('Pacientes'));
    await tester.pumpAndSettle();
    expect(find.byType(AppTable), findsWidgets);
  });
}