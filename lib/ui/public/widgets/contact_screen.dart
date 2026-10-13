// lib/ui/public/widgets/contact_screen.dart
//
// Movimiento: el formulario entra por grupos después del push; un campo
// que no pasa la validación se sacude; el botón cambia de ícono y de texto
// en sitio mientras envía; el diálogo de éxito se abre como caja con la
// insignia (halo, disco y palomita) y el texto en cascada.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/public/view_model/contact_view_model.dart';
import 'package:pier_pasteleria/ui/public/widgets/movimiento_contenido.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const ContactScreen({super.key, this.viewModel});

  final ContactViewModel? viewModel;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nombreCtrl  = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();

  // Para saber qué campo no pasó la validación y sacudir solo ese.
  final _nombreKey = GlobalKey<FormFieldState<String>>();
  final _emailKey = GlobalKey<FormFieldState<String>>();
  final _mensajeKey = GlobalKey<FormFieldState<String>>();
  final _sacudirNombre = ValueNotifier<int>(0);
  final _sacudirEmail = ValueNotifier<int>(0);
  final _sacudirMensaje = ValueNotifier<int>(0);

  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final ContactViewModel _vm = widget.viewModel ??
      ContactViewModel(
        configRepo: context.read<ConfiguracionRepository>(),
        cuentaRepo: context.read<CuentaRepository>(),
      );

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        _nombreCtrl.text =
            '${user['nombre'] ?? ''} ${user['apellido'] ?? ''}'.trim();
        _emailCtrl.text = user['email'] ?? '';
      }
    });
  }

  Future<void> _abrirWhatsApp() async {
    final numero = _vm.numeroWhatsApp;
    final uri = Uri.parse(
        'https://wa.me/$numero?text=${Uri.encodeComponent('Hola, tengo una pregunta')}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo abrir WhatsApp'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _mensajeCtrl.dispose();
    _sacudirNombre.dispose();
    _sacudirEmail.dispose();
    _sacudirMensaje.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// Sacude los campos que quedaron con error (los textos de error son los
  /// de siempre).
  void _sacudirInvalidos() {
    for (final (campo, aviso) in [
      (_nombreKey, _sacudirNombre),
      (_emailKey, _sacudirEmail),
      (_mensajeKey, _sacudirMensaje),
    ]) {
      if (campo.currentState?.hasError ?? false) aviso.value++;
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) {
      _sacudirInvalidos();
      return;
    }
    final enviado = await _vm.enviar(
      nombre: _nombreCtrl.text,
      email: _emailCtrl.text,
      telefono: _telefonoCtrl.text,
      conSesion: context.read<AuthProvider>().isAuthenticated,
    );
    if (!mounted) return;

    if (enviado) {
      _mensajeCtrl.clear();
      _telefonoCtrl.clear();
      _showSuccessDialog();
    } else if (_vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_vm.error!),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  void _showSuccessDialog() {
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      // Se abre como caja (fundido corto + EntradaDialogo); la insignia cae
      // y el texto sube detrás de ella.
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (dialogContext) {
        final espera = esperaDePagina(dialogContext);
        return EntradaDialogo(
          child: Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: InsigniaExito()),
                  const SizedBox(height: 24),
                  EntradaSuave(
                    retraso: espera,
                    child: const Text('¡Mensaje enviado!',
                        style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(height: 10),
                  EntradaSuave(
                    orden: 1,
                    retraso: espera,
                    child: const Text(
                      'Gracias por contactarnos. Te responderemos a la brevedad en tu correo electrónico.',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  EntradaSuave(
                    orden: 2,
                    retraso: espera,
                    child: Row(children: [
                      Expanded(
                          child: Divider(
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(LucideIcons.store,
                            size: 18,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.4)),
                      ),
                      Expanded(
                          child: Divider(
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.2))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  EntradaSuave(
                    orden: 3,
                    retraso: espera,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pierVerde,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50)),
                          elevation: 0,
                        ),
                        child: const Text('Entendido',
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
          ),
        );
      },
    ));
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
    final isAuth = Provider.of<AuthProvider>(context).isAuthenticated;
    final enviando = _vm.enviando;
    // El formulario entra por grupos después de que llega la página (se lee
    // al montarse: escribir no lo repite).
    final espera = esperaDePagina(context);

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
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Icon(LucideIcons.chevronLeft,
                            size: 16, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('Contacto',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── INFO ────────────────────────────────────
                      EntradaSuave(
                        retraso: espera,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.pierVerde.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.pierVerde
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                  LucideIcons.messageCircle,
                                  color: AppColors.pierVerde, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Estamos aquí para ayudarte. Responderemos en un plazo de 24–48 horas hábiles.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.pierVerdeOscuro,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Los campos entran de dos en dos (nunca uno por uno).
                      EntradaSuave(
                        orden: 1,
                        retraso: espera,
                        child: _label('Nombre completo'),
                      ),
                      const SizedBox(height: 8),
                      EntradaSuave(
                        orden: 1,
                        retraso: espera,
                        child: SacudidaConAviso(
                          aviso: _sacudirNombre,
                          child: _inputField(
                            campo: _nombreKey,
                            controller: _nombreCtrl,
                            hint: 'Tu nombre',
                            readOnly: isAuth,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa tu nombre'
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      EntradaSuave(
                        orden: 1,
                        retraso: espera,
                        child: _label('Correo electrónico'),
                      ),
                      const SizedBox(height: 8),
                      EntradaSuave(
                        orden: 1,
                        retraso: espera,
                        child: SacudidaConAviso(
                          aviso: _sacudirEmail,
                          child: _inputField(
                            campo: _emailKey,
                            controller: _emailCtrl,
                            hint: 'tu@correo.com',
                            keyboardType: TextInputType.emailAddress,
                            readOnly: isAuth,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa tu correo';
                              }
                              if (!v.contains('@')) return 'Correo inválido';
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      EntradaSuave(
                        orden: 2,
                        retraso: espera,
                        child: _label('Teléfono (opcional)'),
                      ),
                      const SizedBox(height: 8),
                      EntradaSuave(
                        orden: 2,
                        retraso: espera,
                        child: _inputField(
                          controller: _telefonoCtrl,
                          hint: '771 000 0000',
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(height: 16),

                      EntradaSuave(
                        orden: 2,
                        retraso: espera,
                        child: _label('Asunto'),
                      ),
                      const SizedBox(height: 8),
                      EntradaSuave(
                        orden: 2,
                        retraso: espera,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16)),
                              initialValue: _vm.tipoProducto,
                              icon: Icon(
                                  LucideIcons.chevronDown,
                                  color: AppColors.pierVerde),
                              items: ContactViewModel.tiposProducto
                                  .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t,
                                          style: const TextStyle(
                                              fontSize: 14))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) _vm.elegirTipo(val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      EntradaSuave(
                        orden: 3,
                        retraso: espera,
                        child: _label('Mensaje'),
                      ),
                      const SizedBox(height: 8),
                      EntradaSuave(
                        orden: 3,
                        retraso: espera,
                        child: SacudidaConAviso(
                          aviso: _sacudirMensaje,
                          child: _campoMensaje(),
                        ),
                      ),
                      const SizedBox(height: 28),

                      EntradaSuave(
                        orden: 4,
                        retraso: espera,
                        child: _botonEnviar(enviando: enviando),
                      ),

                      // ── OTROS MEDIOS ──────────────────────────────
                      // ✅ ACTUALIZADO: datos cargados del backend
                      const SizedBox(height: 32),
                      EntradaSuave(
                        orden: 5,
                        retraso: espera,
                        child: Divider(
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.2)),
                      ),
                      const SizedBox(height: 20),
                      EntradaSuave(
                        orden: 5,
                        retraso: espera,
                        child: const Text('Otros medios',
                            style: TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                      ),
                      const SizedBox(height: 14),
                      EntradaSuave(
                        orden: 6,
                        retraso: espera,
                        child: _contactTile(
                            LucideIcons.phone, _vm.telefono, 'Llámanos'),
                      ),
                      const SizedBox(height: 10),
                      EntradaSuave(
                        orden: 6,
                        retraso: espera,
                        child: _contactTile(LucideIcons.mail,
                            _vm.email, 'Escríbenos'),
                      ),
                      const SizedBox(height: 10),
                      EntradaSuave(
                        orden: 6,
                        retraso: espera,
                        child: _contactTile(LucideIcons.clock,
                            _vm.horario, 'Horario de atención'),
                      ),
                      const SizedBox(height: 16),

                      // WhatsApp
                      EntradaSuave(
                        orden: 6,
                        retraso: espera,
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _abrirWhatsApp,
                            icon: const Icon(LucideIcons.messageSquare,
                                color: Colors.white, size: 18),
                            label: const Text(
                              'Escríbenos por WhatsApp',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
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

  /// El mensaje, con su contador «N / mín. 20».
  Widget _campoMensaje() {
    return TextFormField(
      key: _mensajeKey,
      controller: _mensajeCtrl,
      maxLines: 5,
      onChanged: _vm.editarMensaje,
      decoration: InputDecoration(
        hintText:
            'Describe tu consulta o queja con detalle...',
        hintStyle: TextStyle(
            color: AppColors.textSecondary
                .withValues(alpha: 0.6),
            fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.textSecondary
                    .withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.pierVerde,
                width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.error)),
        contentPadding: const EdgeInsets.all(14),
        suffixText:
            '${_vm.largoMensaje} / mín. ${ContactViewModel.minimoMensaje}',
        suffixStyle: TextStyle(
            fontSize: 11,
            color: _vm.mensajeValido
                ? AppColors.pierVerde
                : AppColors.textSecondary
                    .withValues(alpha: 0.6)),
      ),
      validator: (v) =>
          (v == null ||
                  v.trim().length <
                      ContactViewModel.minimoMensaje)
              ? 'Mínimo 20 caracteres'
              : null,
    );
  }

  /// «Enviar Mensaje» ↔ «Enviando...»: el ícono cambia con un pop y el texto
  /// con un fundido, dentro del mismo botón.
  Widget _botonEnviar({required bool enviando}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: enviando ? null : _enviar,
        icon: CambioAnimado(
          tipo: TipoCambio.escalar,
          alineacion: Alignment.center,
          child: enviando
              ? const SizedBox(
                  key: ValueKey('enviando'),
                  height: 18, width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
              : const Icon(LucideIcons.send,
                  key: ValueKey('enviar'),
                  color: Colors.white, size: 18),
        ),
        // El ancho del texto cambia con suavidad: el ícono no salta.
        label: TamanoSuave(
          alineacion: Alignment.center,
          child: CambioAnimado(
            alineacion: Alignment.center,
            child: Text(
                enviando ? 'Enviando...' : 'Enviar Mensaje',
                key: ValueKey(enviando),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pierVerde,
          disabledBackgroundColor:
              AppColors.pierVerde.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    GlobalKey<FormFieldState<String>>? campo,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: campo,
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.6),
            fontSize: 14),
        filled: true,
        fillColor: readOnly ? AppColors.pierArena : Colors.white,
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

  Widget _contactTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.pierVerde.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.pierVerde, size: 18),
        ),
        const SizedBox(width: 12),
        // Expanded: el horario del panel puede ser largo o traer una línea
        // por sucursal; sin límite de ancho se salía del recuadro.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ]),
    );
  }
}
