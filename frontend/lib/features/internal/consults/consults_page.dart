import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_row.dart';
import '../../../data/models/consult_record.dart';
import '../../../state/clinic_provider.dart';
import '../clinical/consult_form_page.dart';

/// Módulo de consultas médicas: historial clínico del consultorio y alta de
/// nuevas consultas (Ejercicio 6).
class ConsultsPage extends StatefulWidget {
  const ConsultsPage({super.key});

  @override
  State<ConsultsPage> createState() => _ConsultsPageState();
}

class _ConsultsPageState extends State<ConsultsPage> {
  String? _doctorFilter;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final q = _search.text.trim().toLowerCase();
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 840;
    final isMobile = width < 700;
    final list = clinic.consults.where((c) {
      if (_doctorFilter != null && c.doctorId != _doctorFilter) return false;
      if (q.isNotEmpty) {
        final hay = '${clinic.patientName(c.patientId)} ${c.motivo} ${c.diagnostico}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      children: [
        PageHeader(
          title: 'Consultas',
          subtitle: 'Historia clínica y registro de atenciones.',
          icon: Icons.medical_information_outlined,
          count: clinic.consults.length,
          actions: [
            FilledButton.icon(
              onPressed: () => _registerConsult(context, clinic),
              icon: const Icon(Icons.add),
              label: const Text('Registrar consulta'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Buscar paciente, motivo o diagnóstico',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        ResponsiveRow(
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _doctorFilter,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Filtrar por médico'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos los médicos')),
                for (final d in clinic.activeDoctors)
                  DropdownMenuItem(value: d.id, child: Text(d.displayName)),
              ],
              onChanged: (v) => setState(() => _doctorFilter = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: AppEmptyState(
              icon: Icons.medical_information_outlined,
              title: 'Sin consultas registradas',
              subtitle: 'Usa "Registrar consulta" para cargar la primera.',
            ),
          )
        else if (isWide)
          AppTable(
            headers: const ['Fecha', 'Paciente', 'Médico', 'Motivo', 'Diagnóstico'],
            rows: [
              for (final c in list)
                [
                  TableText(AppFormatters.shortDate(c.date)),
                  TableText(clinic.patientName(c.patientId), bold: true),
                  TableText(clinic.doctorName(c.doctorId)),
                  TableText(c.motivo),
                  TableText(c.diagnostico),
                ],
            ],
          )
        else
          for (final c in list) _ConsultTile(record: c, onTap: () => _showDetail(context, clinic, c)),
      ],
    );
  }

  void _showDetail(BuildContext context, ClinicProvider clinic, ConsultRecord c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Consulta — ${clinic.patientName(c.patientId)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Fecha', AppFormatters.shortDate(c.date)),
              _DetailRow('Médico', clinic.doctorName(c.doctorId)),
              _DetailRow('Motivo', c.motivo),
              _DetailRow('Diagnóstico', c.diagnostico),
              if (c.observaciones.isNotEmpty) _DetailRow('Observaciones', c.observaciones),
              _DetailRow('Tratamiento', c.tratamiento),
              if (c.proximoControl != null)
                _DetailRow('Próximo control', AppFormatters.shortDate(c.proximoControl!)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _registerConsult(BuildContext context, ClinicProvider clinic) {
    String? patientId;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar consulta'),
        content: StatefulBuilder(
          builder: (ctx, setState) => DropdownButtonFormField<String?>(
            initialValue: patientId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Paciente'),
            items: [
              for (final p in clinic.patients)
                DropdownMenuItem(value: p.id, child: Text(p.fullName)),
            ],
            onChanged: (v) => setState(() => patientId = v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (patientId == null) return;
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ConsultFormPage(patientId: patientId!)),
              );
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

class _ConsultTile extends StatelessWidget {
  const _ConsultTile({required this.record, required this.onTap});

  final ConsultRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clinic = context.read<ClinicProvider>();
    final c = record;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            AppAvatar(name: clinic.patientName(c.patientId), radius: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinic.patientName(c.patientId),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.dark, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppFormatters.shortDate(c.date)} · ${clinic.doctorName(c.doctorId)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.motivo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.dark),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.muted),
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
          Text(value, style: const TextStyle(color: AppColors.dark)),
        ],
      ),
    );
  }
}
