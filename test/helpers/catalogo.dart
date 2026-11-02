// test/helpers/catalogo.dart — lo que comparten las pruebas del catálogo
// (#37): un GET /productos que busca por nombre, las peticiones de productos
// que hizo la app y, en pantalla, el celular, la lista (cuánto se ha bajado,
// los nombres de sus tarjetas, bajar al final) y desmontarla.
//
//   final api = FakeApiClient(respuestas: {
//     ApiConstants.productos: productosQueCoinciden(catalogo),
//   });
//   expect(pedidasDelCatalogo(api), ['/productos?limite=20&offset=0']);
//   tester.usarCelular(alto: 3000);
//   expect(tester.bajadoEnElCatalogo, 0);
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/products/widgets/producto_catalogo_card.dart';

import '../fakes/fake_api_client.dart';

/// GET /productos como el servidor: los de [catalogo] cuyo nombre tiene la
/// `busqueda` (sin ella, todos), sin páginas.
RespuestaDinamica productosQueCoinciden(
  List<Map<String, dynamic>> catalogo,
) =>
    (llamada) {
      final busqueda =
          Uri.parse(llamada.endpoint).queryParameters['busqueda'] ?? '';
      return {
        'success': true,
        'productos': [
          for (final p in catalogo)
            if ((p['nombre'] as String)
                .toLowerCase()
                .contains(busqueda.toLowerCase()))
              p,
        ],
      };
    };

/// Las peticiones de productos del catálogo, en orden: las que llevan
/// parámetros (la lista completa que pide el Inicio no los lleva).
List<String> pedidasDelCatalogo(FakeApiClient api) => [
      for (final l in api.llamadas)
        if (l.endpoint.startsWith('${ApiConstants.productos}?')) l.endpoint,
    ];

/// Los parámetros de cada una de [pedidasDelCatalogo], en orden.
List<Map<String, String>> parametrosDelCatalogo(FakeApiClient api) => [
      for (final pedida in pedidasDelCatalogo(api))
        Uri.parse(pedida).queryParameters,
    ];

/// La lista del catálogo.
final Finder listaDelCatalogo = find.byType(CustomScrollView);

/// Lo que se desplaza en [listaDelCatalogo].
final Finder desplazableDelCatalogo =
    find.descendant(of: listaDelCatalogo, matching: find.byType(Scrollable));

extension CatalogoEnPantalla on WidgetTester {
  /// Un celular de 540 de ancho y [alto] px (vuelve a su tamaño al terminar
  /// la prueba): uno alto deja ver (y construir) más de la lista sin bajar.
  void usarCelular({double alto = 1200}) {
    view
      ..physicalSize = Size(540, alto)
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
  }

  /// Cuánto se ha bajado la lista del catálogo.
  double get bajadoEnElCatalogo =>
      state<ScrollableState>(desplazableDelCatalogo).position.pixels;

  /// Los nombres de las tarjetas que la lista tiene construidas, de arriba
  /// abajo: con un celular alto, toda la lista.
  List<String> get nombresEnElCatalogo => [
        for (final tarjeta in widgetList<ProductoCatalogoCard>(
          find.byType(ProductoCatalogoCard),
        ))
          tarjeta.producto.nombre,
      ];

  /// Baja hasta el final de lo que hay cargado.
  Future<void> bajarAlFinalDelCatalogo() async {
    await drag(listaDelCatalogo, const Offset(0, -20000));
    await pump();
  }

  /// Desmonta el catálogo para cancelar lo que deje esperando (el registro
  /// de una búsqueda).
  Future<void> desmontarCatalogo() async {
    await pumpWidget(const SizedBox());
    await pump(const Duration(seconds: 2));
  }
}
