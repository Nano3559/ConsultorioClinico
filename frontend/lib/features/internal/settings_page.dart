import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/api_client.dart';
import '../../state/clinic_provider.dart';

/// Configuración del sistema.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicProvider>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Configuración', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.dark)),
        const SizedBox(height: 20),
        const _Section(
          title: 'Consultorio',
          children: [
            _InfoRow(label: 'Nombre', value: AppInfo.name),
            _InfoRow(label: 'Dirección', value: AppInfo.address),
            _InfoRow(label: 'Teléfono', value: AppInfo.phone),
            _InfoRow(label: 'Correo', value: AppInfo.email),
            _InfoRow(label: 'Horarios', value: AppInfo.hours),
            _InfoRow(label: 'Precio de consulta', value: 'Gs 150.000'),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Backend (API)',
          children: [
            const _InfoRow(
              label: 'URL base',
              value: ApiConfig.baseUrl,
              highlight: true,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'El frontend está listo para conectarse al backend de Node.js. '
                'Los endpoints esperados están documentados en lib/services/api_client.dart '
                'y los datos actuales son ficticios para el ejercicio académico.',
                style: const TextStyle(color: AppColors.muted, height: 1.5, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Datos de demostración',
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Restablece los datos ficticios del consultorio al estado inicial.',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: OutlinedButton.icon(
                onPressed: () {
                  clinic.resetDemo();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Datos de demostración restablecidos')),
                  );
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restablecer demo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _Section(
          title: 'Acerca de',
          children: [
            _InfoRow(label: 'Versión', value: '1.0.0'),
            _InfoRow(label: 'Plataforma', value: 'Flutter (App móvil + Web)'),
            _InfoRow(label: 'Sistema operativo mínimo', value: 'Android 7 (2016)'),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.dark)),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? AppColors.primary : AppColors.dark,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}