// test/aceptacion/resenas/calificar_producto_test.dart — escenarios Gherkin
// de calificar con estrellas y un comentario un producto comprado (#64;
// historia #41) y el caso de error «reseña duplicada», sin red.
//
// Cada prueba recorre la app como el cliente: inicia sesión, abre el detalle
// del producto desde una página anfitriona, toca «Escribir» en sus opiniones
// y llena «Escribir Opinión». El backend es BackendResenas
// (test/fakes/resenas_json.dart): las reseñas en memoria sobre
// FakeApiClient, que como POST /resenas rechaza una segunda reseña del mismo
// cliente y publica al momento las de 4 o 5 estrellas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_reposteria/ui/reviews/widgets/create_review_screen.dart';

import '../../fakes/resenas_json.dart';
import '../../helpers/pump_app.dart';

/// Página de partida: abre el detalle de Chocoflan, como el catálogo.
class _Tienda extends StatelessWidget {
  const _Tienda();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ProductDetailScreen(product: chocoflan),
          ),
        ),
        child: const Text('Ver Chocoflan'),
      ),
    ),
  );
}

/// Dado que estoy escribiendo la reseña de un producto que compré: con
/// sesión, abre el detalle de Chocoflan (con tres opiniones de otros
/// clientes y, si se dan, las de [deAna]) y toca «Escribir». El detalle se
/// prueba a 1080 de ancho, igual que product_detail_screen_test.dart: con
/// la fuente de pruebas (Ahem, más ancha que la real) se desborda a 412.
Future<BackendResenas> _escribirResena(
  WidgetTester tester, {
  List<Map<String, dynamic>> deAna = const [],
}) async {
  tester.view
    ..physicalSize = const Size(1080, 4200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = BackendResenas([...deAna, ...opinionesDeOtros()]);
  await tester.pumpApp(const _Tienda(), api: backend.api);
  await tester.iniciarSesion(find.byType(_Tienda));
  await tester.tap(find.text('Ver Chocoflan'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Escribir'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Escribir'));
  await tester.pumpAndSettle();
  expect(find.byType(CreateReviewScreen), findsOneWidget);
  expect(find.text('Chocoflan'), findsOneWidget);
  return backend;
}

/// La estrella [n] (de 1 a 5) mientras ninguna está encendida.
Finder _estrella(int n) => find.byIcon(Icons.star_border_rounded).at(n - 1);

/// El campo «Tu experiencia» (el del título va antes).
Finder get _comentario => find.byType(TextField).last;

/// Toca «Publicar Opinión» y espera la respuesta.
Future<void> _publicar(WidgetTester tester) async {
  final boton = find.text('Publicar Opinión');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  group('#41 Calificar un producto comprado', () {
    // Escenario: reseña sin calificación
    //   Dado que estoy escribiendo la reseña de un producto que compré
    //   Cuando intento enviarla sin elegir estrellas
    //   Entonces la app me pide seleccionar una calificación
    testWidgets('Escenario: reseña sin calificación', (tester) async {
      // Dado que estoy escribiendo la reseña de un producto que compré
      final backend = await _escribirResena(tester);
      await tester.enterText(_comentario, 'Delicioso y muy esponjoso');
      await tester.pump();

      // Cuando intento enviarla sin elegir estrellas
      await _publicar(tester);

      // Entonces la app me pide seleccionar una calificación (la etiqueta de
      // las estrellas y el aviso) y no la envía
      expect(find.text('Selecciona una calificación'), findsNWidgets(2));
      expect(backend.api.llamo(ApiConstants.crearResena), isFalse);
      expect(find.byType(CreateReviewScreen), findsOneWidget);
    });

    // Escenario: comentario demasiado corto
    //   Dado que ya elegí una calificación
    //   Cuando envío un comentario de menos de 10 caracteres
    //   Entonces la app me pide un comentario más largo y no envía la reseña
    testWidgets('Escenario: comentario demasiado corto', (tester) async {
      final backend = await _escribirResena(tester);

      // Dado que ya elegí una calificación
      await tester.tap(_estrella(4));
      await tester.pumpAndSettle();
      expect(find.text('Muy bueno 😊'), findsOneWidget);

      // Cuando envío un comentario de menos de 10 caracteres
      await tester.enterText(_comentario, 'Rico');
      await tester.pump();
      expect(find.text('4 / mín. 10'), findsOneWidget);
      await _publicar(tester);

      // Entonces la app me pide un comentario más largo y no envía la reseña
      expect(
        find.text('El comentario debe tener al menos 10 caracteres'),
        findsOneWidget,
      );
      expect(backend.api.llamo(ApiConstants.crearResena), isFalse);
      expect(find.byType(CreateReviewScreen), findsOneWidget);
    });

    // Escenario: reseña válida
    //   Dado que elegí una calificación y escribí un comentario de 10
    //   caracteres o más
    //   Cuando envío la reseña
    //   Entonces queda registrada para ese producto
    testWidgets('Escenario: reseña válida', (tester) async {
      // Ajuste: ni la app ni el backend limitan la reseña a lo comprado
      // (#41): se escribe desde «Escribir» del detalle y la compra solo la
      // marca como «Compra verificada». PedidosRepository.productosComprados
      // no participa: alimenta «Pide de nuevo» del inicio.
      final backend = await _escribirResena(tester);

      // Dado que elegí una calificación y escribí un comentario de 10
      // caracteres o más
      await tester.tap(_estrella(5));
      await tester.enterText(_comentario, 'Delicioso y muy esponjoso');
      await tester.pump();

      // Cuando envío la reseña
      await _publicar(tester);

      // Entonces queda registrada para ese producto: el backend la recibe
      // con su calificación y su comentario y, con 5 estrellas, la publica
      expect(backend.api.ultima(ApiConstants.crearResena)!.body, {
        'producto_id': '7',
        'rating': 5,
        'titulo': '',
        'comentario': 'Delicioso y muy esponjoso',
      });
      expect(backend.deAna, hasLength(1));
      expect(find.textContaining('Tu reseña ha sido publicada'), findsOneWidget);

      // …y al volver al producto aparece entre sus opiniones
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateReviewScreen), findsNothing);
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(find.text('Delicioso y muy esponjoso'), findsOneWidget);
      expect(find.text('Ana L.'), findsOneWidget);
      expect(find.text('Ver las 4 opiniones'), findsOneWidget);
    });

    // Escenario: reseña duplicada (caso de error del #64)
    //   Dado que ya publiqué una reseña de este producto
    //   Cuando escribo y envío otra
    //   Entonces la app muestra el motivo del backend
    //   Y no se registra una segunda reseña
    testWidgets('Escenario: reseña duplicada', (tester) async {
      // Dado que ya publiqué una reseña de este producto
      final backend = await _escribirResena(
        tester,
        deAna: [
          resenaJson(
            id: 10,
            rating: 4,
            comentario: 'Muy esponjoso',
            deAna: true,
          ),
        ],
      );

      // Cuando escribo y envío otra
      await tester.tap(_estrella(5));
      await tester.enterText(_comentario, 'Lo volví a pedir y sigue delicioso');
      await tester.pump();
      await _publicar(tester);

      // Entonces la app muestra el motivo del backend y me deja en la
      // pantalla, sin el diálogo de gracias
      expect(
        backend.api.llamo(ApiConstants.crearResena, metodo: 'POST-Auth'),
        isTrue,
      );
      expect(find.text(BackendResenas.yaResenada), findsOneWidget);
      expect(find.textContaining('¡Gracias por tu'), findsNothing);
      expect(find.byType(CreateReviewScreen), findsOneWidget);

      // Y no se registra una segunda reseña
      expect(backend.deAna, hasLength(1));
      expect(backend.deAna.single['comentario'], 'Muy esponjoso');
    });
  });
}
