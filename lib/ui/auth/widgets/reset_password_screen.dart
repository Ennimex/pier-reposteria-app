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
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
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

  // Un error sacude lo que lo causó: la fila del código (incompleto o
  // rechazado) o las dos contraseñas.
  int _erroresCodigo = 0;
  int _erroresPassword = 0;

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
    final enCodigo = codigo.length < 6 ||
        ResetPasswordViewModel.validar(codigo, password, confirmacion) ==
            null;
    setState(() {
      if (enCodigo) {
        _erroresCodigo++;
      } else {
        _erroresPassword++;
      }
    });
    mostrarAvisoAuth(context, error);
  }

  void _showSuccessDialog() {
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (_) => EntradaDialogo(
        child: _DialogoRestablecida(
          onIrAlLogin: () {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context).popUntil((route) => route.isFirst);
            context.go(AppRoutes.login);
          },
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    // Cascada de entrada (una sola vez) cuando la página ya se ve.
    final retraso = retrasoEntradaAuth(context);
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
                EntradaSuave(
                  retraso: retraso,
                  desplazamiento: Offset.zero,
                  child: const BotonAtrasAuth(),
                ),
                const SizedBox(height: 32),

                // Sin entrada propia: el candado llega volando desde
                // «¿Olvidaste tu contraseña?» (Hero).
                const IconoCandado(),
                const SizedBox(height: 24),

                // ── TÍTULO ──────────────────────────────────────────────────
                EntradaSuave(
                  orden: 1,
                  retraso: retraso,
                  child: const Text('Nueva contraseña',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
                EntradaSuave(
                  orden: 1,
                  retraso: retraso,
                  child: const Text(
                    'Ingresa el código que enviamos a',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                EntradaSuave(
                  orden: 1,
                  retraso: retraso,
                  child: Text(widget.email,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.pierVerde),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 36),

                // ── CÓDIGO 6 DÍGITOS (entran una tras otra) ─────────────────
                Sacudida(
                  disparo: _erroresCodigo,
                  child: CampoCodigo(
                    controller: _codigo,
                    ancho: 48,
                    alto: 56,
                    tamanoLetra: 22,
                    entrada: retraso + AppMovimiento.retrasoCascada(2),
                  ),
                ),
                const SizedBox(height: 32),

                // ── CONTRASEÑAS (se sacuden juntas si no sirven) ────────────
                Sacudida(
                  disparo: _erroresPassword,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── NUEVA CONTRASEÑA ──────────────────────────────────
                      EntradaSuave(
                        orden: 3,
                        retraso: retraso,
                        child: CampoAuth(
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
                      ),
                      const SizedBox(height: 14),

                      // ── CONFIRMAR CONTRASEÑA ──────────────────────────────
                      EntradaSuave(
                        orden: 4,
                        retraso: retraso,
                        child: CampoAuth(
                          controller: _confirmPasswordCtrl,
                          label: 'Confirmar contraseña',
                          icon: LucideIcons.lock,
                          obscureText: !_vm.verConfirmacion,
                          suffixIcon: OjoPassword(
                            visible: _vm.verConfirmacion,
                            onPressed: _vm.alternarConfirmacion,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                EntradaSuave(
                  orden: 5,
                  retraso: retraso,
                  child: BotonPrincipalAuth(
                    texto: 'Restablecer contraseña',
                    cargando: _vm.restableciendo,
                    onPressed: _handleReset,
                  ),
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

/// Aviso de éxito con el botón para volver al inicio de sesión. La palomita
/// llega con un pop y después el texto y el botón suben en cascada.
class _DialogoRestablecida extends StatelessWidget {
  const _DialogoRestablecida({required this.onIrAlLogin});

  final VoidCallback onIrAlLogin;

  // El diálogo ya es visible desde su primer cuadro (fundido corto): el
  // texto espera a que la palomita esté cayendo.
  static const Duration _trasInsignia = Duration(milliseconds: 160);

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
            const _InsigniaExito(),
            const SizedBox(height: 24),
            const EntradaSuave(
              retraso: _trasInsignia,
              child: Text('¡Contraseña restablecida!',
                  style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 10),
            const EntradaSuave(
              orden: 1,
              retraso: _trasInsignia,
              child: Text(
                'Tu contraseña ha sido actualizada correctamente. Ya puedes iniciar sesión.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            EntradaSuave(
              orden: 2,
              retraso: _trasInsignia,
              child: SizedBox(
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
            ),
          ],
        ),
      ),
    );
  }
}

/// La insignia de éxito del diálogo: el halo se abre, el disco verde cae con
/// un rebote y la palomita aparece al último, también con rebote. Una sola
/// vez; con movimiento reducido aparece ya completa.
class _InsigniaExito extends StatefulWidget {
  const _InsigniaExito();

  @override
  State<_InsigniaExito> createState() => _InsigniaExitoState();
}

class _InsigniaExitoState extends State<_InsigniaExito>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _escalaHalo = Tween<double>(
    begin: 0.6,
    end: 1,
  ).chain(CurveTween(
      curve: const Interval(0, 0.55, curve: AppMovimiento.curvaEntrada)));
  static final Animatable<double> _opacidadHalo = CurveTween(
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );
  static final Animatable<double> _escalaDisco = Tween<double>(
    begin: 0.5,
    end: 1,
  ).chain(CurveTween(
      curve: const Interval(0.1, 0.65, curve: AppMovimiento.curvaRebote)));
  static final Animatable<double> _opacidadDisco = CurveTween(
    curve: const Interval(0.1, 0.3, curve: Curves.easeOut),
  );
  static final Animatable<double> _escalaPalomita = Tween<double>(
    begin: 0.3,
    end: 1,
  ).chain(CurveTween(
      curve: const Interval(0.4, 1, curve: AppMovimiento.curvaRebote)));
  static final Animatable<double> _opacidadPalomita = CurveTween(
    curve: const Interval(0.4, 0.6, curve: Curves.easeOut),
  );

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _preparada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    if (AppMovimiento.reducido(context)) {
      _control.value = 1;
      return;
    }
    // Desde un post-frame, como las entradas: arranca con el diálogo ya
    // montado y visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _control.forward().ignore();
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FadeTransition(
          opacity: _control.drive(_opacidadHalo),
          child: ScaleTransition(
            scale: _control.drive(_escalaHalo),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        FadeTransition(
          opacity: _control.drive(_opacidadDisco),
          child: ScaleTransition(
            scale: _control.drive(_escalaDisco),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.pierVerde,
                shape: BoxShape.circle,
              ),
              child: FadeTransition(
                opacity: _control.drive(_opacidadPalomita),
                child: ScaleTransition(
                  scale: _control.drive(_escalaPalomita),
                  child: const Icon(LucideIcons.check,
                      color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
