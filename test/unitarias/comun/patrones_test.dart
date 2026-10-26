// test/unitarias/comun/patrones_test.dart — pruebas de caja blanca de los
// patrones explícitos de la arquitectura (docs/ARQUITECTURA.md):
//   · Singleton: ApiService() devuelve siempre la misma instancia, el único
//     cliente HTTP que comparten los repositorios;
//   · Factory: PasarelaPago() elige la implementación concreta
//     (PasarelaStripe) y dependencies.dart registra esa fábrica.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/dependencies.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:pier_reposteria/data/services/pasarela_pago.dart';
import 'package:pier_reposteria/data/services/pasarela_stripe.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';

void main() {
  group('Singleton: ApiService', () {
    test('ApiService() devuelve siempre la misma instancia', () {
      final primera = ApiService();
      final segunda = ApiService();

      expect(identical(primera, segunda), isTrue);
    });

    test('la instancia única cumple el contrato ApiClient de los '
        'repositorios', () {
      expect(ApiService(), isA<ApiClient>());
    });
  });

  group('Factory: PasarelaPago', () {
    test('PasarelaPago() devuelve una PasarelaStripe que cumple el '
        'contrato', () {
      final pasarela = PasarelaPago();

      expect(pasarela, isA<PasarelaStripe>());
      expect(pasarela, isA<PasarelaPago>());
    });

    test('la fábrica crea una pasarela nueva en cada llamada', () {
      expect(identical(PasarelaPago(), PasarelaPago()), isFalse);
    });

    testWidgets('dependencies.dart registra la pasarela que elige la '
        'fábrica', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late PasarelaPago registrada;

      await tester.pumpWidget(
        MultiProvider(
          providers: dependencias(FakeApiClient()),
          child: Builder(
            builder: (context) {
              registrada = context.read<PasarelaPago>();
              return const SizedBox();
            },
          ),
        ),
      );

      expect(registrada, isA<PasarelaStripe>());
    });
  });
}
