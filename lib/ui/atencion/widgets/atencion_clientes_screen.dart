// lib/ui/atencion/widgets/atencion_clientes_screen.dart
//
// «Atención a clientes» (#138): empleado, gerencia y dirección atienden
// desde el teléfono las quejas, las solicitudes de reembolso y las reseñas
// de los clientes, en tres pestañas como la página de la web
// (src/Empleado/paginas/GestionQuejas.tsx, GestionReembolsos.tsx y
// GestionResenas.tsx). Cada pestaña tiene su ViewModel, carga lo suyo la
// primera vez que se abre y lo conserva mientras la pantalla siga abierta.
// Se abre desde la agenda de comandas.
import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/atencion/widgets/quejas_personal_tab.dart';
import 'package:pier_reposteria/ui/atencion/widgets/reembolsos_personal_tab.dart';
import 'package:pier_reposteria/ui/atencion/widgets/resenas_personal_tab.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

class AtencionClientesScreen extends StatelessWidget {
  const AtencionClientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.pierArena,
        appBar: AppBar(
          backgroundColor: AppColors.pierVerde,
          foregroundColor: Colors.white,
          title: const Text('Atención a clientes'),
          bottom: TabBar(
            // Con letra grande las pestañas se recorren en vez de cortarse.
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
            indicatorColor: Colors.white,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Quejas'),
              Tab(text: 'Reembolsos'),
              Tab(text: 'Reseñas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            QuejasPersonalTab(),
            ReembolsosPersonalTab(),
            ResenasPersonalTab(),
          ],
        ),
      ),
    );
  }
}
