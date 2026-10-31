// lib/ui/more/widgets/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/more/view_model/edit_profile_view_model.dart';
import 'package:pier_reposteria/utils/logger.dart';
import 'package:pier_reposteria/utils/validators.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo
  /// con la sesión actual.
  const EditProfileScreen({super.key, this.viewModel});

  final EditProfileViewModel? viewModel;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // El State es dueño del ViewModel y de los controladores de texto.
  late final EditProfileViewModel _vm = widget.viewModel ??
      EditProfileViewModel(
        repo: context.read<CuentaRepository>(),
        usuario: context.read<AuthProvider>().currentUser,
      );
  late final TextEditingController _nombreCtrl =
      TextEditingController(text: _vm.nombre);
  late final TextEditingController _apellidoCtrl =
      TextEditingController(text: _vm.apellido);
  late final TextEditingController _telefonoCtrl =
      TextEditingController(text: _vm.telefono);

  // Cada guardado exitoso abre un anillo dorado alrededor del avatar.
  int _guardados = 0;

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ EditProfileScreen');
    _nombreCtrl.addListener(_onChanged);
    _apellidoCtrl.addListener(_onChanged);
    _telefonoCtrl.addListener(_onChanged);
  }

  void _onChanged() => _vm.editar(
        nombre: _nombreCtrl.text,
        apellido: _apellidoCtrl.text,
        telefono: _telefonoCtrl.text,
      );

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final usuario = await _vm.guardar();
    if (!mounted) return;

    if (usuario != null) {
      PierLog.info('✅ Perfil actualizado');
      auth.updateCurrentUser(usuario);
      setState(() => _guardados++);
      messenger.showSnackBar(SnackBar(
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
    } else if (_vm.error != null) {
      PierLog.error('Error al guardar perfil: ${_vm.error}');
      messenger.showSnackBar(SnackBar(
        content: Text(_vm.error!),
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
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildPantalla(context),
    );
  }

  Widget _buildPantalla(BuildContext context) {
    final email = _vm.email;
    final guardando = _vm.guardando;
    final cambios = _vm.hayCambios;
    // La página llega con un push: el formulario entra en cascada cuando ya
    // se deslizó casi toda (una sola vez).
    const retraso = AppMovimiento.trasEmpuje;
    final colorGuardar = cambios
        ? AppColors.pierVerde
        : AppColors.textSecondary.withValues(alpha: 0.5);

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
                  PresionEscala(
                    escala: AppMovimiento.escalaPresionChica,
                    child: GestureDetector(
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
                  // Guardar — verde si hay cambios pendientes (el color
                  // cambia con un fundido y el texto en sitio). Deshabilitado
                  // no recibe el toque: así tampoco se hunde.
                  IgnorePointer(
                    ignoring: guardando || !cambios,
                    child: PresionEscala(
                      escala: AppMovimiento.escalaPresionChica,
                      child: GestureDetector(
                        onTap: (guardando || !cambios) ? null : _guardar,
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: colorGuardar),
                          duration: AppMovimiento.duracion(
                              context, AppMovimiento.corta),
                          builder: (context, color, _) => CambioAnimado(
                            alineacion: AlignmentDirectional.centerEnd,
                            child: Text(
                              guardando ? 'Guardando...' : 'Guardar',
                              key: ValueKey<bool>(guardando),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: color),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 16 + 12 de margen interno = los 28 de siempre: el avatar queda
            // donde estaba y el anillo del guardado (crece 9 dp por fuera del
            // avatar) cabe dentro del recorte del scroll.
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── AVATAR (iniciales) ────────────────────
                      // Las iniciales cambian con un pop mientras se
                      // escribe; al guardar, un anillo dorado se abre.
                      EntradaSuave(
                        retraso: retraso,
                        escalaInicial: 0.9,
                        child: Center(
                          child: _AnilloGuardado(
                            guardados: _guardados,
                            child: Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.pierDorado, width: 2),
                              ),
                              child: _buildAvatarIniciales(_vm.iniciales),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      EntradaSuave(
                        retraso: retraso,
                        child: Center(
                          child: Text(email,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── NOMBRE ────────────────────────────────
                      EntradaSuave(
                        orden: 1,
                        retraso: retraso,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── APELLIDO ──────────────────────────────
                      EntradaSuave(
                        orden: 2,
                        retraso: retraso,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Apellido'),
                            const SizedBox(height: 8),
                            _field(
                              controller: _apellidoCtrl,
                              hint: 'Reyes',
                              icon: LucideIcons.user,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── TELÉFONO ──────────────────────────────
                      EntradaSuave(
                        orden: 3,
                        retraso: retraso,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Teléfono'),
                            const SizedBox(height: 8),
                            _field(
                              controller: _telefonoCtrl,
                              hint: '7711234567',
                              icon: LucideIcons.smartphone,
                              keyboardType: TextInputType.phone,
                              validator: Validators.telefonoOpcional,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── EMAIL (solo lectura) ───────────────────
                      EntradaSuave(
                        orden: 4,
                        retraso: retraso,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary)),
                                ),
                                Icon(LucideIcons.lock,
                                    color: AppColors.textSecondary.withValues(alpha: 0.5), size: 16),
                              ]),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                  'El correo no puede ser modificado.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── BOTÓN GUARDAR ─────────────────────────
                      // Un solo ElevatedButton: el ícono y el texto cambian
                      // dentro de él.
                      EntradaSuave(
                        orden: 5,
                        retraso: retraso,
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed:
                                (guardando || !cambios) ? null : _guardar,
                            icon: CambioAnimado(
                              tipo: TipoCambio.escalar,
                              alineacion: Alignment.center,
                              child: guardando
                                  ? const SizedBox(
                                      key: ValueKey<String>('guardando'),
                                      height: 18, width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(LucideIcons.save,
                                      key: ValueKey<String>('guardar'),
                                      color: Colors.white, size: 18),
                            ),
                            label: CambioAnimado(
                              alineacion: Alignment.center,
                              child: Text(
                                  guardando
                                      ? 'Guardando...'
                                      : 'Guardar cambios',
                                  key: ValueKey<bool>(guardando),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
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
                      ),

                      const SizedBox(height: 20),
                      const EntradaSuave(
                        orden: 5,
                        retraso: retraso,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.award,
                                  color: AppColors.textSecondary, size: 14),
                              SizedBox(width: 5),
                              Text('Cliente Distinguido Pier',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
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

  // Las iniciales nuevas entran con un pop (las de antes se apagan).
  Widget _buildAvatarIniciales(String iniciales) => Center(
        child: CambioAnimado(
          tipo: TipoCambio.escalar,
          alineacion: Alignment.center,
          child: Text(
            iniciales,
            key: ValueKey<String>(iniciales),
            style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
        ),
      );
}

/// Anillo dorado que se abre y se apaga alrededor del avatar cada vez que
/// cambia [guardados] (un guardado exitoso). Solo pinta, una vez por
/// guardado; con movimiento reducido no aparece.
class _AnilloGuardado extends StatefulWidget {
  const _AnilloGuardado({required this.guardados, required this.child});

  final int guardados;
  final Widget child;

  @override
  State<_AnilloGuardado> createState() => _AnilloGuardadoState();
}

class _AnilloGuardadoState extends State<_AnilloGuardado>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _escala = Tween<double>(
    begin: 1,
    end: 1.18,
  ).chain(CurveTween(curve: AppMovimiento.curvaEntrada));
  static final Animatable<double> _opacidad = Tween<double>(
    begin: 0.9,
    end: 0,
  ).chain(CurveTween(curve: Curves.easeIn));

  // En reposo vale 1: el anillo ya se abrió y es invisible.
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: AppMovimiento.relleno,
    value: 1,
  );

  @override
  void didUpdateWidget(_AnilloGuardado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.guardados != oldWidget.guardados &&
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
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _control.drive(_opacidad),
              child: ScaleTransition(
                scale: _control.drive(_escala),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.pierDorado, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
