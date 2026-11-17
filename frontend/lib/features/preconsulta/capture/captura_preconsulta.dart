/// Fachada de captura de la PreConsulta IA.
///
/// Resuelve la implementación en tiempo de compilación:
/// - Web -> frames JPEG con `package:web`.
/// - Android/escritorio -> frames JPEG con el plugin `camera`.
/// - Otros (tests) -> stub que explica que la cámara no está disponible.
library;

export 'captura_preconsulta_tipos.dart';
export 'captura_preconsulta_stub.dart'
    if (dart.library.js_interop) 'captura_preconsulta_web.dart'
    if (dart.library.io) 'captura_preconsulta_nativa.dart';
