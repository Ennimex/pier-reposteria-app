// test/widget/reviews/my_reviews_screen_test.dart — la vista de «Mis
// Reseñas» pinta lo que expone su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/ui/reviews/view_model/my_reviews_view_model.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/my_reviews_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Future<void> _montar(WidgetTester tester, FakeApiClient api) async {
  await tester.pumpApp(
    MyReviewsScreen(
      viewModel: MyReviewsViewModel(repo: ResenasRepository(api: api)),
    ),
    api: api,
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MyReviewsScreen', () {
    testWidgets('sin reseñas muestra el estado vacío', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.misResenas: {'success': true, 'resenas': <Object>[]},
        },
      );
      await _montar(tester, api);

      expect(find.text('Sin reseñas aún'), findsOneWidget);
    });

    testWidgets('pinta estado, respuesta y motivo de rechazo',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.misResenas: {
            'success': true,
            'resenas': [
              {
                'id': 7,
                'rating': 4,
                'comentario': 'Muy esponjoso',
                'estado': 'aprobada',
                'producto_nombre': 'Fresa Matcha Bliss',
                'respuesta_negocio': '¡Gracias!',
              },
              {
                'id': 8,
                'rating': 2,
                'comentario': 'Llegó tarde',
                'estado': 'rechazada',
                'producto_nombre': 'Red Velvet',
                'motivo_rechazo': 'Lenguaje inapropiado',
              },
            ],
          },
        },
      );
      await _montar(tester, api);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Publicada'), findsOneWidget);
      expect(find.text('Rechazada'), findsOneWidget);
      expect(find.text('¡Gracias!'), findsOneWidget);
      expect(find.text('Lenguaje inapropiado'), findsOneWidget);
    });

    testWidgets('editar manda los cambios y muestra el aviso',
        (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.misResenas: {
            'success': true,
            'resenas': [
              {
                'id': 7,
                'rating': 4,
                'comentario': 'Muy esponjoso',
                'estado': 'aprobada',
                'producto_nombre': 'Fresa Matcha Bliss',
              },
            ],
          },
          ApiConstants.editarResena('7'): {
            'success': true,
            'message': 'Reseña editada',
          },
        },
      );
      await _montar(tester, api);

      await tester.tap(find.byIcon(LucideIcons.pencil));
      await tester.pumpAndSettle();
      expect(find.text('Editar reseña'), findsOneWidget);

      // Cinco estrellas en la hoja (las de la tarjeta van primero).
      await tester.tap(find.byIcon(Icons.star_border_rounded).last);
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Reseña editada'), findsOneWidget);
      final llamada = api.ultima(ApiConstants.editarResena('7'))!;
      expect(llamada.body?['rating'], 5);
      expect(llamada.body?['comentario'], 'Muy esponjoso');
    });
  });
}
