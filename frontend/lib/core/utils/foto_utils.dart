import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Utilidades para fotos del rostro: livianas por diseño.
///
/// La cámara entrega varios MB por foto; para transporte y Storage se
/// comprimen a JPEG con lado mayor limitado. Una muestra típica queda en
/// 30-80 KB: suficiente para InsightFace y barata de subir/descargar.
class FotoUtils {
  FotoUtils._();

  /// Comprime [bytes] a JPEG liviano (defecto: lado mayor 800, calidad 80).
  /// Devuelve los bytes originales si ya no se pueden comprimir.
  static Uint8List comprimirJpg(
    Uint8List bytes, {
    int maxLado = 800,
    int calidad = 80,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final mayor = decoded.width > decoded.height ? decoded.width : decoded.height;
      final img.Image redimensionada =
          mayor > maxLado ? img.copyResize(decoded, width: decoded.width >= decoded.height ? maxLado : null, height: decoded.height > decoded.width ? maxLado : null) : decoded;
      return Uint8List.fromList(img.encodeJpg(redimensionada, quality: calidad));
    } catch (_) {
      return bytes;
    }
  }

  /// Atajo: comprimir + base64 listo para el payload del backend.
  static String? aBase64Liviano(
    Uint8List bytes, {
    int maxLado = 800,
    int calidad = 80,
  }) {
    try {
      return base64Encode(comprimirJpg(bytes, maxLado: maxLado, calidad: calidad));
    } catch (_) {
      return null;
    }
  }
}
