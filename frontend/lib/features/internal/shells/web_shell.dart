import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../data/models/user.dart';
import '../../../state/auth_provider.dart';
import '../nav/nav_definitions.dart';

/// Caparazón web: sidebar con módulos agrupados + barra superior.
/// Se usa en web (kIsWeb) y en pantallas muy anchas.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _index = 0;

  void _select(int index, NavModule module) {
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
      body: Row(
        children: [
          _Sidebar(
            modules: modules,
            selectedIndex: _index,
            user: user,
            onSelect: _select,
          ),
          Expanded(
            child: Column(
              children: [
                _WebTopBar(title: current.label, user: user),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [for (final m in modules) m.builder(context)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
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
    return Container(
      width: 250,
      color: AppColors.surface,
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
                      style: TextStyle(
                        color: AppColors.dark,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: _groupedItems(context),
              ),
            ),
            const Divider(height: 1),
            _SidebarFooter(user: user),
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
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
          child: Text(
            m.group.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
          ),
        ));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _SidebarItem(
          module: m,
          selected: i == selectedIndex,
          onTap: () => onSelect(i, m),
        ),
      ));
    }
    return children;
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.module, required this.selected, required this.onTap});

  final NavModule module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryBg : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(module.icon, color: selected ? AppColors.primary : AppColors.muted, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  module.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AppAvatar(name: user.name, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark, fontSize: 13)),
                Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout, color: AppColors.muted, size: 20),
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

class _WebTopBar extends StatelessWidget {
  const _WebTopBar({required this.title, required this.user});

  final String title;
  final User user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                  'ConsultorioClínico',
                  style: TextStyle(color: AppColors.muted.withValues(alpha: 0.8), fontSize: 12),
                ),
                Text(
                  title,
                  style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.w800, fontSize: 20),
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
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
              Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}