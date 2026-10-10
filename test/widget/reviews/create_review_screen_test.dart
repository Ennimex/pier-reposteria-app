// test/widget/reviews/create_review_screen_test.dart — la vista de «Escribir
// reseña» refleja su ViewModel (MVVM, Fase 3), sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/reviews/view_model/create_review_view_model.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/create_review_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

final Product _producto = Product(
  id: '36',
  nombre: 'Fresa Matcha Bliss',
  descripcion: '',
  precio: 100,
  categoria: 'Pasteles',
  imagenUrl: '',
);

/// Monta la pantalla con sesión abierta (login contra el fake).
Future<void> _montar(WidgetTester tester, FakeApiClient api) async {
  api.responder(ApiConstants.login, {
    'success': true,
    'token': 'jwt',
    'user': {'id': 1, 'nombre': 'Ana', 'rol': 'cliente'},
  });
  await tester.pumpApp(
    CreateReviewScreen(
      product: _producto,
      viewModel: CreateReviewViewModel(
        repo: ResenasRepositoryRemote(api: api),
        productoId: _producto.id,
      ),
    ),
    api: api,
  );
  await tester
      .element(find.byType(CreateReviewScreen))
      .read<AuthProvider>()
      .login('ana@pier.mx', 'x');
  await tester.pump();
}

Future<void> _publicar(WidgetTester tester) async {
  final boton = find.text('Publicar Opinión');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CreateReviewScreen', () {
    testWidgets('las estrellas y el contador reflejan al ViewModel',
        (tester) async {
      await _montar(tester, FakeApiClient());

      expect(find.text('Selecciona una calificación'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.star_border_rounded).at(3));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Muy bueno 😊'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));

      await tester.enterText(find.byType(TextField).last, 'Delicioso');
      await tester.pump();
      expect(find.text('9 / mín. 10'), findsOneWidget);
    });

    testWidgets('sin calificación avisa y no envía', (tester) async {
      final api = FakeApiClient();
      await _montar(tester, api);

      await _publicar(tester);

      expect(find.text('Selecciona una calificación'), findsNWidgets(2));
      expect(api.llamo(ApiConstants.crearResena, metodo: 'POST-Auth'), isFalse);
    });

    testWidgets('al publicar muestra el diálogo de gracias', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.crearResena: {
            'success': true,
            'resena': {'auto_aprobada': true},
          },
        },
      );
      await _montar(tester, api);
      await tester.tap(find.byIcon(Icons.star_border_rounded).at(4));
      await tester.enterText(find.byType(TextField).last, 'Delicioso pastel');
      await tester.pump();

      await _publicar(tester);

      expect(find.textContaining('Tu reseña ha sido publicada'), findsOneWidget);
    });

    testWidgets('si el backend rechaza muestra su mensaje', (tester) async {
      final api = FakeApiClient()
        ..fallar(
          ApiConstants.crearResena,
          'Ya dejaste una reseña para este producto',
        );
      await _montar(tester, api);
      await tester.tap(find.byIcon(Icons.star_border_rounded).at(4));
      await tester.enterText(find.byType(TextField).last, 'Delicioso pastel');
      await tester.pump();

      await _publicar(tester);

      expect(
        find.text('Ya dejaste una reseña para este producto'),
        findsOneWidget,
      );
    });
  });
}
