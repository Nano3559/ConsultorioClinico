/// Tipos compartidos por las capturas de la PreConsulta IA.
///
/// La captura web envía una secuencia de frames JPEG; la nativa, un video
/// corto. En ambos casos el resultado es solo memoria: nada se guarda en disco
/// ni se retiene en el servidor.
library;

/// Motivo por el que la cámara no está disponible.
enum CapturaErrorKind { denied, noCamera, busy, notSupported, unknown }

class CapturaException implements Exception {
  const CapturaException(this.kind, this.message);

  final CapturaErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Cámara detectada en el dispositivo (web, Android, iOS o escritorio).
class CamaraDisponible {
  const CamaraDisponible({
    required this.id,
    required this.nombre,
    this.frontal = false,
  });

  /// Identificador que entiende la plataforma (deviceId en web, nombre del
  /// plugin `camera` en la app).
  final String id;
  final String nombre;
  final bool frontal;

  /// Cámara que se preselecciona: la frontal (selfie) si existe, o la primera.
  static CamaraDisponible? preferida(List<CamaraDisponible> camaras) {
    if (camaras.isEmpty) return null;
    for (final c in camaras) {
      if (c.frontal) return c;
    }
    return camaras.first;
  }
}

/// Resultado de una captura completa (frames o video, en base64).
class ResultadoCaptura {
  const ResultadoCaptura({
    this.frames = const [],
    this.video,
    required this.fps,
    required this.duracionSeg,
  });

  final List<String> frames;
  final String? video;
  final double fps;
  final double duracionSeg;

  bool get vacia => frames.isEmpty && (video == null || video!.isEmpty);
  int get unidades => video != null ? 1 : frames.length;
}
