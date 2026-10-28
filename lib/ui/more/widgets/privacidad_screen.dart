// lib/ui/more/widgets/privacidad_screen.dart
//
// «Privacidad» (derecho de oposición, #223): el cliente decide si se mandan
// diagnósticos y si se registran sus búsquedas. No pide sesión: aplica a
// quien use la app en este teléfono.
// MVVM: el estado vive en PrivacidadViewModel; esta vista solo lo pinta.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/more/view_model/privacidad_view_model.dart';
import 'package:pier_reposteria/ui/public/widgets/legal_screen.dart';
import 'package:provider/provider.dart';

class PrivacidadScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const PrivacidadScreen({super.key, this.viewModel});

  final PrivacidadViewModel? viewModel;

  static const diagnosticos = 'Enviar diagnósticos';
  static const diagnosticosDetalle =
      'Si la app falla, manda el error y la pantalla donde ocurrió para '
      'corregirlo. Al apagarlo deja de mandarse desde ese momento.';
  static const busquedas = 'Registrar mis búsquedas';
  static const busquedasDetalle =
      'Lo que buscas y no encuentras ayuda a decidir qué preparar. '
      '«Avísame» se registra solo cuando tú lo tocas.';

  @override
  State<PrivacidadScreen> createState() => _PrivacidadScreenState();
}

class _PrivacidadScreenState extends State<PrivacidadScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final PrivacidadViewModel _vm =
      widget.viewModel ?? PrivacidadViewModel();

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

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(title: const Text('Privacidad')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _vm.cargando
            ? Center(
                child: CircularProgressIndicator(color: AppColors.pierVerde))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Material y no un Container con color: el interruptor
                  // pinta su fondo y su onda sobre el Material más cercano.
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _vm.enviaDiagnosticos,
                          onChanged: (v) =>
                              unawaited(_vm.cambiarDiagnosticos(envia: v)),
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.pierVerde,
                          title: const Text(PrivacidadScreen.diagnosticos),
                          subtitle:
                              const Text(PrivacidadScreen.diagnosticosDetalle),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _vm.registraBusquedas,
                          onChanged: (v) =>
                              unawaited(_vm.cambiarBusquedas(registra: v)),
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.pierVerde,
                          title: const Text(PrivacidadScreen.busquedas),
                          subtitle:
                              const Text(PrivacidadScreen.busquedasDetalle),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          // Abre en la pestaña del Aviso de Privacidad.
                          builder: (_) => const LegalScreen()),
                    ),
                    child: const Text('Leer el Aviso de Privacidad'),
                  ),
                ],
              ),
      ),
    );
  }
}
