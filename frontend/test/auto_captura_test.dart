import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:consultorio_clinico/features/public/kiosk/auto_captura_service.dart';

/// Genera un JPEG sintético de 200x200: fondo oscuro + óvalo de "piel".
/// Con [desplazarX] se corre el óvalo a un lado; con [ruido] se agrega
/// textura (sin ella la nitidez da ~0, como una foto desenfocada).
Uint8List fotoSintetica({double desplazarX = 0, bool ruido = true}) {
  const w = 200;
  const h = 200;
  final imagen = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = (x - (w / 2 + desplazarX)) / (w * 0.26);
      final dy = (y - h / 2) / (h * 0.36);
      if (dx * dx + dy * dy <= 1) {
        var r = 200;
        var g = 150;
        var b = 120;
        if (ruido) {
          final n = ((x * 7 + y * 13) % 51) - 25;
          r += n;
          g += n;
          b += n;
        }
        imagen.setPixelRgb(x, y, r, g, b);
      } else {
        imagen.setPixelRgb(x, y, 20, 20, 60);
      }
    }
  }
  return Uint8List.fromList(img.encodeJpg(imagen));
}

Uint8List fotoNegra() {
  final imagen = img.Image(width: 200, height: 200);
  for (var y = 0; y < 200; y++) {
    for (var x = 0; x < 200; x++) {
      imagen.setPixelRgb(x, y, 5, 5, 8);
    }
  }
  return Uint8List.fromList(img.encodeJpg(imagen));
}

void main() {
  group('AutoCapturaService', () {
    test('frame negro: sin rostro y con guía', () {
      final svc = AutoCapturaService();
      final ev = svc.evaluar(fotoNegra());
      expect(ev.tieneRostro, isFalse);
      expect(ev.lista, isFalse);
      expect(ev.mensaje, isNotEmpty);
    });

    test('óvalo de piel centrado con textura: lista al segundo frame', () {
      final svc = AutoCapturaService();
      final foto = fotoSintetica();
      final primero = svc.evaluar(foto);
      expect(primero.tieneRostro, isTrue);
      expect(primero.centrado, isTrue);
      expect(primero.iluminacionOk, isTrue);
      expect(primero.nitida, isTrue);
      // La estabilidad exige racha: el primero nunca dispara.
      expect(primero.estable, isFalse);
      expect(primero.lista, isFalse);

      final segundo = svc.evaluar(foto);
      expect(segundo.estable, isTrue);
      expect(segundo.lista, isTrue);
    });

    test('óvalo desplazado: no centrado y guía de dirección', () {
      final svc = AutoCapturaService();
      final ev = svc.evaluar(fotoSintetica(desplazarX: 40));
      expect(ev.tieneRostro, isTrue);
      expect(ev.centrado, isFalse);
      expect(ev.lista, isFalse);
    });

    test('reiniciar() rompe la racha de estabilidad', () {
      final svc = AutoCapturaService();
      final foto = fotoSintetica();
      svc.evaluar(foto);
      expect(svc.evaluar(foto).lista, isTrue);
      svc.reiniciar();
      expect(svc.evaluar(foto).lista, isFalse);
    });
  });
}
