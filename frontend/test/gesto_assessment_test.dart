import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:consultorio_clinico/features/public/kiosk/gesto_assessment_service.dart';
import 'package:consultorio_clinico/services/api_client.dart';

ApiClient clienteQueResponde(Object? cuerpo, [int codigo = 200]) {
  return ApiClient(
    client: MockClient((_) async => http.Response(
          jsonEncode(cuerpo),
          codigo,
          headers: {'Content-Type': 'application/json'},
        )),
  );
}

void main() {
  group('GestoAssessmentService', () {
    test('veredicto ok se parsea con yaw/pitch', () async {
      final svc = GestoAssessmentService(
        client: clienteQueResponde({
          'success': true,
          'message': 'Perfecto',
          'data': {
            'tiene_rostro': true,
            'yaw': 0.31,
            'pitch': 0.95,
            'calidad': 82.5,
            'gesto_ok': true,
          },
        }),
      );
      final v = await svc.evaluar(base64Jpeg: 'abc', pose: 'izquierda');
      expect(v, isNotNull);
      expect(v!.gestoOk, isTrue);
      expect(v.mensaje, 'Perfecto');
      expect(v.yaw, closeTo(0.31, 1e-9));
      expect(v.pitch, closeTo(0.95, 1e-9));
      expect(v.tieneRostro, isTrue);
    });

    test('veredicto negativo conserva el mensaje de guia', () async {
      final svc = GestoAssessmentService(
        client: clienteQueResponde({
          'success': true,
          'message': 'Gira mas tu cara a tu izquierda',
          'data': {'tiene_rostro': true, 'gesto_ok': false},
        }),
      );
      final v = await svc.evaluar(base64Jpeg: 'abc', pose: 'izquierda');
      expect(v, isNotNull);
      expect(v!.gestoOk, isFalse);
      expect(v.mensaje, contains('izquierda'));
    });

    test('error HTTP devuelve null (fallback local)', () async {
      final svc = GestoAssessmentService(
        client: clienteQueResponde({'success': false}, 500),
      );
      expect(await svc.evaluar(base64Jpeg: 'abc', pose: 'frontal'), isNull);
    });

    test('respuesta sin gesto_ok devuelve null', () async {
      final svc = GestoAssessmentService(
        client: clienteQueResponde({
          'success': true,
          'message': 'ok',
          'data': {'tiene_rostro': true},
        }),
      );
      expect(await svc.evaluar(base64Jpeg: 'abc', pose: 'frontal'), isNull);
    });

    test('excepcion de red devuelve null', () async {
      final svc = GestoAssessmentService(
        client: ApiClient(
          client: MockClient((_) async => throw Exception('corte')),
        ),
      );
      expect(await svc.evaluar(base64Jpeg: 'abc', pose: 'frontal'), isNull);
    });
  });
}
