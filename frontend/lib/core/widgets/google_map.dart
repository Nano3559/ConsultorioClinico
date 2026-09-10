import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';

/// Mapa real del consultorio (OpenStreetMap vía flutter_map).
/// Funciona en web y en móvil sin API keys.
class GoogleMapBox extends StatefulWidget {
  const GoogleMapBox({
    super.key,
    this.query = 'La Paz, Bolivia',
    this.height = 220,
    this.addressText = 'Av. Principal #123, Ciudad',
    this.center = const LatLng(-16.4897, -68.1193),
  });

  final String query;
  final double height;
  final String addressText;
  final LatLng center;

  @override
  State<GoogleMapBox> createState() => _GoogleMapBoxState();
}

class _GoogleMapBoxState extends State<GoogleMapBox> {
  late final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.center,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.consultorio_clinico',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.center,
                    width: 46,
                    height: 46,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.shadowStrong, blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.location_on, color: AppColors.danger, size: 26),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowSoft, blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.addressText,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
