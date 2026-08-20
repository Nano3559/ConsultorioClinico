import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../data/models/user.dart';
import '../../state/auth_provider.dart';
import 'dashboard_page.dart';
import 'patients/patients_page.dart';
import 'doctors/doctors_page.dart';
import 'appointments/agenda_page.dart';
import 'appointments/appointments_page.dart';
import 'payments/payments_page.dart';
import 'reports/reports_page.dart';
import 'settings_page.dart';
import 'doctor_panel_page.dart';
import 'patient_my_appointments_page.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.builder, {this.route});
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  /// Si es una navegación hacia una ruta del router (no un tab interno).
  final String? route;
}

/// Caparazón del sistema interno con navegación según el rol.
class InternalShell extends StatefulWidget {
  const InternalShell({super.key});

  @override
  State<InternalShell> createState() => _InternalShellState();
}

class _InternalShellState extends State<InternalShell> {
  int _index = 0;

  List<_NavItem> _itemsFor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const [
          _NavItem('Dashboard', Icons.dashboard_outlined, _dashboard),
          _NavItem('Agenda', Icons.calendar_view_day_outlined, _agenda),
          _NavItem('Citas', Icons.event_note_outlined, _citas),
          _NavItem('Pacientes', Icons.group_outlined, _pacientes),
          _NavItem('Médicos', Icons.medical_services_outlined, _medicos),
          _NavItem('Pagos', Icons.payments_outlined, _pagos),
          _NavItem('Reportes', Icons.bar_chart_outlined, _reportes),
          _NavItem('Configuración', Icons.settings_outlined, _settings),
        ];
      case UserRole.recepcion:
        return const [
          _NavItem('Agenda', Icons.calendar_view_day_outlined, _agenda),
          _NavItem('Citas', Icons.event_note_outlined, _citas),
          _NavItem('Pacientes', Icons.group_outlined, _pacientes),
          _NavItem('Pagos', Icons.payments_outlined, _pagos),
        ];
      case UserRole.medico:
        return const [
          _NavItem('Mi panel', Icons.medical_services_outlined, _panel),
          _NavItem('Mi agenda', Icons.calendar_view_day_outlined, _agenda),
          _NavItem('Pacientes', Icons.group_outlined, _pacientes),
        ];
      case UserRole.paciente:
        return const [
          _NavItem('Mis citas', Icons.event_outlined, _myAppointments),
          _NavItem('Solicitar cita', Icons.add_circle_outline, _myAppointments, route: '/solicitar-cita'),
        ];
    }
  }

  void _select(int index) {
    final items = _itemsFor(context.read<AuthProvider>().role!);
    final item = items[index];
    if (item.route != null) {
      context.push(item.route!);
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      // Redirección de seguridad si la sesión se pierde.
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const Scaffold(body: SizedBox.shrink());
    }
    final items = _itemsFor(user.role);
    if (_index >= items.length) _index = 0;
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            _NavigationRail(
              items: items,
              selectedIndex: _index,
              onSelect: _select,
            ),
          Expanded(
            child: Column(
              children: [
                _TopBar(user: user),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [for (final it in items) it.builder(context)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final it in items)
                  NavigationDestination(
                    icon: Icon(it.icon),
                    label: it.label,
                  ),
              ],
            ),
    );
  }
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.local_hospital, color: AppColors.primary, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ConsultorioClínico',
                    style: TextStyle(
                      color: AppColors.dark,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (int i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _RailItem(
                        item: items[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.item, required this.selected, required this.onTap});

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: selected ? AppColors.primary : AppColors.muted,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistema de gestión',
                  style: TextStyle(color: AppColors.muted.withValues(alpha: 0.8), fontSize: 12),
                ),
                const Text(
                  'ConsultorioClínico',
                  style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.label,
              style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          AppAvatar(name: user.name, radius: 18),
          if (MediaQuery.of(context).size.width >= 700) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
                Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout, color: AppColors.muted),
            onPressed: () {
              context.read<AuthProvider>().logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

// Builders estáticos para los ítems del menú.
Widget _dashboard(BuildContext _) => const DashboardPage();
Widget _agenda(BuildContext _) => const AgendaPage();
Widget _citas(BuildContext _) => const AppointmentsPage();
Widget _pacientes(BuildContext _) => const PatientsPage();
Widget _medicos(BuildContext _) => const DoctorsPage();
Widget _pagos(BuildContext _) => const PaymentsPage();
Widget _reportes(BuildContext _) => const ReportsPage();
Widget _settings(BuildContext _) => const SettingsPage();
Widget _panel(BuildContext _) => const DoctorPanelPage();
Widget _myAppointments(BuildContext _) => const PatientMyAppointmentsPage();