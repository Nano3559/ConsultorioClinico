import 'package:consultorio_clinico/data/models/user.dart';
import 'package:consultorio_clinico/features/internal/nav/nav_definitions.dart';
import 'package:flutter_test/flutter_test.dart';

/// La PreConsulta IA debe estar disponible para los roles que la usan:
/// recepción/médico/admin gestionan la cola; el paciente inicia la suya.
void main() {
  test('Recepción, médico y admin ven la cola de PreConsulta IA', () {
    for (final role in [UserRole.admin, UserRole.recepcion, UserRole.medico]) {
      final modulos = navModulesFor(role);
      expect(
        modulos.any((m) => m.key == 'preconsulta'),
        isTrue,
        reason: 'Rol $role debe ver la cola de preconsultas',
      );
    }
  });

  test('Admin y médico ven las métricas de PreConsulta IA', () {
    for (final role in [UserRole.admin, UserRole.medico]) {
      final modulos = navModulesFor(role);
      expect(
        modulos.any((m) => m.key == 'preconsultaMetricas'),
        isTrue,
        reason: 'Rol $role debe ver las métricas de preconsulta',
      );
    }
    expect(
      navModulesFor(UserRole.recepcion)
          .any((m) => m.key == 'preconsultaMetricas'),
      isFalse,
    );
  });

  test('El paciente inicia su propia PreConsulta IA', () {
    final modulos = navModulesFor(UserRole.paciente);
    final preconsulta = modulos.firstWhere((m) => m.key == 'preconsulta');
    expect(preconsulta.route, isNull);
    expect(
      stackModulesFor(UserRole.paciente).any((m) => m.key == 'preconsulta'),
      isTrue,
    );
  });
}
