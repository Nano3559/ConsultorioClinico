import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:consultorio_clinico/main.dart';
import 'package:consultorio_clinico/state/auth_provider.dart';
import 'package:consultorio_clinico/state/clinic_provider.dart';

void main() {
  testWidgets('Landing page renders', (WidgetTester tester) async {
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

    expect(find.text('ConsultorioClínico'), findsWidgets);
    expect(find.text('Especialidades'), findsWidgets);
    expect(find.text('Médicos'), findsWidgets);
    expect(find.text('Solicitar cita'), findsWidgets);
  });
}