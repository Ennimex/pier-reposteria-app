// test/widget/reviews/resenas_movimiento_test.dart — el movimiento de las
// reseñas. Escribir: las estrellas que se encienden dan su pop en fila (la
// tocada se endereza) y la etiqueta rueda; sin calificación se sacuden las
// estrellas y con un comentario corto, el campo; el diálogo trae chispas
// solo si la reseña quedó publicada. Mis reseñas: el contador aparece con
// un pop, las estrellas de la hoja de edición también lo dan y la reseña
// que cambia al recargar trae el aro dorado. Opiniones: las barras se
// llenan desde cero, un filtro reparte las opiniones otra vez, «útil» da el
// pop con destello del detalle y su cuenta rueda, recargar no repite
// entradas ni destellos y solo la opinión recién llegada trae el aro
// dorado; con movimiento reducido todo llega en su lugar. Sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/public/widgets/movimiento_contenido.dart';
import 'package:pier_reposteria/ui/reviews/view_model/create_review_view_model.dart';
import 'package:pier_reposteria/ui/reviews/view_model/my_reviews_view_model.dart';
import 'package:pier_reposteria/ui/reviews/view_model/product_reviews_view_model.dart';
import 'package:pier_reposteria/ui/reviews/widgets/create_review_screen.dart';
import 'package:pier_reposteria/ui/reviews/widgets/my_reviews_screen.dart';
import 'package:pier_reposteria/ui/reviews/widgets/product_reviews_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

final Product _producto = Product(
  id: '36',
  nombre: 'Fresa Matcha Bliss',
  descripcion: '',
  precio: 100,
  categoria: 'Pasteles',
  imagenUrl: '',
);

const Map<String, dynamic> _login = {
  'success': true,
  'token': 'jwt',
  'user': {'id': 1, 'nombre': 'Ana', 'rol': 'cliente'},
};

/// Desplazamiento horizontal actual de la sacudida que envuelve a [hijo].
double _dxSacudida(WidgetTester tester, Finder hijo) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.ancestor(of: hijo, matching: find.byType(Sacudida)).first,
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getTranslation()
    .x;

/// Un Transform de la estrella [i] (solo existe mientras se mueve).
Finder _movimientoDeEstrella(int i) => find.descendant(
  of: find.byType(EstrellaAnimada).at(i),
  matching: find.byType(Transform),
);

// ── Escribir opinión ────────────────────────────────────────────────────

Future<void> _montarEscribir(WidgetTester tester, FakeApiClient api) async {
  api.responder(ApiConstants.login, _login);
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
  await tester.iniciarSesion(find.byType(CreateReviewScreen), password: 'x');
  await tester.pump();
}

Future<void> _publicar(WidgetTester tester) async {
  final boton = find.text('Publicar Opinión');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pump();
  await tester.pump();
}

// ── Opiniones del producto ──────────────────────────────────────────────

Map<String, dynamic> _opinion(
  int id,
  int rating,
  String comentario, {
  int util = 0,
}) => {
  'id': id,
  'rating': rating,
  'comentario': comentario,
  'util_count': util,
  'autor_nombre': 'Cliente $id',
};

/// Backend cuyas opiniones se pueden cambiar entre cargas.
FakeApiClient _backendOpiniones(List<Map<String, dynamic>> opiniones) =>
    FakeApiClient(
      respuestas: {
        ApiConstants.resenasPorProducto('36'): (LlamadaApi _) =>
            <String, dynamic>{
              'success': true,
              'resenas': [...opiniones],
            },
        ApiConstants.login: _login,
        ApiConstants.likeResena('1'): {'success': true, 'liked': true},
      },
    );

Future<ProductReviewsViewModel> _montarOpiniones(
  WidgetTester tester,
  FakeApiClient api,
) async {
  final vm = ProductReviewsViewModel(
    repo: ResenasRepositoryRemote(api: api),
    productoId: _producto.id,
  );
  await tester.pumpApp(
    ProductReviewsScreen(product: _producto, viewModel: vm),
    api: api,
  );
  await tester.pump();
  return vm;
}

/// Cuánto está llena cada barra del resumen, de 5★ a 1★.
List<double> _barras(WidgetTester tester) => [
  for (final relleno in tester.widgetList<FractionallySizedBox>(
    find.descendant(
      of: find.byType(BarraRelleno),
      matching: find.byType(FractionallySizedBox),
    ),
  ))
    relleno.widthFactor!,
];

/// La entrada de la tarjeta (o del bloque) que contiene a [texto].
Finder _entradaDe(String texto) => find
    .ancestor(of: find.text(texto), matching: find.byType(EntradaSuave))
    .first;

bool _resaltada(WidgetTester tester, String comentario) => tester
    .widget<ResaltadoUnaVez>(
      find
          .ancestor(
            of: find.text(comentario),
            matching: find.byType(ResaltadoUnaVez),
          )
          .first,
    )
    .activo;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Escribir opinión', () {
    testWidgets('las estrellas se encienden en fila y la etiqueta rueda', (
      tester,
    ) async {
      await _montarEscribir(tester, FakeApiClient());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.star_border_rounded).at(3));
      await tester.pump();
      // El ícono cambia al instante (las pruebas cuentan estrellas llenas).
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Selecciona una calificación'), findsOneWidget);
      expect(find.text('Muy bueno 😊'), findsOneWidget);
      expect(_movimientoDeEstrella(0), findsWidgets);

      // La tocada (cuarta) empieza tres escalones de cascada después
      // (150 ms).
      await tester.pump(const Duration(milliseconds: 120));
      // La tocada (cuarta) ya se endereza; la quinta no se mueve.
      expect(_movimientoDeEstrella(3), findsWidgets);
      expect(_movimientoDeEstrella(4), findsNothing);
      expect(find.text('Selecciona una calificación'), findsNothing);

      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        expect(_movimientoDeEstrella(i), findsNothing);
      }
      expect(find.text('Muy bueno 😊'), findsOneWidget);
    });

    testWidgets('sin calificación se sacuden las estrellas; con comentario '
        'corto, el campo', (tester) async {
      // Pantalla alta: el aviso flotante del primer intento no tapa el botón
      // en el segundo.
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _montarEscribir(tester, FakeApiClient());
      await tester.pumpAndSettle();
      final estrellas = find.text('¿Qué te pareció el producto?');
      final comentario = find.byType(TextField).last;

      await _publicar(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Selecciona una calificación'), findsNWidgets(2));
      expect(_dxSacudida(tester, estrellas), isNot(0));
      expect(_dxSacudida(tester, comentario), 0);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.star_border_rounded).at(4));
      await tester.enterText(comentario, 'Rico');
      await tester.pumpAndSettle();
      await _publicar(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_dxSacudida(tester, comentario), isNot(0));
      expect(_dxSacudida(tester, estrellas), 0);
      await tester.pumpAndSettle();
    });

    for (final autoAprobada in [true, false]) {
      testWidgets(
        autoAprobada
            ? 'el diálogo de una reseña publicada trae chispas'
            : 'el diálogo de una reseña en revisión no trae chispas',
        (tester) async {
          final api = FakeApiClient(
            respuestas: {
              ApiConstants.crearResena: {
                'success': true,
                'resena': {'auto_aprobada': autoAprobada},
              },
            },
          );
          await _montarEscribir(tester, api);
          await tester.tap(find.byIcon(Icons.star_border_rounded).at(4));
          await tester.enterText(
            find.byType(TextField).last,
            'Delicioso pastel',
          );
          await tester.pump();
          await _publicar(tester);

          expect(find.byType(InsigniaExito), findsOneWidget);
          expect(find.byType(EntradaDialogo), findsOneWidget);
          expect(
            find.byType(Chispas),
            autoAprobada ? findsOneWidget : findsNothing,
          );
          await tester.pumpAndSettle();
        },
      );
    }
  });

  group('Mis reseñas', () {
    testWidgets('el contador aparece con un pop y las estrellas de la hoja '
        'lo dan al encenderse', (tester) async {
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
              {
                'id': 8,
                'rating': 2,
                'comentario': 'Llegó tarde',
                'estado': 'en_revision',
                'producto_nombre': 'Red Velvet',
              },
            ],
          },
        },
      );
      await tester.pumpApp(
        MyReviewsScreen(
          viewModel: MyReviewsViewModel(
            repo: ResenasRepositoryRemote(api: api),
          ),
        ),
        api: api,
      );
      await tester.pump();
      final contador = find
          .ancestor(of: find.text('2'), matching: find.byType(PopAlEntrar))
          .first;
      expect(escalaEn(tester, contador), lessThan(1));
      await tester.pumpAndSettle();
      expect(escalaEn(tester, contador), 1);

      await tester.tap(find.byIcon(LucideIcons.pencil).first);
      await tester.pumpAndSettle();
      expect(find.byType(EstrellaAnimada), findsNWidgets(5));
      await tester.tap(find.byIcon(Icons.star_border_rounded).last);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_movimientoDeEstrella(4), findsWidgets);
      await tester.pumpAndSettle();
      expect(_movimientoDeEstrella(4), findsNothing);
    });

    testWidgets('la reseña que cambia al recargar trae el aro dorado y las '
        'demás no', (tester) async {
      final resenas = <Map<String, Object>>[
        {
          'id': 7,
          'rating': 4,
          'comentario': 'Muy esponjoso',
          'estado': 'aprobada',
          'producto_nombre': 'Fresa Matcha Bliss',
        },
        {
          'id': 8,
          'rating': 2,
          'comentario': 'Llegó tarde',
          'estado': 'en_revision',
          'producto_nombre': 'Red Velvet',
        },
      ];
      final api = FakeApiClient(
        respuestas: {
          ApiConstants.misResenas: (LlamadaApi _) => <String, dynamic>{
            'success': true,
            'resenas': [...resenas],
          },
        },
      );
      final vm = MyReviewsViewModel(repo: ResenasRepositoryRemote(api: api));
      await tester.pumpApp(MyReviewsScreen(viewModel: vm), api: api);
      await tester.pump();
      await tester.pumpAndSettle();
      CustomPaint aroDe(String comentario) => tester.widget<CustomPaint>(
        find
            .descendant(
              of: find
                  .ancestor(
                    of: find.text(comentario),
                    matching: find.byType(ResaltadoUnaVez),
                  )
                  .first,
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      // La primera carga no resalta nada.
      expect(aroDe('Muy esponjoso').foregroundPainter, isNull);
      expect(aroDe('Llegó tarde').foregroundPainter, isNull);

      // Recargar sin cambios tampoco.
      await vm.cargar(silenciosa: true);
      await tester.pump();
      expect(aroDe('Muy esponjoso').foregroundPainter, isNull);

      // La editada cambia en sitio y trae el aro; la otra no.
      resenas[0] = {...resenas[0], 'comentario': 'Muy esponjoso y fresco'};
      await vm.cargar(silenciosa: true);
      await tester.pump();
      expect(aroDe('Muy esponjoso y fresco').foregroundPainter, isNotNull);
      expect(aroDe('Llegó tarde').foregroundPainter, isNull);
      await tester.pumpAndSettle();
    });
  });

  group('Opiniones del producto', () {
    testWidgets('las barras se llenan desde cero; recargar no repite la '
        'entrada y solo la opinión nueva trae el aro', (tester) async {
      final opiniones = [
        _opinion(1, 5, 'El mejor pastel', util: 3),
        _opinion(2, 3, 'Regular'),
      ];
      final api = _backendOpiniones(opiniones);
      final vm = await _montarOpiniones(tester, api);
      expect(_barras(tester), everyElement(0));
      await tester.pumpAndSettle();
      expect(_barras(tester), [0.5, 0, 0.5, 0, 0]);
      expect(opacidadEn(tester, _entradaDe('4.0')), 1);

      // Recarga lenta: pasa por el indicador y vuelve sin repetir entradas.
      api.demorar(
        ApiConstants.resenasPorProducto('36'),
        const Duration(milliseconds: 100),
      );
      // La recién publicada llega primero (las más recientes arriba).
      opiniones.insert(0, _opinion(3, 4, 'Esponjoso'));
      final carga = vm.cargar();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await carga;
      await tester.pump();
      expect(find.text('3 reseñas'), findsOneWidget);
      expect(opacidadEn(tester, _entradaDe('4.0')), 1);
      expect(_barras(tester), [
        closeTo(1 / 3, 0.001),
        closeTo(1 / 3, 0.001),
        closeTo(1 / 3, 0.001),
        0,
        0,
      ]);
      expect(_resaltada(tester, 'Esponjoso'), isTrue);
      expect(_resaltada(tester, 'El mejor pastel'), isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('un filtro reparte las opiniones otra vez, sin salida', (
      tester,
    ) async {
      await _montarOpiniones(
        tester,
        _backendOpiniones([
          _opinion(1, 5, 'El mejor pastel'),
          _opinion(2, 3, 'Regular'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, _entradaDe('El mejor pastel')), 1);

      await tester.tap(find.text('5 ★'));
      await tester.pump();
      expect(find.text('Regular'), findsNothing);
      expect(opacidadEn(tester, _entradaDe('El mejor pastel')), lessThan(1));
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, _entradaDe('El mejor pastel')), 1);
    });

    testWidgets('«útil» da el pop con destello del detalle, su pulgar funde '
        'el color y la cuenta rueda; recargar no lo repite', (tester) async {
      final api = _backendOpiniones([
        _opinion(1, 5, 'El mejor pastel', util: 3),
      ]);
      final vm = await _montarOpiniones(tester, api);
      await tester.iniciarSesion(find.byType(ProductReviewsScreen));
      await tester.pumpAndSettle();
      final cuenta = find.byType(CuentaRodante).first;
      final destello = find.byType(DestelloAlMarcar).first;
      Color? colorPulgar() =>
          tester.widget<Icon>(find.byIcon(LucideIcons.thumbsUp).first).color;
      final apagado = colorPulgar();
      // Quieto mientras nadie lo marca.
      expect(escalaEn(tester, destello), 1);

      await tester.tap(find.byIcon(LucideIcons.thumbsUp).first);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.widget<CuentaRodante>(cuenta).valor, 4);
      expect(
        find.descendant(of: cuenta, matching: find.byType(Text)),
        findsNWidgets(2),
      );
      expect(tester.widget<DestelloAlMarcar>(destello).activo, isTrue);
      expect(escalaEn(tester, destello), greaterThan(1));
      // El pulgar va a medio camino entre los dos colores (no salta).
      expect(colorPulgar(), isNot(apagado));

      await tester.pumpAndSettle();
      expect(
        find.descendant(of: cuenta, matching: find.byType(Text)),
        findsOneWidget,
      );
      expect(escalaEn(tester, destello), 1);
      expect(api.llamo(ApiConstants.likeResena('1')), isTrue);

      // Una recarga deja la marca como estaba y no vuelve a destellar.
      await vm.cargar();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.widget<DestelloAlMarcar>(destello).activo, isTrue);
      expect(escalaEn(tester, destello), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('si desmarcar «útil» falla, la marca vuelve sin destello', (
      tester,
    ) async {
      final api = _backendOpiniones([
        _opinion(1, 5, 'El mejor pastel', util: 3),
      ]);
      await _montarOpiniones(tester, api);
      await tester.iniciarSesion(find.byType(ProductReviewsScreen));
      await tester.pumpAndSettle();
      final destello = find.byType(DestelloAlMarcar).first;
      final pulgar = find.byIcon(LucideIcons.thumbsUp).first;
      await tester.tap(pulgar);
      await tester.pumpAndSettle();
      expect(tester.widget<DestelloAlMarcar>(destello).activo, isTrue);

      // Desmarcar: se apaga al instante y el backend tarda en fallar.
      api
        ..fallar(ApiConstants.likeResena('1'), 'Sin conexión')
        ..demorar(
          ApiConstants.likeResena('1'),
          const Duration(milliseconds: 100),
        );
      await tester.tap(pulgar);
      await tester.pump();
      expect(tester.widget<DestelloAlMarcar>(destello).activo, isFalse);

      // La marca vuelve sola (la cuenta también): no la pidió el toque, así
      // que no se celebra.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<DestelloAlMarcar>(destello).activo, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(escalaEn(tester, destello), 1);
      await tester.pumpAndSettle();
      expect(tester.widget<CuentaRodante>(find.byType(CuentaRodante)).valor, 4);
    });

    testWidgets('con movimiento reducido el resumen y las barras ya están', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      await _montarOpiniones(
        tester,
        _backendOpiniones([
          _opinion(1, 5, 'El mejor pastel'),
          _opinion(2, 3, 'Regular'),
        ]),
      );
      expect(_barras(tester), [0.5, 0, 0.5, 0, 0]);
      expect(opacidadEn(tester, _entradaDe('4.0')), 1);
      expect(opacidadEn(tester, _entradaDe('El mejor pastel')), 1);
    });
  });
}
