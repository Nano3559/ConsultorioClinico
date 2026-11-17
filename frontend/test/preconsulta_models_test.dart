import 'package:consultorio_clinico/data/models/preconsulta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato defensivo de la PreConsulta IA.
///
/// El backend devuelve NUMERIC como texto y JSONB con estructuras variables;
/// estos tests fijan que un detalle completo se lea bien y que una respuesta
/// incompleta nunca rompa la pantalla.
void main() {
  group('PreconsultaDetalle.fromJson', () {
    test('interpreta el detalle completo con números como texto', () {
      final detalle = PreconsultaDetalle.fromJson({
        'id': '12',
        'estado': 'completada',
        'canal': 'web',
        'motivo': 'Dolor de cabeza',
        'creado_en': '2026-11-16T10:00:00Z',
        'analizado_en': '2026-11-16T10:00:25Z',
        'paciente': {
          'id': '7',
          'nombre': 'Ana López',
          'cedula': '0102030405',
          'edad': '34',
        },
        'captura': {
          'duracion_seg': '22.4',
          'frames': '280',
          'calidad': '86.5',
          'rostro_detectado': true,
          'detalle': {
            'advertencias': ['senal_cardíaca_debil'],
            'metodo_rppg': 'pos',
          },
        },
        'vitales': {
          'hr_bpm': '78.4',
          'hr_confianza': '0.810',
          'rmssd_ms': '42.0',
          'sdnn_ms': '51.2',
          'pnn50': '12.5',
          'hrv_confianza': '0.640',
          'respiraciones_rpm': '15.5',
          'senal_snr_db': '6.20',
          'senal_confianza': '0.770',
        },
        'rostro': {
          'pain_score': '3.5',
          'pain_confianza': '0.700',
          'stress_score': '41.0',
          'fatigue_score': '28.0',
          'blink_rate': '17.0',
          'expresion_dominante': 'tristeza',
          'microexpresiones': [
            {'tipo': 'tension', 'intensidad': 0.4},
          ],
          'pose_estabilidad': '0.910',
        },
        'identidad': {
          'similitud': '0.8700',
          'coincide': true,
          'disponible': true,
        },
        'triage': {
          'nivel': 2,
          'nivel_etiqueta': 'Urgente',
          'nivel_clave': 'urgente',
          'color': '#EA580C',
          'confianza': '0.880',
          'motivos': [
            {
              'codigo': 'dolor_severo',
              'etiqueta': 'Dolor severo',
              'peso': '24.5',
              'detalle': 'Refiere 8/10',
              'fuente': 'cuestionario',
            },
          ],
          'recomendaciones': ['Valoración prioritaria'],
          'banderas': [
            {
              'codigo': 'dolor_toracico',
              'severidad': 'critica',
              'texto': 'Dolor torácico con disnea',
            },
          ],
          'resumen': 'Nivel 2 — Urgente',
          'version': 'preconsulta-triage-1.0.0',
          'requiere_revision': true,
          'nivel_revisado': 3,
          'nota_revision': 'Se ajusta tras valoración',
        },
        'respuestas': [
          {
            'codigo': 'dolor_intensidad',
            'pregunta': 'Intensidad del dolor',
            'seccion': 'sintomas',
            'tipo': 'escala',
            'valor': 8,
            'etiqueta': '8/10',
          },
        ],
        'revisiones': [
          {
            'id': '3',
            'nivel_anterior': '2',
            'nivel_nuevo': '3',
            'nota': 'Se ajusta',
            'usuario_id': '9',
            'creado_en': '2026-11-16T10:05:00Z',
          },
        ],
        'modelo_version': 'preconsulta-vision-1.0.0',
        'no_es_diagnostico': true,
        'requiere_revision_humana': true,
      });

      expect(detalle.id, 12);
      expect(detalle.pacienteNombre, 'Ana López');
      expect(detalle.pacienteEdad, 34);
      expect(detalle.captura.calidad, 86.5);
      expect(detalle.captura.frames, 280);
      expect(detalle.captura.advertencias, ['senal_cardíaca_debil']);
      expect(detalle.vitales.hrBpm, 78.4);
      expect(detalle.vitales.tienePulso, isTrue);
      expect(detalle.rostro.expresionEtiqueta, 'Tristeza');
      expect(detalle.rostro.microexpresiones, hasLength(1));
      expect(detalle.identidad?.coincide, isTrue);
      expect(detalle.identidad?.similitud, 0.87);
      expect(detalle.triage.nivel, 2);
      expect(detalle.triage.nivelEfectivo, 3, reason: 'La revisión manda');
      expect(detalle.triage.tieneBanderasCriticas, isTrue);
      expect(detalle.triage.motivos.single.peso, 24.5);
      expect(detalle.triage.motivos.single.fuenteEtiqueta, 'Cuestionario');
      expect(detalle.respuestas.single.valor, 8);
      expect(detalle.revisiones.single.nivelNuevo, 3);
      expect(detalle.modeloVersion, 'preconsulta-vision-1.0.0');
      expect(detalle.noEsDiagnostico, isTrue);
    });

    test('un detalle vacío no lanza y usa valores seguros', () {
      final detalle = PreconsultaDetalle.fromJson(const {});

      expect(detalle.id, 0);
      expect(detalle.estado, 'pendiente');
      expect(detalle.canal, 'web');
      expect(detalle.captura.rostroDetectado, isFalse);
      expect(detalle.captura.detalle, isEmpty);
      expect(detalle.vitales.hrBpm, isNull);
      expect(detalle.vitales.tienePulso, isFalse);
      expect(detalle.rostro.painScore, isNull);
      expect(detalle.rostro.expresionEtiqueta, 'Sin dato');
      expect(detalle.identidad, isNull);
      expect(detalle.triage.tieneResultado, isFalse);
      expect(detalle.triage.nivelEfectivo, isNull);
      expect(detalle.triage.requiereRevision, isTrue);
      expect(detalle.respuestas, isEmpty);
      expect(detalle.revisiones, isEmpty);
      expect(detalle.noEsDiagnostico, isTrue);
      expect(detalle.requiereRevisionHumana, isTrue);
    });
  });

  group('PreconsultaCatalogo.fromJson', () {
    test('ordena las preguntas por sección y conserva opciones', () {
      final catalogo = PreconsultaCatalogo.fromJson({
        'habilitado': true,
        'consentimiento': {
          'version': '2026-11',
          'titulo': 'Consentimiento',
          'no_es_diagnostico': true,
          'requiere_revision_humana': true,
          'datos': ['pulso estimado'],
          'derechos': ['retirar el consentimiento'],
        },
        'secciones': [
          {'clave': 'sintomas', 'titulo': 'Síntomas', 'descripcion': '...'},
        ],
        'preguntas': [
          {
            'codigo': 'dolor_intensidad',
            'seccion': 'sintomas',
            'pregunta': 'Intensidad del dolor',
            'tipo': 'escala',
            'orden': 20,
            'requerida': true,
            'min': 0,
            'max': 10,
          },
          {
            'codigo': 'dolor_inicio',
            'seccion': 'sintomas',
            'pregunta': '¿Cuándo comenzó?',
            'tipo': 'opcion',
            'orden': 10,
            'opciones': [
              {'valor': 'hoy', 'etiqueta': 'Hoy'},
              {'valor': 'semana', 'etiqueta': 'Esta semana'},
            ],
          },
        ],
        'niveles': [
          {
            'nivel': 1,
            'clave': 'inmediato',
            'etiqueta': 'Atención inmediata',
            'color': '#DC2626',
            'max_minutos': 0,
          },
        ],
        'ya_aceptado': true,
        'aceptado_en': '2026-11-15T08:00:00Z',
        'paciente_id': '7',
        'version': '2026-11',
      });

      expect(catalogo.habilitado, isTrue);
      expect(catalogo.version, '2026-11');
      expect(catalogo.yaAceptado, isTrue);
      expect(catalogo.pacienteId, 7);
      expect(catalogo.consentimiento.noEsDiagnostico, isTrue);
      expect(catalogo.preguntasDe('sintomas').map((p) => p.codigo).toList(), [
        'dolor_inicio',
        'dolor_intensidad',
      ]);
      expect(catalogo.preguntasDe('sintomas').first.opciones, hasLength(2));
      expect(catalogo.niveles.single.tiempo, 'Ahora');
    });

    test('sin catálogo sigue siendo usable con valores por defecto', () {
      final catalogo = PreconsultaCatalogo.fromJson(const {});

      expect(catalogo.habilitado, isTrue);
      expect(catalogo.preguntas, isEmpty);
      expect(catalogo.secciones, isEmpty);
      expect(catalogo.niveles, isEmpty);
      expect(catalogo.yaAceptado, isFalse);
      expect(catalogo.pacienteId, isNull);
    });
  });

  test('ColaPreconsultas interpreta estadísticas y tarjetas', () {
    final cola = ColaPreconsultas.fromJson({
      'fecha': '2026-11-16',
      'stats': {
        'total': '4',
        'pendientes': '1',
        'completadas': '3',
        'sin_revisar': '2',
        'criticas': '1',
        'por_nivel': {'1': '1', '2': '0', '3': '3'},
      },
      'preconsultas': [
        {
          'id': '12',
          'estado': 'completada',
          'canal': 'recepcion',
          'motivo': 'Dolor abdominal',
          'calidad_captura': '90.0',
          'rostro_detectado': true,
          'requiere_revision': true,
          'paciente': {'id': '7', 'nombre': 'Ana López', 'edad': '34'},
          'triage': {'nivel': 2, 'nivel_etiqueta': 'Urgente'},
        },
      ],
    });

    expect(cola.fecha, '2026-11-16');
    expect(cola.stats.total, 4);
    expect(cola.stats.porNivel[3], 3);
    expect(cola.stats.criticas, 1);
    expect(cola.preconsultas.single.paciente?.nombre, 'Ana López');
    expect(cola.preconsultas.single.triage.nivel, 2);
    expect(cola.preconsultas.single.calidadCaptura, 90.0);
  });

  test('MetricasPreconsulta lee rango, canales y series', () {
    final metricas = MetricasPreconsulta.fromJson({
      'rango': {'desde': '2026-10-18', 'hasta': '2026-11-16', 'dias': '30'},
      'total': '18',
      'completadas': '15',
      'pendientes': '3',
      'revisadas': '9',
      'tasa_revision': '60.0',
      'sin_revision': '6',
      'criticas': '2',
      'con_banderas': '5',
      'promedio_nivel': '3.20',
      'promedio_calidad': '84.5',
      'promedio_confianza': '0.810',
      'tiempo_promedio_analisis_seg': '6.2',
      'distribucion': [
        {
          'nivel': 3,
          'etiqueta': 'Prioritario',
          'color': '#D97706',
          'total': '7',
          'porcentaje': '38.9',
        },
      ],
      'por_canal': {'web': '10', 'recepcion': '5', 'android': '3'},
      'top_motivos': [
        {'codigo': 'dolor_severo', 'etiqueta': 'Dolor severo', 'total': '4'},
      ],
      'top_banderas': [
        {'codigo': 'disnea', 'texto': 'Dificultad respiratoria', 'total': '2'},
      ],
      'serie_diaria': [
        {
          'fecha': '2026-11-16',
          'total': '3',
          'completadas': '2',
          'criticas': '1',
          'revisadas': '1',
          'promedio_nivel': '2.7',
        },
      ],
    });

    expect(metricas.dias, 30);
    expect(metricas.desde, '2026-10-18');
    expect(metricas.total, 18);
    expect(metricas.tasaRevision, 60.0);
    expect(metricas.porCanal['recepcion'], 5);
    expect(metricas.distribucion.single.porcentaje, 38.9);
    expect(metricas.topBanderas.single.etiqueta, 'Dificultad respiratoria');
    expect(metricas.serieDiaria.single.promedioNivel, 2.7);
  });

  test('TendenciasPaciente y eventos toleran datos parciales', () {
    final tendencias = TendenciasPaciente.fromJson({
      'paciente_id': '7',
      'resumen': {'total': '2', 'promedio_hr': '76.5'},
      'puntos': [
        {
          'id': '31',
          'fecha': '2026-11-16T10:00:00Z',
          'hr_bpm': '76.5',
          'triage_nivel': '3',
          'resumen': 'Nivel 3 — Prioritario',
        },
      ],
    });
    final evento = EventoPreconsulta.fromJson({
      'id': '4',
      'tipo': 'revisada',
      'detalle': {'nivel': 3},
      'usuario_id': '9',
    });

    expect(tendencias.pacienteId, 7);
    expect(tendencias.total, 2);
    expect(tendencias.promedioHr, 76.5);
    expect(tendencias.puntos.single.triageNivel, 3);
    expect(evento.tipo, 'revisada');
    expect(evento.detalle['nivel'], 3);
    expect(evento.usuarioId, 9);
  });

  test('colorDesdeHex acepta #RRGGBB y cae al color por defecto', () {
    expect(colorDesdeHex('#DC2626'), const Color(0xFFDC2626));
    expect(colorDesdeHex('16A34A'), const Color(0xFF16A34A));
    expect(colorDesdeHex(null), const Color(0xFF0D9488));
    expect(colorDesdeHex('nope'), const Color(0xFF0D9488));
  });
}
