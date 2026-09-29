import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Motor de reconocimiento facial LOCAL del kiosco (OpenCV en el equipo).
///
/// Flujo: Haar Cascade detecta el rostro -> se recorta, pasa a gris,
/// ecualiza y calcula su histograma -> se compara (correlación) contra los
/// histogramas de las fotos descargadas de los pacientes con cita hoy.
///
/// Todo ocurre en la PC del consultorio: las fotos NUNCA se procesan en la
/// nube, solo se descargan para enrolar.
class FaceEngine {
  cv.CascadeClassifier? _cascade;
  final Map<String, cv.Mat> _plantillas = {};

  /// Umbral de correlación para aceptar una coincidencia (0..1).
  static const double umbral = 0.55;

  bool get listo => _cascade != null;

  /// Carga el clasificador Haar desde el asset empaquetado.
  Future<void> init() async {
    final data = await rootBundle
        .load('assets/opencv/haarcascade_frontalface_default.xml');
    final dir = Directory.systemTemp.createTempSync('kiosco_');
    final file = File('${dir.path}/haarcascade.xml');
    await file.writeAsBytes(data.buffer.asUint8List());
    _cascade = cv.CascadeClassifier.fromFile(file.path);
  }

  /// Calcula el histograma normalizado del rostro en [bytes] (JPG/PNG).
  /// Devuelve null si no se detecta ningún rostro.
  cv.Mat? histogramaDe(Uint8List bytes) {
    final cascade = _cascade;
    if (cascade == null) return null;
    try {
      final img = cv.imdecode(bytes, cv.IMREAD_COLOR);
      if (img.isEmpty) return null;
      final rostros = cascade.detectMultiScale(
        img,
        scaleFactor: 1.1,
        minNeighbors: 4,
        minSize: (60, 60),
      );
      if (rostros.length == 0) return null;
      // El rostro más grande (el más cercano a la cámara).
      var mejor = rostros[0];
      for (var i = 1; i < rostros.length; i++) {
        final r = rostros[i];
        if (r.width * r.height > mejor.width * mejor.height) mejor = r;
      }
      final x = mejor.x.clamp(0, img.cols - 1);
      final y = mejor.y.clamp(0, img.rows - 1);
      final w = (mejor.width).clamp(1, img.cols - x);
      final h = (mejor.height).clamp(1, img.rows - y);
      final cara = img.region(cv.Rect(x, y, w, h));
      final gris = cv.cvtColor(cara, cv.COLOR_BGR2GRAY);
      final eq = cv.equalizeHist(gris);
      final hist = cv.calcHist(
        cv.VecMat.fromList([eq]),
        cv.VecI32.fromList([0]),
        cv.Mat.empty(),
        cv.VecI32.fromList([64]),
        cv.VecF32.fromList([0.0, 256.0]),
      );
      return hist;
    } catch (_) {
      return null;
    }
  }

  /// Enrola las fotos descargadas: {pacienteId: base64}.
  /// Devuelve cuántos rostros quedaron registrados.
  int enrolar(Map<String, String> fotos) {
    _plantillas.clear();
    var n = 0;
    fotos.forEach((id, b64) {
      if (b64.isEmpty) return;
      try {
        final hist = histogramaDe(base64Decode(b64));
        if (hist != null) {
          _plantillas[id] = hist;
          n++;
        }
      } catch (_) {}
    });
    return n;
  }

  int get enrolados => _plantillas.length;

  /// Reconoce el rostro en [bytes]. Devuelve (pacienteId, puntaje) o null.
  (String, double)? reconocer(Uint8List bytes) {
    final hist = histogramaDe(bytes);
    if (hist == null || _plantillas.isEmpty) return null;
    String? mejorId;
    var mejorScore = -1.0;
    _plantillas.forEach((id, plantilla) {
      try {
        final s = cv.compareHist(hist, plantilla);
        if (s > mejorScore) {
          mejorScore = s;
          mejorId = id;
        }
      } catch (_) {}
    });
    if (mejorId == null || mejorScore < umbral) return null;
    return (mejorId!, mejorScore);
  }

  /// Captura un frame de la webcam (índice 0) y lo devuelve como JPG.
  /// Devuelve null si no hay cámara disponible.
  Uint8List? capturar() {
    try {
      final cap = cv.VideoCapture.fromDevice(0);
      if (!cap.isOpened) {
        cap.release();
        return null;
      }
      Uint8List? out;
      for (var i = 0; i < 5; i++) {
        final (ok, frame) = cap.read();
        if (!ok || frame.isEmpty) continue;
        final (okEnc, buf) = cv.imencode('.jpg', frame);
        if (okEnc) {
          out = Uint8List.fromList(buf);
          break;
        }
      }
      cap.release();
      return out;
    } catch (_) {
      return null;
    }
  }
}
