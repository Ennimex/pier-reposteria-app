// lib/ui/auth/widgets/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/data/repositories/auth_repository.dart';
import 'package:pier_reposteria/routing/app_routes.dart';
import 'package:pier_reposteria/ui/auth/view_model/login_view_model.dart';
import 'package:pier_reposteria/ui/auth/widgets/auth_partes.dart';
import 'package:pier_reposteria/ui/auth/widgets/forgot_password_screen.dart';
import 'package:pier_reposteria/ui/auth/widgets/register_screen.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/utils/validators.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const LoginScreen({super.key, this.viewModel});

  final LoginViewModel? viewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // El State es dueño del ViewModel y de los controladores de texto.
  late final LoginViewModel _vm = widget.viewModel ??
      LoginViewModel(repo: context.read<AuthRepository>());

  // Cada intento fallido sacude el bloque de credenciales.
  int _errores = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _errores++);
      return;
    }
    final usuario = await _vm.iniciarSesion(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    if (usuario != null) {
      final auth = context.read<AuthProvider>()..abrirSesion(usuario);
      context.go(AppRoutes.homeForRole(auth.rol));
    } else {
      setState(() => _errores++);
      mostrarAvisoAuth(context, _vm.error ?? 'Verifica tus credenciales');
    }
  }

  // Con Google no se navega aquí: al abrirse la sesión, el redirect del
  // router saca al usuario del login según su rol.
  Future<void> _handleGoogleLogin() async {
    final usuario = await _vm.iniciarSesionConGoogle();
    if (!mounted) return;
    if (usuario != null) {
      context.read<AuthProvider>().abrirSesion(usuario);
    } else if (_vm.error != null) {
      mostrarAvisoAuth(context, _vm.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    // Cascada de entrada: espera a que la página se vea (fundido de
    // context.go o deslizamiento del push) y se reproduce una sola vez.
    final retraso = retrasoEntradaAuth(context);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.pierArena,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // ── BACK (esquina superior izquierda) ────────────
                    EntradaSuave(
                      retraso: retraso,
                      desplazamiento: Offset.zero,
                      child: BotonAtrasAuth(
                        grande: false,
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            context.go(AppRoutes.main);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // El logo vuela al registro (Hero) y regresa.
                    EntradaSuave(
                      retraso: retraso,
                      escalaInicial: 0.92,
                      child: const LogoAuth(
                        tamano: 110,
                        margen: 15,
                        alfaSombra: 0.2,
                        desenfoque: 15,
                        caida: 5,
                        tamanoRespaldo: 50,
                      ),
                    ),
                    const SizedBox(height: 24),

                    EntradaSuave(
                      orden: 1,
                      retraso: retraso,
                      child: const Text('Bienvenido',
                          style: TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 6),
                    EntradaSuave(
                      orden: 1,
                      retraso: retraso,
                      child: const Text('Inicia sesión para continuar',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary),
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 32),

                    // ── CREDENCIALES (se sacuden si el intento falla) ─
                    EntradaSuave(
                      orden: 2,
                      retraso: retraso,
                      child: Sacudida(
                        disparo: _errores,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── EMAIL ────────────────────────────────
                            CampoAuth(
                              controller: _emailController,
                              label: 'Email',
                              icon: LucideIcons.mail,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: Validators.email,
                              sinBordeBase: true,
                            ),
                            const SizedBox(height: 14),

                            // ── CONTRASEÑA ───────────────────────────
                            CampoAuth(
                              controller: _passwordController,
                              label: 'Contraseña',
                              icon: LucideIcons.lock,
                              obscureText: !_vm.verPassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _handleLogin(),
                              suffixIcon: OjoPassword(
                                visible: _vm.verPassword,
                                onPressed: _vm.alternarPassword,
                              ),
                              validator: Validators.passwordLogin,
                              sinBordeBase: true,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── OLVIDÉ CONTRASEÑA ────────────────────────────
                    EntradaSuave(
                      orden: 3,
                      retraso: retraso,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ForgotPasswordScreen())),
                          child: Text('¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                  color: AppColors.pierDorado, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── BOTÓN LOGIN ──────────────────────────────────
                    EntradaSuave(
                      orden: 3,
                      retraso: retraso,
                      child: BotonPrincipalAuth(
                        texto: 'Iniciar Sesión',
                        cargando: _vm.ingresando,
                        onPressed: _handleLogin,
                      ),
                    ),
                    const SizedBox(height: 24),

                    EntradaSuave(
                      orden: 4,
                      retraso: retraso,
                      child: const _Separador(),
                    ),
                    const SizedBox(height: 20),

                    // ── GOOGLE ───────────────────────────────────────
                    EntradaSuave(
                      orden: 4,
                      retraso: retraso,
                      child: _BotonGoogle(
                        cargando: _vm.ingresandoConGoogle,
                        onPressed: _handleGoogleLogin,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── REGISTRO ─────────────────────────────────────
                    EntradaSuave(
                      orden: 5,
                      retraso: retraso,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('¿No tienes cuenta?',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                          TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen())),
                            child: Text('Regístrate',
                                style: TextStyle(
                                    color: AppColors.pierVerde,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Línea «O continúa con» entre el login con correo y el de Google.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    final linea = Expanded(
        child:
            Divider(color: AppColors.textSecondary.withValues(alpha: 0.3)));
    return Row(children: [
      linea,
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text('O continúa con',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ),
      linea,
    ]);
  }
}

/// Botón «Continuar con Google» (logo o «G» de respaldo; indicador al cargar,
/// que cambia con un pop dentro del mismo botón).
class _BotonGoogle extends StatelessWidget {
  const _BotonGoogle({required this.cargando, required this.onPressed});

  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: cargando ? null : onPressed,
        icon: CambioAnimado(
          tipo: TipoCambio.escalar,
          alineacion: Alignment.center,
          child: cargando
              ? const SizedBox(
                  key: ValueKey<String>('cargando'),
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textPrimary))
              : Image.asset(
                  'assets/images/google_logo.png',
                  key: const ValueKey<String>('google'),
                  height: 22,
                  width: 22,
                  errorBuilder: (_, _, _) => Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    child: const Text('G',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4285F4))),
                  ),
                ),
        ),
        label: const Text('Continuar con Google',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: AppColors.textSecondary.withValues(alpha: 0.3)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
