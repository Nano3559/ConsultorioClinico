import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../data/models/user.dart';
import '../../state/auth_provider.dart';

/// Cuentas sembradas en la base de datos para pruebas por rol.
const _demoAccounts = [
  (UserRole.admin, 'admin@consultorio.com', 'admin123'),
  (UserRole.medico, 'carlos@consultorio.com', 'medico123'),
  (UserRole.recepcion, 'maria@consultorio.com', 'recepcion123'),
  (UserRole.paciente, 'pedro@gmail.com', 'paciente123'),
];

/// Pantalla de acceso por rol (Ejercicio: Login).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.go('/app');
  }

  void _quickLogin(String email, String password) {
    _email.text = email;
    _password.text = password;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;
    return Scaffold(
      body: Row(
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
                      Icon(Icons.local_hospital, size: 80, color: Colors.white.withValues(alpha: 0.9)),
                      SizedBox(height: 8),
                      Text(
                        'ConsultorioClínico',
                        style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Sistema de gestión médica y clínica',
                        style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 16),
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
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
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
                        const SizedBox(height: 24),
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
                          validator: (v) => (v == null || v.isEmpty) ? 'La contraseña es requerida' : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _login,
                            child: Text(_loading ? 'Ingresando...' : 'Ingresar'),
                          ),
                        ),
                        const SizedBox(height: 24),
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
                                onPressed: () => _quickLogin(email, password),
                              ),
                          ],
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
        ],
      ),
    );
  }
}
