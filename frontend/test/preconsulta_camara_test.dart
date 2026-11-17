import 'package:flutter_test/flutter_test.dart';

import 'package:consultorio_clinico/features/preconsulta/capture/captura_preconsulta.dart';

void main() {
  group('CamaraDisponible.preferida', () {
    test('sin cámaras no preselecciona nada', () {
      expect(CamaraDisponible.preferida(const []), isNull);
    });

    test('una sola cámara se usa aunque sea trasera', () {
      const trasera = CamaraDisponible(id: 'a', nombre: 'Trasera');
      expect(CamaraDisponible.preferida(const [trasera]), trasera);
    });

    test('la frontal tiene prioridad sobre la trasera', () {
      const trasera = CamaraDisponible(id: 'a', nombre: 'Trasera');
      const frontal = CamaraDisponible(
        id: 'b',
        nombre: 'Frontal',
        frontal: true,
      );
      expect(CamaraDisponible.preferida(const [trasera, frontal]), frontal);
    });

    test('sin frontal se usa la primera de la lista', () {
      const usb1 = CamaraDisponible(id: 'u1', nombre: 'Webcam A');
      const usb2 = CamaraDisponible(id: 'u2', nombre: 'Webcam B');
      expect(CamaraDisponible.preferida(const [usb1, usb2]), usb1);
    });
  });
}
