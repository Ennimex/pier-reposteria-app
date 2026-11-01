// lib/ui/actividad/widgets/actividad_equipo_screen.dart
//
// «Actividad del equipo» (#139): gerencia y dirección supervisan desde el
// teléfono, en solo lectura, qué hace su equipo (pestaña «Equipo»: las
// cifras de 30 días, el último acceso y la actividad de cada persona, las
// zonas con más entregas y los últimos movimientos) y quién cambió qué y
// cuándo en la bitácora, con sus filtros (pestaña «Bitácora»), como
// ActividadEquipo.tsx y Bitacora.tsx de la web. A gerencia el servidor ya
// le quita las operaciones técnicas. Cada pestaña tiene su ViewModel, carga
// lo suyo la primera vez que se abre y lo conserva mientras la pantalla
// siga abierta. Se abre desde la agenda de comandas.
import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/actividad/view_model/actividad_equipo_view_model.dart';
import 'package:pier_reposteria/ui/actividad/view_model/bitacora_view_model.dart';
import 'package:pier_reposteria/ui/actividad/widgets/bitacora_tab.dart';
import 'package:pier_reposteria/ui/actividad/widgets/equipo_tab.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

class ActividadEquipoScreen extends StatelessWidget {
  /// [equipo] y [bitacora] solo se pasan en pruebas (con el reloj fijo); en
  /// la app cada pestaña crea el suyo.
  const ActividadEquipoScreen({super.key, this.equipo, this.bitacora});

  final ActividadEquipoViewModel? equipo;
  final BitacoraViewModel? bitacora;

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.pierArena,
        appBar: AppBar(
          backgroundColor: AppColors.pierVerde,
          foregroundColor: Colors.white,
          title: const Text('Actividad del equipo'),
          bottom: TabBar(
            // Con letra grande las pestañas se recorren en vez de cortarse.
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
            indicatorColor: Colors.white,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Equipo'),
              Tab(text: 'Bitácora'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            EquipoTab(viewModel: equipo),
            BitacoraTab(viewModel: bitacora),
          ],
        ),
      ),
    );
  }
}
