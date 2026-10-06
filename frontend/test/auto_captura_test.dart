import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:consultorio_clinico/features/public/kiosk/auto_captura_service.dart';

/// Genera un JPEG sintético de 200x200: fondo oscuro + óvalo de "piel".
/// Con [desplazarX]/[desplazarY] se corre el óvalo; con [escalaX] se
/// angosta (simula giro); con [ruido] se agrega textura (sin ella la
/// nitidez da ~0, como una foto desenfocada).
Uint8List fotoSintetica({
  double desplazarX = 0,
  double desplazarY = 0,
  double escalaX = 1,
  bool ruido = true,
}) {
  const w = 200;
  const h = 200;
  final imagen = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = (x - (w / 2 + desplazarX)) / (w * 0.26 * escalaX);
      final dy = (y - (h / 2 + desplazarY)) / (h * 0.36);
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
      final primero = svc.evaluar(foto, pose: 'frontal');
      expect(primero.tieneRostro, isTrue);
      expect(primero.centrado, isTrue);
      expect(primero.iluminacionOk, isTrue);
      expect(primero.nitida, isTrue);
      // La estabilidad exige racha: el primero nunca dispara.
      expect(primero.estable, isFalse);
      expect(primero.lista, isFalse);

      final segundo = svc.evaluar(foto, pose: 'frontal');
      expect(segundo.estable, isTrue);
      expect(segundo.gestoOk, isTrue);
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
      svc.evaluar(foto, pose: 'frontal');
      expect(svc.evaluar(foto, pose: 'frontal').lista, isTrue);
      svc.reiniciar();
      expect(svc.evaluar(foto, pose: 'frontal').lista, isFalse);
    });

    test('izquierda sin moverse: gesto no válido, no dispara', () {
      final svc = AutoCapturaService();
      final frontal = fotoSintetica();
      svc.evaluar(frontal, pose: 'frontal');
      svc.evaluar(frontal, pose: 'frontal');
      svc.fijarReferenciaFrontal(frontal);
      // Mismo encuadre pidiendo izquierda: encuadre ok pero sin giro.
      final ev1 = svc.evaluar(frontal, pose: 'izquierda');
      final ev2 = svc.evaluar(frontal, pose: 'izquierda');
      expect(ev2.tieneRostro, isTrue);
      expect(ev2.gestoOk, isFalse);
      expect(ev2.lista, isFalse);
      expect(ev1.mensaje, isNotEmpty);
    });

    test('izquierda con giro (angosto + a la derecha): dispara', () {
      final svc = AutoCapturaService();
      final frontal = fotoSintetica();
      svc.evaluar(frontal, pose: 'frontal');
      svc.evaluar(frontal, pose: 'frontal');
      svc.fijarReferenciaFrontal(frontal);
      // Giro a su izquierda: máscara angosta y corrida a la derecha.
      final giro = fotoSintetica(escalaX: 0.8, desplazarX: 15);
      svc.evaluar(giro, pose: 'izquierda');
      final ev = svc.evaluar(giro, pose: 'izquierda');
      expect(ev.tieneRostro, isTrue);
      expect(ev.gestoOk, isTrue);
      expect(ev.lista, isTrue);
    });

    test('giro al lado contrario no pasa', () {
      final svc = AutoCapturaService();
      final frontal = fotoSintetica();
      svc.evaluar(frontal, pose: 'frontal');
      svc.evaluar(frontal, pose: 'frontal');
      svc.fijarReferenciaFrontal(frontal);
      final giroDer = fotoSintetica(escalaX: 0.8, desplazarX: -15);
      svc.evaluar(giroDer, pose: 'izquierda');
      final ev = svc.evaluar(giroDer, pose: 'izquierda');
      expect(ev.gestoOk, isFalse);
      expect(ev.lista, isFalse);
    });

    test('arriba con centroide abajo: dispara; abajo no', () {
      final svc = AutoCapturaService();
      final frontal = fotoSintetica();
      svc.evaluar(frontal, pose: 'frontal');
      svc.evaluar(frontal, pose: 'frontal');
      svc.fijarReferenciaFrontal(frontal);
      // Mentón arriba: la máscara se corre hacia abajo en la imagen.
      final sube = fotoSintetica(desplazarY: 20);
      svc.evaluar(sube, pose: 'arriba');
      final evArr = svc.evaluar(sube, pose: 'arriba');
      expect(evArr.gestoOk, isTrue);
      expect(evArr.lista, isTrue);
      final evAba = svc.evaluar(sube, pose: 'abajo');
      expect(evAba.gestoOk, isFalse);
    });

    test('sin referencia frontal se aprueba el gesto (lo verifica el servidor)', () {
      final svc = AutoCapturaService();
      final foto = fotoSintetica();
      svc.evaluar(foto, pose: 'izquierda');
      final ev = svc.evaluar(foto, pose: 'izquierda');
      expect(ev.gestoOk, isTrue);
    });
  });
}
