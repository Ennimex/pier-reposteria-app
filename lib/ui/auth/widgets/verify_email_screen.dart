// lib/ui/auth/widgets/verify_email_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/view_model/verify_email_view_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/auth_partes.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const VerifyEmailScreen({required this.email, this.viewModel, super.key});

  final String email;
  final VerifyEmailViewModel? viewModel;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codigo = CodigoController();

  // El State es dueño del ViewModel y de las cajas del código.
  late final VerifyEmailViewModel _vm = widget.viewModel ??
      VerifyEmailViewModel(
        repo: context.read<AuthRepository>(),
        email: widget.email,
      );

  @override
  void dispose() {
    _codigo.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final codigo = _codigo.codigo;
    final usuario = await _vm.verificar(codigo);
    if (!mounted) return;
    if (usuario != null) {
      context.read<AuthProvider>().abrirSesion(usuario);
      context.go(AppRoutes.main);
      return;
    }
    final error = _vm.error;
    if (error == null) return; // ya había una verificación en curso
    // Un código completo rechazado se borra para volver a capturarlo.
    if (codigo.length == 6) _codigo.limpiar();
    mostrarAvisoAuth(context, error);
  }

  Future<void> _handleResend() async {
    final mensaje = await _vm.reenviar();
    if (!mounted) return;
    if (mensaje != null) {
      mostrarAvisoAuth(context, mensaje, color: AppColors.pierVerde);
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
      // Única pantalla de auth que era Column fija: con el teclado numérico
      // abierto (aquí siempre lo está) desbordaba y Flutter pintaba las
      // franjas de "BOTTOM OVERFLOWED". Ahora scrollea cuando falta espacio
      // y conserva el centrado (Spacers) cuando sobra.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: ListenableBuilder(
                  listenable: _vm,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      const BotonAtrasAuth(),
                      const Spacer(),

                      // ── ÍCONO EMAIL ──────────────────────────────────
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.mail,
                            size: 48,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── TÍTULO ───────────────────────────────────────
                      const Text(
                        'Verifica tu correo',
                        style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ingresa el código de 6 dígitos que enviamos a',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.pierVerde,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // ── CAMPOS CÓDIGO (al completar, verifica solo) ──
                      CampoCodigo(
                        controller: _codigo,
                        ancho: 50,
                        alto: 58,
                        tamanoLetra: 24,
                        onChanged: (codigo) {
                          if (codigo.length == 6) unawaited(_handleVerify());
                        },
                      ),
                      const SizedBox(height: 32),

                      BotonPrincipalAuth(
                        texto: 'Verificar',
                        cargando: _vm.verificando,
                        onPressed: _handleVerify,
                      ),
                      const SizedBox(height: 20),

                      // ── REENVIAR ─────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿No recibiste el código?  ',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: _vm.reenviando ? null : _handleResend,
                            child: _vm.reenviando
                                ? SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.pierVerde,
                                    ),
                                  )
                                : Text(
                                    'Reenviar',
                                    style: TextStyle(
                                      color: AppColors.pierVerde,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),

                      const Spacer(),
                      const SizedBox(height: 20),
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
