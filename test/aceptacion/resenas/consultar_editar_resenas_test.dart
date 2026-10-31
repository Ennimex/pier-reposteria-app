// test/aceptacion/resenas/consultar_editar_resenas_test.dart — escenarios
// Gherkin de leer las reseñas de un producto, marcar una como «útil» y
// editar las propias desde «Mis Reseñas» (#64; historia #42), sin red.
//
// Cada prueba recorre la app como el cliente: desde una página anfitriona
// abre el detalle del producto y sus opiniones, o «Mis Reseñas», y toca los
// mismos botones. El backend es BackendResenas
// (test/fakes/resenas_json.dart): las reseñas en memoria sobre
// FakeApiClient, con los votos «útil» del cliente y la edición como en el
// backend, para que lo que se ve sea lo que el «servidor» tiene.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/movimiento_contenido.dart';
import 'package:pier_reposteria/ui/reviews/widgets/my_reviews_screen.dart';
import 'package:pier_reposteria/ui/reviews/widgets/product_reviews_screen.dart';

import '../../fakes/resenas_json.dart';
import '../../helpers/pump_app.dart';

/// Página de partida: abre el detalle de Chocoflan, como el catálogo, o
/// «Mis Reseñas», como la pestaña «Más».
class _Tienda extends StatelessWidget {
  const _Tienda();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ProductDetailScreen(product: chocoflan),
            ),
          ),
          child: const Text('Ver Chocoflan'),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const MyReviewsScreen()),
          ),
          child: const Text('Mis reseñas'),
        ),
      ],
    ),
  );
}

/// Monta la tienda sobre el backend falso. Todo se prueba a 1080 de ancho,
/// igual que product_detail_screen_test.dart: con la fuente de pruebas
/// (Ahem, más ancha que la real) el detalle se desborda a 412. Con
/// [conSesion], el cliente ya inició sesión.
Future<void> _abrirTienda(
  WidgetTester tester,
  BackendResenas backend, {
  bool conSesion = false,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 4200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpApp(const _Tienda(), api: backend.api);
  if (conSesion) {
    await tester.iniciarSesion(find.byType(_Tienda));
    await tester.pump();
  }
}

/// Toca [boton] y espera a que todo se acomode (páginas, hojas, avisos y
/// animaciones).
Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

/// Desde el detalle del producto, «Ver las N opiniones» abre sus reseñas.
Future<void> _verOpiniones(WidgetTester tester) async {
  final boton = find.textContaining('Ver las ');
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await _tocar(tester, boton);
}

/// Algo dentro de la tarjeta de la reseña con [comentario] (en «Opiniones»
/// o en «Mis Reseñas»).
Finder _enResena(String comentario, Finder algo) => find.descendant(
  of: find.ancestor(
    of: find.text(comentario),
    matching: find.byType(ResaltadoUnaVez),
  ),
  matching: algo,
);

/// Si la reseña con [comentario] se ve marcada «útil» (el pulgar encendido).
bool _marcadaUtil(WidgetTester tester, String comentario) => tester
    .widget<DestelloAlMarcar>(
      _enResena(comentario, find.byType(DestelloAlMarcar)),
    )
    .activo;

/// Algo dentro de la hoja de «Editar reseña».
Finder _enHoja(Finder algo) =>
    find.descendant(of: find.byType(BottomSheet), matching: algo);

void main() {
  group('#42 Consultar reseñas y editar las propias', () {
    // Escenario: ver las reseñas de un producto
    //   Dado que estoy viendo un producto con reseñas
    //   Cuando abro sus reseñas
    //   Entonces veo la calificación y el comentario de cada una
    testWidgets('Escenario: ver las reseñas de un producto', (tester) async {
      final backend = BackendResenas(opinionesDeOtros());
      await _abrirTienda(tester, backend);

      // Dado que estoy viendo un producto con reseñas
      await _tocar(tester, find.text('Ver Chocoflan'));
      expect(find.text('Opiniones destacadas'), findsOneWidget);
      expect(find.text('Ver las 3 opiniones'), findsOneWidget);

      // Cuando abro sus reseñas
      await _verOpiniones(tester);

      // Entonces veo la calificación y el comentario de cada una
      expect(find.byType(ProductReviewsScreen), findsOneWidget);
      expect(
        backend.api.llamo(ApiConstants.resenasPorProducto('7'), metodo: 'GET'),
        isTrue,
      );
      expect(find.text('3 reseñas'), findsOneWidget);
      expect(
        _enResena('El mejor flan que he probado', find.text('5.0')),
        findsOneWidget,
      );
      expect(
        _enResena('Muy rico, aunque algo dulce', find.text('4.0')),
        findsOneWidget,
      );
      expect(
        _enResena('Llegó un poco aplastado', find.text('2.0')),
        findsOneWidget,
      );
      expect(
        _enResena('El mejor flan que he probado', find.text('Luis P.')),
        findsOneWidget,
      );
    });

    // Escenario: dar «me gusta» a una reseña
    //   Dado que estoy leyendo las reseñas de un producto
    //   Cuando marco «me gusta» en una
    //   Entonces la reseña refleja mi voto
    testWidgets('Escenario: dar «me gusta» a una reseña', (tester) async {
      const opinion = 'El mejor flan que he probado';
      final backend = BackendResenas(opinionesDeOtros());
      await _abrirTienda(tester, backend, conSesion: true);
      await _tocar(tester, find.text('Ver Chocoflan'));

      // Dado que estoy leyendo las reseñas de un producto
      await _verOpiniones(tester);
      expect(_enResena(opinion, find.text('3')), findsOneWidget);
      expect(_marcadaUtil(tester, opinion), isFalse);

      // Cuando marco «me gusta» en una.
      // Ajuste: en la app el voto se llama «Útil» (el pulgar con su cuenta),
      // no «me gusta»; va a POST /resenas/:id/like y pide sesión.
      await _tocar(tester, _enResena(opinion, find.byIcon(LucideIcons.thumbsUp)));

      // Entonces la reseña refleja mi voto: el pulgar encendido y la cuenta
      // con un voto más
      expect(
        backend.api.llamo(ApiConstants.likeResena('1'), metodo: 'POST-Auth'),
        isTrue,
      );
      expect(_enResena(opinion, find.text('4')), findsOneWidget);
      expect(_marcadaUtil(tester, opinion), isTrue);
      expect(backend.utiles, {1});

      // …y lo sigue reflejando al volver a abrir las opiniones
      await _tocar(tester, find.byIcon(LucideIcons.chevronLeft));
      await _verOpiniones(tester);
      expect(_enResena(opinion, find.text('4')), findsOneWidget);
      expect(_marcadaUtil(tester, opinion), isTrue);
    });

    // Escenario: editar mi reseña
    //   Dado que tengo una reseña publicada
    //   Cuando la edito desde «Mis reseñas» y guardo
    //   Entonces la reseña muestra la calificación y el comentario nuevos
    testWidgets('Escenario: editar mi reseña', (tester) async {
      const original = 'Muy esponjoso';
      const editada = 'Muy esponjoso y con mucho chocolate';
      // Dado que tengo una reseña publicada (de 4 estrellas)
      final backend = BackendResenas([
        resenaJson(id: 10, rating: 4, comentario: original, deAna: true),
        ...opinionesDeOtros(),
      ]);
      await _abrirTienda(tester, backend, conSesion: true);
      await _tocar(tester, find.text('Mis reseñas'));
      expect(find.byType(MyReviewsScreen), findsOneWidget);
      expect(_enResena(original, find.text('Publicada')), findsOneWidget);
      expect(_enResena(original, find.text('4.0')), findsOneWidget);

      // Cuando la edito desde «Mis reseñas» (cinco estrellas y otro
      // comentario) y guardo
      await _tocar(tester, _enResena(original, find.byIcon(LucideIcons.pencil)));
      expect(find.text('Editar reseña'), findsOneWidget);
      await tester.tap(_enHoja(find.byIcon(Icons.star_border_rounded)));
      await tester.pump();
      await tester.enterText(_enHoja(find.byType(TextField)).last, editada);
      await _tocar(tester, find.text('Guardar'));

      // Entonces la reseña muestra la calificación y el comentario nuevos.
      // Con 4 o 5 estrellas el backend la deja publicada; con menos
      // volvería a revisión.
      expect(backend.api.ultima(ApiConstants.editarResena('10'))!.body, {
        'rating': 5,
        'titulo': '',
        'comentario': editada,
      });
      expect(find.text('Reseña actualizada'), findsOneWidget);
      expect(find.text(original), findsNothing);
      expect(_enResena(editada, find.text('5.0')), findsOneWidget);
      expect(
        _enResena(editada, find.byIcon(Icons.star_rounded)),
        findsNWidgets(5),
      );
      expect(_enResena(editada, find.text('Publicada')), findsOneWidget);
    });
  });
}
