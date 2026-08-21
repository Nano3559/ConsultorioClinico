import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:consultorio_clinico/main.dart';
import 'package:consultorio_clinico/state/auth_provider.dart';
import 'package:consultorio_clinico/state/clinic_provider.dart';

<<<<<<< HEAD
import 'helpers/fake_api.dart';

=======
>>>>>>> origin/main
void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es';
    await initializeDateFormatting('es');
  });

  testWidgets('admin flow responsive at phone size (drawer navigation)', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
<<<<<<< HEAD
          ChangeNotifierProvider(create: (_) => AuthProvider(api: fakeApiClient())),
=======
          ChangeNotifierProvider(create: (_) => AuthProvider()),
>>>>>>> origin/main
          ChangeNotifierProvider(create: (_) => ClinicProvider()),
        ],
        child: const ConsultorioClinicoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ingresar al sistema'));
    await tester.tap(find.text('Ingresar al sistema'));
    await tester.pumpAndSettle();

<<<<<<< HEAD
    await tester.enterText(find.byType(TextFormField).first, 'admin@consultorio.com');
    await tester.enterText(find.byType(TextFormField).last, 'admin123');
=======
    await tester.enterText(find.byType(TextFormField).first, 'admin@clinica.com');
    await tester.enterText(find.byType(TextFormField).last, '123456');
>>>>>>> origin/main
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Resumen del día'), findsOneWidget);
    // En móvil no hay barra de navegación inferior: todo vive en el drawer.
    expect(find.byType(NavigationBar), findsNothing);

    const modules = ['Consulta', 'Agenda', 'Citas', 'Pacientes', 'Médicos', 'Pagos', 'Reportes', 'Configuración'];
    for (final module in modules) {
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final item = find.descendant(
        of: find.byType(Drawer),
        matching: find.text(module),
      );
      await tester.scrollUntilVisible(
        item,
        120,
        scrollable: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        ).first,
      );
      await tester.tap(item);
      await tester.pumpAndSettle();
      // El título de la barra superior refleja el módulo activo.
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(module)),
        findsOneWidget,
      );
    }
  });
}