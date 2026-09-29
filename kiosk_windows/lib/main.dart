import 'package:flutter/material.dart';

import 'kiosk_page.dart';

void main() {
  runApp(const KioscoApp());
}

/// App del kiosco (PC del consultorio, Windows).
///
/// Reconocimiento facial 100% local con OpenCV: descarga las citas de hoy +
/// fotos, verifica en el equipo y confirma el check-in en Firestore por REST.
/// No usa los plugins de Firebase (no compilan en Windows).
class KioscoApp extends StatelessWidget {
  const KioscoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kiosco ConsultorioClínico',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
      ),
      home: const KioskPage(),
    );
  }
}
