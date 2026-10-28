// lib/ui/more/widgets/mis_datos_screen.dart
//
// «Mis datos» (derechos ARCO, #221): muestra lo que el servidor tiene de la
// cuenta (GET /auth/profile) y lleva a corregirlo en «Editar perfil». Para
// borrar la cuenta u oponerse al uso de los datos, el aviso de privacidad
// pide escribir al correo de Pier.
// MVVM: el estado vive en MisDatosViewModel; esta vista solo lo pinta.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/auth_repository.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/more/view_model/mis_datos_view_model.dart';
import 'package:pier_reposteria/ui/more/widgets/edit_profile_screen.dart';
import 'package:provider/provider.dart';

class MisDatosScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const MisDatosScreen({super.key, this.viewModel});

  final MisDatosViewModel? viewModel;

  static const explicacion =
      'Estos son los datos de tu cuenta que guarda Pier. Puedes corregir tu '
      'nombre y tu teléfono en «Editar perfil».';

  static const otrosDerechos =
      'Para pedir que se borren tus datos o para oponerte a su uso, escribe a '
      '${BusinessInfo.email}.';

  @override
  State<MisDatosScreen> createState() => _MisDatosScreenState();
}

class _MisDatosScreenState extends State<MisDatosScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final MisDatosViewModel _vm = widget.viewModel ??
      MisDatosViewModel(repo: context.read<AuthRepository>());

  @override
  void initState() {
    super.initState();
    _vm.cargar();
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
      return const Center(
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
      ],
    );
  }
}
