import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Barra de navegación de la página pública (responsiva).
class LandingNavbar extends StatelessWidget {
  const LandingNavbar({super.key, required this.onNavigate, required this.onRequest});

  final ValueChanged<String> onNavigate;
  final VoidCallback onRequest;

  static const _menu = [
    'Inicio',
    'Nosotros',
    'Especialidades',
    'Médicos',
    'Servicios',
    'Horarios',
    'Contacto',
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: AppColors.primary, size: 32),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              AppInfo.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            for (final item in _menu)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextButton(
                  onPressed: () => onNavigate(item),
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                  child: Text(item),
                ),
              ),
            FilledButton(
              onPressed: onRequest,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Solicitar cita'),
            ),
          ] else
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.dark),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        for (final item in [..._menu, 'Solicitar cita'])
                          ListTile(
                            leading: const Icon(Icons.chevron_right,
                                color: AppColors.primary),
                            title: Text(
                              item,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              if (item == 'Solicitar cita') {
                                onRequest();
                              } else {
                                onNavigate(item);
                              }
                            },
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}