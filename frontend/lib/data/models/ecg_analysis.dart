/// Resultado del análisis de ECG con IA del servicio CardiologiaEGC.
///
/// Respuesta de `POST /api/analizar-ecg` (FastAPI + modelo ECG_ResNet1D).
class EcgAnalysis {
  const EcgAnalysis({
    required this.diagnosticoPrincipal,
    required this.confianza,
    required this.desglose,
    required this.bpm,
    required this.causas,
    required this.recomendaciones,
  });

  /// Dictamen con mayor probabilidad emitido por el modelo.
  final String diagnosticoPrincipal;

  /// Confianza del dictamen principal en porcentaje (0..100).
  final double confianza;

  /// Probabilidad por patología, en porcentaje (0..100).
  final Map<String, double> desglose;

  /// Frecuencia cardíaca sincronizada con el trazado (texto, ej. "72 BPM").
  final String bpm;

  /// Causas posibles del cuadro clínico detectado.
  final List<String> causas;

  /// Recomendaciones médicas asociadas al dictamen.
  final List<String> recomendaciones;

  /// Construye un [EcgAnalysis] desde el JSON del servicio de IA.
  factory EcgAnalysis.fromApi(Map<String, dynamic> json) {
    final desglose = <String, double>{};
    final raw = json['desglose'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final prob = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
        desglose['$k'] = prob;
      });
    }
    final confianza = json['confianza'] is num
        ? (json['confianza'] as num).toDouble()
        : double.tryParse('${json['confianza']}') ?? 0;
    return EcgAnalysis(
      diagnosticoPrincipal: (json['diagnostico_principal'] ?? '').toString(),
      confianza: confianza,
      desglose: desglose,
      bpm: (json['bpm'] ?? '').toString(),
      causas: (json['causas'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      recomendaciones: (json['recomendaciones'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  /// Color semántico del dictamen: normal (éxito), isquemia/infarto
  /// (urgencia) o atención/monitoreo (alerta).
  bool get esNormal => diagnosticoPrincipal.contains('Normal');

  bool get esUrgencia =>
      diagnosticoPrincipal.contains('Isquemia') ||
      diagnosticoPrincipal.contains('Infarto');
}
