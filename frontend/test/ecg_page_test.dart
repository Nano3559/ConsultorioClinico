import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:consultorio_clinico/data/models/ecg_analysis.dart';
import 'package:consultorio_clinico/data/models/specialty.dart';
import 'package:consultorio_clinico/data/models/user.dart';
import 'package:consultorio_clinico/features/internal/ecg/ecg_page.dart';
import 'package:consultorio_clinico/features/internal/nav/nav_definitions.dart';

void main() {
  Map<String, dynamic> respuestaFake({
    String diagnostico = 'Ritmo Sinusal Normal',
    double confianza = 93.5,
  }) =>
      {
        'diagnostico_principal': diagnostico,
        'confianza': confianza,
        'desglose': {
          'Ritmo Sinusal Normal': 93.5,
          'Fibrilación Auricular (AFib)': 2.0,
          'Isquemia / Infarto Agudo': 1.5,
          'Bloqueo de Rama Izquierda (LBBB)': 1.0,
          'Contracción Ventricular Prematura (PVC)': 2.0,
        },
        'bpm': '72 BPM (Ritmo Regular)',
        'causas': ['Conducción eléctrica cardíaca fisiológica y estable.'],
        'recomendaciones': ['Chequeos cardiológicos preventivos anuales.'],
      };

  test('EcgAnalysis.fromApi parsea la respuesta del servicio de IA', () {
    final r = EcgAnalysis.fromApi(respuestaFake());

    expect(r.diagnosticoPrincipal, 'Ritmo Sinusal Normal');
    expect(r.confianza, 93.5);
    expect(r.desglose.length, 5);
    expect(r.desglose['Contracción Ventricular Prematura (PVC)'], 2.0);
    expect(r.bpm, '72 BPM (Ritmo Regular)');
    expect(r.causas, hasLength(1));
    expect(r.recomendaciones.first, 'Chequeos cardiológicos preventivos anuales.');
    expect(r.esNormal, isTrue);
    expect(r.esUrgencia, isFalse);
  });

  test('EcgAnalysis marca urgencia con isquemia o infarto agudo', () {
    final isquemia = EcgAnalysis.fromApi(
      respuestaFake(diagnostico: 'Isquemia / Infarto Agudo', confianza: 95),
    );
    expect(isquemia.esNormal, isFalse);
    expect(isquemia.esUrgencia, isTrue);
    expect(isquemia.esNormal || isquemia.esUrgencia, isTrue);

    final afib = EcgAnalysis.fromApi(respuestaFake(diagnostico: 'Fibrilación Auricular (AFib)'));
    expect(afib.esNormal, isFalse);
    expect(afib.esUrgencia, isFalse);
  });

  test('EcgAnalysis.fromApi tolera campos ausentes o con otro tipo', () {
    final r = EcgAnalysis.fromApi(<String, dynamic>{});

    expect(r.diagnosticoPrincipal, '');
    expect(r.confianza, 0);
    expect(r.desglose, isEmpty);
    expect(r.causas, isEmpty);
    expect(r.recomendaciones, isEmpty);
    expect(r.bpm, '');
  });

  test('Specialty.isCardiologia solo marca la especialidad Cardiología', () {
    const cardio = Specialty(
      id: '1',
      name: 'Cardiología',
      description: '',
      icon: Icons.favorite,
    );
    const pedia = Specialty(
      id: '2',
      name: 'Pediatría',
      description: '',
      icon: Icons.child_care,
    );

    expect(cardio.isCardiologia, isTrue);
    expect(pedia.isCardiologia, isFalse);
  });

  test('El módulo de ECG con IA solo aparece para el médico cardiólogo', () {
    final medico = navModulesFor(UserRole.medico);
    expect(medico.any((m) => m.key == 'ecg'), isFalse);

    final cardio = navModulesFor(UserRole.medico, esCardiologo: true);
    expect(cardio.any((m) => m.key == 'ecg'), isTrue);
    final ecg = cardio.firstWhere((m) => m.key == 'ecg');
    expect(ecg.label, 'Evaluar ECG con IA');
    // Se muestra como pestaña dentro de `/app` (no navega a otra ruta).
    expect(ecg.route, isNull);

    expect(
      stackModulesFor(UserRole.medico, esCardiologo: true)
          .any((m) => m.key == 'ecg'),
      isTrue,
    );
    // El resto de módulos del médico no cambia.
    expect(cardio.take(4).map((m) => m.key).toList(),
        ['panel', 'consulta', 'miagenda', 'pacientes']);
  });

  test('Ningún otro rol ve el módulo de ECG con IA', () {
    for (final role in [
      UserRole.admin,
      UserRole.recepcion,
      UserRole.paciente,
    ]) {
      expect(
        navModulesFor(role, esCardiologo: true).any((m) => m.key == 'ecg'),
        isFalse,
        reason: 'Rol $role no debe ver el módulo de ECG',
      );
    }
  });

  testWidgets('Página de ECG de cardiología renderiza su vista interna', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardioEcgPage()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Cargar registro de ECG'), findsOneWidget);
    expect(find.text('Ejecutar Inferencia IA'), findsOneWidget);
    expect(find.text('Esperando registro de ECG'), findsOneWidget);
    expect(find.text('ESPECIFICACIÓN DEL FORMATO CSV'), findsOneWidget);
    expect(find.text('DESGLOSE PROBABILÍSTICO POR PATOLOGÍA'), findsNothing);

    // Sin servidor de IA activo, el botón de inferencia queda deshabilitado.
    final boton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Ejecutar Inferencia IA'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(boton.onPressed, isNull);
  });
}
