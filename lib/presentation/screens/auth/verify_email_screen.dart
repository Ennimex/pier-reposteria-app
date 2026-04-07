// lib/presentation/screens/auth/verify_email_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../routes/app_routes.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Refrescar UI cuando cambia el foco (para el borde activo)
    for (final f in _focusNodes) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _codigo =>
      _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    if (_codigo.length < 6) {
      _showSnack('Ingresa el código completo de 6 dígitos', Colors.red);
      return;
    }
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyEmail(widget.email, _codigo);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      context.go(AppRoutes.main);
    } else {
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      _showSnack(
          auth.errorMessage ?? 'Código inválido o expirado',
          Colors.red);
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result =
        await auth.resendVerificationCode(widget.email);
    if (!mounted) return;
    setState(() => _isResending = false);
    _showSnack(
      result['message'] ?? 'Código reenviado',
      result['success'] == true ? AppColors.pierVerde : Colors.red,
    );
  }

  void _onDigitChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_codigo.length == 6) _handleVerify();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // ── BOTÓN BACK ───────────────────────────────────
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

              const Spacer(),

              // ── ÍCONO EMAIL ──────────────────────────────────
              Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 48,
                    color: Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── TÍTULO ───────────────────────────────────────
              const Text('Verifica tu correo',
                  style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Ingresa el código de 6 dígitos que enviamos a',
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(widget.email,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerde),
                  textAlign: TextAlign.center),

              const SizedBox(height: 40),

              // ── CAMPOS CÓDIGO ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final isFocused = _focusNodes[i].hasFocus;
                  final hasValue =
                      _controllers[i].text.isNotEmpty;

                  return SizedBox(
                    width: 50, height: 58,
                    child: TextFormField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(
                          fontSize: 24,
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
                                  ? AppColors.pierVerde
                                      .withValues(alpha: 0.4)
                                  : Colors.transparent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.pierVerde,
                              width: 2),
                        ),
                      ),
                      onChanged: (v) => _onDigitChanged(v, i),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // ── BOTÓN VERIFICAR ──────────────────────────────
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerify,
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
                      : const Text('Verificar',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),

              // ── REENVIAR ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿No recibiste el código?  ',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13)),
                  GestureDetector(
                    onTap: _isResending ? null : _handleResend,
                    child: _isResending
                        ? const SizedBox(
                            height: 14, width: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.pierVerde))
                        : const Text('Reenviar',
                            style: TextStyle(
                                color: AppColors.pierVerde,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              const Spacer(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}