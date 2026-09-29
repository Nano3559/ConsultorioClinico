import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:consultorio_clinico/main.dart';
import 'package:consultorio_clinico/state/auth_provider.dart';
import 'package:consultorio_clinico/state/clinic_provider.dart';

/// Fakes de Firebase para widget tests (sin red ni nativo).
/// Cubren lo que usan los providers al construirse: initializeApp,
/// FirebaseAuth.instance (authStateChanges/currentUser).

class FakeFirebaseCore extends Fake
    with MockPlatformInterfaceMixin
    implements FirebasePlatform {
  final _apps = <String, FirebaseAppPlatform>{};

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    final app = FirebaseAppPlatform(
      name ?? defaultFirebaseAppName,
      options ?? _fakeOptions,
    );
    _apps[app.name] = app;
    return app;
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    final app = _apps[name];
    if (app == null) {
      throw FirebaseException(
        plugin: 'core',
        code: 'no-app',
        message: 'No Firebase App in test',
      );
    }
    return app;
  }

  @override
  List<FirebaseAppPlatform> get apps => _apps.values.toList();
}

class FakeFirebaseAuth extends Fake
    with MockPlatformInterfaceMixin
    implements FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor(
      {required FirebaseApp app, Persistence? persistence}) =>
      this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;
  @override
  Stream<UserPlatform?> authStateChanges() =>
      const Stream<UserPlatform?>.empty();

  @override
  UserPlatform? get currentUser => null;
}

const _fakeOptions = FirebaseOptions(
  apiKey: 'test',
  appId: 'test',
  messagingSenderId: 'test',
  projectId: 'test',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FirebasePlatform.instance = FakeFirebaseCore();
    FirebaseAuthPlatform.instance = FakeFirebaseAuth();
    await Firebase.initializeApp(options: _fakeOptions);
  });

  testWidgets('Landing page renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ClinicProvider()),
        ],
        child: const ConsultorioClinicoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ConsultorioClínico'), findsWidgets);
    expect(find.text('Especialidades'), findsWidgets);
    expect(find.text('Médicos'), findsWidgets);
    expect(find.text('Solicitar cita'), findsWidgets);
  });
}
