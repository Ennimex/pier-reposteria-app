// lib/ui/auth/widgets/login_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/auth/widgets/register_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/forgot_password_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      context.go(AppRoutes.homeForRole(auth.rol));
    } else {
      _showSnack(auth.errorMessage ?? 'Verifica tus credenciales');
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (!success &&
        auth.errorMessage != 'Inicio de sesión cancelado') {
      _showSnack(auth.errorMessage ?? 'Error con Google');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        context.go(AppRoutes.main);
                      }
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(LucideIcons.chevronLeft,
                          size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── LOGO ─────────────────────────────────────────
                Center(
                  child: Container(
                    width: 110, height: 110,
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
                          errorBuilder: (_, _, _) => Icon(
                              LucideIcons.cake,
                              size: 50,
                              color: AppColors.pierVerde),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text('Bienvenido',
                    style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('Inicia sesión para continuar',
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),

                // ── EMAIL ────────────────────────────────────────
                _field(
                  controller: _emailController,
                  label: 'Email',
                  icon: LucideIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu email';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── CONTRASEÑA ───────────────────────────────────
                _field(
                  controller: _passwordController,
                  label: 'Contraseña',
                  icon: LucideIcons.lock,
                  obscureText: !_isPasswordVisible,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _handleLogin(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? LucideIcons.eye
                          : LucideIcons.eyeOff,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),

                // ── OLVIDÉ CONTRASEÑA ────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ForgotPasswordScreen())),
                    child: Text('¿Olvidaste tu contraseña?',
                        style: TextStyle(
                            color: AppColors.pierDorado,
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 8),

                // ── BOTÓN LOGIN ──────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pierVerde,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Iniciar Sesión',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),

                // ── DIVIDER ──────────────────────────────────────
                Row(children: [
                  Expanded(
                      child: Divider(
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.3))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('O continúa con',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  Expanded(
                      child: Divider(
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.3))),
                ]),
                const SizedBox(height: 20),

                // ── GOOGLE ───────────────────────────────────────
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isGoogleLoading
                        ? null
                        : _handleGoogleLogin,
                    icon: _isGoogleLoading
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textPrimary))
                        : Image.asset(
                            'assets/images/google_logo.png',
                            height: 22, width: 22,
                            errorBuilder: (_, _, _) => Container(
                              width: 22, height: 22,
                              alignment: Alignment.center,
                              child: const Text('G',
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4285F4))),
                            ),
                          ),
                    label: const Text('Continuar con Google',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── REGISTRO ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿No tienes cuenta?',
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
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
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    List<String>? autofillHints,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.pierVerde, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.textSecondary.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.pierVerde, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error)),
        contentPadding: const EdgeInsets.all(14),
      ),
      validator: validator,
    );
  }
}