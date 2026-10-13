// lib/ui/auth/widgets/verify_email_screen.dart
import 'dart:async';
import 'dart:math' as math;

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
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
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

  // Un código rechazado o incompleto sacude la fila de cajas; un reenvío
  // aceptado hace que el sobre «salga» otra vez.
  int _erroresCodigo = 0;
  int _reenvios = 0;

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
    setState(() => _erroresCodigo++);
    mostrarAvisoAuth(context, error);
  }

  Future<void> _handleResend() async {
    final mensaje = await _vm.reenviar();
    if (!mounted) return;
    if (mensaje != null) {
      setState(() => _reenvios++);
      mostrarAvisoAuth(context, mensaje, color: AppColors.pierVerde);
    } else if (_vm.error != null) {
      mostrarAvisoAuth(context, _vm.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    // Cascada de entrada (una sola vez). Aquí todo es de pintura: el cuerpo
    // usa IntrinsicHeight y se reconstruye con cada cuadro del teclado.
    final retraso = retrasoEntradaAuth(context);
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
                      EntradaSuave(
                        retraso: retraso,
                        desplazamiento: Offset.zero,
                        child: const BotonAtrasAuth(),
                      ),
                      const Spacer(),

                      // ── ÍCONO EMAIL (baja al llegar) ─────────────────
                      EntradaSuave(
                        orden: 1,
                        retraso: retraso,
                        escalaInicial: 0.9,
                        desplazamiento:
                            const Offset(0, -AppMovimiento.distancia),
                        child: Center(child: _Sobre(reenvios: _reenvios)),
                      ),
                      const SizedBox(height: 28),

                      // ── TÍTULO ───────────────────────────────────────
                      EntradaSuave(
                        orden: 2,
                        retraso: retraso,
                        child: const Text(
                          'Verifica tu correo',
                          style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      EntradaSuave(
                        orden: 2,
                        retraso: retraso,
                        child: const Text(
                          'Ingresa el código de 6 dígitos que enviamos a',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      EntradaSuave(
                        orden: 2,
                        retraso: retraso,
                        child: Text(
                          widget.email,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.pierVerde,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── CAMPOS CÓDIGO (al completar, verifica solo) ──
                      // Las cajas entran una tras otra; un código rechazado
                      // sacude la fila (ya vacía).
                      Sacudida(
                        disparo: _erroresCodigo,
                        child: CampoCodigo(
                          controller: _codigo,
                          ancho: 50,
                          alto: 58,
                          tamanoLetra: 24,
                          entrada: retraso + AppMovimiento.retrasoCascada(3),
                          onChanged: (codigo) {
                            if (codigo.length == 6) unawaited(_handleVerify());
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      EntradaSuave(
                        orden: 4,
                        retraso: retraso,
                        child: BotonPrincipalAuth(
                          texto: 'Verificar',
                          cargando: _vm.verificando,
                          onPressed: _handleVerify,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── REENVIAR ─────────────────────────────────────
                      // Solo fundido: el renglón mide un texto de alto y, con
                      // desplazamiento, un toque al inicio de la entrada
                      // caería fuera de su caja.
                      EntradaSuave(
                        orden: 5,
                        retraso: retraso,
                        desplazamiento: Offset.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '¿No recibiste el código?  ',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: _vm.reenviando ? null : _handleResend,
                              child: CambioAnimado(
                                tipo: TipoCambio.escalar,
                                alineacion: Alignment.center,
                                child: _vm.reenviando
                                    ? SizedBox(
                                        key: const ValueKey<String>(
                                            'reenviando'),
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.pierVerde,
                                        ),
                                      )
                                    : PresionEscala(
                                        key: const ValueKey<String>(
                                            'reenviar'),
                                        escala:
                                            AppMovimiento.escalaPresionChica,
                                        child: Text(
                                          'Reenviar',
                                          style: TextStyle(
                                            color: AppColors.pierVerde,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
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

/// El sobre en su círculo. Cada reenvío aceptado ([reenvios] cambia) lo
/// hace «salir» otra vez: el sobre sube y regresa mientras un anillo se
/// abre y se apaga. Solo pinta (el cuerpo usa IntrinsicHeight).
class _Sobre extends StatefulWidget {
  const _Sobre({required this.reenvios});

  final int reenvios;

  @override
  State<_Sobre> createState() => _SobreState();
}

class _SobreState extends State<_Sobre> with SingleTickerProviderStateMixin {
  static const double _diametro = 100;
  static const double _subida = 10;

  static final Animatable<double> _escalaAnillo = Tween<double>(
    begin: 1,
    end: 1.3,
  ).chain(CurveTween(curve: AppMovimiento.curvaEntrada));
  static final Animatable<double> _opacidadAnillo = Tween<double>(
    begin: 0.6,
    end: 0,
  ).chain(CurveTween(curve: Curves.easeIn));

  // En reposo vale 1: el anillo ya se abrió (invisible) y el sobre está en
  // su lugar.
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: AppMovimiento.enfasis,
    value: 1,
  );

  @override
  void didUpdateWidget(_Sobre oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reenvios != oldWidget.reenvios &&
        !AppMovimiento.reducido(context)) {
      _control.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gris = AppColors.textSecondary;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Anillo verde que se abre (invisible en reposo).
        IgnorePointer(
          child: FadeTransition(
            opacity: _control.drive(_opacidadAnillo),
            child: ScaleTransition(
              scale: _control.drive(_escalaAnillo),
              child: Container(
                width: _diametro,
                height: _diametro,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.pierVerde, width: 2),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: _diametro,
          height: _diametro,
          decoration: BoxDecoration(
            color: gris.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: AnimatedBuilder(
            animation: _control,
            child: Icon(
              LucideIcons.mail,
              size: 48,
              color: gris.withValues(alpha: 0.7),
            ),
            builder: (context, sobre) => Transform.translate(
              offset: Offset(0, -_subida * math.sin(math.pi * _control.value)),
              child: sobre,
            ),
          ),
        ),
      ],
    );
  }
}
