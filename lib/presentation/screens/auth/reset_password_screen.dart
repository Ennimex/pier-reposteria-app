// lib/presentation/screens/auth/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../routes/app_routes.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // ── Código 6 dígitos ──────────────────────────────────────────────────────
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  // ── Contraseña ────────────────────────────────────────────────────────────
  final _passwordCtrl        = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isPasswordVisible        = false;
  bool _isConfirmPasswordVisible = false;

  bool _isLoading   = false;
  bool _codigoListo = false; // true cuando los 6 campos están llenos

  @override
  void initState() {
    super.initState();
    for (final f in _focusNodes) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _codeControllers) { c.dispose(); }
    for (final f in _focusNodes)      { f.dispose(); }
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  String get _codigo =>
      _codeControllers.map((c) => c.text).join();

  void _onDigitChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _codigoListo = _codigo.length == 6);
  }

  Future<void> _handleReset() async {
    if (_codigo.length < 6) {
      _showSnack('Ingresa el código completo de 6 dígitos', Colors.red);
      return;
    }
    final pass = _passwordCtrl.text.trim();
    if (pass.length < 8) {
      _showSnack('La contraseña debe tener al menos 8 caracteres', Colors.red);
      return;
    }
    if (pass != _confirmPasswordCtrl.text.trim()) {
      _showSnack('Las contraseñas no coinciden', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.resetPassword(
      email:         widget.email,
      codigo:        _codigo,
      nuevaPassword: pass,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      // Código incorrecto — limpiar campos de código
      for (final c in _codeControllers) { c.clear(); }
      _focusNodes[0].requestFocus();
      setState(() => _codigoListo = false);
      _showSnack(result['message'] ?? 'Código inválido o expirado', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono check
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 56, height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.pierVerde,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
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
              Text(
                'Tu contraseña ha sido actualizada correctamente. Ya puedes iniciar sesión.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Cerrar el diálogo primero usando el rootNavigator
                    Navigator.of(context, rootNavigator: true).pop();
                    // Limpiar todo el stack de Navigator y navegar al login
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    context.go(AppRoutes.login);
                  },
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // ── BACK ──────────────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 16, color: AppColors.textPrimary),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── ÍCONO ─────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.pierVerde.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      size: 44, color: AppColors.pierVerde),
                ),
              ),
              const SizedBox(height: 24),

              // ── TÍTULO ────────────────────────────────────────────────────
              const Text('Nueva contraseña',
                  style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Ingresa el código que enviamos a',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(widget.email,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerde),
                  textAlign: TextAlign.center),

              const SizedBox(height: 36),

              // ── CÓDIGO 6 DÍGITOS ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final isFocused = _focusNodes[i].hasFocus;
                  final hasValue  = _codeControllers[i].text.isNotEmpty;
                  return SizedBox(
                    width: 48, height: 56,
                    child: TextFormField(
                      controller: _codeControllers[i],
                      focusNode:  _focusNodes[i],
                      textAlign:  TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: isFocused || hasValue
                            ? Colors.white
                            : Colors.grey.withValues(alpha: 0.15),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: hasValue
                                  ? AppColors.pierVerde.withValues(alpha: 0.4)
                                  : Colors.transparent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.pierVerde, width: 2),
                        ),
                      ),
                      onChanged: (v) => _onDigitChanged(v, i),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // ── NUEVA CONTRASEÑA ──────────────────────────────────────────
              _field(
                controller: _passwordCtrl,
                label: 'Nueva contraseña',
                icon: Icons.lock_outline_rounded,
                obscureText: !_isPasswordVisible,
                helperText: 'Mínimo 8 caracteres',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey, size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              const SizedBox(height: 14),

              // ── CONFIRMAR CONTRASEÑA ──────────────────────────────────────
              _field(
                controller: _confirmPasswordCtrl,
                label: 'Confirmar contraseña',
                icon: Icons.lock_outline_rounded,
                obscureText: !_isConfirmPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey, size: 20,
                  ),
                  onPressed: () => setState(() =>
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
              ),

              const SizedBox(height: 32),

              // ── BOTÓN RESTABLECER ─────────────────────────────────────────
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleReset,
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
                      : const Text('Restablecer contraseña',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon, color: AppColors.pierVerde, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.pierVerde, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red)),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }
}