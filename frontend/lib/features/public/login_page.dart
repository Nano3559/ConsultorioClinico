import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../core/widgets/ambient_background.dart';
import '../../data/models/user.dart';
import '../../state/auth_provider.dart';
import '../../state/clinic_provider.dart';

/// Cuentas sembradas en la base de datos para pruebas por rol (acceso personal).
const _demoAccounts = [
  (UserRole.admin, 'admin@consultorio.com', 'Admin1234'),
  (UserRole.medico, 'qbrayanm05@gmail.com', 'Medico1234'),
  (UserRole.recepcion, 'recepcion@consultorio.com', 'Recepcion1234'),
];

/// Pantalla de acceso (personal por email/clave, o paciente por CI + nacimiento).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _ci = TextEditingController();
  DateTime? _birthDate;
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _email.dispose();
    _password.dispose();
    _ci.dispose();
    super.dispose();
  }

  Future<void> _enterApp() async {
    final auth = context.read<AuthProvider>();
    final clinic = context.read<ClinicProvider>();
    clinic.setAuthToken(auth.token, perfilTipo: auth.perfilTipo, perfilId: auth.perfilId);
    clinic.loadAll();
    if (!mounted) return;
    context.go('/app');
  }

  Future<void> _loginPersonal() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingresa correo y contraseña')));
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _enterApp();
  }

  Future<void> _loginPatient() async {
    if (_ci.text.trim().isEmpty || _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa tu carnet y fecha de nacimiento')));
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.loginPatient(_ci.text.trim(), _birthDate!);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _enterApp();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;
    return Scaffold(
      body: AmbientBackground(
        child: Row(
          children: [
            if (isWide)
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryDark, AppColors.primaryLight],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_hospital, size: 84, color: Colors.white.withValues(alpha: 0.95)),
                        const SizedBox(height: 10),
                        const Text(
                          'ConsultorioClínico',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sistema de gestión médica y clínica',
                          style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: 220,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.white, Colors.white.withValues(alpha: 0.0)]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FadeSlide(
                      child: Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white),
                          boxShadow: [
                            BoxShadow(color: AppColors.shadowSoft, blurRadius: 42, offset: const Offset(0, 14)),
                            BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 2, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: Lottie.asset('assets/lottie/Heartbeat Lottie Animation.json'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Bienvenido', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.dark)),
                            const SizedBox(height: 6),
                            const Text('Ingresa con tu cuenta para continuar.', style: TextStyle(color: AppColors.muted)),
                            const SizedBox(height: 16),
                            TabBar(
                              controller: _tab,
                              labelColor: AppColors.primaryDark,
                              dividerColor: AppColors.border,
                              tabs: const [
                                Tab(text: 'Personal'),
                                Tab(text: 'Paciente'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 250,
                              child: TabBarView(
                                controller: _tab,
                                children: [
                                  _personalForm(),
                                  _patientForm(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: TextButton(
                                  onPressed: () => context.go('/'),
                                  child: const Text('← Volver al inicio'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline)),
          keyboardType: TextInputType.emailAddress,
          validator: AppValidators.email,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _password,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          obscureText: _obscure,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _loginPersonal,
            child: Text(_loading ? 'Ingresando...' : 'Ingresar'),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Acceso rápido de demostración', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (role, email, password) in _demoAccounts)
              ActionChip(
                avatar: Icon(role.icon, size: 18, color: AppColors.primary),
                label: Text(role.label),
                onPressed: () {
                  _email.text = email;
                  _password.text = password;
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _patientForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _ci,
          decoration: const InputDecoration(labelText: 'Carnet de identidad', prefixIcon: Icon(Icons.badge_outlined)),
        ),
        const SizedBox(height: 14),
        TextFormField(
          readOnly: true,
          decoration: const InputDecoration(labelText: 'Fecha de nacimiento', prefixIcon: Icon(Icons.cake_outlined)),
          controller: TextEditingController(
            text: _birthDate == null
                ? ''
                : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _birthDate ?? DateTime(2000),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _birthDate = picked);
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _loginPatient,
            child: Text(_loading ? 'Ingresando...' : 'Ingresar como paciente'),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Solo necesitas tu carnet y tu fecha de nacimiento. Si aún no tienes cita, pídela desde el inicio.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
