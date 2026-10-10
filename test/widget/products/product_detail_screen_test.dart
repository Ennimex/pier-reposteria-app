// test/widget/products/product_detail_screen_test.dart — el detalle pinta lo
// que expone su ViewModel (MVVM, Fase 4), sin red: galería, precio con
// promoción, tamaños, cantidad, reseñas, recomendados y las acciones con y
// sin sesión.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/product_reviews_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _json(int id, String nombre,
        {num precio = 300, num? grande, bool agotado = false}) =>
    {
      'id': id,
      'nombre': nombre,
      'descripcion': 'Delicioso $nombre',
      'precio_chico': precio,
      'precio_grande': grande,
      'categoria': 'Pasteles',
      'imagen_url': '',
      'sabor': 'Chocolate',
      'tipo': 'Horneado',
      'ingredientes': ['Cacao', 'Huevo'],
      'popular': true,
      'stock_online': agotado ? 0 : null,
      'activo': true,
      'rating': 4,
      'reviews': 2,
    };

final Product _pastel =
    Product.fromJson(_json(7, 'Chocoflan', grande: 500));

FakeApiClient _backend({String tipoPromo = 'temporada'}) =>
    FakeApiClient(respuestas: {
      ApiConstants.productoById('7'): {
        'success': true,
        'producto': {
          'imagenes': ['https://pier/1.jpg', 'https://pier/2.jpg'],
          'reviews': 12,
          'rating_promedio': 4.5,
        },
        'resenas': [
          {
            'id': 1,
            'autor_nombre': 'Ana',
            'autor_apellido': 'García',
            'rating': 5,
            'comentario': 'Me encantó',
            'created_at': DateTime.now().toIso8601String(),
            'likes_count': 2,
          },
        ],
      },
      ApiConstants.recomendaciones('7'): {
        'success': true,
        'recomendaciones': [_json(8, 'Pay de queso', precio: 250)],
      },
      ApiConstants.productos: {
        'success': true,
        'productos': [_json(8, 'Pay de queso', precio: 250)],
      },
      ApiConstants.promocionesActivas: {
        'success': true,
        'promociones': [
          {
            'producto_id': 7,
            'tipo': tipoPromo,
            'descuento_porcentaje': 10,
            'nombre_temporada': 'Día de Muertos',
          },
          {'producto_id': 8, 'tipo': 'relampago', 'descuento_porcentaje': 20},
        ],
      },
      ApiConstants.login: {
        'success': true,
        'token': 'jwt',
        'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
      },
      ApiConstants.favoritosIds: {'success': true, 'ids': <int>[]},
      ApiConstants.favoritoById('7'): {'success': true},
      ApiConstants.likeResena('1'): {'success': true, 'liked': true},
      ApiConstants.clicsAgotados: {'success': true},
      ApiConstants.carrito: {'success': true},
    });

/// Página anfitriona: abre el detalle con push para que "Añadir" (que hace
/// pop) tenga a dónde regresar.
class _Anfitrion extends StatelessWidget {
  const _Anfitrion(this.producto);
  final Product producto;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => ProductDetailScreen(product: producto))),
            child: const Text('Abrir'),
          ),
        ),
      );
}

Future<FakeApiClient> _montar(WidgetTester tester,
    {Product? producto, bool conSesion = false, String tipoPromo = 'temporada'}) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _backend(tipoPromo: tipoPromo);
  await tester.pumpApp(_Anfitrion(producto ?? _pastel), api: api);
  if (conSesion) {
    await tester.iniciarSesion(find.byType(_Anfitrion));
  }
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  group('ProductDetailScreen', () {
    testWidgets('pinta galería, precio con promoción, reseñas y recomendados',
        (tester) async {
      await _montar(tester);

      expect(find.text('Chocoflan'), findsOneWidget);
      expect(find.text('PASTELES'), findsOneWidget);
      expect(find.text('Horneado'), findsOneWidget);
      expect(find.text('(12)'), findsOneWidget);
      expect(find.text(r'$270'), findsWidgets); // 300 - 10 %
      expect(find.text('Día de Muertos'), findsNWidgets(2)); // galería + info
      expect(find.text('-10%'), findsOneWidget);
      expect(find.text('Cacao'), findsOneWidget);
      expect(find.text('Me encantó'), findsOneWidget);
      expect(find.text('Ana G.'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Ver las 12 opiniones'), findsOneWidget);
      expect(find.text('Otros clientes también pidieron'), findsOneWidget);
      expect(find.text('Pay de queso'), findsOneWidget);
      expect(find.text('Flash'), findsOneWidget);
    });

    testWidgets('tamaño y cantidad cambian el total', (tester) async {
      await _montar(tester);

      expect(find.text(r'$270.00'), findsOneWidget);
      await tester.tap(find.text('Grande'));
      await tester.pumpAndSettle();
      expect(find.text(r'$450.00'), findsOneWidget); // 500 - 10 %

      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pumpAndSettle();
      expect(find.text(r'$900.00'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pumpAndSettle();
      expect(find.text(r'$450.00'), findsOneWidget);
    });

    testWidgets('sin sesión, añadir y el corazón mandan a iniciar sesión',
        (tester) async {
      await _montar(tester, tipoPromo: 'nuevo');

      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(LoginScreen))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('con sesión agrega al carrito, marca favorito y útil',
        (tester) async {
      final api = await _montar(tester, conSesion: true, tipoPromo: 'relampago');

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(api.llamo(ApiConstants.favoritoById('7'), metodo: 'POST-Auth'),
          isTrue);

      await tester.tap(find.byIcon(LucideIcons.thumbsUp));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      // Agregar un recomendado no cierra el detalle.
      await tester.tap(find.byIcon(LucideIcons.plus).last);
      await tester.pumpAndSettle();
      expect(find.text('Pay de queso agregado'), findsOneWidget);

      await tester.tap(find.text('Grande'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailScreen), findsNothing);
      expect(find.text('1 × Chocoflan (Grande) agregado'), findsOneWidget);
      final alta = api.llamadas.lastWhere((l) =>
          l.endpoint == ApiConstants.carrito && l.metodo == 'POST-Auth');
      expect(alta.body, {'producto_id': 7, 'cantidad': 1, 'tamano': 'grande'});
    });

    testWidgets('un agotado ofrece Avísame y lo registra', (tester) async {
      final api = await _montar(tester,
          producto: Product.fromJson(_json(7, 'Chocoflan', agotado: true)),
          tipoPromo: 'destacado');

      await tester.tap(find.text('Avísame'));
      await tester.pump();

      expect(find.textContaining('Anotamos tu interés'), findsOneWidget);
      expect(api.ultima(ApiConstants.clicsAgotados)!.body, {'producto_id': 7});
      expect(find.text('Selecciona el tamaño'), findsNothing);
    });

    testWidgets('ver todas las opiniones abre la lista y al volver recarga',
        (tester) async {
      final api = await _montar(tester);
      final antes = api.llamadas
          .where((l) => l.endpoint == ApiConstants.productoById('7'))
          .length;

      await tester.tap(find.text('Ver las 12 opiniones'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductReviewsScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(ProductReviewsScreen))).pop();
      await tester.pumpAndSettle();
      expect(
          api.llamadas
              .where((l) => l.endpoint == ApiConstants.productoById('7'))
              .length,
          antes + 1);
    });

    testWidgets('tocar un recomendado abre su detalle', (tester) async {
      await _montar(tester);

      await tester.tap(find.text('Pay de queso'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductDetailScreen, skipOffstage: false),
          findsNWidgets(2));
    });
  });
}
