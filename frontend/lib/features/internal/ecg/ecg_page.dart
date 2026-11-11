import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/hover_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/models/ecg_analysis.dart';
import '../../../services/api_client.dart';

/// Módulo interno del médico cardiólogo: evaluación de ECG con IA.
///
/// Integra el módulo `CardiologiaEGC` (FastAPI + ECG_ResNet1D): el cardiólogo
/// carga un CSV de 12 derivaciones, el servicio lo analiza y la vista muestra
/// el dictamen, el trazado dinámico en vivo y la orientación médica (causas y
/// recomendaciones). Se muestra como una pestaña dentro de `/app`, solo para un
/// médico cuya especialidad es Cardiología.
class CardioEcgPage extends StatefulWidget {
  const CardioEcgPage({super.key});

  @override
  State<CardioEcgPage> createState() => _CardioEcgPageState();
}

class _CardioEcgPageState extends State<CardioEcgPage>
    with SingleTickerProviderStateMixin {
  /// Muestras visibles en la ventana del trazado (monitor en vivo).
  static const int _maxVentana = 300;

  final EcgApiClient _api = EcgApiClient();

  Timer? _healthTimer;
  bool? _servidorOk;

  String? _nombreArchivo;
  Uint8List? _bytes;
  List<double> _puntos = [];
  double _min = 0;
  double _rango = 1;
  double _umbral = 0;

  EcgAnalysis? _resultado;
  bool _procesando = false;
  String? _error;

  /// Ancla del panel de resultados para desplazarse a él tras analizar.
  final GlobalKey _resultadoKey = GlobalKey();

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  /// Ventana deslizante del trazado (valores crudos de la derivación V1).
  final List<double> _ventana = [];
  int _indice = 0;
  double _latido = 1.0;
  double _giro = 0;

  @override
  void initState() {
    super.initState();
    _anim.addListener(_avanzarTrazado);
    _verificarServidor();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _verificarServidor(),
    );
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _anim.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _verificarServidor() async {
    final ok = await _api.servidorActivo();
    if (!mounted) return;
    setState(() => _servidorOk = ok);
  }

  /// Avanza la ventana del trazado 2 muestras por frame y detecta los picos R
  /// para sincronizar el "latido" del corazón (misma lógica del visor web).
  void _avanzarTrazado() {
    if (_puntos.isEmpty) return;
    for (var i = 0; i < 2; i++) {
      final val = _puntos[_indice];
      if (_ventana.length >= _maxVentana) _ventana.removeAt(0);
      _ventana.add(val);
      if (val > _umbral) _latido = 1.25;
      _indice = (_indice + 1) % _puntos.length;
    }
    _latido += (1.0 - _latido) * 0.12;
    _giro += 0.012;
  }

  /// Lee los bytes del archivo de forma segura (en web file_picker puede no
  /// entregar el contenido del archivo).
  Uint8List? _leerBytes(PlatformFile file) {
    try {
      return file.bytes;
    } on Error {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Convierte un token a número aceptando coma decimal ("0,5").
  double? _numero(String token) {
    var t = token.trim().replaceAll('\u00a0', '').replaceAll(' ', '');
    if (t.isEmpty) return null;
    if (t.contains(',') && !t.contains('.')) {
      t = t.replaceAll(',', '.'); // coma decimal
    } else if (t.contains(',')) {
      t = t.replaceAll(',', ''); // separador de miles
    }
    return double.tryParse(t);
  }

  /// Extrae la derivación V1 del CSV (columna 7 / fila 7) para el trazado.
  ///
  /// Tolera separadores `;`, tabulación y `,`, encabezados, coma decimal y
  /// archivos transpuestos (12 derivaciones en filas), igual que el backend.
  List<double> _parsearPuntos(String texto) {
    final lineas = texto
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lineas.isEmpty) return const [];

    var delim = ',';
    for (final c in [';', '\t', ',']) {
      if (lineas.first.contains(c)) {
        delim = c;
        break;
      }
    }

    final filas = <List<double?>>[];
    for (final ln in lineas) {
      final partes = ln.split(delim);
      if (partes.length < 2) continue;
      final fila = partes.map(_numero).toList();
      // Encabezado o metadatos sin valores numéricos: se ignora.
      if (fila.every((v) => v == null)) continue;
      filas.add(fila);
    }
    if (filas.isEmpty) return const [];

    final ancho = filas.map((f) => f.length).reduce(math.max);
    for (final f in filas) {
      while (f.length < ancho) {
        f.add(null);
      }
    }

    final transpuesto = filas.length <= 15 && ancho > 15;
    final serie = transpuesto
        ? filas[filas.length > 6 ? 6 : 0]
        : [for (final f in filas) f[ancho > 6 ? 6 : 0]];

    return [
      for (final v in serie) ?v,
    ];
  }

  Future<void> _seleccionarCsv() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true,
      );
      if (!mounted) return;
      final archivos = res?.files ?? [];
      if (archivos.isEmpty) return; // El usuario canceló: no es error.
      final archivo = archivos.first;
      final nombre = archivo.name;
      final bytes = _leerBytes(archivo);
      if (!nombre.toLowerCase().endsWith('.csv')) {
        setState(() => _error = 'El archivo seleccionado debe ser .csv');
        return;
      }
      if (bytes == null || bytes.isEmpty) {
        setState(() => _error = 'No se pudo leer el archivo. Intenta de nuevo.');
        return;
      }
      final texto = String.fromCharCodes(bytes);
      final puntos = _parsearPuntos(texto);
      if (puntos.isEmpty) {
        setState(
          () => _error = 'El CSV no contiene lecturas válidas de ECG.',
        );
        return;
      }
      var min = puntos.first;
      var max = puntos.first;
      for (final p in puntos) {
        if (p < min) min = p;
        if (p > max) max = p;
      }
      setState(() {
        _nombreArchivo = nombre;
        _bytes = bytes;
        _puntos = puntos;
        _min = min;
        _rango = max - min == 0 ? 1 : max - min;
        _umbral = min + _rango * 0.75;
        _resultado = null;
        _error = null;
      });
      _iniciarTrazado();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo abrir el explorador de archivos.');
    }
  }

  void _iniciarTrazado() {
    final reducirMovimiento =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reducirMovimiento && !_anim.isAnimating) _anim.repeat();
  }

  Future<void> _analizar() async {
    if (_bytes == null || _procesando) return;
    setState(() {
      _procesando = true;
      _error = null;
    });
    final res = await _api.analizarEcg(
      nombreArchivo: _nombreArchivo!,
      bytes: _bytes!,
    );
    if (!mounted) return;
    if (!res.isSuccess) {
      setState(() {
        _procesando = false;
        _error = res.error ?? 'Error al procesar la señal de ECG.';
      });
      return;
    }
    setState(() {
      _procesando = false;
      _resultado = EcgAnalysis.fromApi(res.data ?? {});
      // Si respondió bien, el servidor está activo (actualiza el badge).
      _servidorOk = true;
    });
    _iniciarTrazado();
    _mostrarResultado();
  }

  /// En pantallas estrechas el panel de resultados queda debajo del formulario;
  /// se desplaza automáticamente para que el dictamen se vea al instante.
  void _mostrarResultado() {
    if (MediaQuery.of(context).size.width >= 1000) return;
    final ctx = _resultadoKey.currentContext;
    if (ctx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  void _limpiar() {
    setState(() {
      _nombreArchivo = null;
      _bytes = null;
      _puntos = [];
      _ventana.clear();
      _indice = 0;
      _latido = 1.0;
      _resultado = null;
      _error = null;
    });
    _anim.stop();
  }

  Color get _colorTema {
    final r = _resultado;
    if (r == null) return AppColors.primary;
    if (r.esNormal) return AppColors.success;
    if (r.esUrgencia) return AppColors.danger;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esMovil = ancho < 1000;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: esMovil ? 24 : 48,
        vertical: 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                label: 'CARDIOLOGÍA',
                title: 'Evaluación de ECG con IA',
                subtitle:
                    'Análisis asistido por la red neuronal ResNet-1D sobre'
                    ' registros de 12 derivaciones.',
              ),
              const SizedBox(height: 16),
              Center(child: _badgeServidor()),
              const SizedBox(height: 32),
              if (esMovil)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _panelCarga(),
                    const SizedBox(height: 24),
                    KeyedSubtree(key: _resultadoKey, child: _panelResultado()),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _panelCarga()),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 7,
                      child: KeyedSubtree(key: _resultadoKey, child: _panelResultado()),
                    ),
                  ],
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Estado del servidor de IA
  // --------------------------------------------------------------------------

  Widget _badgeServidor() {
    final ok = _servidorOk;
    final color = ok == null ? AppColors.muted : ok ? AppColors.success : AppColors.danger;
    final texto = ok == null
        ? 'Verificando servidor…'
        : ok
            ? 'Servidor de IA activo'
            : 'Servidor de IA desconectado';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Panel izquierdo: carga del CSV y especificación del formato
  // --------------------------------------------------------------------------

  Widget _panelCarga() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HoverCard(
          accent: AppColors.danger,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const GradientIconChip(
                    icon: Icons.description_outlined,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cargar registro de ECG',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Archivo CSV de 12 derivaciones · 12 × 2500 lecturas a 500 Hz',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _zonaCarga(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _cajaError(),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _puedeAnalizar ? _analizar : null,
                  icon: const Icon(Icons.memory),
                  label: const Text(
                    'Ejecutar Inferencia IA',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _tarjetaEspecificacion(),
      ],
    );
  }

  /// El botón se habilita en cuanto hay un CSV: no se bloquea esperando el
  /// chequeo de `/health` (el servidor puede tardar en arrancar). Si el servicio
  /// no responde, el error aparece al instante al intentar analizar.
  bool get _puedeAnalizar => _bytes != null && !_procesando;

  Widget _zonaCarga() {
    final seleccionado = _nombreArchivo != null;
    return GestureDetector(
      onTap: _seleccionarCsv,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.successBg : AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: CustomPaint(
          painter: _BordePunteadoPainter(
            color: seleccionado ? AppColors.success : AppColors.muted,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  seleccionado
                      ? Icons.check_circle_outline
                      : Icons.cloud_upload_outlined,
                  size: 34,
                  color: seleccionado ? AppColors.success : AppColors.muted,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    seleccionado ? _nombreArchivo! : 'Selecciona tu archivo CSV',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: seleccionado ? AppColors.dark : AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  seleccionado
                      ? '${_puntos.length} lecturas de la derivación V1'
                      : 'Formato soportado: .csv (12 derivaciones × 2500 puntos)',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cajaError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? '',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.danger,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaEspecificacion() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ESPECIFICACIÓN DEL FORMATO CSV',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _filaSpec('Derivaciones requeridas', '12 (I, II, III, aVR, aVL, aVF, V1–V6)'),
          _filaSpec('Frecuencia / muestras', '500 Hz (2500 puntos / 5 seg)'),
          _filaSpec('Manejo de nulos (NaN)', 'Imputación automática a 0.0'),
          _filaSpec('Acondicionamiento', 'Normalización min–max por canal'),
        ],
      ),
    );
  }

  Widget _filaSpec(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  etiqueta,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  valor,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Panel derecho: estado vacío, carga y resultados
  // --------------------------------------------------------------------------

  Widget _panelResultado() {
    if (_procesando) return _estadoCargando();
    final r = _resultado;
    if (r == null) return _estadoVacio();
    return _resultados(r);
  }

  Widget _estadoVacio() {
    return HoverCard(
      accent: AppColors.info,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.monitor_heart_outlined,
                size: 30,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Esperando registro de ECG',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 380,
              child: Text(
                'Sube un archivo CSV para procesar las 12 derivaciones con la'
                ' red ResNet-1D, ver el trazado en vivo y consultar la'
                ' orientación médica.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoCargando() {
    return HoverCard(
      accent: AppColors.info,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(color: AppColors.info, strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            const Text(
              'Procesando tensor (1, 12, 2500) en PyTorch…',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultados(EcgAnalysis r) {
    final esMovil = MediaQuery.of(context).size.width < 1000;
    final tema = _colorTema;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (esMovil)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tarjetaCorazon(tema),
              const SizedBox(height: 16),
              _tarjetaDiagnostico(r, tema),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: _tarjetaCorazon(tema)),
              const SizedBox(width: 16),
              Expanded(child: _tarjetaDiagnostico(r, tema)),
            ],
          ),
        const SizedBox(height: 16),
        _tarjetaTrazado(),
        const SizedBox(height: 16),
        _tarjetaDesglose(r, tema),
        const SizedBox(height: 16),
        _tarjetasOrientacion(r),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _limpiar,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Analizar otro registro'),
          ),
        ),
      ],
    );
  }

  /// Corazón "3D" que late sincronizado con los picos R del trazado.
  Widget _tarjetaCorazon(Color tema) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.dark.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.view_in_ar_outlined, color: tema, size: 14),
              const SizedBox(width: 6),
              const Text(
                'MODELO ANATÓMICO',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 170,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => CustomPaint(
                size: const Size(220, 170),
                painter: _CorazonPainter(escala: _latido, giro: _giro),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Simulación ventricular sincronizada con el ECG',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaDiagnostico(EcgAnalysis r, Color tema) {
    return HoverCard(
      accent: tema,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.medical_services_outlined, color: tema, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'DIAGNÓSTICO IMPRESO',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tema.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tema.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${r.confianza.toStringAsFixed(2)}% Confianza',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: tema,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            r.diagnosticoPrincipal,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: tema,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite_border, color: tema, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Frecuencia sincronizada',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
                Text(
                  r.bpm.isEmpty ? '—' : r.bpm,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: tema,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaTrazado() {
    final reducirMovimiento =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart, color: AppColors.info, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'TRAZADO DINÁMICO · DERIVACIÓN V1',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.dark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '500 Hz | Vivo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.dark),
              ),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _TrazadoPainter(
                    valores: reducirMovimiento || !_anim.isAnimating
                        ? _puntos
                        : _ventana,
                    min: _min,
                    rango: _rango,
                    maxVentana: _maxVentana,
                    estatica: reducirMovimiento || !_anim.isAnimating,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaDesglose(EcgAnalysis r, Color tema) {
    final entradas = r.desglose.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline, color: AppColors.info, size: 16),
              const SizedBox(width: 6),
              const Text(
                'DESGLOSE PROBABILÍSTICO POR PATOLOGÍA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final e in entradas)
            _barraProbabilidad(
              clave: '${r.diagnosticoPrincipal}|${e.key}',
              etiqueta: e.key,
              prob: e.value,
              principal: e.key == r.diagnosticoPrincipal,
              tema: tema,
            ),
        ],
      ),
    );
  }

  Widget _barraProbabilidad({
    required String clave,
    required String etiqueta,
    required double prob,
    required bool principal,
    required Color tema,
  }) {
    final color = principal ? tema : const Color(0xFF334155);
    return Padding(
      key: ValueKey(clave),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  etiqueta,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: principal ? FontWeight.w800 : FontWeight.w600,
                    color: principal ? tema : AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${prob.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: principal ? tema : AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              color: const Color(0xFF0F172A),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: prob / 100),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: Container(color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetasOrientacion(EcgAnalysis r) {
    final esMovil = MediaQuery.of(context).size.width < 800;
    if (esMovil) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tarjetaLista(
            titulo: 'CAUSAS DEL CUADRO CLÍNICO',
            icono: Icons.account_tree_outlined,
            color: AppColors.warning,
            fondo: AppColors.warningBg,
            items: r.causas,
            vineta: '•',
          ),
          const SizedBox(height: 16),
          _tarjetaLista(
            titulo: 'RECOMENDACIONES MÉDICAS',
            icono: Icons.medical_information_outlined,
            color: AppColors.success,
            fondo: AppColors.successBg,
            items: r.recomendaciones,
            vineta: '✓',
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _tarjetaLista(
            titulo: 'CAUSAS DEL CUADRO CLÍNICO',
            icono: Icons.account_tree_outlined,
            color: AppColors.warning,
            fondo: AppColors.warningBg,
            items: r.causas,
            vineta: '•',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _tarjetaLista(
            titulo: 'RECOMENDACIONES MÉDICAS',
            icono: Icons.medical_information_outlined,
            color: AppColors.success,
            fondo: AppColors.successBg,
            items: r.recomendaciones,
            vineta: '✓',
          ),
        ),
      ],
    );
  }

  Widget _tarjetaLista({
    required String titulo,
    required IconData icono,
    required Color color,
    required Color fondo,
    required List<String> items,
    required String vineta,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  titulo,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'Sin información registrada para este dictamen.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            )
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vineta,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.dark,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Borde punteado (drop zone) dibujado a mano: Flutter no tiene borde dashed.
class _BordePunteadoPainter extends CustomPainter {
  _BordePunteadoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    var distancia = 0.0;
    while (distancia < metric.length) {
      final tramo = metric.extractPath(distancia, distancia + 6);
      canvas.drawPath(tramo, paint);
      distancia += 12;
    }
  }

  @override
  bool shouldRepaint(_BordePunteadoPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Trazado ECG estilo monitor: fondo oscuro, cuadrícula y línea verde con
/// brillo que se desplaza de derecha a izquierda.
class _TrazadoPainter extends CustomPainter {
  _TrazadoPainter({
    required this.valores,
    required this.min,
    required this.rango,
    required this.maxVentana,
    required this.estatica,
  });

  final List<double> valores;
  final double min;
  final double rango;
  final int maxVentana;
  final bool estatica;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF020617));

    final cuadricula = Paint()
      ..color = const Color(0x1F0EA5E9)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cuadricula);
    }
    for (var y = 0.0; y <= size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), cuadricula);
    }

    if (valores.isEmpty) return;

    final path = Path();
    final paso = size.width / maxVentana;
    for (var i = 0; i < valores.length; i++) {
      final x = estatica
          ? (valores.length <= 1
              ? size.width
              : i / (valores.length - 1) * size.width)
          : size.width - (valores.length - i) * paso;
      final y = size.height -
          (((valores[i] - min) / rango) * (size.height - 30) + 15);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final brillo = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, brillo);

    final linea = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linea);
  }

  @override
  bool shouldRepaint(_TrazadoPainter oldDelegate) => true;
}

/// Corazón estilizado que late (escala por pico R) y gira suavemente,
/// versión 2D del modelo anatómico 3D del visor original.
class _CorazonPainter extends CustomPainter {
  _CorazonPainter({required this.escala, required this.giro});

  final double escala;
  final double giro;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(math.sin(giro) * 0.10);
    canvas.scale(escala);
    canvas.translate(-centro.dx, -centro.dy);

    final w = size.width;
    final h = size.height;

    // Cuerpo del corazón (dos lóbulos) con gradiente rojo profundo.
    final cuerpo = Path()
      ..moveTo(w * 0.5, h * 0.34)
      ..cubicTo(w * 0.16, h * 0.02, w * 0.0, h * 0.42, w * 0.5, h * 0.84)
      ..cubicTo(w * 1.0, h * 0.42, w * 0.84, h * 0.02, w * 0.5, h * 0.34);

    // Resplandor exterior al latir.
    final glow = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawPath(cuerpo, glow);

    final relleno = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: const [
          Color(0xFFFCA5A5),
          Color(0xFFEF4444),
          Color(0xFF7F1D1D),
        ],
        radius: 1.1,
      ).createShader(Offset.zero & size);
    canvas.drawPath(cuerpo, relleno);

    // Aorta (tubo azul superior-izquierdo) y vena cava (derecha).
    final vaso = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7DD3FC), Color(0xFF0284C7)],
      ).createShader(Offset.zero & size)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075;
    canvas.drawLine(
      Offset(w * 0.46, h * 0.18),
      Offset(w * 0.40, h * 0.02),
      vaso,
    );
    canvas.drawLine(
      Offset(w * 0.56, h * 0.16),
      Offset(w * 0.62, h * 0.02),
      vaso..strokeWidth = w * 0.055,
    );

    // Brillo especular (sistema de conducción).
    final brillo = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.36, h * 0.30),
        width: w * 0.22,
        height: h * 0.16,
      ),
      brillo,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CorazonPainter oldDelegate) => true;
}
