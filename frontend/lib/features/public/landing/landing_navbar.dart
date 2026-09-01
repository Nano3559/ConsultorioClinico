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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.gradientPrimary,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.local_hospital, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              AppInfo.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
          ),
          const Spacer(),
          if (!isMobile)
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in _menu)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: TextButton(
                          onPressed: () => onNavigate(item),
                          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                          child: Text(item),
                        ),
                      ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: onRequest,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      child: const Text('Solicitar cita'),
                    ),
                  ],
                ),
              ),
            )
          else
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