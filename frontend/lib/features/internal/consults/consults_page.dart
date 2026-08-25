import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_table.dart';
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

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 840;
    final list = clinic.consults.where((c) {
      if (_doctorFilter != null && c.doctorId != _doctorFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
            FilledButton.icon(
              onPressed: () => _registerConsult(context, clinic),
              icon: const Icon(Icons.add),
              label: const Text('Registrar consulta'),
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
          for (final c in list)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.medical_information_outlined, color: AppColors.primary),
                title: Text(clinic.patientName(c.patientId), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
                subtitle: Text(
                  '${AppFormatters.shortDate(c.date)} · ${clinic.doctorName(c.doctorId)}\n${c.motivo}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                onTap: () => _showDetail(context, clinic, c),
              ),
            ),
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
