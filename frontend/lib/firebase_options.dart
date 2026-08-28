import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default Firebase configuration for the Consultorio Clinico app.
/// Generated manually from the Firebase project `consultorioclinico-2026`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions no ha sido configurado para iOS. '
          'Ejecuta "flutterfire configure" para agregar la plataforma iOS.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions no ha sido configurado para macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions no ha sido configurado para Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions no ha sido configurado para Linux.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions no ha sido configurado para Fuchsia.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4LkmBEK4RozuqL374WsvB6dqyWZbtmgg',
    authDomain: 'consultorioclinico-2026.firebaseapp.com',
    projectId: 'consultorioclinico-2026',
    storageBucket: 'consultorioclinico-2026.firebasestorage.app',
    messagingSenderId: '279633708085',
    appId: '1:279633708085:web:3ee31312b71562134f9d7c',
    measurementId: null,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAXa0dmDh7Cll8Sb--gKUFSikOoK3eF-mQ',
    appId: '1:279633708085:android:10ffae799fe788254f9d7c',
    messagingSenderId: '279633708085',
    projectId: 'consultorioclinico-2026',
    storageBucket: 'consultorioclinico-2026.firebasestorage.app',
  );
}
