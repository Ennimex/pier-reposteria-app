// lib/ui/more/widgets/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _cuentaRepo = CuentaRepository();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _telefonoCtrl;

  bool _guardando = false;
  bool _cambios = false;

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ EditProfileScreen');
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    _nombreCtrl =
        TextEditingController(text: user?['nombre']?.toString() ?? '');
    _apellidoCtrl =
        TextEditingController(text: user?['apellido']?.toString() ?? '');
    _telefonoCtrl =
        TextEditingController(text: user?['telefono']?.toString() ?? '');

    _nombreCtrl.addListener(_onChanged);
    _apellidoCtrl.addListener(_onChanged);
    _telefonoCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _cambios = true);

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final body = <String, dynamic>{
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim(),
    };

    final result = await _cuentaRepo.actualizarPerfil(body);

    if (!mounted) return;
    setState(() => _guardando = false);

    if (result['success'] == true) {
      PierLog.info('✅ Perfil actualizado');
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final updatedUser =
          result['user'] as Map<String, dynamic>?;
      if (updatedUser != null) auth.updateCurrentUser(updatedUser);
      setState(() => _cambios = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded,
              color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Perfil actualizado'),
        ]),
        backgroundColor: AppColors.pierVerde,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
    } else {
      PierLog.error('Error al guardar perfil: ${result['message']}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Error al guardar'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final user = Provider.of<AuthProvider>(context).currentUser;
    final email = user?['email']?.toString() ?? '';
    final nombre = _nombreCtrl.text;
    final apellido = _apellidoCtrl.text;
    final iniciales =
        '${nombre.isNotEmpty ? nombre[0].toUpperCase() : ''}'
        '${apellido.isNotEmpty ? apellido[0].toUpperCase() : ''}';

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: const Icon(LucideIcons.chevronLeft,
                          size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Editar Perfil',
                          style: TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ),
                  ),
                  // Guardar — verde si hay cambios pendientes
                  GestureDetector(
                    onTap: (_guardando || !_cambios) ? null : _guardar,
                    child: Text(
                      _guardando ? 'Guardando...' : 'Guardar',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _cambios
                              ? AppColors.pierVerde
                              : AppColors.textSecondary.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── AVATAR (iniciales) ────────────────────
                      Center(
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.pierDorado, width: 2),
                          ),
                          child: _buildAvatarIniciales(iniciales),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(email,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ),
                      const SizedBox(height: 32),

                      // ── NOMBRE ────────────────────────────────
                      _label('Nombre'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _nombreCtrl,
                        hint: 'Alejandro',
                        icon: LucideIcons.user,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Ingresa tu nombre'
                                : null,
                      ),
                      const SizedBox(height: 20),

                      // ── APELLIDO ──────────────────────────────
                      _label('Apellido'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _apellidoCtrl,
                        hint: 'Reyes',
                        icon: LucideIcons.user,
                      ),
                      const SizedBox(height: 20),

                      // ── TELÉFONO ──────────────────────────────
                      _label('Teléfono'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _telefonoCtrl,
                        hint: '7711234567',
                        icon: LucideIcons.smartphone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),

                      // ── EMAIL (solo lectura) ───────────────────
                      _label('Correo electrónico'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Icon(LucideIcons.mail,
                              color: AppColors.textSecondary.withValues(alpha: 0.5), size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(email,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary)),
                          ),
                          Icon(LucideIcons.lock,
                              color: AppColors.textSecondary.withValues(alpha: 0.5), size: 16),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                            'El correo no puede ser modificado.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ),
                      const SizedBox(height: 36),

                      // ── BOTÓN GUARDAR ─────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed:
                              (_guardando || !_cambios) ? null : _guardar,
                          icon: _guardando
                              ? const SizedBox(
                                  height: 18, width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(LucideIcons.save,
                                  color: Colors.white, size: 18),
                          label: Text(
                              _guardando
                                  ? 'Guardando...'
                                  : 'Guardar cambios',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pierVerde,
                            disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.award,
                                color: AppColors.textSecondary, size: 14),
                            const SizedBox(width: 5),
                            Text('Cliente Distinguido Pier',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 18),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.textSecondary.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.pierVerde, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error)),
        contentPadding: const EdgeInsets.all(14),
      ),
      validator: validator,
    );
  }

  Widget _buildAvatarIniciales(String iniciales) => Center(
        child: Text(
          iniciales.isNotEmpty ? iniciales : 'U',
          style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
      );
}