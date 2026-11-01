// test/widget/atencion/respuestas_al_cliente_test.dart — lo que el cliente
// ve de «Atención a clientes» (#138), sin red: la respuesta de Pier bajo su
// opinión (en el detalle del producto y en todas las opiniones) y por qué
// se rechazó su solicitud de reembolso.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/reembolsos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/domain/models/resena_producto.dart';
import 'package:pier_reposteria/ui/products/widgets/detalle_resenas.dart';
import 'package:pier_reposteria/ui/refunds/view_model/refunds_view_model.dart';
import 'package:pier_reposteria/ui/refunds/widgets/refunds_screen.dart';
import 'package:pier_reposteria/ui/reviews/view_model/product_reviews_view_model.dart';
import 'package:pier_reposteria/ui/reviews/widgets/product_reviews_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _opinion({String? respuesta}) => {
      'id': 1,
      'rating': 5,
      'titulo': 'Delicioso',
      'comentario': 'El mejor pastel',
      'verificada': true,
      'autor_nombre': 'Ana',
      'autor_apellido': 'García',
      'respuesta_negocio': respuesta,
    };

Future<void> _opinionDelDetalle(WidgetTester tester, {String? respuesta}) =>
    tester.pumpApp(
      Scaffold(
        body: ResenaDestacadaItem(
          resena: ResenaProducto.fromJson(_opinion(respuesta: respuesta)),
          onUtil: () {},
        ),
      ),
    );

void main() {
  group('El cliente ve la respuesta de Pier', () {
    testWidgets('bajo su opinión en el detalle del producto', (tester) async {
      await _opinionDelDetalle(tester, respuesta: 'Gracias &amp; vuelve');

      expect(find.text('El mejor pastel'), findsOneWidget);
      expect(find.text('Respuesta de Pier Repostería'), findsOneWidget);
      expect(find.text('Gracias & vuelve'), findsOneWidget);
    });

    testWidgets('sin respuesta no hay recuadro', (tester) async {
      await _opinionDelDetalle(tester);

      expect(find.text('El mejor pastel'), findsOneWidget);
      expect(find.text('Respuesta de Pier Repostería'), findsNothing);
    });

    testWidgets('y en todas las opiniones del producto', (tester) async {
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.resenasPorProducto('36'): {
            'success': true,
            'resenas': [_opinion(respuesta: '¡Gracias por tu visita!')],
          },
        },
      );
      final producto = Product(
        id: '36',
        nombre: 'Fresa Matcha Bliss',
        precio: 320,
        imagenUrl: '',
        descripcion: '',
        categoria: 'Pasteles',
      );
      await tester.pumpApp(
        ProductReviewsScreen(
          product: producto,
          viewModel: ProductReviewsViewModel(
            repo: ResenasRepositoryRemote(api: api),
            productoId: producto.id,
          ),
        ),
        api: api,
      );
      await tester.pump();

      expect(find.text('Respuesta de Pier Repostería'), findsOneWidget);
      expect(find.text('¡Gracias por tu visita!'), findsOneWidget);
    });
  });

  testWidgets('el cliente ve por qué se rechazó su reembolso', (tester) async {
    final api = FakeApiClient(
      respuestas: {
        ApiConstants.misReembolsos: {
          'success': true,
          'reembolsos': [
            {
              'id': 3,
              'pedido_numero': 'PIER-9',
              'monto': '640',
              'motivo': 'producto_danado',
              'estado': 'rechazado',
              'justificacion_rechazo': 'La foto no muestra el da&#x27;o',
            },
          ],
        },
        ApiConstants.misPedidos: {'success': true, 'pedidos': <Object>[]},
      },
    );
    final vm = RefundsViewModel(
      reembolsosRepo: ReembolsosRepositoryRemote(api: api),
      pedidosRepo: PedidosRepositoryRemote(api: api),
    );
    await tester.pumpApp(RefundsScreen(viewModel: vm), api: api);
    await tester.pump();

    expect(find.text('Rechazado'), findsOneWidget);
    expect(find.text('Motivo del rechazo'), findsOneWidget);
    expect(find.text("La foto no muestra el da'o"), findsOneWidget);
  });
}
