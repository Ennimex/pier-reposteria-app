// test/widget/reviews/product_reviews_screen_test.dart — la vista de
// «Opiniones» pinta lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/reviews/view_model/product_reviews_view_model.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/product_reviews_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
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
        repo: ResenasRepository(api: api),
        productoId: _producto.id,
      ),
    ),
    api: api,
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ProductReviewsScreen', () {
    testWidgets('sin reseñas muestra el estado vacío', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.resenasPorProducto('36'): {
            'success': true,
            'resenas': <Object>[],
          },
        },
      );
      await _montar(tester, api);

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
}
