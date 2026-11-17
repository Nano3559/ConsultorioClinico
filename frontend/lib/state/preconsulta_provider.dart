import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models/preconsulta.dart';
import '../services/api_client.dart';

/// Estado de la PreConsulta IA.
///
/// Concentra el catálogo (consentimiento + cuestionario), la preconsulta en
/// curso, la cola del personal y las métricas agregadas. La red pasa siempre
/// por [ApiClient] (nunca por `http` directo), como exige la arquitectura.
///
/// El token se obtiene de Firebase Auth en cada operación para no caducar a
/// mitad de un flujo largo de captura (20-30 s + análisis).
class PreconsultaProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  PreconsultaCatalogo? _catalogo;
  PreconsultaDetalle? _detalle;
  ColaPreconsultas? _cola;
  MetricasPreconsulta? _metricas;
  TendenciasPaciente? _tendencias;
  List<EventoPreconsulta> _eventos = const [];

  bool _cargando = false;
  bool _analizando = false;
  bool _guardando = false;
  String? _error;
  String? _aviso;

  PreconsultaCatalogo? get catalogo => _catalogo;
  PreconsultaDetalle? get detalle => _detalle;
  ColaPreconsultas? get cola => _cola;
  MetricasPreconsulta? get metricas => _metricas;
  TendenciasPaciente? get tendencias => _tendencias;
  List<EventoPreconsulta> get eventos => List.unmodifiable(_eventos);

  bool get cargando => _cargando;
  bool get analizando => _analizando;
  bool get guardando => _guardando;
  String? get error => _error;
  String? get aviso => _aviso;

  void limpiarMensajes() {
    _error = null;
    _aviso = null;
    notifyListeners();
  }

  void limpiarDetalle() {
    _detalle = null;
    _eventos = const [];
    notifyListeners();
  }

  Future<String?> _token() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  /// Catálogo de consentimiento, preguntas y niveles.
  Future<bool> cargarCatalogo({int? pacienteId}) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      final res = await _api.preconsultaCatalogo(
        token: token,
        pacienteId: pacienteId,
      );
      if (!res.isSuccess) {
        _error = res.error;
        return false;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _catalogo = PreconsultaCatalogo.fromJson(data);
        return true;
      }
      _error = 'El servidor no devolvió el catálogo de la preconsulta.';
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Crea la preconsulta tras aceptar el consentimiento.
  Future<int?> crear({
    required int pacienteId,
    required String consentimientoVersion,
    int? citaId,
    int? medicoId,
    String canal = 'web',
    String? motivo,
  }) async {
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) {
        _error = 'La sesión expiró. Vuelve a iniciar sesión.';
        return null;
      }
      final res = await _api.preconsultaCrear(
        pacienteId: pacienteId,
        consentimientoVersion: consentimientoVersion,
        token: token,
        citaId: citaId,
        medicoId: medicoId,
        canal: canal,
        motivo: motivo,
      );
      if (!res.isSuccess) {
        _error = res.error;
        return null;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _detalle = PreconsultaDetalle.fromJson(data);
        return _detalle?.id;
      }
      _error = 'No se pudo crear la preconsulta.';
      return null;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  /// Envía la captura al servicio de visión y guarda el resultado.
  Future<bool> analizar({
    required int id,
    List<String>? frames,
    String? video,
    double? fps,
    double? duracionSeg,
    String? mime,
    required String canal,
  }) async {
    _analizando = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) {
        _error = 'La sesión expiró. Vuelve a iniciar sesión.';
        return false;
      }
      final res = await _api.preconsultaAnalizar(
        id: id,
        token: token,
        frames: frames,
        video: video,
        fps: fps,
        duracionSeg: duracionSeg,
        mime: mime,
      );
      if (!res.isSuccess) {
        _error = res.error;
        return false;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _detalle = PreconsultaDetalle.fromJson(data);
        if (_detalle?.captura.rostroDetectado == false) {
          _aviso = 'No se detectó un rostro estable. El triage usará solo el cuestionario.';
        }
        return true;
      }
      _error = 'El análisis no devolvió resultados.';
      return false;
    } finally {
      _analizando = false;
      notifyListeners();
    }
  }

  /// Guarda las respuestas y recalcula el triage (con captura existente).
  Future<bool> guardarRespuestas({
    required int id,
    required List<Map<String, dynamic>> respuestas,
  }) async {
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) {
        _error = 'La sesión expiró. Vuelve a iniciar sesión.';
        return false;
      }
      final res = await _api.preconsultaRespuestas(
        id: id,
        token: token,
        respuestas: respuestas,
      );
      if (!res.isSuccess) {
        _error = res.error;
        return false;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _detalle = PreconsultaDetalle.fromJson(data);
        return true;
      }
      return true;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  /// Finaliza sin cámara: solo cuestionario (degradación honesta).
  Future<bool> finalizarSinCaptura({
    required int id,
    required List<Map<String, dynamic>> respuestas,
  }) async {
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) {
        _error = 'La sesión expiró. Vuelve a iniciar sesión.';
        return false;
      }
      final res = await _api.preconsultaFinalizar(
        id: id,
        token: token,
        respuestas: respuestas,
      );
      if (!res.isSuccess) {
        _error = res.error;
        return false;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _detalle = PreconsultaDetalle.fromJson(data);
      }
      return true;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  Future<bool> cargarDetalle(int id) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) {
        _error = 'La sesión expiró. Vuelve a iniciar sesión.';
        return false;
      }
      final res = await _api.preconsultaDetalle(id: id, token: token);
      if (!res.isSuccess) {
        _error = res.error;
        return false;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _detalle = PreconsultaDetalle.fromJson(data);
        return true;
      }
      _error = 'No se pudo cargar la preconsulta.';
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> cargarCola({
    String? fecha,
    int? nivel,
    String? estado,
    String? medicoId,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) {
        _error = 'La sesión expiró. Vuelve a iniciar sesión.';
        return false;
      }
      final res = await _api.preconsultaCola(
        token: token,
        fecha: fecha,
        nivel: nivel,
        estado: estado,
        medicoId: medicoId,
      );
      if (!res.isSuccess) {
        _error = res.error;
        return false;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _cola = ColaPreconsultas.fromJson(data);
        return true;
      }
      _error = 'No se pudo cargar la cola de preconsultas.';
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> cargarMetricas({int dias = 7}) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) {
        _error = 'La sesión expiró. Vuelve a iniciar sesión.';
        return false;
      }
      final res = await _api.preconsultaMetricas(token: token, dias: dias);
      if (!res.isSuccess) {
        _error = res.error;
        return false;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _metricas = MetricasPreconsulta.fromJson(data);
        return true;
      }
      _error = 'No se pudieron cargar las métricas.';
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> cargarTendencias(int pacienteId, {int limite = 10}) async {
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) {
        _error = 'La sesión expiró. Vuelve a iniciar sesión.';
        return false;
      }
      final res = await _api.preconsultaTendencias(
        pacienteId: pacienteId,
        token: token,
        limite: limite,
      );
      if (!res.isSuccess) {
        _error = res.error;
        return false;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _tendencias = TendenciasPaciente.fromJson(data);
        return true;
      }
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> revisar({
    required int id,
    required int nivelRevisado,
    String nota = '',
  }) async {
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) {
        _error = 'La sesión expiró. Vuelve a iniciar sesión.';
        return false;
      }
      final res = await _api.preconsultaRevisar(
        id: id,
        token: token,
        nivelRevisado: nivelRevisado,
        nota: nota,
      );
      if (!res.isSuccess) {
        _error = res.error;
        return false;
      }
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        _detalle = PreconsultaDetalle.fromJson(data);
        _aviso = 'Triage revisado: nivel $nivelRevisado.';
      }
      await cargarEventos(id);
      return true;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  Future<void> cargarEventos(int id) async {
    try {
      final token = await _token();
      if (token == null) return;
      final res = await _api.preconsultaEventos(id: id, token: token);
      if (!res.isSuccess) return;
      // El backend responde `{ data: { eventos: [...] } }`; se acepta también
      // una lista directa por compatibilidad.
      final data = res.data?['data'];
      final lista = data is List
          ? data
          : (data is Map<String, dynamic> ? data['eventos'] : null);
      if (lista is List) {
        _eventos = lista
            .whereType<Map<String, dynamic>>()
            .map(EventoPreconsulta.fromJson)
            .toList();
        notifyListeners();
      }
    } catch (_) {
      // La auditoría es informativa: no rompe la pantalla.
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
