import 'package:flutter/material.dart';

/// Modelos de la PreConsulta IA (migración 015).
///
/// El backend devuelve metadatos en snake_case, números que pueden llegar
/// como texto (NUMERIC de PostgreSQL) y fechas ISO. Todos los `fromJson`
/// son defensivos: un dato ausente se convierte en `null` o en una lista
/// vacía, nunca en una excepción que rompa la pantalla.

double? _num(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().replaceAll(',', '.'));
}

int? _int(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}

DateTime? _fecha(dynamic valor) {
  if (valor == null) return null;
  if (valor is DateTime) return valor;
  return DateTime.tryParse(valor.toString())?.toLocal();
}

List<dynamic> _lista(dynamic valor) => valor is List ? valor : const [];

Map<String, dynamic> _mapa(dynamic valor) =>
    valor is Map<String, dynamic> ? valor : <String, dynamic>{};

/// Convierte un color hex del backend (#RRGGBB) en [Color].
Color colorDesdeHex(String? hex, {Color fallback = const Color(0xFF0D9488)}) {
  final texto = (hex ?? '').replaceAll('#', '').trim();
  if (texto.length != 6) return fallback;
  final valor = int.tryParse(texto, radix: 16);
  if (valor == null) return fallback;
  return Color(0xFF000000 | valor);
}

// ============================================================================
// Catálogo y consentimiento
// ============================================================================
class PreconsultaOpcion {
  const PreconsultaOpcion({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  factory PreconsultaOpcion.fromJson(Map<String, dynamic> json) =>
      PreconsultaOpcion(
        valor: (json['valor'] ?? '').toString(),
        etiqueta: (json['etiqueta'] ?? json['valor'] ?? '').toString(),
      );
}

class PreconsultaPregunta {
  const PreconsultaPregunta({
    required this.codigo,
    required this.seccion,
    required this.pregunta,
    required this.tipo,
    required this.orden,
    this.ayuda = '',
    this.requerida = false,
    this.min,
    this.max,
    this.opciones = const [],
  });

  final String codigo;
  final String seccion;
  final String pregunta;
  final String ayuda;
  final String tipo;
  final bool requerida;
  final int? min;
  final int? max;
  final int orden;
  final List<PreconsultaOpcion> opciones;

  factory PreconsultaPregunta.fromJson(Map<String, dynamic> json) =>
      PreconsultaPregunta(
        codigo: (json['codigo'] ?? '').toString(),
        seccion: (json['seccion'] ?? 'otros').toString(),
        pregunta: (json['pregunta'] ?? '').toString(),
        ayuda: (json['ayuda'] ?? '').toString(),
        tipo: (json['tipo'] ?? 'texto').toString(),
        requerida: json['requerida'] == true,
        min: _int(json['min']),
        max: _int(json['max']),
        orden: _int(json['orden']) ?? 999,
        opciones: _lista(json['opciones'])
            .whereType<Map<String, dynamic>>()
            .map(PreconsultaOpcion.fromJson)
            .toList(),
      );
}

class PreconsultaSeccion {
  const PreconsultaSeccion({
    required this.clave,
    required this.titulo,
    required this.descripcion,
  });

  final String clave;
  final String titulo;
  final String descripcion;

  factory PreconsultaSeccion.fromJson(Map<String, dynamic> json) =>
      PreconsultaSeccion(
        clave: (json['clave'] ?? '').toString(),
        titulo: (json['titulo'] ?? '').toString(),
        descripcion: (json['descripcion'] ?? '').toString(),
      );
}

class ConsentimientoParrafo {
  const ConsentimientoParrafo({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  factory ConsentimientoParrafo.fromJson(Map<String, dynamic> json) =>
      ConsentimientoParrafo(
        titulo: (json['titulo'] ?? '').toString(),
        texto: (json['texto'] ?? '').toString(),
      );
}

class ConsentimientoPreconsulta {
  const ConsentimientoPreconsulta({
    required this.version,
    required this.titulo,
    required this.subtitulo,
    required this.resumen,
    required this.parrafos,
    required this.datos,
    required this.derechos,
    required this.retencion,
    required this.contacto,
    required this.noEsDiagnostico,
    required this.requiereRevisionHumana,
  });

  final String version;
  final String titulo;
  final String subtitulo;
  final String resumen;
  final List<ConsentimientoParrafo> parrafos;
  final List<String> datos;
  final List<String> derechos;
  final String retencion;
  final String contacto;
  final bool noEsDiagnostico;
  final bool requiereRevisionHumana;

  factory ConsentimientoPreconsulta.fromJson(Map<String, dynamic> json) =>
      ConsentimientoPreconsulta(
        version: (json['version'] ?? '').toString(),
        titulo: (json['titulo'] ?? '').toString(),
        subtitulo: (json['subtitulo'] ?? '').toString(),
        resumen: (json['resumen'] ?? '').toString(),
        parrafos: _lista(json['parrafos'])
            .whereType<Map<String, dynamic>>()
            .map(ConsentimientoParrafo.fromJson)
            .toList(),
        datos: _lista(json['datos']).map((e) => e.toString()).toList(),
        derechos: _lista(json['derechos']).map((e) => e.toString()).toList(),
        retencion: (json['retencion'] ?? '').toString(),
        contacto: (json['contacto'] ?? '').toString(),
        noEsDiagnostico: json['no_es_diagnostico'] == true,
        requiereRevisionHumana: json['requiere_revision_humana'] == true,
      );
}

class NivelTriage {
  const NivelTriage({
    required this.nivel,
    required this.clave,
    required this.etiqueta,
    required this.color,
    this.maxMinutos,
  });

  final int nivel;
  final String clave;
  final String etiqueta;
  final Color color;
  final int? maxMinutos;

  String get tiempo {
    if (maxMinutos == null) return 'Sin límite';
    if (maxMinutos == 0) return 'Ahora';
    if (maxMinutos! < 60) return '≤ ${maxMinutos!} min';
    final horas = (maxMinutos! / 60).round();
    return '≤ $horas h';
  }

  factory NivelTriage.fromJson(Map<String, dynamic> json) => NivelTriage(
    nivel: _int(json['nivel']) ?? 5,
    clave: (json['clave'] ?? '').toString(),
    etiqueta: (json['etiqueta'] ?? '').toString(),
    color: colorDesdeHex(json['color']?.toString()),
    maxMinutos: _int(json['max_minutos']),
  );
}

class PreconsultaCatalogo {
  const PreconsultaCatalogo({
    required this.habilitado,
    required this.consentimiento,
    required this.secciones,
    required this.preguntas,
    required this.niveles,
    required this.yaAceptado,
    required this.aceptadoEn,
    this.pacienteId,
  });

  final bool habilitado;
  final ConsentimientoPreconsulta consentimiento;
  final List<PreconsultaSeccion> secciones;
  final List<PreconsultaPregunta> preguntas;
  final List<NivelTriage> niveles;
  final bool yaAceptado;
  final DateTime? aceptadoEn;
  final int? pacienteId;

  String get version => consentimiento.version;

  /// Preguntas de una sección, ya ordenadas.
  List<PreconsultaPregunta> preguntasDe(String seccion) =>
      preguntas.where((p) => p.seccion == seccion).toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));

  factory PreconsultaCatalogo.fromJson(Map<String, dynamic> json) =>
      PreconsultaCatalogo(
        habilitado: json['habilitado'] != false,
        consentimiento: ConsentimientoPreconsulta.fromJson(
          _mapa(json['consentimiento']),
        ),
        secciones: _lista(json['secciones'])
            .whereType<Map<String, dynamic>>()
            .map(PreconsultaSeccion.fromJson)
            .toList(),
        preguntas: _lista(json['preguntas'])
            .whereType<Map<String, dynamic>>()
            .map(PreconsultaPregunta.fromJson)
            .toList(),
        niveles: _lista(json['niveles'])
            .whereType<Map<String, dynamic>>()
            .map(NivelTriage.fromJson)
            .toList(),
        yaAceptado: json['ya_aceptado'] == true,
        aceptadoEn: _fecha(json['aceptado_en']),
        pacienteId: _int(json['paciente_id']),
      );
}

// ============================================================================
// Resultado del triage
// ============================================================================
class MotivoTriage {
  const MotivoTriage({
    required this.codigo,
    required this.etiqueta,
    required this.peso,
    required this.detalle,
    required this.fuente,
  });

  final String codigo;
  final String etiqueta;
  final double peso;
  final String detalle;
  final String fuente;

  /// Etiqueta legible de la fuente que aportó el peso.
  String get fuenteEtiqueta {
    switch (fuente) {
      case 'cuestionario':
        return 'Cuestionario';
      case 'signos':
        return 'Signos estimados';
      case 'facial':
        return 'Expresión facial';
      case 'contexto':
        return 'Contexto clínico';
      default:
        return 'Sistema';
    }
  }

  factory MotivoTriage.fromJson(Map<String, dynamic> json) => MotivoTriage(
    codigo: (json['codigo'] ?? '').toString(),
    etiqueta: (json['etiqueta'] ?? '').toString(),
    peso: _num(json['peso']) ?? 0,
    detalle: (json['detalle'] ?? '').toString(),
    fuente: (json['fuente'] ?? 'sistema').toString(),
  );
}

class BanderaTriage {
  const BanderaTriage({
    required this.codigo,
    required this.severidad,
    required this.texto,
  });

  final String codigo;
  final String severidad;
  final String texto;

  bool get critica => severidad == 'critica';

  factory BanderaTriage.fromJson(Map<String, dynamic> json) => BanderaTriage(
    codigo: (json['codigo'] ?? '').toString(),
    severidad: (json['severidad'] ?? 'media').toString(),
    texto: (json['texto'] ?? '').toString(),
  );
}

class TriagePreconsulta {
  const TriagePreconsulta({
    this.nivel,
    this.nivelEtiqueta,
    this.nivelClave,
    this.color,
    this.confianza,
    this.motivos = const [],
    this.recomendaciones = const [],
    this.banderas = const [],
    this.resumen = '',
    this.version = '',
    this.requiereRevision = true,
    this.revisadoPorUsuarioId,
    this.revisadoEn,
    this.nivelRevisado,
    this.notaRevision = '',
  });

  final int? nivel;
  final String? nivelEtiqueta;
  final String? nivelClave;
  final Color? color;
  final double? confianza;
  final List<MotivoTriage> motivos;
  final List<String> recomendaciones;
  final List<BanderaTriage> banderas;
  final String resumen;
  final String version;
  final bool requiereRevision;
  final int? revisadoPorUsuarioId;
  final DateTime? revisadoEn;
  final int? nivelRevisado;
  final String notaRevision;

  bool get revisado => revisadoEn != null;
  bool get tieneResultado => nivel != null;

  /// Nivel efectivo: el revisado por el personal manda sobre el sugerido.
  int? get nivelEfectivo => nivelRevisado ?? nivel;

  bool get tieneBanderasCriticas => banderas.any((b) => b.critica);

  factory TriagePreconsulta.fromJson(Map<String, dynamic> json) =>
      TriagePreconsulta(
        nivel: _int(json['nivel']),
        nivelEtiqueta: json['nivel_etiqueta']?.toString(),
        nivelClave: json['nivel_clave']?.toString(),
        color: json['color'] == null
            ? null
            : colorDesdeHex(json['color']?.toString()),
        confianza: _num(json['confianza']),
        motivos: _lista(json['motivos'])
            .whereType<Map<String, dynamic>>()
            .map(MotivoTriage.fromJson)
            .toList(),
        recomendaciones: _lista(json['recomendaciones'])
            .map((e) => e.toString())
            .toList(),
        banderas: _lista(json['banderas'])
            .whereType<Map<String, dynamic>>()
            .map(BanderaTriage.fromJson)
            .toList(),
        resumen: (json['resumen'] ?? '').toString(),
        version: (json['version'] ?? '').toString(),
        requiereRevision: json['requiere_revision'] != false,
        revisadoPorUsuarioId: _int(json['revisado_por_usuario_id']),
        revisadoEn: _fecha(json['revisado_en']),
        nivelRevisado: _int(json['nivel_revisado']),
        notaRevision: (json['nota_revision'] ?? '').toString(),
      );
}

// ============================================================================
// Signos y captura
// ============================================================================
class SignosVitales {
  const SignosVitales({
    this.hrBpm,
    this.hrConfianza,
    this.rmssdMs,
    this.sdnnMs,
    this.pnn50,
    this.hrvConfianza,
    this.respiracionesRpm,
    this.senalSnrDb,
    this.senalConfianza,
  });

  final double? hrBpm;
  final double? hrConfianza;
  final double? rmssdMs;
  final double? sdnnMs;
  final double? pnn50;
  final double? hrvConfianza;
  final double? respiracionesRpm;
  final double? senalSnrDb;
  final double? senalConfianza;

  bool get tienePulso => hrBpm != null && (hrConfianza ?? 0) >= 0.45;

  factory SignosVitales.fromJson(Map<String, dynamic> json) => SignosVitales(
    hrBpm: _num(json['hr_bpm']),
    hrConfianza: _num(json['hr_confianza']),
    rmssdMs: _num(json['rmssd_ms']),
    sdnnMs: _num(json['sdnn_ms']),
    pnn50: _num(json['pnn50']),
    hrvConfianza: _num(json['hrv_confianza']),
    respiracionesRpm: _num(json['respiraciones_rpm']),
    senalSnrDb: _num(json['senal_snr_db']),
    senalConfianza: _num(json['senal_confianza']),
  );
}

class MetricasRostro {
  const MetricasRostro({
    this.painScore,
    this.painConfianza,
    this.stressScore,
    this.fatigueScore,
    this.blinkRate,
    this.expresionDominante,
    this.microexpresiones = const [],
    this.poseEstabilidad,
  });

  final double? painScore;
  final double? painConfianza;
  final double? stressScore;
  final double? fatigueScore;
  final double? blinkRate;
  final String? expresionDominante;
  final List<Map<String, dynamic>> microexpresiones;
  final double? poseEstabilidad;

  String get expresionEtiqueta {
    switch (expresionDominante) {
      case 'sonrisa':
        return 'Sonrisa';
      case 'sorpresa':
        return 'Sorpresa';
      case 'tristeza':
        return 'Tristeza';
      case 'enfado':
        return 'Tensión';
      case 'dolor':
        return 'Dolor';
      case 'neutral':
        return 'Neutral';
      default:
        return 'Sin dato';
    }
  }

  factory MetricasRostro.fromJson(Map<String, dynamic> json) => MetricasRostro(
    painScore: _num(json['pain_score']),
    painConfianza: _num(json['pain_confianza']),
    stressScore: _num(json['stress_score']),
    fatigueScore: _num(json['fatigue_score']),
    blinkRate: _num(json['blink_rate']),
    expresionDominante: json['expresion_dominante']?.toString(),
    microexpresiones: _lista(json['microexpresiones'])
        .whereType<Map<String, dynamic>>()
        .toList(),
    poseEstabilidad: _num(json['pose_estabilidad']),
  );
}

class CapturaPreconsulta {
  const CapturaPreconsulta({
    this.duracionSeg,
    this.frames,
    this.calidad,
    this.rostroDetectado = false,
    this.detalle = const {},
  });

  final double? duracionSeg;
  final int? frames;
  final double? calidad;
  final bool rostroDetectado;
  final Map<String, dynamic> detalle;

  List<String> get advertencias =>
      _lista(detalle['advertencias']).map((e) => e.toString()).toList();

  factory CapturaPreconsulta.fromJson(Map<String, dynamic> json) =>
      CapturaPreconsulta(
        duracionSeg: _num(json['duracion_seg']),
        frames: _int(json['frames']),
        calidad: _num(json['calidad']),
        rostroDetectado: json['rostro_detectado'] == true,
        detalle: _mapa(json['detalle']),
      );
}

class IdentidadPreconsulta {
  const IdentidadPreconsulta({
    required this.similitud,
    required this.coincide,
    required this.disponible,
  });

  final double? similitud;
  final bool coincide;
  final bool disponible;

  factory IdentidadPreconsulta.fromJson(Map<String, dynamic> json) =>
      IdentidadPreconsulta(
        similitud: _num(json['similitud']),
        coincide: json['coincide'] == true,
        disponible: json['disponible'] != false,
      );
}

// ============================================================================
// Respuestas del cuestionario
// ============================================================================
class RespuestaPreconsulta {
  const RespuestaPreconsulta({
    required this.codigo,
    required this.pregunta,
    required this.seccion,
    required this.tipo,
    required this.valor,
    required this.etiqueta,
  });

  final String codigo;
  final String pregunta;
  final String seccion;
  final String tipo;
  final dynamic valor;
  final String etiqueta;

  factory RespuestaPreconsulta.fromJson(Map<String, dynamic> json) =>
      RespuestaPreconsulta(
        codigo: (json['codigo'] ?? '').toString(),
        pregunta: (json['pregunta'] ?? '').toString(),
        seccion: (json['seccion'] ?? 'otras').toString(),
        tipo: (json['tipo'] ?? 'texto').toString(),
        valor: json['valor'],
        etiqueta: (json['etiqueta'] ?? '').toString(),
      );
}

class RevisionPreconsulta {
  const RevisionPreconsulta({
    required this.id,
    this.nivelAnterior,
    required this.nivelNuevo,
    this.nota = '',
    this.usuarioId,
    this.creadoEn,
  });

  final int id;
  final int? nivelAnterior;
  final int nivelNuevo;
  final String nota;
  final int? usuarioId;
  final DateTime? creadoEn;

  factory RevisionPreconsulta.fromJson(Map<String, dynamic> json) =>
      RevisionPreconsulta(
        id: _int(json['id']) ?? 0,
        nivelAnterior: _int(json['nivel_anterior']),
        nivelNuevo: _int(json['nivel_nuevo']) ?? 5,
        nota: (json['nota'] ?? '').toString(),
        usuarioId: _int(json['usuario_id']),
        creadoEn: _fecha(json['creado_en']),
      );
}

// ============================================================================
// Resumen (cola) y detalle
// ============================================================================
class PacienteResumen {
  const PacienteResumen({
    required this.id,
    required this.nombre,
    this.cedula = '',
    this.edad,
  });

  final int id;
  final String nombre;
  final String cedula;
  final int? edad;

  factory PacienteResumen.fromJson(Map<String, dynamic> json) =>
      PacienteResumen(
        id: _int(json['id']) ?? 0,
        nombre: (json['nombre'] ?? '').toString(),
        cedula: (json['cedula'] ?? '').toString(),
        edad: _int(json['edad']),
      );
}

class PreconsultaResumen {
  const PreconsultaResumen({
    required this.id,
    this.paciente,
    this.estado = 'pendiente',
    this.canal = 'web',
    this.motivo = '',
    this.creadoEn,
    this.analizadoEn,
    this.calidadCaptura,
    this.rostroDetectado = false,
    this.requiereRevision = true,
    this.revisadoEn,
    required this.triage,
    this.medico,
    this.cita,
  });

  final int id;
  final PacienteResumen? paciente;
  final String estado;
  final String canal;
  final String motivo;
  final DateTime? creadoEn;
  final DateTime? analizadoEn;
  final double? calidadCaptura;
  final bool rostroDetectado;
  final bool requiereRevision;
  final DateTime? revisadoEn;
  final TriagePreconsulta triage;
  final Map<String, dynamic>? medico;
  final Map<String, dynamic>? cita;

  factory PreconsultaResumen.fromJson(Map<String, dynamic> json) {
    final paciente = json['paciente'];
    return PreconsultaResumen(
      id: _int(json['id']) ?? 0,
      paciente: paciente is Map<String, dynamic>
          ? PacienteResumen.fromJson(paciente)
          : null,
      estado: (json['estado'] ?? 'pendiente').toString(),
      canal: (json['canal'] ?? 'web').toString(),
      motivo: (json['motivo'] ?? '').toString(),
      creadoEn: _fecha(json['creado_en']),
      analizadoEn: _fecha(json['analizado_en']),
      calidadCaptura: _num(json['calidad_captura']),
      rostroDetectado: json['rostro_detectado'] == true,
      requiereRevision: json['requiere_revision'] != false,
      revisadoEn: _fecha(json['revisado_en']),
      triage: TriagePreconsulta.fromJson(_mapa(json['triage'])),
      medico: json['medico'] is Map<String, dynamic>
          ? json['medico'] as Map<String, dynamic>
          : null,
      cita: json['cita'] is Map<String, dynamic>
          ? json['cita'] as Map<String, dynamic>
          : null,
    );
  }
}

class PreconsultaDetalle {
  const PreconsultaDetalle({
    required this.id,
    required this.estado,
    required this.canal,
    this.motivo = '',
    this.creadoEn,
    this.actualizadoEn,
    this.analizadoEn,
    this.paciente,
    this.medico,
    this.cita,
    required this.captura,
    required this.vitales,
    required this.rostro,
    this.identidad,
    required this.triage,
    this.respuestas = const [],
    this.revisiones = const [],
    this.modeloVersion = '',
    this.noEsDiagnostico = true,
    this.requiereRevisionHumana = true,
  });

  final int id;
  final String estado;
  final String canal;
  final String motivo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;
  final DateTime? analizadoEn;
  final Map<String, dynamic>? paciente;
  final Map<String, dynamic>? medico;
  final Map<String, dynamic>? cita;
  final CapturaPreconsulta captura;
  final SignosVitales vitales;
  final MetricasRostro rostro;
  final IdentidadPreconsulta? identidad;
  final TriagePreconsulta triage;
  final List<RespuestaPreconsulta> respuestas;
  final List<RevisionPreconsulta> revisiones;
  final String modeloVersion;
  final bool noEsDiagnostico;
  final bool requiereRevisionHumana;

  String get pacienteNombre =>
      (paciente?['nombre'] ?? 'Paciente sin nombre').toString();
  String get pacienteCedula => (paciente?['cedula'] ?? '').toString();
  int? get pacienteEdad => _int(paciente?['edad']);

  factory PreconsultaDetalle.fromJson(Map<String, dynamic> json) {
    final identidad = json['identidad'];
    return PreconsultaDetalle(
      id: _int(json['id']) ?? 0,
      estado: (json['estado'] ?? 'pendiente').toString(),
      canal: (json['canal'] ?? 'web').toString(),
      motivo: (json['motivo'] ?? '').toString(),
      creadoEn: _fecha(json['creado_en']),
      actualizadoEn: _fecha(json['actualizado_en']),
      analizadoEn: _fecha(json['analizado_en']),
      paciente: json['paciente'] is Map<String, dynamic>
          ? json['paciente'] as Map<String, dynamic>
          : null,
      medico: json['medico'] is Map<String, dynamic>
          ? json['medico'] as Map<String, dynamic>
          : null,
      cita: json['cita'] is Map<String, dynamic>
          ? json['cita'] as Map<String, dynamic>
          : null,
      captura: CapturaPreconsulta.fromJson(_mapa(json['captura'])),
      vitales: SignosVitales.fromJson(_mapa(json['vitales'])),
      rostro: MetricasRostro.fromJson(_mapa(json['rostro'])),
      identidad: identidad is Map<String, dynamic>
          ? IdentidadPreconsulta.fromJson(identidad)
          : null,
      triage: TriagePreconsulta.fromJson(_mapa(json['triage'])),
      respuestas: _lista(json['respuestas'])
          .whereType<Map<String, dynamic>>()
          .map(RespuestaPreconsulta.fromJson)
          .toList(),
      revisiones: _lista(json['revisiones'])
          .whereType<Map<String, dynamic>>()
          .map(RevisionPreconsulta.fromJson)
          .toList(),
      modeloVersion: (json['modelo_version'] ?? '').toString(),
      noEsDiagnostico: json['no_es_diagnostico'] != false,
      requiereRevisionHumana: json['requiere_revision_humana'] != false,
    );
  }
}

// ============================================================================
// Cola de atención
// ============================================================================
class EstadisticasCola {
  const EstadisticasCola({
    this.total = 0,
    this.pendientes = 0,
    this.completadas = 0,
    this.sinRevisar = 0,
    this.criticas = 0,
    this.porNivel = const {},
  });

  final int total;
  final int pendientes;
  final int completadas;
  final int sinRevisar;
  final int criticas;
  final Map<int, int> porNivel;

  factory EstadisticasCola.fromJson(Map<String, dynamic> json) {
    final porNivelRaw = _mapa(json['por_nivel']);
    final porNivel = <int, int>{};
    porNivelRaw.forEach((clave, valor) {
      final nivel = int.tryParse(clave);
      final total = _int(valor);
      if (nivel != null && total != null) porNivel[nivel] = total;
    });
    return EstadisticasCola(
      total: _int(json['total']) ?? 0,
      pendientes: _int(json['pendientes']) ?? 0,
      completadas: _int(json['completadas']) ?? 0,
      sinRevisar: _int(json['sin_revisar']) ?? 0,
      criticas: _int(json['criticas']) ?? 0,
      porNivel: porNivel,
    );
  }
}

class ColaPreconsultas {
  const ColaPreconsultas({
    required this.fecha,
    required this.preconsultas,
    required this.stats,
  });

  final String fecha;
  final List<PreconsultaResumen> preconsultas;
  final EstadisticasCola stats;

  factory ColaPreconsultas.fromJson(Map<String, dynamic> json) =>
      ColaPreconsultas(
        fecha: (json['fecha'] ?? '').toString(),
        preconsultas: _lista(json['preconsultas'])
            .whereType<Map<String, dynamic>>()
            .map(PreconsultaResumen.fromJson)
            .toList(),
        stats: EstadisticasCola.fromJson(_mapa(json['stats'])),
      );
}

// ============================================================================
// Métricas agregadas
// ============================================================================
class PuntoDistribucion {
  const PuntoDistribucion({
    required this.nivel,
    required this.etiqueta,
    required this.color,
    required this.total,
    required this.porcentaje,
  });

  final int nivel;
  final String etiqueta;
  final Color color;
  final int total;
  final double porcentaje;

  factory PuntoDistribucion.fromJson(Map<String, dynamic> json) =>
      PuntoDistribucion(
        nivel: _int(json['nivel']) ?? 0,
        etiqueta: (json['etiqueta'] ?? '').toString(),
        color: colorDesdeHex(json['color']?.toString()),
        total: _int(json['total']) ?? 0,
        porcentaje: _num(json['porcentaje']) ?? 0,
      );
}

class MotivoFrecuente {
  const MotivoFrecuente({
    required this.codigo,
    required this.etiqueta,
    required this.total,
  });

  final String codigo;
  final String etiqueta;
  final int total;

  factory MotivoFrecuente.fromJson(Map<String, dynamic> json) =>
      MotivoFrecuente(
        codigo: (json['codigo'] ?? '').toString(),
        etiqueta: (json['etiqueta'] ?? json['texto'] ?? json['codigo'] ?? '')
            .toString(),
        total: _int(json['total']) ?? 0,
      );
}

class PuntoSerieDiaria {
  const PuntoSerieDiaria({
    required this.fecha,
    required this.total,
    required this.completadas,
    required this.criticas,
    required this.revisadas,
    this.promedioNivel,
  });

  final String fecha;
  final int total;
  final int completadas;
  final int criticas;
  final int revisadas;
  final double? promedioNivel;

  factory PuntoSerieDiaria.fromJson(Map<String, dynamic> json) =>
      PuntoSerieDiaria(
        fecha: (json['fecha'] ?? '').toString(),
        total: _int(json['total']) ?? 0,
        completadas: _int(json['completadas']) ?? 0,
        criticas: _int(json['criticas']) ?? 0,
        revisadas: _int(json['revisadas']) ?? 0,
        promedioNivel: _num(json['promedio_nivel']),
      );
}

class MetricasPreconsulta {
  const MetricasPreconsulta({
    this.desde = '',
    this.hasta = '',
    this.dias = 0,
    this.total = 0,
    this.completadas = 0,
    this.pendientes = 0,
    this.revisadas = 0,
    this.tasaRevision = 0,
    this.sinRevision = 0,
    this.criticas = 0,
    this.conBanderas = 0,
    this.promedioNivel,
    this.promedioCalidad,
    this.promedioConfianza,
    this.tiempoPromedioAnalisisSeg,
    this.distribucion = const [],
    this.porCanal = const {},
    this.topMotivos = const [],
    this.topBanderas = const [],
    this.serieDiaria = const [],
  });

  final String desde;
  final String hasta;
  final int dias;
  final int total;
  final int completadas;
  final int pendientes;
  final int revisadas;
  final double tasaRevision;
  final int sinRevision;
  final int criticas;
  final int conBanderas;
  final double? promedioNivel;
  final double? promedioCalidad;
  final double? promedioConfianza;
  final double? tiempoPromedioAnalisisSeg;
  final List<PuntoDistribucion> distribucion;
  final Map<String, int> porCanal;
  final List<MotivoFrecuente> topMotivos;
  final List<MotivoFrecuente> topBanderas;
  final List<PuntoSerieDiaria> serieDiaria;

  factory MetricasPreconsulta.fromJson(Map<String, dynamic> json) {
    final rango = _mapa(json['rango']);
    final canalRaw = _mapa(json['por_canal']);
    final porCanal = <String, int>{};
    canalRaw.forEach((clave, valor) {
      final total = _int(valor);
      if (total != null) porCanal[clave] = total;
    });
    return MetricasPreconsulta(
      desde: (rango['desde'] ?? '').toString(),
      hasta: (rango['hasta'] ?? '').toString(),
      dias: _int(rango['dias']) ?? 0,
      total: _int(json['total']) ?? 0,
      completadas: _int(json['completadas']) ?? 0,
      pendientes: _int(json['pendientes']) ?? 0,
      revisadas: _int(json['revisadas']) ?? 0,
      tasaRevision: _num(json['tasa_revision']) ?? 0,
      sinRevision: _int(json['sin_revision']) ?? 0,
      criticas: _int(json['criticas']) ?? 0,
      conBanderas: _int(json['con_banderas']) ?? 0,
      promedioNivel: _num(json['promedio_nivel']),
      promedioCalidad: _num(json['promedio_calidad']),
      promedioConfianza: _num(json['promedio_confianza']),
      tiempoPromedioAnalisisSeg: _num(json['tiempo_promedio_analisis_seg']),
      distribucion: _lista(json['distribucion'])
          .whereType<Map<String, dynamic>>()
          .map(PuntoDistribucion.fromJson)
          .toList(),
      porCanal: porCanal,
      topMotivos: _lista(json['top_motivos'])
          .whereType<Map<String, dynamic>>()
          .map(MotivoFrecuente.fromJson)
          .toList(),
      topBanderas: _lista(json['top_banderas'])
          .whereType<Map<String, dynamic>>()
          .map(MotivoFrecuente.fromJson)
          .toList(),
      serieDiaria: _lista(json['serie_diaria'])
          .whereType<Map<String, dynamic>>()
          .map(PuntoSerieDiaria.fromJson)
          .toList(),
    );
  }
}

// ============================================================================
// Tendencias del paciente
// ============================================================================
class PuntoTendencia {
  const PuntoTendencia({
    required this.id,
    required this.fecha,
    this.hrBpm,
    this.hrConfianza,
    this.rmssdMs,
    this.painScore,
    this.stressScore,
    this.fatigueScore,
    this.triageNivel,
    this.resumen = '',
    this.calidadCaptura,
    this.rostroDetectado = false,
  });

  final int id;
  final DateTime? fecha;
  final double? hrBpm;
  final double? hrConfianza;
  final double? rmssdMs;
  final double? painScore;
  final double? stressScore;
  final double? fatigueScore;
  final int? triageNivel;
  final String resumen;
  final double? calidadCaptura;
  final bool rostroDetectado;

  factory PuntoTendencia.fromJson(Map<String, dynamic> json) => PuntoTendencia(
    id: _int(json['id']) ?? 0,
    fecha: _fecha(json['fecha']),
    hrBpm: _num(json['hr_bpm']),
    hrConfianza: _num(json['hr_confianza']),
    rmssdMs: _num(json['rmssd_ms']),
    painScore: _num(json['pain_score']),
    stressScore: _num(json['stress_score']),
    fatigueScore: _num(json['fatigue_score']),
    triageNivel: _int(json['triage_nivel']),
    resumen: (json['resumen'] ?? '').toString(),
    calidadCaptura: _num(json['calidad_captura']),
    rostroDetectado: json['rostro_detectado'] == true,
  );
}

class TendenciasPaciente {
  const TendenciasPaciente({
    required this.pacienteId,
    required this.puntos,
    this.total = 0,
    this.promedioHr,
    this.promedioRmssd,
    this.promedioDolor,
    this.promedioEstres,
    this.promedioNivel,
  });

  final int pacienteId;
  final List<PuntoTendencia> puntos;
  final int total;
  final double? promedioHr;
  final double? promedioRmssd;
  final double? promedioDolor;
  final double? promedioEstres;
  final double? promedioNivel;

  factory TendenciasPaciente.fromJson(Map<String, dynamic> json) {
    final resumen = _mapa(json['resumen']);
    return TendenciasPaciente(
      pacienteId: _int(json['paciente_id']) ?? 0,
      puntos: _lista(json['puntos'])
          .whereType<Map<String, dynamic>>()
          .map(PuntoTendencia.fromJson)
          .toList(),
      total: _int(resumen['total']) ?? 0,
      promedioHr: _num(resumen['promedio_hr']),
      promedioRmssd: _num(resumen['promedio_rmssd']),
      promedioDolor: _num(resumen['promedio_dolor']),
      promedioEstres: _num(resumen['promedio_estres']),
      promedioNivel: _num(resumen['promedio_nivel']),
    );
  }
}

/// Evento de auditoría de una preconsulta (solo personal).
class EventoPreconsulta {
  const EventoPreconsulta({
    required this.id,
    required this.tipo,
    this.detalle = const {},
    this.usuarioId,
    this.creadoEn,
  });

  final int id;
  final String tipo;
  final Map<String, dynamic> detalle;
  final int? usuarioId;
  final DateTime? creadoEn;

  factory EventoPreconsulta.fromJson(Map<String, dynamic> json) =>
      EventoPreconsulta(
        id: _int(json['id']) ?? 0,
        tipo: (json['tipo'] ?? '').toString(),
        detalle: _mapa(json['detalle']),
        usuarioId: _int(json['usuario_id']),
        creadoEn: _fecha(json['creado_en']),
      );
}
