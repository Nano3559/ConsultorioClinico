import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_row.dart';
import '../../../data/models/payment.dart';
import '../../../state/clinic_provider.dart';
import 'payment_dialog.dart';

/// Módulo de pagos (Ejercicio 11).
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  PaymentStatus? _filter;
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
    final list = clinic.payments.where((p) {
      if (_filter != null && p.status != _filter) return false;
      if (q.isNotEmpty) {
        final hay = '${clinic.patientName(p.patientId)} ${clinic.doctorName(p.doctorId)} ${p.method.label}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = clinic.payments
        .where((p) => p.status == PaymentStatus.pagado)
        .fold<double>(0, (s, p) => s + p.amount);
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      children: [
        PageHeader(
          title: 'Pagos',
          subtitle: 'Registro de cobros del consultorio.',
          icon: Icons.payments_outlined,
          count: clinic.payments.length,
          actions: [
            FilledButton.icon(
              onPressed: () => showRegisterPaymentDialog(context, clinic),
              icon: const Icon(Icons.add),
              label: const Text('Registrar pago'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.success),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Ingresos cobrados (pagados)', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w700)),
              ),
              Text(
                AppFormatters.money(total),
                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Buscar paciente, médico o método',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        ResponsiveRow(
          children: [
            DropdownButtonFormField<PaymentStatus?>(
              initialValue: _filter,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final s in PaymentStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _filter = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: AppEmptyState(icon: Icons.receipt_long_outlined, title: 'Sin pagos registrados'),
          )
        else if (isWide)
          AppTable(
            headers: const ['Fecha', 'Paciente', 'Médico', 'Método', 'Monto', 'Estado'],
            rows: [
              for (final p in list)
                [
                  TableText(AppFormatters.shortDate(p.date)),
                  TableText(clinic.patientName(p.patientId), bold: true),
                  TableText(clinic.doctorName(p.doctorId)),
                  TableText(p.method.label),
                  TableText(AppFormatters.money(p.amount)),
                  _PaymentStatusChip(status: p.status),
                ],
            ],
          )
        else
          for (final p in list)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(p.method.icon, color: AppColors.primary),
                title: Text(
                  '${clinic.patientName(p.patientId)} — ${AppFormatters.money(p.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark),
                ),
                subtitle: Text(
                  '${AppFormatters.shortDate(p.date)} · ${clinic.doctorName(p.doctorId)} · ${p.method.label}',
                ),
                trailing: _PaymentStatusChip(status: p.status),
                onTap: () => _toggleStatus(context, clinic, p),
              ),
            ),
      ],
    );
  }

  void _toggleStatus(BuildContext context, ClinicProvider clinic, Payment p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${clinic.patientName(p.patientId)} — ${p.method.label}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.dark),
                ),
              ),
              for (final s in PaymentStatus.values)
                if (s != p.status)
                  ListTile(
                    leading: Icon(Icons.circle, color: s.color, size: 16),
                    title: Text('Marcar como ${s.label}'),
                    onTap: () {
                      Navigator.pop(ctx);
                      clinic.setPaymentStatus(p.id, s);
                    },
                  ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

}

class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: status.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: status.color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
