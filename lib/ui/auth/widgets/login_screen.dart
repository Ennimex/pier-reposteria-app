// lib/ui/auth/widgets/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/view_model/login_view_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/auth_partes.dart';
import 'package:pier_pasteleria/ui/auth/widgets/forgot_password_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/register_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/utils/validators.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final usuario = await _vm.iniciarSesion(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    if (usuario != null) {
      final auth = context.read<AuthProvider>()..abrirSesion(usuario);
      context.go(AppRoutes.homeForRole(auth.rol));
    } else {
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
                    BotonAtrasAuth(
                      grande: false,
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          context.go(AppRoutes.main);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    const _Logo(),
                    const SizedBox(height: 24),

                    const Text('Bienvenido',
                        style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    const Text('Inicia sesión para continuar',
                        style: TextStyle(
                            fontSize: 15, color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 32),

                    // ── EMAIL ────────────────────────────────────────
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

                    // ── CONTRASEÑA ───────────────────────────────────
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

                    // ── OLVIDÉ CONTRASEÑA ────────────────────────────
                    Align(
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
                    const SizedBox(height: 8),

                    // ── BOTÓN LOGIN ──────────────────────────────────
                    BotonPrincipalAuth(
                      texto: 'Iniciar Sesión',
                      cargando: _vm.ingresando,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 24),

                    const _Separador(),
                    const SizedBox(height: 20),

                    // ── GOOGLE ───────────────────────────────────────
                    _BotonGoogle(
                      cargando: _vm.ingresandoConGoogle,
                      onPressed: _handleGoogleLogin,
                    ),
                    const SizedBox(height: 28),

                    // ── REGISTRO ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿No tienes cuenta?',
                            style: TextStyle(color: AppColors.textSecondary)),
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

/// Logo de Pier en un círculo blanco con sombra verde.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.pierVerde.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(LucideIcons.cake, size: 50, color: AppColors.pierVerde),
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

/// Botón «Continuar con Google» (logo o «G» de respaldo; indicador al cargar).
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
        icon: cargando
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.textPrimary))
            : Image.asset(
                'assets/images/google_logo.png',
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
