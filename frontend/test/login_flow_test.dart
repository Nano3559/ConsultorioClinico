import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:consultorio_clinico/main.dart';
import 'package:consultorio_clinico/state/auth_provider.dart';
import 'package:consultorio_clinico/state/clinic_provider.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es';
    await initializeDateFormatting('es');
  });

  testWidgets('login as admin and land on dashboard', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ClinicProvider()),
        ],
        child: const ConsultorioClinicoApp(),
      ),
    );

    expect(find.text('ConsultorioClínico'), findsWidgets);

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
  });
}