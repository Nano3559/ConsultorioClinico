import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../data/models/user.dart';
import '../../../state/auth_provider.dart';
import '../nav/nav_definitions.dart';

/// Caparazón móvil: barra superior con menú (drawer) para acceder a todos los
/// módulos agrupados. Sin barra inferior: la navegación vive en el drawer.
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _index = 0;

  void _select(int index, NavModule module) {
    Navigator.of(context).pop(); // cierra el drawer
    if (module.route != null) {
      context.push(module.route!);
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final modules = stackModulesFor(user.role);
    if (_index >= modules.length) _index = 0;
    final current = modules[_index];

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menú',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          current.label,
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.dark),
        ),
        backgroundColor: AppColors.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: AppAvatar(name: user.name, radius: 16)),
          ),
        ],
      ),
      drawer: _ModuleDrawer(modules: modules, selectedIndex: _index, user: user, onSelect: _select),
      body: IndexedStack(
        index: _index,
        children: [for (final m in modules) m.builder(context)],
      ),
    );
  }
}

class _ModuleDrawer extends StatelessWidget {
  const _ModuleDrawer({
    required this.modules,
    required this.selectedIndex,
    required this.user,
    required this.onSelect,
  });

  final List<NavModule> modules;
  final int selectedIndex;
  final User user;
  final void Function(int, NavModule) onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_hospital, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ConsultorioClínico',
                      style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: _groupedItems(context),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, color: AppColors.muted),
              title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.dark)),
              onTap: () {
                context.read<AuthProvider>().logout();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupedItems(BuildContext context) {
    final children = <Widget>[];
    String? lastGroup;
    for (var i = 0; i < modules.length; i++) {
      final m = modules[i];
      if (m.group != lastGroup) {
        lastGroup = m.group;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            m.group.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
          ),
        ));
      }
      children.add(ListTile(
        leading: Icon(m.icon, color: i == selectedIndex ? AppColors.primary : AppColors.muted),
        title: Text(m.label, style: TextStyle(color: i == selectedIndex ? AppColors.primary : AppColors.dark)),
        selected: i == selectedIndex,
        selectedTileColor: AppColors.primaryBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () => onSelect(i, m),
      ));
    }
    return children;
  }
}