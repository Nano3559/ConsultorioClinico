import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;

/// Evaluación de un frame de prueba para la captura automática estilo
/// Binance: el paciente solo posiciona el rostro y sigue la instrucción del
/// gesto; la foto se toma sola cuando el encuadre es óptimo.
///
/// Todo el análisis es local (sin red) sobre una copia de ~160 px: es
/// una GUÍA de encuadre, no una verificación biométrica. El control de
/// calidad real sigue siendo el pipeline del backend al enviar el pack
/// (calidad + gesto + identidad por pose). Los umbrales son conservadores
/// a propósito: ante la duda se pide otro frame, y el diálogo ofrece
/// captura manual si el auto no lo logra en un tiempo prudente.
///
/// SUPUESTO de espejo resuelto por plataforma: en web la cámara frontal
/// entrega archivos espejados (lo voltea el propio plugin) y en móvil o
/// Windows no. El flag `espejado` (por defecto según plataforma) invierte
/// el signo horizontal para que "su izquierda" siempre sea su izquierda.
class EvaluacionFoto {
  const EvaluacionFoto({
    required this.tieneRostro,
    required this.centrado,
    required this.iluminacionOk,
    required this.nitida,
    required this.estable,
    required this.gestoOk,
    required this.mensaje,
  });

  /// Rostro presente + centrado + bien iluminado + nítido + quieto +
  /// gesto de la pose ejecutado (para frontal no hay gesto que verificar).
  /// `estable` exige 2 frames buenos seguidos (nunca dispara al primero).
  bool get lista =>
      tieneRostro &&
      centrado &&
      iluminacionOk &&
      nitida &&
      estable &&
      gestoOk;

  final bool tieneRostro;
  final bool centrado;
  final bool iluminacionOk;
  final bool nitida;
  final bool estable;

  /// El giro/inclinación pedido se midió de verdad (vs referencia frontal).
  final bool gestoOk;

  /// Guía corta para mostrar bajo la instrucción ("Acércate al óvalo"…).
  final String mensaje;
}

/// Geometría del rostro frontal (ancla para medir el gesto de las demás
/// poses). Todo normalizado 0-1 contra el tamaño del frame analizado.
class ReferenciaRostro {
  const ReferenciaRostro({
    required this.ancho,
    required this.alto,
    required this.cx,
    required this.cy,
  });

  final double ancho;
  final double alto;
  final double cx;
  final double cy;
}

/// Servicio sin estado de UI: evalúa frames JPEG y decide si disparar.
class AutoCapturaService {
  AutoCapturaService({this.anchoAnalisis = 160, bool? espejado})
      : _espejado = espejado ?? kIsWeb;

  /// Ancho al que se reduce el frame para analizar (rapidez).
  final int anchoAnalisis;

  /// En web la cámara frontal entrega archivos ESPEJADOS (camera_web voltea
  /// las capturas no-traseras): la derecha de la imagen es la derecha de la
  /// persona. En móvil/Windows no se espeja. Si alguna plataforma se comporta
  /// distinto, se invierte solo este flag (los mensajes anatómicos no cambian).
  final bool _espejado;

  _Racha? _anterior;

  /// Ancla frontal para medir el gesto (se fija al capturar la frontal).
  ReferenciaRostro? _referencia;

  /// Llamar al cambiar de pose: la estabilidad exige racha nueva (la
  /// referencia frontal se conserva).
  void nuevaPose() => _anterior = null;

  /// Reinicio total (al abrir/cerrar el diálogo).
  void reiniciar() {
    _anterior = null;
    _referencia = null;
  }

  /// Fija la geometría frontal a partir de sus bytes (se llama al aceptar
  /// la foto frontal, sea automática o manual).
  void fijarReferenciaFrontal(Uint8List jpegBytes) {
    final m = _analizar(jpegBytes);
    _anterior = _Racha(
      hayRostro: m.tieneRostro,
      desplazamientoX: m.desplazamientoX,
      desplazamientoY: m.desplazamientoY,
      fraccionPiel: m.fraccionPiel,
      lumaMedia: m.lumaMedia,
    );
    if (!m.tieneRostro) return;
    _referencia = ReferenciaRostro(
      ancho: (m.maxX - m.minX).clamp(0.01, 1.0),
      alto: (m.maxY - m.minY).clamp(0.01, 1.0),
      cx: m.centroideX,
      cy: m.centroideY,
    );
  }

  EvaluacionFoto evaluar(Uint8List jpegBytes, {String pose = 'frontal'}) {
    final actual = _analizar(jpegBytes);
    // En poses de giro la cara ocupa menos óvalo y media queda en sombra:
    // la presencia se relaja (el gesto se verifica aparte contra la
    // frontal). El estable usa esta misma presencia relajada.
    final esGiro = pose.trim().toLowerCase() != 'frontal';
    final hayRostro =
        esGiro ? actual.fraccionPiel > 0.12 : actual.tieneRostro;
    final previo = _anterior;
    final estable = previo != null &&
        previo.hayRostro &&
        hayRostro &&
        (previo.desplazamientoX - actual.desplazamientoX).abs() < 0.05 &&
        (previo.desplazamientoY - actual.desplazamientoY).abs() < 0.05 &&
        (previo.fraccionPiel - actual.fraccionPiel).abs() < 0.08 &&
        (previo.lumaMedia - actual.lumaMedia).abs() < 15;
    _anterior = _Racha(
        hayRostro: hayRostro,
        desplazamientoX: actual.desplazamientoX,
        desplazamientoY: actual.desplazamientoY,
        fraccionPiel: actual.fraccionPiel,
        lumaMedia: actual.lumaMedia);
    final tieneRostro = hayRostro;
    final centrado = esGiro
        ? actual.desplazamientoX.abs() < 0.20 &&
            actual.desplazamientoY.abs() < 0.20
        : actual.centrado;
    final iluminacionOk = esGiro
        ? actual.lumaPiel >= 50 && actual.lumaPiel <= 215
        : actual.iluminacionOk;
    final nitida =
        esGiro ? actual.varLapPiel > 8 : actual.nitida;

    final String mensaje;
    var gestoOk = true;
    if (!tieneRostro) {
      mensaje = 'Ubica tu rostro dentro del óvalo';
    } else if (!centrado) {
      mensaje = actual.desplazamientoX < -0.02
          ? 'Muévete un poco a tu derecha'
          : actual.desplazamientoX > 0.02
              ? 'Muévete un poco a tu izquierda'
              : 'Centra tu rostro en el óvalo';
    } else if (!iluminacionOk) {
      mensaje = actual.lumaPiel < 50
          ? 'Hay poca luz: acércate a una luz'
          : 'Hay demasiada luz detrás: muévete';
    } else if (!nitida) {
      mensaje = 'Quédate quieto…';
    } else if (!estable) {
      mensaje = 'Quietito… capturando';
    } else {
      // Encuadre óptimo: verificar que el gesto pedido se ejecutó de
      // verdad (diferencial contra la frontal). Sin referencia se aprueba:
      // el servidor igual lo verifica por pose.
      gestoOk = _verificarGesto(pose, actual);
      if (gestoOk) {
        mensaje = '¡Perfecto!';
      } else if (_giroContrario(pose, actual)) {
        mensaje = _mensajeLadoContrario(pose);
      } else {
        mensaje = _mensajeGesto(pose);
      }
    }
    return EvaluacionFoto(
      tieneRostro: tieneRostro,
      centrado: centrado,
      iluminacionOk: iluminacionOk,
      nitida: nitida,
      estable: estable,
      gestoOk: gestoOk,
      mensaje: mensaje,
    );
  }

  /// Compara la geometría actual contra la frontal: el giro debe verse.
  /// Giros suaves (~12-15°) ya pasan: el que no se movió da ~1.0/~0 y
  /// queda fuera por ambos lados. El signo horizontal se invierte si la
  /// plataforma espeja (web); la vertical nunca se espeja.
  bool _verificarGesto(String pose, _Medicion actual) {
    final ref = _referencia;
    if (ref == null) return true;
    final repouse = pose.trim().toLowerCase();
    if (repouse == 'frontal') return true;
    final ancho = (actual.maxX - actual.minX).clamp(0.01, 1.0);
    final alto = (actual.maxY - actual.minY).clamp(0.01, 1.0);
    final razonAncho = ancho / ref.ancho;
    final razonAlto = alto / ref.alto;
    // dx>0 = corrido a la derecha de la imagen. Sin espejar eso es SU
    // izquierda; espejado (web) es SU derecha: se invierte el signo.
    final dx = (actual.centroideX - ref.cx) * (_espejado ? -1 : 1);
    final dy = actual.centroideY - ref.cy;
    switch (repouse) {
      case 'izquierda': // su izquierda
        return razonAncho < 0.98 && dx > 0.015;
      case 'derecha':
        return razonAncho < 0.98 && dx < -0.015;
      case 'arriba': // mentón arriba: el centroide baja en la imagen
        return dy > 0.022;
      case 'abajo': // mentón abajo (encoge): alto se acorta, ancho se
        // mantiene y el centroide NO baja (eso sería deslizar la cara,
        // no meter el mentón)
        return razonAlto < 0.94 && razonAncho > 0.95 && dy < 0.01;
      default:
        return true;
    }
  }

  /// Detecta giro CLARO al lado contrario (para guiar, no para aprobar).
  bool _giroContrario(String pose, _Medicion actual) {
    final ref = _referencia;
    if (ref == null) return false;
    final dx = (actual.centroideX - ref.cx) * (_espejado ? -1 : 1);
    final dy = actual.centroideY - ref.cy;
    switch (pose.trim().toLowerCase()) {
      case 'izquierda':
        return dx < -0.03;
      case 'derecha':
        return dx > 0.03;
      case 'arriba':
        return dy < -0.03;
      case 'abajo':
        return dy > 0.03;
      default:
        return false;
    }
  }

  String _mensajeGesto(String pose) {
    switch (pose.trim().toLowerCase()) {
      case 'izquierda':
        return 'Gira más tu cara a tu izquierda';
      case 'derecha':
        return 'Gira más tu cara a tu derecha';
      case 'arriba':
        return 'Levanta más el mentón';
      case 'abajo':
        return 'Baja más el mentón';
      default:
        return 'Quietito… capturando';
    }
  }

  String _mensajeLadoContrario(String pose) {
    switch (pose.trim().toLowerCase()) {
      case 'izquierda':
        return '¡Es al otro lado! Gira a tu IZQUIERDA';
      case 'derecha':
        return '¡Es al otro lado! Gira a tu DERECHA';
      case 'arriba':
        return '¡Al revés! Levanta el MENTÓN';
      case 'abajo':
        return '¡Al revés! Baja el MENTÓN';
      default:
        return '¡Al revés! Baja el MENTÓN';
    }
  }

  _Medicion _analizar(Uint8List jpegBytes) {
    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) {
      return const _Medicion(
        tieneRostro: false,
        centrado: false,
        iluminacionOk: false,
        nitida: false,
        fraccionPiel: 0,
        lumaMedia: 0,
        lumaPiel: 0,
        varLapPiel: 0,
        desplazamientoX: 0,
        desplazamientoY: 0,
        centroideX: 0.5,
        centroideY: 0.5,
        minX: 0,
        maxX: 0,
        minY: 0,
        maxY: 0,
      );
    }
    final trabajo = img.copyResize(decoded, width: anchoAnalisis);
    final w = trabajo.width;
    final h = trabajo.height;

    // Óvalo guía (misma geometría que el pintor de la UI: 52% x 72%).
    final cx = w / 2;
    final cy = h / 2;
    final rx = w * 0.26;
    final ry = h * 0.36;

    var sumaLuma = 0.0;
    var nOvalo = 0;
    var nPiel = 0;
    var sumaLumaPiel = 0.0;
    var sumaPielX = 0.0;
    var sumaPielY = 0.0;
    var minPX = w.toDouble();
    var maxPX = -1.0;
    var minPY = h.toDouble();
    var maxPY = -1.0;
    // Grises para nitidez (Laplaciano) en pasada posterior.
    final grises = List<int>.filled(w * h, 0);
    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < w; x += 2) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        final px = trabajo.getPixel(x, y);
        final r = px.r.toInt();
        final g = px.g.toInt();
        final b = px.b.toInt();
        final luma = (0.299 * r + 0.587 * g + 0.114 * b).round();
        grises[y * w + x] = luma;
        if (dx * dx + dy * dy > 1) continue;
        nOvalo++;
        sumaLuma += luma;
        if (_esPiel(r, g, b)) {
          nPiel++;
          sumaLumaPiel += luma;
          sumaPielX += x;
          sumaPielY += y;
          if (x < minPX) minPX = x.toDouble();
          if (x > maxPX) maxPX = x.toDouble();
          if (y < minPY) minPY = y.toDouble();
          if (y > maxPY) maxPY = y.toDouble();
        }
      }
    }
    if (nOvalo == 0) {
      return const _Medicion(
        tieneRostro: false,
        centrado: false,
        iluminacionOk: false,
        nitida: false,
        fraccionPiel: 0,
        lumaMedia: 0,
        lumaPiel: 0,
        varLapPiel: 0,
        desplazamientoX: 0,
        desplazamientoY: 0,
        centroideX: 0.5,
        centroideY: 0.5,
        minX: 0,
        maxX: 0,
        minY: 0,
        maxY: 0,
      );
    }
    final fraccionPiel = nPiel / nOvalo;
    final lumaMedia = sumaLuma / nOvalo;
    final tieneRostro = fraccionPiel > 0.18;
    var dxN = 0.0;
    var dyN = 0.0;
    if (nPiel > 0) {
      dxN = (sumaPielX / nPiel - cx) / w;
      dyN = (sumaPielY / nPiel - cy) / h;
    }
    final centrado = tieneRostro && dxN.abs() < 0.10 && dyN.abs() < 0.12;
    final iluminacionOk = lumaMedia >= 55 && lumaMedia <= 205;

    // Nitidez: varianza del Laplaciano sobre el óvalo (muestreo grueso),
    // más versión SOLO-piel (para giros con fondo/sombra).
    var sumaLap = 0.0;
    var sumaLap2 = 0.0;
    var nLap = 0;
    var sumaLapP = 0.0;
    var sumaLap2P = 0.0;
    var nLapP = 0;
    for (var y = 2; y < h - 2; y += 4) {
      for (var x = 2; x < w - 2; x += 4) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        if (dx * dx + dy * dy > 1) continue;
        final lap = (grises[(y - 2) * w + x] +
                grises[(y + 2) * w + x] +
                grises[y * w + x - 2] +
                grises[y * w + x + 2] -
                4 * grises[y * w + x])
            .abs()
            .toDouble();
        sumaLap += lap;
        sumaLap2 += lap * lap;
        nLap++;
        final px2 = trabajo.getPixel(x, y);
        if (_esPiel(px2.r.toInt(), px2.g.toInt(), px2.b.toInt())) {
          sumaLapP += lap;
          sumaLap2P += lap * lap;
          nLapP++;
        }
      }
    }
    var nitida = false;
    if (nLap > 0) {
      final media = sumaLap / nLap;
      final varianza = sumaLap2 / nLap - media * media;
      nitida = varianza > 12;
    }
    var varLapPiel = 0.0;
    if (nLapP > 0) {
      final mediaP = sumaLapP / nLapP;
      varLapPiel = sumaLap2P / nLapP - mediaP * mediaP;
    }

    return _Medicion(
      tieneRostro: tieneRostro,
      centrado: centrado,
      iluminacionOk: iluminacionOk,
      nitida: nitida,
      fraccionPiel: fraccionPiel,
      lumaMedia: lumaMedia,
      lumaPiel: nPiel > 0 ? sumaLumaPiel / nPiel : 0,
      varLapPiel: varLapPiel,
      desplazamientoX: dxN,
      desplazamientoY: dyN,
      centroideX: nPiel > 0 ? (sumaPielX / nPiel) / w : 0.5,
      centroideY: nPiel > 0 ? (sumaPielY / nPiel) / h : 0.5,
      minX: nPiel > 0 ? minPX / w : 0,
      maxX: nPiel > 0 ? maxPX / w : 0,
      minY: nPiel > 0 ? minPY / h : 0,
      maxY: nPiel > 0 ? maxPY / h : 0,
    );
  }

  /// Regla de piel en YCrCb (rápida y estable entre tonos): devuelve true
  /// para píxeles de piel con luz normal.
  bool _esPiel(int r, int g, int b) {
    if (!(r > 95 && g > 40 && b > 20 && r > g && r > b && (r - g) > 15)) {
      return false;
    }
    final cr = 128 + 0.5 * r - 0.4187 * g - 0.0813 * b;
    final cb = 128 - 0.1687 * r - 0.3313 * g + 0.5 * b;
    return cr >= 133 && cr <= 173 && cb >= 77 && cb <= 127;
  }
}

/// Foto instantánea para la racha de estabilidad (interna).
class _Racha {
  const _Racha({
    required this.hayRostro,
    required this.desplazamientoX,
    required this.desplazamientoY,
    required this.fraccionPiel,
    required this.lumaMedia,
  });

  final bool hayRostro;
  final double desplazamientoX;
  final double desplazamientoY;
  final double fraccionPiel;
  final double lumaMedia;
}

/// Medición cruda de un frame (interna; la racha la lleva el servicio).
class _Medicion {
  const _Medicion({
    required this.tieneRostro,
    required this.centrado,
    required this.iluminacionOk,
    required this.nitida,
    required this.fraccionPiel,
    required this.lumaMedia,
    required this.lumaPiel,
    required this.varLapPiel,
    required this.desplazamientoX,
    required this.desplazamientoY,
    required this.centroideX,
    required this.centroideY,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final bool tieneRostro;
  final bool centrado;
  final bool iluminacionOk;
  final bool nitida;
  final double fraccionPiel;
  final double lumaMedia;

  /// Luz y nitidez medidas SOLO sobre piel (robustas en giros con sombra).
  final double lumaPiel;
  final double varLapPiel;

  final double desplazamientoX;
  final double desplazamientoY;

  /// Centroide y caja de la máscara de piel, normalizados 0-1.
  final double centroideX;
  final double centroideY;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}

