import 'dart:async';

import '../../../services/api_client.dart';
import 'kiosk_service.dart';

/// Sincronización del kiosco con la nube (plantillas + modelo).
///
/// Cada [intervalo] (defecto: lo que diga el manifest, si no 15 min):
///   1. Descarga `GET /api/kiosco/manifest` (liviano: hashes md5).
///   2. Compara con la caché en memoria; descarga SOLO los paquetes
///      cambiados (`GET /api/kiosco/paquete/:id` con embeddings + fotos).
///   3. Si `modelo_version` difiere de la local, avisa vía [onModeloCambio]
///      para que el sidecar Python purge y descargue el pack nuevo.
///
/// Autenticación con la clave del kiosco (`x-kiosk-key`, compilada con
/// `--dart-define=KIOSK_API_KEY=...`). Sin clave válida el backend exige
/// JWT de personal: la descarga masiva de plantillas jamás es pública.
class KioskSyncService {
  KioskSyncService({
    ApiClient? client,
    String? kioskKey,
    this.intervalo = const Duration(minutes: 15),
  })  : _api = client ?? ApiClient(),
        _kioskKey = kioskKey ?? KioskService.kioskApiKey;

  final ApiClient _api;
  final String _kioskKey;
  final Duration intervalo;

  Timer? _timer;
  bool _sincronizando = false;

  /// Caché en memoria: pacienteId -> { hash, embedding, nombre }.
  final Map<int, Map<String, dynamic>> plantillas = {};

  /// Versión del pack de modelos vigente localmente (la setea el kiosco
  /// tras actualizar; `null` = primera sincronización).
  String? modeloVersionLocal;

  Map<String, String> get _headers =>
      _kioskKey.isNotEmpty ? {'x-kiosk-key': _kioskKey} : const {};

  /// Una pasada de sincronización. Devuelve qué cambió.
  Future<SyncResultado> sincronizar() async {
    if (_sincronizando) {
      return const SyncResultado(sinCambios: true);
    }
    _sincronizando = true;
    try {
      final res = await _api.getJson(
        '/kiosco/manifest',
        extraHeaders: _headers.isEmpty ? null : _headers,
      );
      if (!res.isSuccess) {
        return SyncResultado(error: res.error ?? 'No se pudo sincronizar.');
      }
      final data = (res.data?['data'] as Map<String, dynamic>?) ?? const {};
      final remoto = (data['pacientes'] as List?) ?? const [];
      final modeloRemoto = data['modelo_version']?.toString();

      var actualizados = 0;
      var eliminados = 0;
      final vistos = <int>{};
      for (final p in remoto) {
        if (p is! Map<String, dynamic>) continue;
        final id = (p['paciente_id'] as num?)?.toInt() ?? 0;
        if (id <= 0) continue;
        vistos.add(id);
        final hash = p['template_hash']?.toString();
        if (plantillas[id]?['hash'] == hash) continue; // sin cambios
        final pack = await _api.getJson(
          '/kiosco/paquete/$id',
          extraHeaders: _headers.isEmpty ? null : _headers,
        );
        if (!pack.isSuccess) continue;
        final pd = (pack.data?['data'] as Map<String, dynamic>?) ?? const {};
        plantillas[id] = {
          'hash': hash,
          'embedding': pd['rostro_embedding'],
          'nombre': pd['nombre']?.toString() ?? '',
          'poses': pd['poses'],
        };
        actualizados++;
      }
      // Pacientes que ya no tienen plantilla en la nube salen de la caché.
      final obsoletos =
          plantillas.keys.where((id) => !vistos.contains(id)).toList();
      for (final id in obsoletos) {
        plantillas.remove(id);
        eliminados++;
      }

      final modeloCambio =
          modeloRemoto != null && modeloVersionLocal != modeloRemoto;
      return SyncResultado(
        actualizados: actualizados,
        eliminados: eliminados,
        total: plantillas.length,
        modeloRemoto: modeloRemoto,
        modeloCambio: modeloCambio,
      );
    } finally {
      _sincronizando = false;
    }
  }

  /// Inicia el temporizador periódico. Llama [onSync] con cada resultado
  /// (el kiosco decide qué mostrar; los errores se reportan, no rompen nada).
  void start(void Function(SyncResultado) onSync) {
    stop();
    sincronizar().then(onSync);
    _timer = Timer.periodic(intervalo, (_) async {
      onSync(await sincronizar());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}

/// Resultado de una pasada de sincronización.
class SyncResultado {
  const SyncResultado({
    this.actualizados = 0,
    this.eliminados = 0,
    this.total = 0,
    this.modeloRemoto,
    this.modeloCambio = false,
    this.error,
    this.sinCambios = false,
  });

  final int actualizados;
  final int eliminados;
  final int total;
  final String? modeloRemoto;
  final bool modeloCambio;
  final String? error;
  final bool sinCambios;

  bool get ok => error == null;
}
