import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../state/auth_provider.dart';

/// El médico llega aquí desde el correo de confirmación para fijar su contraseña.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.oobCode});

  final String? oobCode;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _verifyError;
  bool _verifying = true;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = widget.oobCode;
    if (code == null || code.isEmpty) {
      setState(() {
        _verifying = false;
        _verifyError = 'Enlace inválido.';
      });
      return;
    }
    final auth = context.read<AuthProvider>();
    final err = await auth.verifyResetCode(code);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verifyError = err;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final err = await auth.confirmPasswordReset(widget.oobCode!, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _verifying
                    ? const Center(child: CircularProgressIndicator())
                    : _verifyError != null
                        ? Column(
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                              const SizedBox(height: 12),
                              Text(_verifyError!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(onPressed: () => context.go('/login'), child: const Text('Ir al inicio de sesión')),
                            ],
                          )
                        : _done
                            ? Column(
                                children: [
                                  const Icon(Icons.check_circle, size: 48, color: AppColors.success),
                                  const SizedBox(height: 12),
                                  const Text('Contraseña lista. Ya puedes iniciar sesión.', textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  FilledButton(onPressed: () => context.go('/login'), child: const Text('Iniciar sesión')),
                                ],
                              )
                            : Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Crear contraseña', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.dark)),
                                    const SizedBox(height: 6),
                                    const Text('Define la contraseña de tu cuenta de médico.', style: TextStyle(color: AppColors.muted)),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _password,
                                      obscureText: true,
                                      decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                                      validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _confirm,
                                      obscureText: true,
                                      decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                                      validator: (v) => (v != _password.text) ? 'Las contraseñas no coinciden' : null,
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: _loading ? null : _submit,
                                        child: Text(_loading ? 'Guardando...' : 'Guardar contraseña'),
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
    );
  }
}
