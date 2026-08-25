import 'package:flutter/material.dart';
import '../../../../data/models/user.dart';
import '../dashboard_page.dart';
import '../consults/consults_page.dart';
import '../appointments/agenda_page.dart';
import '../appointments/appointments_page.dart';
import '../patients/patients_page.dart';
import '../doctors/doctors_page.dart';
import '../payments/payments_page.dart';
import '../reports/reports_page.dart';
import '../settings_page.dart';
import '../doctor_panel_page.dart';
import '../patient_my_appointments_page.dart';

/// Módulo de navegación del sistema interno. Cada módulo pertenece a un grupo
/// para organizarlo en el sidebar web y el drawer móvil.
class NavModule {
  const NavModule(this.key, this.label, this.icon, this.group, this.builder,
      {this.route});

  final String key;
  final String label;
  final IconData icon;
  final String group;
  final WidgetBuilder builder;

  /// Si se define, el módulo navega a una ruta del router en vez de un tab.
  final String? route;
}

/// Grupos de módulos (orden de aparición).
const String kGroupPrincipal = 'Principal';
const String kGroupClinico = 'Clínico';
const String kGroupPersonas = 'Personas';
const String kGroupFinanzas = 'Finanzas';
const String kGroupAnalisis = 'Análisis';
const String kGroupSistema = 'Sistema';

/// Módulos disponibles por rol. Cada rol ve solo lo que le corresponde.
List<NavModule> navModulesFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const [
        NavModule('dashboard', 'Dashboard', Icons.dashboard_outlined, kGroupPrincipal, _dashboard),
        NavModule('consulta', 'Consulta', Icons.medical_information_outlined, kGroupClinico, _consulta),
        NavModule('agenda', 'Agenda', Icons.calendar_view_day_outlined, kGroupClinico, _agenda),
        NavModule('citas', 'Citas', Icons.event_note_outlined, kGroupClinico, _citas),
        NavModule('pacientes', 'Pacientes', Icons.group_outlined, kGroupPersonas, _pacientes),
        NavModule('medicos', 'Médicos', Icons.medical_services_outlined, kGroupPersonas, _medicos),
        NavModule('pagos', 'Pagos', Icons.payments_outlined, kGroupFinanzas, _pagos),
        NavModule('reportes', 'Reportes', Icons.bar_chart_outlined, kGroupAnalisis, _reportes),
        NavModule('configuracion', 'Configuración', Icons.settings_outlined, kGroupSistema, _settings),
      ];
    case UserRole.recepcion:
      return const [
        NavModule('agenda', 'Agenda', Icons.calendar_view_day_outlined, kGroupClinico, _agenda),
        NavModule('citas', 'Citas', Icons.event_note_outlined, kGroupClinico, _citas),
        NavModule('pacientes', 'Pacientes', Icons.group_outlined, kGroupPersonas, _pacientes),
        NavModule('pagos', 'Pagos', Icons.payments_outlined, kGroupFinanzas, _pagos),
      ];
    case UserRole.medico:
      return const [
        NavModule('panel', 'Mi panel', Icons.medical_services_outlined, kGroupPrincipal, _panel),
        NavModule('consulta', 'Consulta', Icons.medical_information_outlined, kGroupClinico, _consulta),
        NavModule('miagenda', 'Mi agenda', Icons.calendar_view_day_outlined, kGroupClinico, _agenda),
        NavModule('pacientes', 'Pacientes', Icons.group_outlined, kGroupPersonas, _pacientes),
      ];
    case UserRole.paciente:
      return const [
        NavModule('miscitas', 'Mis citas', Icons.event_outlined, kGroupPrincipal, _myAppointments),
        NavModule('solicitar', 'Solicitar cita', Icons.add_circle_outline, kGroupPrincipal, _myAppointments, route: '/solicitar-cita'),
      ];
  }
}

/// Módulos que forman parte del IndexedStack (los que no navegan por ruta).
List<NavModule> stackModulesFor(UserRole role) =>
    navModulesFor(role).where((m) => m.route == null).toList();

Widget _dashboard(BuildContext _) => const DashboardPage();
Widget _consulta(BuildContext _) => const ConsultsPage();
Widget _agenda(BuildContext _) => const AgendaPage();
Widget _citas(BuildContext _) => const AppointmentsPage();
Widget _pacientes(BuildContext _) => const PatientsPage();
Widget _medicos(BuildContext _) => const DoctorsPage();
Widget _pagos(BuildContext _) => const PaymentsPage();
Widget _reportes(BuildContext _) => const ReportsPage();
Widget _settings(BuildContext _) => const SettingsPage();
Widget _panel(BuildContext _) => const DoctorPanelPage();
Widget _myAppointments(BuildContext _) => const PatientMyAppointmentsPage();
