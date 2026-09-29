import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'face_engine.dart';
import 'rest_client.dart';

enum _Etapa { cargando, listo, verificando, exito, sinCita, noReconocido, error }

/// Pantalla del kiosco (PC del consultorio, Windows, offline-first).
///
/// 1. Al iniciar descarga las citas de HOY + las fotos de esos pacientes.
/// 2. El paciente pulsa "Verificarme" y mira a la cámara.
/// 3. OpenCV local reconoce el rostro y, si tiene cita pendiente hoy,
///    la marca como confirmada (check-in) en Firestore.
class KioskPage extends StatefulWidget {
  const KioskPage({super.key});

  @override
  State<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  final _rest = KioskRest();
  final _motor = FaceEngine();

  _Etapa _etapa = _Etapa.cargando;
  String _mensaje = 'Iniciando kiosco…';
  int _enrolados = 0;
  int _citasHoy = 0;
  Uint8List? _foto;
  String _nombreOk = '';
  String _detalleOk = '';
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _arrancar() async {
    await _sincronizar(mostrarCargando: true);
  }

  Future<void> _sincronizar({bool mostrarCargando = false}) async {
    if (mostrarCargando) {
      setState(() {
        _etapa = _Etapa.cargando;
        _mensaje = 'Iniciando kiosco…';
      });
    }
    try {
      setState(() => _mensaje = 'Cargando reconocimiento facial…');
      await _motor.init();
      setState(() => _mensaje = 'Conectando con el consultorio…');
      await _rest.signIn();
      setState(() => _mensaje = 'Descargando citas de hoy…');
      final citas = await _rest.citasHoy();
      final fotos = <String, String>{};
      for (final c in citas) {
        final p = await _rest.paciente(c.pacienteId);
        if (p != null && p.faceBase64.isNotEmpty) {
          fotos[p.id] = p.faceBase64;
        }
      }
      setState(() => _mensaje = 'Registrando rostros…');
      // El enrolado puede tardar: ceder un frame a la UI primero.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final n = _motor.enrolar(fotos);
      if (!mounted) return;
      setState(() {
        _enrolados = n;
        _citasHoy = citas.length;
        _etapa = _Etapa.listo;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _etapa = _Etapa.error;
        _mensaje = 'No se pudo iniciar: $e';
      });
    }
  }

  void _autoReset({int segundos = 8}) {
    _resetTimer?.cancel();
    _resetTimer = Timer(Duration(seconds: segundos), () {
      if (!mounted) return;
      setState(() {
        _etapa = _Etapa.listo;
        _foto = null;
      });
    });
  }

  Future<void> _verificar() async {
    setState(() {
      _etapa = _Etapa.verificando;
      _mensaje = 'Mira a la cámara…';
      _foto = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final bytes = _motor.capturar();
    if (!mounted) return;
    if (bytes == null) {
      setState(() {
        _etapa = _Etapa.error;
        _mensaje = 'No se detectó cámara en este equipo.';
      });
      return;
    }
    setState(() => _foto = bytes);
    final match = _motor.reconocer(bytes);
    if (match == null) {
      setState(() => _etapa = _Etapa.noReconocido);
      _autoReset(segundos: 10);
      return;
    }
    final pacienteId = match.$1;
    try {
      final citas = await _rest.citasHoy();
      final deHoy = citas.where((c) => c.pacienteId == pacienteId).toList();
      if (!mounted) return;
      if (deHoy.isEmpty) {
        setState(() => _etapa = _Etapa.sinCita);
        _autoReset();
        return;
      }
      final cita = deHoy.firstWhere(
        (c) => c.porConfirmar,
        orElse: () => deHoy.first,
      );
      final p = await _rest.paciente(pacienteId);
      final medico = await _rest.medicoNombre(cita.medicoId);
      if (!mounted) return;
      if (cita.porConfirmar) {
        await _rest.confirmarCita(cita.id);
        if (!mounted) return;
      }
      setState(() {
        _nombreOk = p?.nombre ?? 'Paciente';
        _detalleOk = cita.porConfirmar
            ? 'Check-in confirmado · ${cita.hora}${medico.isNotEmpty ? ' · $medico' : ''}'
            : 'Tu cita de las ${cita.hora} ya estaba confirmada. Pasa por favor.';
        _etapa = _Etapa.exito;
      });
      _autoReset();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _etapa = _Etapa.error;
        _mensaje = 'Error al confirmar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _contenido(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    switch (_etapa) {
      case _Etapa.cargando:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_hospital, size: 72, color: Color(0xFF0D9488)),
            const SizedBox(height: 16),
            const Text('Kiosco ConsultorioClínico',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFF0D9488)),
            const SizedBox(height: 16),
            Text(_mensaje, style: const TextStyle(color: Colors.black54)),
          ],
        );
      case _Etapa.listo:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.face_outlined, size: 88, color: Color(0xFF0D9488)),
            const SizedBox(height: 16),
            const Text('Auto check-in',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Hoy hay $_citasHoy cita(s) · $_enrolados rostro(s) registrado(s)',
              style: const TextStyle(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                onPressed: _verificar,
                icon: const Icon(Icons.photo_camera_outlined, size: 28),
                label: const Text('Verificarme con mi rostro'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _sincronizar(),
              icon: const Icon(Icons.sync_outlined),
              label: const Text('Sincronizar agenda'),
            ),
          ],
        );
      case _Etapa.verificando:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_foto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(_foto!, height: 280, fit: BoxFit.cover),
              )
            else
              const SizedBox(
                height: 120,
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D9488))),
              ),
            const SizedBox(height: 16),
            Text(_mensaje, style: const TextStyle(fontSize: 18)),
          ],
        );
      case _Etapa.exito:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 88, color: Color(0xFF16A34A)),
            const SizedBox(height: 16),
            Text('¡Hola, $_nombreOk!',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_detalleOk,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, color: Colors.black54)),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => setState(() {
                _etapa = _Etapa.listo;
                _foto = null;
              }),
              child: const Text('Siguiente paciente'),
            ),
          ],
        );
      case _Etapa.sinCita:
        return _infoPantalla(
          Icons.event_busy_outlined,
          const Color(0xFFD97706),
          'No tienes cita pendiente hoy',
          'Si crees que es un error, pasa a recepción.',
        );
      case _Etapa.noReconocido:
        return _infoPantalla(
          Icons.face_retouching_off_outlined,
          const Color(0xFFDC2626),
          'No te reconocí',
          'Intenta de nuevo con buena luz y de frente, o pasa a recepción.',
        );
      case _Etapa.error:
        return _infoPantalla(
          Icons.error_outline,
          const Color(0xFFDC2626),
          'Algo salió mal',
          _mensaje,
        );
    }
  }

  Widget _infoPantalla(IconData icon, Color color, String titulo, String detalle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 88, color: color),
        const SizedBox(height: 16),
        Text(titulo,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(detalle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              onPressed: _verificar,
              child: const Text('Reintentar'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => setState(() {
                _etapa = _Etapa.listo;
                _foto = null;
              }),
              child: const Text('Volver'),
            ),
          ],
        ),
      ],
    );
  }
}
