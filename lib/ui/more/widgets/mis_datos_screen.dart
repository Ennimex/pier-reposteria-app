// lib/ui/more/widgets/mis_datos_screen.dart
//
// «Mis datos» (derechos ARCO, #221): muestra lo que el servidor tiene de la
// cuenta (GET /auth/profile) y lleva a corregirlo en «Editar perfil».
// «Eliminar mi cuenta» (#222) la da de baja en ese momento (DELETE
// /usuarios/perfil): cierra la sesión en el teléfono y vuelve al Inicio. Si
// falla la red o el servidor, ofrece pedir la baja por correo a Pier.
// MVVM: el estado vive en MisDatosViewModel; esta vista solo lo pinta.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/auth_repository.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/state/notification_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/more/view_model/mis_datos_view_model.dart';
import 'package:pier_reposteria/ui/more/widgets/edit_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MisDatosScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const MisDatosScreen({super.key, this.viewModel});

  final MisDatosViewModel? viewModel;

  static const explicacion =
      'Estos son los datos de tu cuenta que guarda Pier. Puedes corregir tu '
      'nombre y tu teléfono en «Editar perfil».';

  static const otrosDerechos =
      'Para oponerte al uso de tus datos, escribe a ${BusinessInfo.email}. '
      'Si eliminas tu cuenta, tus datos se borran en ese momento.';

  static const confirmarBaja =
      'Tu cuenta se elimina en este momento y no se puede deshacer: ya no '
      'podrás entrar con ella.';

  /// Qué se borra y qué se conserva, como en la página de la web
  /// /eliminar-cuenta.
  static const queSeBorra =
      'Se borran tu nombre, correo, teléfono, direcciones, favoritos y '
      'carrito. Tus pedidos y pagos se conservan sin tus datos, y tus '
      'reseñas quedan sin tu nombre ni tus fotos.';

  static const eliminando = 'Eliminando tu cuenta…';

  static const cuentaEliminada = 'Tu cuenta se eliminó';

  static const respaldoCorreo =
      'También puedes pedir la baja por correo a Pier.';

  static const sinAppDeCorreo =
      'No encontramos una app de correo. Escribe a ${BusinessInfo.email} '
      'para pedir que se elimine tu cuenta.';

  @override
  State<MisDatosScreen> createState() => _MisDatosScreenState();
}

class _MisDatosScreenState extends State<MisDatosScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final MisDatosViewModel _vm = widget.viewModel ??
      MisDatosViewModel(
        repo: context.read<AuthRepository>(),
        cuenta: context.read<CuentaRepository>(),
      );

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _corregir() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (mounted) await _vm.cargar();
  }

  /// «Eliminar mi cuenta» (#222): pide confirmar y la da de baja en ese
  /// momento. Si se eliminó, la sesión se cierra en el teléfono y el cliente
  /// vuelve al Inicio; si no, ve por qué y, si falló la red o el servidor,
  /// puede pedir la baja por correo.
  Future<void> _eliminarCuenta() async {
    final confirmado = await _dialogo(
      titulo: '¿Eliminar tu cuenta?',
      texto: '${MisDatosScreen.confirmarBaja}\n\n${MisDatosScreen.queSeBorra}',
      cerrar: 'Cancelar',
      aceptar: 'Eliminar mi cuenta',
      colorAceptar: AppColors.error,
    );
    if (!confirmado || !mounted) return;
    // Se toman antes de esperar: si la cuenta se elimina, esta pantalla se
    // cierra y su context deja de servir.
    final auth = context.read<AuthProvider>();
    final carrito = context.read<CartProvider>();
    final notificaciones = context.read<NotificationProvider>();
    final pestanas = context.read<NavigationProvider>();
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    final resultado =
        await _vm.eliminarCuenta(cerrarSesion: auth.cerrarSesionLocal);
    switch (resultado) {
      case ResultadoBaja.eliminada:
        // Lo que quedaba en memoria de la cuenta se limpia como al cerrar
        // sesión en «Más»; luego, al Inicio.
        carrito.limpiarLocal();
        notificaciones.stopPolling();
        pestanas.goToHome();
        navegador.popUntil((ruta) => ruta.isFirst);
        mensajero.showSnackBar(
            const SnackBar(content: Text(MisDatosScreen.cuentaEliminada)));
      case ResultadoBaja.pedidosEnCurso || ResultadoBaja.personal:
        if (mounted) await _noSeElimino(ofrecerCorreo: false);
      case ResultadoBaja.error:
        if (mounted) await _noSeElimino(ofrecerCorreo: true);
      case ResultadoBaja.ocupado || ResultadoBaja.sesionVencida:
      // Doble toque, o la app ya cerró la sesión y avisó que expiró.
    }
  }

  /// Por qué no se eliminó la cuenta, con el mensaje del backend. Si falló
  /// la red o el servidor, ofrece pedir la baja por correo.
  Future<void> _noSeElimino({required bool ofrecerCorreo}) async {
    final aviso = _vm.avisoBaja ?? '';
    final escribir = await _dialogo(
      titulo: 'No se eliminó tu cuenta',
      texto: ofrecerCorreo ? '$aviso\n\n${MisDatosScreen.respaldoCorreo}' : aviso,
      cerrar: ofrecerCorreo ? 'Cerrar' : 'Entendido',
      aceptar: ofrecerCorreo ? 'Pedirlo por correo' : null,
      colorAceptar: AppColors.pierVerde,
    );
    if (escribir && mounted) await _pedirPorCorreo();
  }

  /// Abre el correo a Pier ya escrito; si el teléfono no tiene app de
  /// correo, dice a dónde escribir.
  Future<void> _pedirPorCorreo() async {
    bool abierto;
    try {
      abierto = await launchUrl(_vm.correoParaEliminarCuenta);
    } on Exception {
      abierto = false;
    }
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(MisDatosScreen.sinAppDeCorreo)));
    }
  }

  /// Diálogo de la baja: [cerrar] y, si se da, [aceptar]. Devuelve true si
  /// se tocó [aceptar].
  Future<bool> _dialogo({
    required String titulo,
    required String texto,
    required String cerrar,
    required Color colorAceptar,
    String? aceptar,
  }) async {
    final aceptado = await showDialog<bool>(
      context: context,
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (dialogContext) => EntradaDialogo(
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(titulo,
              style: const TextStyle(
                  fontFamily: 'Playfair Display', fontWeight: FontWeight.bold)),
          content: Text(texto),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cerrar,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            if (aceptar != null)
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(backgroundColor: colorAceptar),
                child: Text(aceptar),
              ),
          ],
        ),
      ),
    );
    return aceptado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(title: const Text('Mis datos')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _contenido(),
      ),
    );
  }

  Widget _contenido() {
    if (_vm.cargando) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.pierVerde));
    }
    final error = _vm.error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(onPressed: _vm.cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    const retraso = AppMovimiento.trasEmpuje;
    final eliminando = _vm.eliminando;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(MisDatosScreen.explicacion,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 16),
        EntradaSuave(
          retraso: retraso,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (final dato in _vm.datos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(dato.etiqueta,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(dato.valor,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _corregir,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.pierVerde,
              minimumSize: const Size.fromHeight(48)),
          icon: const Icon(LucideIcons.pencil, size: 18),
          label: const Text('Corregir mis datos'),
        ),
        const SizedBox(height: 16),
        const Text(MisDatosScreen.otrosDerechos,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        // Mientras se da de baja, el botón dice que trabaja y no responde.
        OutlinedButton.icon(
          onPressed: eliminando ? null : _eliminarCuenta,
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(48)),
          icon: eliminando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.error))
              : const Icon(LucideIcons.trash2, size: 18),
          label: Text(
              eliminando ? MisDatosScreen.eliminando : 'Eliminar mi cuenta'),
        ),
      ],
    );
  }
}
