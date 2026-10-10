// lib/ui/auth/widgets/register_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/view_model/register_view_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/auth_partes.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/public/widgets/legal_screen.dart';
import 'package:pier_pasteleria/utils/validators.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const RegisterScreen({super.key, this.viewModel});

  final RegisterViewModel? viewModel;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  // El State es dueño del ViewModel, de los controladores y de los enlaces.
  late final RegisterViewModel _vm = widget.viewModel ??
      RegisterViewModel(repo: context.read<AuthRepository>());
  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = _abrirLegal;
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = _abrirLegal;

  void _abrirLegal() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const LegalScreen()));

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_vm.aceptaTerminos) {
      mostrarAvisoAuth(context, RegisterViewModel.faltanTerminos);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final ok = await _vm.registrar(
      nombre: _nombreCtrl.text.trim(),
      apellido: _apellidoCtrl.text.trim(),
      email: email,
      telefono: _telefonoCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );
    if (!mounted) return;

    if (ok) {
      context.go(AppRoutes.verificarEmail, extra: {'email': email});
    } else {
      mostrarAvisoAuth(context, _vm.error ?? 'Error al registrar');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    const separacion = SizedBox(height: 12);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.pierArena,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // ── HEADER ───────────────────────────────────────
                  const BotonAtrasAuth(grande: false),
                  const SizedBox(height: 20),

                  const _Logo(),
                  const SizedBox(height: 20),

                  const Text('Crea tu cuenta',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  const Text('Completa los siguientes datos',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 28),

                  // ── CAMPOS ───────────────────────────────────────
                  CampoAuth(
                      controller: _nombreCtrl,
                      label: 'Nombre',
                      icon: LucideIcons.user,
                      validator: Validators.nombre),
                  separacion,
                  CampoAuth(
                      controller: _apellidoCtrl,
                      label: 'Apellido',
                      icon: LucideIcons.user,
                      validator: Validators.nombre),
                  separacion,
                  CampoAuth(
                      controller: _emailCtrl,
                      label: 'Email',
                      icon: LucideIcons.mail,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email),
                  separacion,
                  CampoAuth(
                      controller: _telefonoCtrl,
                      label: 'Teléfono',
                      icon: LucideIcons.phone,
                      keyboardType: TextInputType.phone,
                      validator: Validators.telefono),
                  separacion,
                  CampoAuth(
                      controller: _passwordCtrl,
                      label: 'Contraseña',
                      icon: LucideIcons.lock,
                      obscureText: !_vm.verPassword,
                      suffixIcon: OjoPassword(
                        visible: _vm.verPassword,
                        onPressed: _vm.alternarPassword,
                      ),
                      // Sincronizado con backend (mín 6 + letra + número)
                      helperText: 'Mínimo 6 caracteres, 1 letra y 1 número',
                      validator: Validators.passwordNueva),
                  separacion,
                  CampoAuth(
                      controller: _confirmPasswordCtrl,
                      label: 'Confirmar contraseña',
                      icon: LucideIcons.lock,
                      obscureText: !_vm.verConfirmacion,
                      suffixIcon: OjoPassword(
                        visible: _vm.verConfirmacion,
                        onPressed: _vm.alternarConfirmacion,
                      ),
                      validator: (v) =>
                          Validators.confirmarPassword(v, _passwordCtrl.text)),
                  const SizedBox(height: 16),

                  // ── TÉRMINOS ─────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _vm.aceptaTerminos,
                          activeColor: AppColors.pierVerde,
                          onChanged: (v) => _vm.aceptaTerminos = v ?? false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                            children: [
                              const TextSpan(text: 'Acepto los '),
                              TextSpan(
                                text: 'Términos y Condiciones',
                                style: TextStyle(
                                    color: AppColors.pierVerde,
                                    fontWeight: FontWeight.bold),
                                recognizer: _termsRecognizer,
                              ),
                              const TextSpan(text: ' y el '),
                              TextSpan(
                                text: 'Aviso de Privacidad',
                                style: TextStyle(
                                    color: AppColors.pierVerde,
                                    fontWeight: FontWeight.bold),
                                recognizer: _privacyRecognizer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── BOTÓN REGISTRAR ──────────────────────────────
                  BotonPrincipalAuth(
                    texto: 'Registrarse',
                    cargando: _vm.registrando,
                    onPressed: _handleRegister,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo de Pier en un círculo blanco con sombra verde suave.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.pierVerde.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              Icon(LucideIcons.cake, size: 40, color: AppColors.pierVerde),
        ),
      ),
    );
  }
}
