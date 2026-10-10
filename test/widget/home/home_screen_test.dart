// test/widget/home/home_screen_test.dart — el inicio arma sus secciones con
// lo que expone HomeViewModel (MVVM, Fase 4), sin red: carrusel, promociones
// por tipo, categorías, productos, reseñas, sucursales y pedido activo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/home/widgets/home_screen.dart';
import 'package:pier_pasteleria/ui/orders/widgets/order_detail_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_pasteleria/ui/public/widgets/contact_screen.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _producto(int id, String nombre,
        {bool popular = false, num rating = 4.5, bool nuevo = false}) =>
    {
      'id': id,
      'nombre': nombre,
      'descripcion': 'Rico $nombre',
      'precio_chico': 300,
      'categoria': 'Pasteles',
      'imagen_url': '',
      'popular': popular,
      'es_nuevo': nuevo,
      'activo': true,
      'rating': rating,
      'reviews': 3,
    };

final String _fin = DateTime.now().add(const Duration(days: 2)).toIso8601String();

Map<String, dynamic> _promo(String tipo, int productoId, String nombre) => {
      'tipo': tipo,
      'producto_id': productoId,
      'producto_nombre': nombre,
      'producto_imagen': '',
      'precio_chico': 300,
      'descuento_porcentaje': 10,
      'fecha_fin': _fin,
      'titulo_banner': 'Promo $nombre',
      'subtitulo_banner': 'Solo hoy',
      'nombre_temporada': 'Día de Muertos',
      'badge_destacado': 'Favorito',
    };

FakeApiClient _backend({Map<String, dynamic>? contacto}) =>
    FakeApiClient(respuestas: {
      ApiConstants.productos: {
        'success': true,
        'productos': [
          _producto(1, 'Chocoflan', popular: true),
          _producto(2, 'Pay de queso', nuevo: true),
          _producto(3, 'Rosca'),
        ],
      },
      ApiConstants.promocionesActivas: {
        'success': true,
        'promociones': [
          {
            'tipo': 'banner',
            'titulo_banner': 'Gran venta',
            'subtitulo_banner': 'Todo el mes',
            'descripcion_banner': 'En toda la tienda',
            'codigo_descuento': 'PIER10',
            'fecha_fin': _fin,
          },
          _promo('relampago', 1, 'Chocoflan'),
          _promo('relampago', 3, 'Rosca'),
          _promo('temporada', 2, 'Pay de queso'),
          _promo('destacado', 99, 'Fuera de catálogo'),
        ],
      },
      ApiConstants.categorias: {
        'success': true,
        'categorias': [
          {'id': 1, 'nombre': 'Pasteles'},
          {'id': 2, 'nombre': 'Galletas'},
        ],
      },
      ApiConstants.resenasDestacadas: {
        'success': true,
        'resenas': [
          {
            'autor_nombre': 'Ana',
            'autor_apellido': 'García',
            'producto_nombre': 'Chocoflan',
            'rating': 5,
            'comentario': 'El mejor flan',
          },
        ],
      },
      ApiConstants.configuracionSeccion('contacto'): {
        'success': true,
        'config': contacto ?? {'direccion': 'Centro, Pachuca'},
      },
      ApiConstants.configuracionSeccion('personalizacion'): {
        'success': true,
        'config': <String, dynamic>{},
      },
      ApiConstants.configuracionSeccion('inicio'): {
        'success': true,
        'config': <String, dynamic>{},
      },
      ApiConstants.login: {
        'success': true,
        'token': 'jwt',
        'user': {'id': 1, 'nombre': 'Ana María', 'email': 'ana@pier.mx'},
      },
      ApiConstants.productosComprados: {
        'success': true,
        'productos': [
          {'id': 3, 'nombre': 'Rosca', 'precio_unitario': 280},
        ],
      },
      ApiConstants.misPedidos: {
        'success': true,
        'pedidos': [
          {
            'id': 6,
            'numero': 'P-6',
            'estado': 'listo',
            'tipo_entrega': 'domicilio',
            'items': <dynamic>[],
          },
        ],
      },
      ApiConstants.notificaciones: {'success': true, 'notificaciones': <dynamic>[]},
    });

Future<FakeApiClient> _montar(WidgetTester tester,
    {bool conSesion = false, Map<String, dynamic>? contacto}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _backend(contacto: contacto);
  await tester.pumpApp(const HomeScreen(), api: api);
  if (conSesion) {
    await tester
        .element(find.byType(HomeScreen))
        .read<AuthProvider>()
        .login('ana@pier.mx', 'secreta');
  }
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return api;
}

/// Desmonta para cancelar el carrusel y el sondeo de notificaciones.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('HomeScreen', () {
    testWidgets('pinta carrusel, promociones, categorías, productos y reseñas',
        (tester) async {
      await _montar(tester);

      expect(find.text('Bienvenido'), findsOneWidget);
      expect(find.text('Tradición en cada\nRebanada'), findsOneWidget);
      expect(find.text('Gran venta'), findsOneWidget);
      expect(find.textContaining('Chocoflan'), findsWidgets);
      expect(find.text('Galletas'), findsOneWidget);
      expect(find.text('Destacados'), findsOneWidget);
      expect(find.text('Recién llegados'), findsOneWidget);
      expect(find.text('El mejor flan'), findsOneWidget);
      expect(find.text('Encuéntranos'), findsOneWidget);
      expect(find.textContaining('Centro, Pachuca'), findsOneWidget);
      expect(find.text('Pide de nuevo'), findsNothing);

      await _desmontar(tester);
    });

    testWidgets('el carrusel avanza solo', (tester) async {
      await _montar(tester);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Pasteles\nde Autor'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('con sesión saluda, muestra el pedido activo y pide de nuevo',
        (tester) async {
      await _montar(tester, conSesion: true);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(find.text('Pedido #P-6 listo, buscando repartidor'),
          findsOneWidget);
      expect(find.text('Pide de nuevo'), findsOneWidget);

      await tester.tap(find.text('Pedido #P-6 listo, buscando repartidor'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(OrderDetailScreen), findsOneWidget);

      await _desmontar(tester);
    });

    testWidgets('dos sucursales en la configuración pintan dos tarjetas',
        (tester) async {
      await _montar(tester, contacto: {
        'direccion': 'Centro',
        'horarios': [
          {'sucursal': 'Repostería', 'horario': '9 a 8', 'descripcion': 'Pasteles'},
          {'sucursal': 'Cafetería', 'horario': '8 a 10'},
        ],
      });

      expect(find.text('Repostería'), findsOneWidget);
      expect(find.text('Cafetería'), findsWidgets);
      expect(find.text('9 a 8'), findsOneWidget);

      await tester.tap(find.text('Repostería'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ContactScreen), findsOneWidget);

      await _desmontar(tester);
    });

    testWidgets('tocar un producto abre su detalle', (tester) async {
      await _montar(tester);

      await tester.tap(find.text('Rico Rosca').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ProductDetailScreen), findsOneWidget);
      await _desmontar(tester);
    });
  });
}
