import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../data/models/user.dart';
import '../../../state/auth_provider.dart';
import '../../../state/clinic_provider.dart';
import 'patient_form_page.dart';
import '../clinical/consult_form_page.dart';

/// Detalle de paciente con historial de citas e historia clínica.
class PatientDetailPage extends StatelessWidget {
  const PatientDetailPage({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final clinic = context.watch<ClinicProvider>();
    final patient = clinic.patientById(patientId);
    final isMedico = auth.currentUser?.role == UserRole.medico;
    final puedeRegistrar = isMedico || auth.currentUser?.role == UserRole.admin;
    final authorized = !isMedico || clinic.patients.any((p) => p.id == patientId);
    if (!authorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso restringido')),
        body: const AppEmptyState(
          icon: Icons.lock_outline,
          title: 'Paciente no asignado',
          subtitle: 'Solo puedes ver pacientes con citas o consultas a tu nombre.',
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(patient.fullName),
          actions: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PatientFormPage(patient: patient)),
              ),
            ),
            if (puedeRegistrar)
              IconButton(
                tooltip: 'Nueva consulta',
                icon: const Icon(Icons.add_box_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ConsultFormPage(patientId: patientId)),
                ),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Datos'),
              Tab(text: 'Citas'),
              Tab(text: 'Historia clínica'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PatientData(patientId: patientId),
            _PatientAppointments(patientId: patientId),
            _ClinicalHistory(patientId: patientId),
          ],
        ),
      ),
    );
  }
}

class _PatientData extends StatelessWidget {
  const _PatientData({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final p = clinic.patientById(patientId);
    final age = DateTime.now().year - p.birthDate.year;
    final isMobile = MediaQuery.of(context).size.width < 700;
    final items = [
      (Icons.badge_outlined, 'CI', p.ci),
      (Icons.cake_outlined, 'Nacimiento', '${AppFormatters.shortDate(p.birthDate)} ($age años)'),
      (Icons.phone_outlined, 'Teléfono', p.phone),
      (Icons.mail_outline, 'Correo', p.email),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              AppAvatar(name: p.fullName, radius: 30, backgroundColor: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text(p.email, style: const TextStyle(color: Color(0xFFE2E8F0))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isMobile ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3.4,
          children: [for (final (icon, label, value) in items) _DataCard(icon: icon, label: label, value: value)],
        ),
      ],
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientAppointments extends StatelessWidget {
  const _PatientAppointments({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final list = clinic.appointmentsOfPatient(patientId);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (list.isEmpty)
          const AppEmptyState(icon: Icons.event_note_outlined, title: 'Sin citas registradas')
        else
          for (final a in list)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.event, color: AppColors.primary),
                title: Text('${AppFormatters.shortDate(a.date)} · ${a.time}'),
                subtitle: Text('${clinic.doctorName(a.doctorId)} — ${a.reason}'),
                trailing: AppStatusBadge(status: a.status),
              ),
            ),
      ],
    );
  }
}

class _ClinicalHistory extends StatelessWidget {
  const _ClinicalHistory({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    final p = clinic.patientById(patientId);
    final consults = clinic.historyOf(patientId);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _InfoBlock(title: 'Antecedentes', text: p.antecedentes.isEmpty ? 'Sin antecedentes registrados' : p.antecedentes),
        const SizedBox(height: 10),
        _InfoBlock(title: 'Alergias', text: p.alergias.isEmpty ? 'Sin alergias registradas' : p.alergias),
        const SizedBox(height: 10),
        _InfoBlock(title: 'Observaciones', text: p.observaciones.isEmpty ? 'Sin observaciones' : p.observaciones),
        const SizedBox(height: 20),
        const Text('Consultas anteriores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.dark)),
        const SizedBox(height: 12),
        if (consults.isEmpty)
          const AppEmptyState(
            icon: Icons.folder_open_outlined,
            title: 'Sin consultas registradas',
            subtitle: 'Registra una consulta desde el panel del médico.',
          )
        else
          for (final c in consults)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: BorderSide(color: AppColors.primary, width: 4),
                  top: BorderSide(color: AppColors.border),
                  right: BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${AppFormatters.shortDate(c.date)} · ${clinic.doctorName(c.doctorId)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _line('Motivo', c.motivo),
                    _line('Diagnóstico', c.diagnostico),
                    _line('Tratamiento', c.tratamiento),
                    if (c.observaciones.isNotEmpty) _line('Observaciones', c.observaciones),
                    if (c.proximoControl != null)
                      _line('Próximo control', AppFormatters.shortDate(c.proximoControl!)),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600))),
            Expanded(child: Text(value, style: const TextStyle(color: AppColors.dark, height: 1.4))),
          ],
        ),
      );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: AppColors.muted, height: 1.5)),
        ],
      ),
    );
  }
}
