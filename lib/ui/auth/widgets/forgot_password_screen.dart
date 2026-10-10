// lib/ui/auth/widgets/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/ui/auth/view_model/forgot_password_view_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/auth_partes.dart';
import 'package:pier_pasteleria/ui/auth/widgets/reset_password_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const ForgotPasswordScreen({super.key, this.viewModel});

  final ForgotPasswordViewModel? viewModel;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();

  // El State es dueño del ViewModel y del controlador de texto.
  late final ForgotPasswordViewModel _vm = widget.viewModel ??
      ForgotPasswordViewModel(repo: context.read<AuthRepository>());

  @override
  void dispose() {
    _emailCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final email = _emailCtrl.text.trim();
    final ok = await _vm.enviar(email);
    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: email),
        ),
      );
    } else if (_vm.error != null) {
      mostrarAvisoAuth(context, _vm.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const BotonAtrasAuth(),
              const SizedBox(height: 40),

              // ── ÍCONO ─────────────────────────────────────────────────────
              const IconoCandado(),
              const SizedBox(height: 28),

              // ── TÍTULO ────────────────────────────────────────────────────
              const Text(
                '¿Olvidaste tu\ncontraseña?',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ingresa tu correo y te enviaremos un código para restablecer tu contraseña.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // ── EMAIL ─────────────────────────────────────────────────────
              CampoAuth(
                controller: _emailCtrl,
                label: 'Correo electrónico',
                icon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),

              // ── BOTÓN ENVIAR ──────────────────────────────────────────────
              ListenableBuilder(
                listenable: _vm,
                builder: (context, _) => BotonPrincipalAuth(
                  texto: 'Enviar código',
                  cargando: _vm.enviando,
                  onPressed: _handleSend,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
