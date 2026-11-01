// lib/ui/products/widgets/pie_catalogo.dart
//
// Pie del catálogo (#37), abajo de la última tarjeta: un indicador mientras
// llega la siguiente página o, si no pudo llegar, el aviso con «Reintentar».
// El indicador también sale mientras llega la página 1 con algo ya en
// pantalla (la copia guardada en el teléfono, #265, o al jalar para
// refrescar): quien baja al final ve que viene más. Las piezas son las del
// pie del feed (CargandoMas y AvisoDeLista, #283). Se repinta solo cuando
// cambia el ViewModel.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/ui/pie_de_lista.dart';
import 'package:pier_reposteria/ui/products/view_model/products_view_model.dart';

class PieCatalogo extends StatelessWidget {
  const PieCatalogo({required this.viewModel, super.key});

  final ProductsViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.cargandoMas ||
              (viewModel.cargando && viewModel.productos.isNotEmpty)) {
            return const CargandoMas(etiqueta: 'Cargando más productos');
          }
          final error = viewModel.errorMas;
          if (error != null) {
            return AvisoDeLista.noCargaronMas(
              detalle: error,
              alReintentar: () => unawaited(viewModel.cargarMas()),
            );
          }
          return const SizedBox(height: 24);
        },
      );
}
