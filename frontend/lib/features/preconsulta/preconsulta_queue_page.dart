import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_stat_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/preconsulta.dart';
import '../../state/preconsulta_provider.dart';
import 'widgets/preconsulta_ui.dart';

/// Cola diaria de preconsultas para recepción, médicos y administración.
class PreconsultaQueuePage extends StatefulWidget {
  const PreconsultaQueuePage({super.key});

  @override
  State<PreconsultaQueuePage> createState() => _PreconsultaQueuePageState();
}

class _PreconsultaQueuePageState extends State<PreconsultaQueuePage> {
  DateTime _fecha = DateTime.now();
  int? _nivel;
  String? _estado;
  String _busqueda = '';
  bool _cargado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final prov = context.read<PreconsultaProvider>();
    await prov.cargarCola(
      fecha: DateFormat('yyyy-MM-dd').format(_fecha),
      nivel: _nivel,
      estado: _estado,
    );
    if (mounted) setState(() => _cargado = true);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PreconsultaProvider>();
    final cola = prov.cola;
    final stats = cola?.stats;
    final lista = (cola?.preconsultas ?? const <PreconsultaResumen>[])
        .where(_coincideBusqueda)
        .toList();
    final ancho = MediaQuery.sizeOf(context).width;
    final compacto = ancho < 720;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PageHeader(
            title: 'PreConsulta IA',
            subtitle: 'Triage asistido con cámara y cuestionario. La IA prioriza; el personal confirma.',
            icon: Icons.auto_awesome_outlined,
            count: stats?.total,
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/preconsulta'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(compacto ? 'Nueva' : 'Nueva preconsulta'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (stats != null)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Stat(
                  width: compacto ? (ancho - 52) / 2 : 220,
                  child: AppStatCard(
                    label: 'Hoy',
                    value: '${stats.total}',
                    icon: Icons.today_outlined,
                    color: AppColors.primary,
                  ),
                ),
                _Stat(
                  width: compacto ? (ancho - 52) / 2 : 220,
                  child: AppStatCard(
                    label: 'Pendientes',
                    value: '${stats.pendientes}',
                    icon: Icons.hourglass_empty,
                    color: AppColors.warning,
                  ),
                ),
                _Stat(
                  width: compacto ? (ancho - 52) / 2 : 220,
                  child: AppStatCard(
                    label: 'Sin revisar',
                    value: '${stats.sinRevisar}',
                    icon: Icons.rate_review_outlined,
                    color: AppColors.info,
                  ),
                ),
                _Stat(
                  width: compacto ? (ancho - 52) / 2 : 220,
                  child: AppStatCard(
                    label: 'Críticas (nivel 1-2)',
                    value: '${stats.criticas}',
                    icon: Icons.priority_high,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          PreconsultaCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        DateFormat("EEEE d 'de' MMMM", 'es').format(_fecha),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      backgroundColor: AppColors.primaryBg,
                      side: BorderSide.none,
                      onPressed: _elegirFecha,
                    ),
                    _ChipFiltro(
                      texto: 'Todas',
                      activo: _nivel == null,
                      onTap: () => _filtrarNivel(null),
                    ),
                    for (var n = 1; n <= 5; n++)
                      _ChipFiltro(
                        texto: 'N$n',
                        color: nivelColor(n),
                        activo: _nivel == n,
                        onTap: () => _filtrarNivel(n),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Buscar por paciente, cédula o motivo',
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                        onChanged: (v) => setState(() => _busqueda = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        initialValue: _estado ?? 'todos',
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'todos',
                            child: Text('Todos'),
                          ),
                          DropdownMenuItem(
                            value: 'pendiente',
                            child: Text('Pendientes'),
                          ),
                          DropdownMenuItem(
                            value: 'completada',
                            child: Text('Completadas'),
                          ),
                          DropdownMenuItem(
                            value: 'revisada',
                            child: Text('Revisadas'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelada',
                            child: Text('Canceladas'),
                          ),
                        ],
                        onChanged: (v) =>
                            _filtrarEstado(v == 'todos' ? null : v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_cargado && prov.cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (prov.error != null && cola == null)
            PreconsultaCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 40,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    prov.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _cargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else if (lista.isEmpty)
            PreconsultaCard(
              child: AppEmptyState(
                icon: Icons.event_available_outlined,
                title: _filtrosActivos
                    ? 'Sin preconsultas con estos filtros'
                    : 'No hay preconsultas para este día',
                subtitle: _filtrosActivos
                    ? 'Prueba con otro nivel, estado o fecha.'
                    : 'Las preconsultas aparecen aquí en cuanto se crean.',
                action: FilledButton.icon(
                  onPressed: () => context.push('/preconsulta'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Crear preconsulta'),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Text(
                  '${lista.length} preconsulta${lista.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Prioriza nivel 1 → 5',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final p in lista)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ColaTile(
                  preconsulta: p,
                  onTap: () => context.push('/preconsulta/${p.id}'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool get _filtrosActivos =>
      _nivel != null || _estado != null || _busqueda.trim().isNotEmpty;

  bool _coincideBusqueda(PreconsultaResumen p) {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return true;
    final nombre = (p.paciente?.nombre ?? '').toLowerCase();
    final cedula = (p.paciente?.cedula ?? '').toLowerCase();
    final motivo = p.motivo.toLowerCase();
    final resumen = p.triage.resumen.toLowerCase();
    return nombre.contains(q) ||
        cedula.contains(q) ||
        motivo.contains(q) ||
        resumen.contains(q);
  }

  Future<void> _elegirFecha() async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      helpText: 'Fecha de la cola',
    );
    if (seleccion == null || !mounted) return;
    setState(() => _fecha = seleccion);
    await _cargar();
  }

  Future<void> _filtrarNivel(int? nivel) async {
    setState(() => _nivel = nivel);
    await _cargar();
  }

  Future<void> _filtrarEstado(String? estado) async {
    setState(() => _estado = estado);
    await _cargar();
  }
}

class _ColaTile extends StatelessWidget {
  const _ColaTile({required this.preconsulta, required this.onTap});

  final PreconsultaResumen preconsulta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = preconsulta;
    final nivel = p.triage.nivelEfectivo;
    final color = nivelColor(nivel);
    final nombre = p.paciente?.nombre ?? 'Paciente';
    final iniciales = _iniciales(nombre);
    final hora = horaCorta(p.creadoEn);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 23,
                          backgroundColor: color.withValues(alpha: 0.14),
                          child: Text(
                            iniciales,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.dark,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (p.paciente?.edad != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '${p.paciente!.edad} años',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  EstadoChip(estado: p.estado, compact: true),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                p.motivo.isNotEmpty
                                    ? p.motivo
                                    : (p.triage.resumen.isNotEmpty
                                          ? p.triage.resumen
                                          : 'Sin motivo registrado'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  TriageBadge(nivel: nivel, compact: true),
                                  if (p.calidadCaptura != null)
                                    _DatoMini(
                                      icono: Icons.center_focus_strong_outlined,
                                      texto:
                                          'Calidad ${p.calidadCaptura!.round()}',
                                    ),
                                  if (!p.rostroDetectado)
                                    const _DatoMini(
                                      icono: Icons.no_photography_outlined,
                                      texto: 'Sin rostro',
                                    ),
                                  if (p.requiereRevision && !p.triage.revisado)
                                    const _DatoMini(
                                      icono: Icons.rate_review_outlined,
                                      texto: 'Revisar',
                                      color: AppColors.info,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              hora,
                              style: const TextStyle(
                                color: AppColors.dark,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Icon(
                              Icons.chevron_right,
                              color: color.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes[1][0]}'.toUpperCase();
  }
}

class _DatoMini extends StatelessWidget {
  const _DatoMini({
    required this.icono,
    required this.texto,
    this.color = AppColors.muted,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.texto,
    required this.activo,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String texto;
  final bool activo;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? color : AppColors.border,
            width: activo ? 1.4 : 1,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: activo ? color : AppColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}
