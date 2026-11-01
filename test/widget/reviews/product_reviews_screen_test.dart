// test/widget/reviews/product_reviews_screen_test.dart — la vista de
// «Opiniones» pinta lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/reviews/view_model/product_reviews_view_model.dart';
import 'package:pier_reposteria/ui/reviews/widgets/product_reviews_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pantalla_apretada.dart';
import '../../helpers/pump_app.dart';

final _producto = Product(
  id: '36',
  nombre: 'Fresa Matcha Bliss',
  precio: 320,
  imagenUrl: '',
  descripcion: '',
  categoria: 'Pasteles',
);

Future<void> _montar(WidgetTester tester, FakeApiClient api) async {
  await tester.pumpApp(
    ProductReviewsScreen(
      product: _producto,
      viewModel: ProductReviewsViewModel(
        repo: ResenasRepositoryRemote(api: api),
        productoId: _producto.id,
      ),
    ),
    api: api,
  );
  await tester.pump();
}

/// El producto todavía no tiene reseñas.
FakeApiClient _sinResenas() => FakeApiClient(
      respuestas: {
        ApiConstants.resenasPorProducto('36'): {
          'success': true,
          'resenas': <Object>[],
        },
      },
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ProductReviewsScreen', () {
    testWidgets('sin reseñas muestra el estado vacío', (tester) async {
      await _montar(tester, _sinResenas());

      expect(find.text('Aún no hay calificaciones'), findsOneWidget);
      expect(find.text('Sin opiniones aún'), findsOneWidget);
    });

    testWidgets('pinta resumen y tarjetas, y filtra por estrellas',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.resenasPorProducto('36'): {
            'success': true,
            'resenas': [
              {
                'id': 1,
                'rating': 5,
                'titulo': 'Delicioso',
                'comentario': 'El mejor pastel',
                'util_count': 3,
                'verificada': true,
                'autor_nombre': 'Ana',
                'autor_apellido': 'García',
              },
              {
                'id': 2,
                'rating': 3,
                'comentario': 'Regular',
                'autor_nombre': 'Luis',
              },
            ],
          },
        },
      );
      await _montar(tester, api);

      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('2 reseñas'), findsOneWidget);
      expect(find.text('Ana G.'), findsOneWidget);
      expect(find.text('Compra verificada'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);

      await tester.tap(find.text('5 ★'));
      await tester.pump();

      expect(find.text('Regular'), findsNothing);
      expect(find.text('El mejor pastel'), findsOneWidget);

      await tester.tap(find.text('1 ★'));
      await tester.pump();

      expect(find.text('No hay opiniones de 1 estrella'), findsOneWidget);
    });
  });

  // Regresión de #285: el estado vacío medía justo lo que quedaba de
  // pantalla; si no cabía se desbordaba y el texto quedaba cortado.
  group('El estado vacío de Opiniones cabe en una pantalla apretada (#285)',
      () {
    for (final apreton in Apreton.values) {
      testWidgets(
          'sin reseñas, la invitación a calificar se alcanza '
          '${apreton.descripcion}', (tester) async {
        await _montar(tester, _sinResenas());
        await tester.apretar(apreton);

        await tester.alcanzar(
            find.text('Sé el primero en calificar\neste producto.'));
      }, tags: 'regresion');
    }
  });
}
