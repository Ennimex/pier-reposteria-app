// test/widget/products/products_screen_test.dart — el catálogo pinta lo que
// expone su ViewModel (MVVM, Fase 4) sobre el catálogo de ProductProvider,
// sin red: tarjetas en cuadrícula y lista, badges de promoción, categorías,
// hojas de filtros y orden, estado vacío y acciones sin sesión.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/products_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _p(
  int id,
  String nombre, {
  num precio = 100,
  String categoria = 'Pasteles',
  String? sabor,
  bool popular = false,
  bool agotado = false,
}) =>
    {
      'id': id,
      'nombre': nombre,
      'descripcion': 'Rico $nombre',
      'precio_chico': precio,
      'categoria': categoria,
      'imagen_url': '',
      'sabor': sabor,
      'popular': popular,
      'stock_online': agotado ? 0 : null,
      'activo': true,
      'rating': 4.5,
    };

FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.productos: {
        'success': true,
        'productos': [
          _p(1, 'Chocoflan', precio: 300, sabor: 'Chocolate', popular: true),
          _p(2, 'Cheesecake', precio: 450, categoria: 'Pays', sabor: 'Fresa'),
          _p(3, 'Pay de limón', precio: 200, categoria: 'Pays', agotado: true),
          _p(4, 'Rosca', precio: 380, popular: true),
          _p(5, 'Tres leches', precio: 320),
          _p(6, 'Flan napolitano', precio: 150),
        ],
      },
      ApiConstants.promocionesActivas: {
        'success': true,
        'promociones': [
          {'producto_id': 4, 'tipo': 'relampago', 'descuento_porcentaje': 10},
          {'producto_id': 5, 'tipo': 'temporada', 'descuento_porcentaje': 15},
          {
            'producto_id': 6,
            'tipo': 'destacado',
            'descuento_porcentaje': 5,
            'badge_destacado': 'Favorito',
          },
          {'producto_id': 2, 'tipo': 'nuevo', 'descuento_porcentaje': 20},
        ],
      },
      ApiConstants.categorias: {
        'success': true,
        'categorias': [
          {'id': 1, 'nombre': 'Pasteles'},
          {'id': 2, 'nombre': 'Pays'},
        ],
      },
      ApiConstants.filtros: {
        'success': true,
        'filtros': {
          'sabores': ['Todos', 'Chocolate', 'Fresa'],
          'tamanos': ['Chico', 'Grande'],
          'tipos': ['Horneado'],
        },
      },
      ApiConstants.categoriaOpciones('2'): {
        'success': true,
        'sabores': ['Fresa'],
        'tipos': <String>[],
      },
      ApiConstants.clicsAgotados: {'success': true},
    });

Future<FakeApiClient> _montar(WidgetTester tester) async {
  // Pantalla alta para que el grid construya todas las tarjetas.
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _backend();
  await tester.pumpApp(const ProductsScreen(), api: api);
  await tester.pumpAndSettle();
  return api;
}

void main() {
  group('ProductsScreen', () {
    testWidgets('pinta el catálogo con badges, precios con descuento y '
        'lo agotado al final', (tester) async {
      await _montar(tester);

      expect(find.text('Nuestro Menú'), findsOneWidget);
      for (final nombre in ['Chocoflan', 'Cheesecake', 'Rosca', 'Pay de limón']) {
        expect(find.text(nombre), findsOneWidget);
      }
      expect(find.text('Agotado'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget); // Rosca tiene promo
      expect(find.text('Flash'), findsOneWidget);
      expect(find.text('Temporada'), findsOneWidget);
      expect(find.text('Favorito'), findsOneWidget);
      expect(find.text('Nuevo'), findsOneWidget);
      expect(find.text('-10%'), findsOneWidget);
      expect(find.text(r'$342'), findsOneWidget); // 380 - 10 %
      expect(find.text(r'$380'), findsOneWidget); // tachado

      final y = tester.getTopLeft(find.text('Pay de limón')).dy;
      expect(y, greaterThan(tester.getTopLeft(find.text('Chocoflan')).dy));
    });

    testWidgets('cambia a lista y de regreso', (tester) async {
      await _montar(tester);

      await tester.tap(find.text('Cuadrícula'));
      await tester.pumpAndSettle();

      expect(find.text('Lista'), findsOneWidget);
      expect(find.text('Avísame'), findsOneWidget);
      expect(find.text('Popular'), findsNWidgets(2)); // en lista sale siempre

      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();
      expect(find.text('Cuadrícula'), findsOneWidget);
    });

    testWidgets('el chip de categoría filtra y "Quitar filtros" lo regresa',
        (tester) async {
      await _montar(tester);

      // El chip va arriba; las tarjetas también muestran su categoría.
      await tester.tap(find.text('Pays').first);
      await tester.pumpAndSettle();

      expect(find.text('Chocoflan'), findsNothing);
      expect(find.text('Cheesecake'), findsOneWidget);

      await tester.tap(find.text('Quitar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan'), findsOneWidget);
    });

    testWidgets('la hoja de filtros aplica y limpia el sabor', (tester) async {
      await _montar(tester);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      expect(find.text('Tamaño'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget); // solo el chip de categoría

      await tester.tap(find.text('Fresa'));
      await tester.pumpAndSettle();
      expect(find.text('Limpiar'), findsOneWidget);

      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan'), findsNothing);
      expect(find.text('Cheesecake'), findsOneWidget);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan'), findsOneWidget);
    });

    testWidgets('ordena por precio desde la hoja de orden', (tester) async {
      await _montar(tester);

      await tester.tap(find.byTooltip('Ordenar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Precio: Mayor a Menor'));
      await tester.pumpAndSettle();

      final cheesecake = tester.getTopLeft(find.text('Cheesecake'));
      final chocoflan = tester.getTopLeft(find.text('Chocoflan'));
      expect(cheesecake.dy <= chocoflan.dy, isTrue);
      expect(find.text('Ordenar por'), findsNothing);
    });

    testWidgets('una búsqueda sin resultados ofrece limpiar los filtros',
        (tester) async {
      await _montar(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan'), findsOneWidget);
    });

    testWidgets('el botón de borrar búsqueda vacía el buscador', (tester) async {
      await _montar(tester);

      await tester.enterText(find.byType(TextField), 'choco');
      await tester.pumpAndSettle();
      expect(find.text('Rosca'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(find.text('Rosca'), findsOneWidget);
      expect(find.byTooltip('Ordenar'), findsOneWidget);
    });

    testWidgets('Avísame en un agotado registra el interés y lo confirma',
        (tester) async {
      final api = await _montar(tester);

      await tester.tap(find.text('Cuadrícula'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avísame'));
      await tester.pump();

      expect(find.textContaining('Anotamos tu interés'), findsOneWidget);
      expect(api.ultima(ApiConstants.clicsAgotados)!.body, {'producto_id': 3});
    });

    testWidgets('sin sesión, el corazón manda a iniciar sesión', (tester) async {
      await _montar(tester);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
