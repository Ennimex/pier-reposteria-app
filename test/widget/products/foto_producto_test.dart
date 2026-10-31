// test/widget/products/foto_producto_test.dart — las fotos de las tarjetas de
// producto (#267): la del catálogo (cuadrícula y lista), la del Inicio, la de
// Favoritos y la del Perfil piden la foto reducida de Cloudinary
// (proveedorDeFoto anota lo que se pide, sin red ni disco). La tarjeta, el
// vuelo al detalle y la foto de abajo de la galería comparten la misma entrada
// de caché; las fotos del carrusel del detalle siguen completas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/domain/models/promociones_inicio.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/core/ui/foto_producto.dart';
import 'package:pier_reposteria/ui/core/ui/tarjeta_producto_angosta.dart';
import 'package:pier_reposteria/ui/favorites/view_model/favorites_view_model.dart';
import 'package:pier_reposteria/ui/favorites/widgets/favorites_screen.dart';
import 'package:pier_reposteria/ui/home/widgets/home_promociones.dart';
import 'package:pier_reposteria/ui/more/view_model/profile_view_model.dart';
import 'package:pier_reposteria/ui/more/widgets/profile_screen.dart';
import 'package:pier_reposteria/ui/products/widgets/detalle_galeria.dart';
import 'package:pier_reposteria/ui/products/widgets/producto_catalogo_card.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

const _original = 'https://res.cloudinary.com/pier/image/upload/v1/rosca.jpg';
const _reducida =
    'https://res.cloudinary.com/pier/image/upload/'
    'w_600,c_limit,q_auto,f_auto/v1/rosca.jpg';
const _otraOriginal = 'https://res.cloudinary.com/pier/image/upload/v1/pay.jpg';

Product _producto({String imagen = _original}) => Product(
  id: '1',
  nombre: 'Rosca',
  descripcion: 'Rica rosca',
  precio: 300,
  categoria: 'Pasteles',
  imagenUrl: imagen,
);

/// La tarjeta del catálogo de [producto] centrada, con el ProductProvider de
/// la app; al tocarla abre un detalle con su galería.
Widget _catalogo(Product producto, {bool enCuadricula = true}) => Scaffold(
  body: Center(
    child: Builder(
      builder: (context) {
        final promociones = context.read<ProductProvider>();
        return SizedBox(
          width: enCuadricula ? 180 : 360,
          height: enCuadricula ? 300 : 130,
          child: ProductoCatalogoCard(
            producto: producto,
            promociones: promociones,
            enCuadricula: enCuadricula,
            esFavorito: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: _galeria(producto, [producto.imagenUrl], promociones),
                ),
              ),
            ),
            onToggleFavorito: () {},
            onAgregar: (_) {},
          ),
        );
      },
    ),
  ),
);

DetalleGaleria _galeria(
  Product producto,
  List<String> imagenes,
  ProductProvider promociones,
) => DetalleGaleria(
  producto: producto,
  imagenes: imagenes,
  promociones: promociones,
  esFavorito: false,
  onFavorito: () {},
  onCompartir: () {},
);

/// Monta la galería de [producto] con [imagenes] y deja correr sus entradas.
Future<void> _montarGaleria(
  WidgetTester tester,
  Product producto,
  List<String> imagenes,
) async {
  await tester.pumpApp(
    Builder(
      builder: (context) => Scaffold(
        body: _galeria(producto, imagenes, context.read<ProductProvider>()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Los proveedores de las fotos de la galería, en el orden en que se pintan.
List<ImageProvider> _fotosDeLaGaleria(WidgetTester tester) => [
  for (final foto in tester.widgetList<Image>(
    find.descendant(
      of: find.byType(DetalleGaleria),
      matching: find.byType(Image),
    ),
  ))
    foto.image,
];

/// Una promoción de [tipo] del producto 1 con su foto.
Map<String, dynamic> _promo(String tipo) => {
  'tipo': tipo,
  'producto_id': 1,
  'producto_nombre': 'Rosca',
  'producto_imagen': _original,
  'precio_chico': 300,
  'descuento_porcentaje': 10,
  'nombre_temporada': 'Temporada de rosca',
};

/// Un favorito con foto de Cloudinary, como lo manda el backend.
Map<String, dynamic> _favorito() => {
  'id': 36,
  'nombre': 'Fresa Matcha Bliss',
  'categoria': 'Pasteles',
  'imagen_url': _original,
};

void main() {
  // Lo que las fotos pidieron a proveedorDeFoto desde el inicio de la prueba.
  late List<String> pedidas;

  setUp(() {
    pedidas = [];
    proveedorDeFoto = (url) {
      pedidas.add(url);
      return NetworkImage(url);
    };
  });

  /// Se pidió algo y solo fue la foto reducida.
  void esperarSoloLaReducida() {
    expect(pedidas, isNotEmpty);
    expect(pedidas, everyElement(_reducida));
  }

  group('fotoDeTarjeta', () {
    test('pide al proveedor la foto reducida', () {
      expect(fotoDeTarjeta(_original), const NetworkImage(_reducida));
      expect(pedidas, [_reducida]);
    });

    test('lo que no es de Cloudinary se pide como viene', () {
      fotoDeTarjeta('https://pier.mx/a.png');
      fotoDeTarjeta('');
      expect(pedidas, ['https://pier.mx/a.png', '']);
    });
  });

  group('tarjetas', () {
    testWidgets('la tarjeta del catálogo pide la foto reducida', (
      tester,
    ) async {
      await tester.pumpApp(_catalogo(_producto()));
      esperarSoloLaReducida();
    });

    testWidgets('la tarjeta del catálogo en lista pide la foto reducida', (
      tester,
    ) async {
      await tester.pumpApp(_catalogo(_producto(), enCuadricula: false));
      esperarSoloLaReducida();
    });

    for (final ambito in <String?>[null, 'recomendado-1']) {
      testWidgets(
        'la tarjeta angosta ${ambito == null ? 'sin' : 'con'} vuelo pide la '
        'foto reducida',
        (tester) async {
          await tester.pumpApp(
            Scaffold(
              body: Center(
                child: SizedBox(
                  height: 310,
                  child: TarjetaProductoAngosta(
                    producto: _producto(),
                    precio: 300,
                    boton: const SizedBox.shrink(),
                    ambitoFoto: ambito,
                  ),
                ),
              ),
            ),
          );
          esperarSoloLaReducida();
        },
      );
    }

    testWidgets('Favoritos pide la foto reducida', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.favoritos: {
            'success': true,
            'favoritos': [_favorito()],
          },
        },
      );
      tester.view
        ..physicalSize = const Size(1440, 3040)
        ..devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        FavoritesScreen(
          viewModel: FavoritesViewModel(
            favoritosRepo: FavoritosRepositoryRemote(api: api),
            productosRepo: ProductosRepositoryRemote(api: api),
            registrarInteres: (_) {},
          ),
        ),
        api: api,
      );
      await tester.pumpAndSettle();
      esperarSoloLaReducida();
    });

    testWidgets('los favoritos del Perfil piden la foto reducida', (
      tester,
    ) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.favoritos: {
            'success': true,
            'favoritos': [_favorito()],
          },
          ApiConstants.misPedidos: {'success': true, 'pedidos': <Object>[]},
        },
      );
      await tester.pumpApp(
        ProfileScreen(
          viewModel: ProfileViewModel(
            favoritosRepo: FavoritosRepositoryRemote(api: api),
            pedidosRepo: PedidosRepositoryRemote(api: api),
          ),
        ),
        api: api,
      );
      await tester.pump(const Duration(seconds: 1));
      esperarSoloLaReducida();
    });

    testWidgets('las ofertas de temporada y las destacadas del Inicio piden '
        'la foto reducida', (tester) async {
      final promociones = PromocionesInicio.fromLista([
        _promo('temporada'),
        _promo('destacado'),
      ]);
      await tester.pumpApp(
        Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                HomeOfertasTemporada(promociones: promociones),
                HomePromoDestacado(promociones: promociones),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      // Una foto por oferta.
      expect(pedidas, hasLength(2));
      esperarSoloLaReducida();
    });
  });

  group('detalle', () {
    testWidgets('la tarjeta, el vuelo y la foto de abajo de la galería '
        'comparten la misma entrada de caché', (tester) async {
      await tester.pumpApp(_catalogo(_producto()));
      final deLaTarjeta = tester.widget<Image>(find.byType(Image)).image;
      expect(deLaTarjeta, const NetworkImage(_reducida));

      await tester.tap(find.byType(ProductoCatalogoCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // A medio vuelo la tarjeta y la galería dejan su hueco: la única foto
      // es la del vuelo.
      expect(tester.widget<Image>(find.byType(Image)).image, deLaTarjeta);

      await tester.pumpAndSettle();
      // Abajo, la de la tarjeta (ya en caché); encima, la completa.
      expect(_fotosDeLaGaleria(tester), [
        deLaTarjeta,
        const NetworkImage(_original),
      ]);
    });

    testWidgets('la foto de abajo es la reducida de la tarjeta aunque la '
        'primera de la galería sea la misma dirección', (tester) async {
      await _montarGaleria(tester, _producto(), [_original]);
      expect(_fotosDeLaGaleria(tester), [
        const NetworkImage(_reducida),
        const NetworkImage(_original),
      ]);
    });

    testWidgets('si la primera foto de la galería es otra, debajo queda la '
        'de la tarjeta', (tester) async {
      await _montarGaleria(tester, _producto(), [_otraOriginal]);
      expect(_fotosDeLaGaleria(tester), [
        const NetworkImage(_reducida),
        const NetworkImage(_otraOriginal),
      ]);
    });

    testWidgets('sin foto en la tarjeta no hay nada debajo', (tester) async {
      await _montarGaleria(tester, _producto(imagen: ''), [_original]);
      expect(_fotosDeLaGaleria(tester), [const NetworkImage(_original)]);
      expect(pedidas, isEmpty);
    });

    testWidgets('las demás fotos del carrusel van completas y sin nada '
        'debajo', (tester) async {
      await _montarGaleria(tester, _producto(), [_original, _otraOriginal]);

      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
      await tester.pumpAndSettle();
      expect(_fotosDeLaGaleria(tester), [const NetworkImage(_otraOriginal)]);
    });
  });
}
