// lib/ui/auth/widgets/reset_password_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/view_model/reset_password_view_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/auth_partes.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const ResetPasswordScreen({required this.email, this.viewModel, super.key});

  final String email;
  final ResetPasswordViewModel? viewModel;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codigo = CodigoController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  // El State es dueño del ViewModel, de las cajas del código y de los campos.
  late final ResetPasswordViewModel _vm = widget.viewModel ??
      ResetPasswordViewModel(
        repo: context.read<AuthRepository>(),
        email: widget.email,
      );

  @override
  void dispose() {
    _codigo.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final codigo = _codigo.codigo;
    final password = _passwordCtrl.text.trim();
    final confirmacion = _confirmPasswordCtrl.text.trim();
    final ok = await _vm.restablecer(codigo, password, confirmacion);
    if (!mounted) return;

    if (ok) {
      _showSuccessDialog();
      return;
    }
    final error = _vm.error;
    if (error == null) return; // ya había un intento en curso
    // Si lo capturado era válido, el backend rechazó el código: se borra
    // para volver a capturarlo.
    if (ResetPasswordViewModel.validar(codigo, password, confirmacion) ==
        null) {
      _codigo.limpiar();
    }
    mostrarAvisoAuth(context, error);
  }

  void _showSuccessDialog() {
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoRestablecida(
        onIrAlLogin: () {
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
          context.go(AppRoutes.login);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.pierArena,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const BotonAtrasAuth(),
                const SizedBox(height: 32),

                const IconoCandado(),
                const SizedBox(height: 24),

                // ── TÍTULO ──────────────────────────────────────────────────
                const Text('Nueva contraseña',
                    style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa el código que enviamos a',
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(widget.email,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.pierVerde),
                    textAlign: TextAlign.center),
                const SizedBox(height: 36),

                // ── CÓDIGO 6 DÍGITOS ────────────────────────────────────────
                CampoCodigo(
                  controller: _codigo,
                  ancho: 48,
                  alto: 56,
                  tamanoLetra: 22,
                ),
                const SizedBox(height: 32),

                // ── NUEVA CONTRASEÑA ────────────────────────────────────────
                CampoAuth(
                  controller: _passwordCtrl,
                  label: 'Nueva contraseña',
                  icon: LucideIcons.lock,
                  obscureText: !_vm.verPassword,
                  // Sincronizado con backend (mín 6 + letra + número)
                  helperText: 'Mínimo 6 caracteres, 1 letra y 1 número',
                  suffixIcon: OjoPassword(
                    visible: _vm.verPassword,
                    onPressed: _vm.alternarPassword,
                  ),
                ),
                const SizedBox(height: 14),

                // ── CONFIRMAR CONTRASEÑA ────────────────────────────────────
                CampoAuth(
                  controller: _confirmPasswordCtrl,
                  label: 'Confirmar contraseña',
                  icon: LucideIcons.lock,
                  obscureText: !_vm.verConfirmacion,
                  suffixIcon: OjoPassword(
                    visible: _vm.verConfirmacion,
                    onPressed: _vm.alternarConfirmacion,
                  ),
                ),
                const SizedBox(height: 32),

                BotonPrincipalAuth(
                  texto: 'Restablecer contraseña',
                  cargando: _vm.restableciendo,
                  onPressed: _handleReset,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso de éxito con el botón para volver al inicio de sesión.
class _DialogoRestablecida extends StatelessWidget {
  const _DialogoRestablecida({required this.onIrAlLogin});

  final VoidCallback onIrAlLogin;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.pierVerde,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.check,
                      color: Colors.white, size: 30),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('¡Contraseña restablecida!',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Tu contraseña ha sido actualizada correctamente. Ya puedes iniciar sesión.',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onIrAlLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                child: const Text('Ir al Login',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
