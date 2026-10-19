// test/widget/home/movimiento_inicio_test.dart — el movimiento del inicio:
// cada sección entra una sola vez (en cascada, después de la llegada de la
// página) y la que está más abajo espera a que el scroll la traiga; lo de
// adentro entra al compás de su sección y lo que llega tarde llega quieto;
// la ranura de una sección abre y cierra su espacio sin perder lo que
// mostraba; los gestos de los íconos y el barrido de luz terminan en reposo;
// la campana se mece y su insignia crece, salta y se va; el aviso del pedido
// cambia de estado sin duplicar textos y late al quedar listo; el carrusel
// hace paralaje solo mientras desliza, oculto no avanza (al volver no barre
// de golpe), del último slide pasa al primero hacia adelante y, con
// movimiento reducido, salta de slide; mientras cargan los productos se ve su
// esqueleto y la foto de una tarjeta (también la de una oferta de temporada
// o destacada) vuela al detalle con su propio ámbito. Con movimiento
// reducido todo queda en su lugar. Sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/domain/models/order_model.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/core/ui/tarjeta_producto_angosta.dart';
import 'package:pier_reposteria/ui/home/view_model/home_view_model.dart';
import 'package:pier_reposteria/ui/home/widgets/home_carrusel.dart';
import 'package:pier_reposteria/ui/home/widgets/home_encabezado.dart';
import 'package:pier_reposteria/ui/home/widgets/home_promociones.dart';
import 'package:pier_reposteria/ui/home/widgets/home_screen.dart';
import 'package:pier_reposteria/ui/home/widgets/home_secciones.dart';
import 'package:pier_reposteria/ui/home/widgets/movimiento_inicio.dart';
import 'package:pier_reposteria/ui/products/widgets/detalle_galeria.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

// ── Ayudas ──────────────────────────────────────────────────────────────

/// Opacidad de una entrada (su propio FadeTransition), aunque esté fuera de
/// la vista.
double _opacidad(WidgetTester tester, Finder entrada) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: entrada,
            matching: find.byType(FadeTransition, skipOffstage: false),
            skipOffstage: false,
          )
          .first,
    )
    .opacity
    .value;

/// Desplazamiento actual de una entrada (el Transform.translate de su
/// llegada).
Offset _desplazamiento(WidgetTester tester, Finder entrada) {
  final traslado = tester
      .widget<Transform>(
        find
            .descendant(
              of: entrada,
              matching: find.byType(Transform, skipOffstage: false),
              skipOffstage: false,
            )
            .first,
      )
      .transform
      .getTranslation();
  return Offset(traslado.x, traslado.y);
}

/// La entrada que envuelve a [texto] (la más cercana).
Finder _entradaDe(String texto) => find
    .ancestor(
      of: find.text(texto, skipOffstage: false),
      matching: find.byType(EntradaInicio, skipOffstage: false),
    )
    .first;

/// Si todos los Transform del gesto están en reposo.
bool _gestoEnReposo(WidgetTester tester) => tester
    .widgetList<Transform>(
      find.descendant(
        of: find.byType(GestoIcono),
        matching: find.byType(Transform),
      ),
    )
    .every((t) => t.transform.isIdentity());

/// Una sección de prueba de [alto] dp con su [texto].
Widget _seccion(Object id, String texto, {double alto = 300}) =>
    SliverToBoxAdapter(
      child: EntradaInicio(
        id: id,
        child: SizedBox(height: alto, child: Text(texto)),
      ),
    );

Order _pedido(String estado) => Order.fromJson({
  'id': 6,
  'numero': 'P-6',
  'estado': estado,
  'tipo_entrega': 'domicilio',
  'items': <dynamic>[],
});

Map<String, dynamic> _producto(int id, String nombre, {bool popular = false}) =>
    {
      'id': id,
      'nombre': nombre,
      'descripcion': 'Rico $nombre',
      'precio_chico': 300,
      'categoria': 'Pasteles',
      'imagen_url': '',
      'popular': popular,
      'es_nuevo': false,
      'activo': true,
      'rating': 4.5,
      'reviews': 3,
    };

/// Una oferta de [tipo] del producto [productoId], con foto.
Map<String, dynamic> _promo(String tipo, int productoId, String nombre) => {
  'tipo': tipo,
  'producto_id': productoId,
  'producto_nombre': nombre,
  'producto_imagen': 'https://pier.mx/$tipo-$productoId.png',
  'precio_chico': 300,
  'descuento_porcentaje': 10,
  'titulo_banner': 'Promo $nombre',
  'nombre_temporada': 'Temporada de $nombre',
};

FakeApiClient _backend({
  List<Map<String, dynamic>> promociones = const [],
}) => FakeApiClient(
  respuestas: {
    ApiConstants.productos: {
      'success': true,
      'productos': [
        _producto(1, 'Chocoflan', popular: true),
        _producto(2, 'Rosca'),
      ],
    },
    ApiConstants.promocionesActivas: {
      'success': true,
      'promociones': promociones,
    },
    ApiConstants.categorias: {
      'success': true,
      'categorias': [
        {'id': 1, 'nombre': 'Pasteles'},
      ],
    },
    ApiConstants.resenasDestacadas: {
      'success': true,
      'resenas': <Map<String, dynamic>>[],
    },
    ApiConstants.configuracionSeccion('contacto'): {
      'success': true,
      'config': <String, dynamic>{},
    },
    ApiConstants.configuracionSeccion('personalizacion'): {
      'success': true,
      'config': <String, dynamic>{},
    },
    ApiConstants.configuracionSeccion('inicio'): {
      'success': true,
      'config': <String, dynamic>{},
    },
  },
);

/// Pantalla de [ancho]×[alto] lógicos.
void _pantalla(WidgetTester tester, {double ancho = 1080, double alto = 9000}) {
  tester.view
    ..physicalSize = Size(ancho, alto)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Desmonta para cancelar el carrusel (Timer) y el sondeo.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('EntradaInicio', () {
    testWidgets('sola: entra una vez desde abajo y termina en su lugar', (
      tester,
    ) async {
      await montarMovimiento(tester, const EntradaInicio(child: Text('Hola')));
      final entrada = find.byType(EntradaInicio);
      expect(_opacidad(tester, entrada), 0);
      expect(
        _desplazamiento(tester, entrada),
        const Offset(0, AppMovimiento.distancia),
      );

      await tester.pump(); // tic 0
      await tester.pump(const Duration(milliseconds: 175));
      expect(_opacidad(tester, entrada), greaterThan(0));
      expect(
        _desplazamiento(tester, entrada).dy,
        inExclusiveRange(0, AppMovimiento.distancia),
      );

      await tester.pump(AppMovimiento.entrada);
      expect(_opacidad(tester, entrada), 1);
      expect(_desplazamiento(tester, entrada), Offset.zero);

      // Reconstruir no la repite.
      await montarMovimiento(tester, const EntradaInicio(child: Text('Hola')));
      await tester.pump();
      expect(_opacidad(tester, entrada), 1);
    });

    testWidgets('con id pero sin VistaInicio entra sola', (tester) async {
      await montarMovimiento(
        tester,
        const EntradaInicio(id: 'x', child: Text('Hola')),
      );
      await tester.pump();
      await tester.pump(AppMovimiento.entrada);
      expect(_opacidad(tester, find.byType(EntradaInicio)), 1);
    });

    testWidgets('con movimiento reducido aparece en su lugar', (tester) async {
      await montarMovimiento(
        tester,
        const EntradaInicio(child: Text('Hola')),
        reducido: true,
      );
      final entrada = find.byType(EntradaInicio);
      expect(_opacidad(tester, entrada), 1);
      expect(_desplazamiento(tester, entrada), Offset.zero);
    });

    testWidgets('lo de adentro entra después de su sección, en su escalón', (
      tester,
    ) async {
      await montarMovimiento(
        tester,
        const EntradaInicio(
          child: Column(
            children: [
              Text('Título'),
              EntradaInicio(orden: 2, child: Text('Tarjeta')),
            ],
          ),
        ),
      );
      final seccion = find.byType(EntradaInicio).first;
      final tarjeta = find.byType(EntradaInicio).last;
      await tester.pump(); // tic 0
      await tester.pump(const Duration(milliseconds: 90));
      // La sección ya empezó; la tarjeta espera sus dos escalones (100 ms).
      expect(_opacidad(tester, seccion), greaterThan(0));
      expect(_opacidad(tester, tarjeta), 0);

      await tester.pump(const Duration(milliseconds: 600));
      expect(_opacidad(tester, tarjeta), 1);
      expect(_desplazamiento(tester, tarjeta), Offset.zero);
    });

    testWidgets('lo que se monta a media entrada de su sección la alcanza; '
        'lo que llega cuando ya entró, llega quieto', (tester) async {
      Widget arbol({required int tarjetas}) => EntradaInicio(
        child: Column(
          children: [
            const Text('Título'),
            for (var i = 0; i < tarjetas; i++)
              EntradaInicio(orden: 1, child: Text('Tarjeta $i')),
          ],
        ),
      );
      await montarMovimiento(tester, arbol(tarjetas: 0));
      await tester.pump(); // tic 0
      await tester.pump(const Duration(milliseconds: 100));

      // A media entrada: la tarjeta todavía se mueve.
      await montarMovimiento(tester, arbol(tarjetas: 1));
      expect(_opacidad(tester, _entradaDe('Tarjeta 0')), lessThan(1));
      await tester.pump(const Duration(milliseconds: 600));
      expect(_opacidad(tester, _entradaDe('Tarjeta 0')), 1);

      // Con la sección ya en su lugar: llega quieta desde el primer cuadro.
      await montarMovimiento(tester, arbol(tarjetas: 2));
      expect(_opacidad(tester, _entradaDe('Tarjeta 1')), 1);
      expect(_desplazamiento(tester, _entradaDe('Tarjeta 1')), Offset.zero);
    });
  });

  group('VistaInicio', () {
    testWidgets('lo que ya se ve entra en cascada después de la llegada', (
      tester,
    ) async {
      await montarMovimiento(
        tester,
        VistaInicio(
          retrasoLlegada: AppMovimiento.trasRaiz,
          child: CustomScrollView(
            slivers: [_seccion('a', 'Primera'), _seccion('b', 'Segunda')],
          ),
        ),
      );
      final primera = _entradaDe('Primera');
      final segunda = _entradaDe('Segunda');
      await tester.pump(); // tic 0
      await tester.pump(const Duration(milliseconds: 100));
      // Todavía espera a que la página empiece a verse (110 ms).
      expect(_opacidad(tester, primera), 0);

      await tester.pump(const Duration(milliseconds: 50));
      // La primera ya entra; la segunda va un escalón (50 ms) atrás.
      expect(_opacidad(tester, primera), greaterThan(0));
      expect(_opacidad(tester, segunda), 0);

      await tester.pump(const Duration(seconds: 1));
      expect(_opacidad(tester, primera), 1);
      expect(_opacidad(tester, segunda), 1);
    });

    testWidgets('lo de abajo espera al scroll y entra al verse', (
      tester,
    ) async {
      final control = ScrollController();
      addTearDown(control.dispose);
      await montarMovimiento(
        tester,
        VistaInicio(
          child: CustomScrollView(
            controller: control,
            slivers: [
              _seccion('a', 'Arriba'),
              _seccion('b', 'Lejos', alto: 1500),
              _seccion('c', 'Abajo'),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_opacidad(tester, _entradaDe('Arriba')), 1);
      // No gastó su entrada fuera de la pantalla.
      expect(_opacidad(tester, _entradaDe('Abajo')), 0);

      control.jumpTo(control.position.maxScrollExtent);
      await tester.pump(); // revisa después del layout
      await tester.pump(); // tic 0
      await tester.pump(const Duration(milliseconds: 150));
      expect(_opacidad(tester, _entradaDe('Abajo')), greaterThan(0));
      await tester.pump(AppMovimiento.entrada);
      expect(_opacidad(tester, _entradaDe('Abajo')), 1);
    });

    testWidgets('las que se destapan juntas entran de arriba abajo aunque '
        'hayan llegado en tandas distintas', (tester) async {
      final control = ScrollController();
      addTearDown(control.dispose);
      Widget seccion(String id, String texto, double alto) =>
          SliverToBoxAdapter(
            key: ValueKey(id),
            child: EntradaInicio(
              id: id,
              child: SizedBox(height: alto, child: Text(texto)),
            ),
          );
      Widget arbol({required bool conMedia}) => VistaInicio(
        child: CustomScrollView(
          controller: control,
          slivers: [
            seccion('a', 'Arriba', 1500),
            if (conMedia) seccion('b', 'Media', 100),
            seccion('c', 'Abajo', 100),
          ],
        ),
      );
      await montarMovimiento(tester, arbol(conMedia: false));
      await tester.pump();
      // «Media» llega en otra tanda, arriba de «Abajo»: las dos esperan.
      await montarMovimiento(tester, arbol(conMedia: true));
      await tester.pump(const Duration(seconds: 1));
      expect(_opacidad(tester, _entradaDe('Media')), 0);
      expect(_opacidad(tester, _entradaDe('Abajo')), 0);

      control.jumpTo(control.position.maxScrollExtent);
      await tester.pump(); // revisa después del layout
      await tester.pump(); // tic 0
      await tester.pump(const Duration(milliseconds: 30));
      // Primero la de arriba; la de abajo, un escalón después.
      expect(_opacidad(tester, _entradaDe('Media')), greaterThan(0));
      expect(_opacidad(tester, _entradaDe('Abajo')), 0);

      await tester.pump(const Duration(seconds: 1));
      expect(_opacidad(tester, _entradaDe('Media')), 1);
      expect(_opacidad(tester, _entradaDe('Abajo')), 1);
    });

    testWidgets('una sección que se va y vuelve no repite su entrada', (
      tester,
    ) async {
      Widget arbol({required bool visible}) => VistaInicio(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: RanuraInicio(
                child: visible
                    ? const EntradaInicio(
                        id: 'x',
                        child: SizedBox(height: 100, child: Text('Sección')),
                      )
                    : null,
              ),
            ),
          ],
        ),
      );
      await montarMovimiento(tester, arbol(visible: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_opacidad(tester, _entradaDe('Sección')), 1);

      await montarMovimiento(tester, arbol(visible: false));
      await tester.pumpAndSettle();
      expect(find.text('Sección'), findsNothing);

      // Vuelve sin repetir su entrada (solo el fundido de la ranura).
      await montarMovimiento(tester, arbol(visible: true));
      expect(_opacidad(tester, _entradaDe('Sección')), 1);
      await tester.pumpAndSettle();
    });
  });

  group('RanuraInicio', () {
    testWidgets('abre su espacio al llegar y lo cierra al irse sin perder '
        'lo que mostraba', (tester) async {
      Widget arbol({Widget? aviso}) => Column(
        children: [
          RanuraInicio(child: aviso),
          const Text('Debajo'),
        ],
      );
      await montarMovimiento(tester, arbol());
      final ranura = find.byType(RanuraInicio);
      expect(tester.getSize(ranura).height, 0);

      await montarMovimiento(
        tester,
        arbol(aviso: const SizedBox(height: 80, child: Text('Aviso'))),
      );
      expect(find.text('Aviso'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(ranura).height, inExclusiveRange(0, 80));
      await tester.pumpAndSettle();
      expect(tester.getSize(ranura).height, 80);

      // Se va: el aviso se apaga (sigue en el árbol) y luego sale.
      await montarMovimiento(tester, arbol());
      expect(find.text('Aviso'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Aviso'), findsNothing);
      expect(tester.getSize(ranura).height, 0);
    });
  });

  group('GestoIcono', () {
    for (final tipo in TipoGesto.values) {
      testWidgets('${tipo.name} hace su gesto una vez y termina en reposo', (
        tester,
      ) async {
        await montarMovimiento(
          tester,
          GestoIcono(
            tipo: tipo,
            retraso: Duration.zero,
            child: const Icon(Icons.star),
          ),
        );
        expect(_gestoEnReposo(tester), isTrue);
        await tester.pump(); // arma y tic 0
        await tester.pump(GestoIcono.duracionDe(tipo) ~/ 3);
        expect(_gestoEnReposo(tester), isFalse);

        await tester.pump(GestoIcono.duracionDe(tipo));
        expect(_gestoEnReposo(tester), isTrue);
      });
    }

    testWidgets('espera a su sección y queda quieto si ya había entrado', (
      tester,
    ) async {
      Widget arbol({required bool conIcono}) => EntradaInicio(
        child: Column(
          children: [
            const Text('Título'),
            if (conIcono)
              const GestoIcono(
                tipo: TipoGesto.brinco,
                child: Icon(Icons.star),
              ),
          ],
        ),
      );
      await montarMovimiento(tester, arbol(conIcono: true));
      await tester.pump(); // tic 0
      await tester.pump(const Duration(milliseconds: 100));
      // Armado: espera su retraso con la forma del inicio del brinco.
      expect(_gestoEnReposo(tester), isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(_gestoEnReposo(tester), isTrue);

      await montarMovimiento(tester, arbol(conIcono: false));
      await montarMovimiento(tester, arbol(conIcono: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_gestoEnReposo(tester), isTrue);
    });

    testWidgets('con movimiento reducido se queda quieto', (tester) async {
      await montarMovimiento(
        tester,
        const GestoIcono(tipo: TipoGesto.vuelta, child: Icon(Icons.star)),
        reducido: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_gestoEnReposo(tester), isTrue);
    });
  });

  group('BarridoDeLuz', () {
    testWidgets('la luz cruza una vez y se apaga', (tester) async {
      await montarMovimiento(
        tester,
        BarridoDeLuz(
          radio: BorderRadius.circular(12),
          retraso: Duration.zero,
          child: const SizedBox(width: 120, height: 40),
        ),
      );
      final lienzo = find.descendant(
        of: find.byType(BarridoDeLuz),
        matching: find.byType(CustomPaint),
      );
      await tester.pump(); // arma y tic 0
      await tester.pump(BarridoDeLuz.duracion ~/ 2);
      expect(tester.renderObject(lienzo), paints..rect());

      await tester.pumpAndSettle();
      expect(tester.renderObject(lienzo), isNot(paints..rect()));
    });

    testWidgets('con movimiento reducido no hay barrido', (tester) async {
      await montarMovimiento(
        tester,
        BarridoDeLuz(
          radio: BorderRadius.circular(12),
          retraso: Duration.zero,
          child: const SizedBox(width: 120, height: 40),
        ),
        reducido: true,
      );
      await tester.pump();
      await tester.pump(BarridoDeLuz.duracion ~/ 2);
      expect(
        tester.renderObject(
          find.descendant(
            of: find.byType(BarridoDeLuz),
            matching: find.byType(CustomPaint),
          ),
        ),
        isNot(paints..rect()),
      );
    });
  });

  testWidgets('FotoConFundido: la de caché se pinta tal cual y la de red '
      'aparece con un fundido', (tester) async {
    await montarMovimiento(
      tester,
      const FotoConFundido(foto: Text('Foto'), cuadro: null, sincrona: true),
    );
    expect(find.byType(AnimatedOpacity), findsNothing);

    await montarMovimiento(
      tester,
      const FotoConFundido(foto: Text('Foto'), cuadro: null, sincrona: false),
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    await montarMovimiento(
      tester,
      const FotoConFundido(foto: Text('Foto'), cuadro: 0, sincrona: false),
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });

  group('CampanaNotificaciones', () {
    double giro(WidgetTester tester) => tester
        .widget<RotationTransition>(
          find.descendant(
            of: find.byType(CampanaNotificaciones),
            matching: find.byType(RotationTransition),
          ),
        )
        .turns
        .value;

    testWidgets('al montarse con avisos no anima', (tester) async {
      await montarMovimiento(tester, const CampanaNotificaciones(cantidad: 3));
      expect(find.text('3'), findsOneWidget);
      expect(escalaEn(tester, find.byType(CampanaNotificaciones)), 1);
      expect(giro(tester), 0);
    });

    testWidgets('cuando llegan avisos se mece y la insignia crece; al '
        'leerlos se encoge y se va', (tester) async {
      await montarMovimiento(tester, const CampanaNotificaciones(cantidad: 0));
      expect(
        find.descendant(
          of: find.byType(CampanaNotificaciones),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );

      await montarMovimiento(tester, const CampanaNotificaciones(cantidad: 12));
      expect(find.text('9+'), findsOneWidget);
      // El primer vaivén llega a su punto más alto a 1/12 del meneo.
      await tester.pump(AppMovimiento.relleno ~/ 12);
      expect(giro(tester), isNot(0));
      expect(
        escalaEn(tester, find.byType(CampanaNotificaciones)),
        greaterThan(0),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(giro(tester), 0);
      expect(escalaEn(tester, find.byType(CampanaNotificaciones)), 1);

      // Al leerlos: se encoge con su último número y sale del árbol.
      await montarMovimiento(tester, const CampanaNotificaciones(cantidad: 0));
      expect(find.text('9+'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('9+'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('si sube la cuenta la insignia salta y vuelve a su tamaño', (
      tester,
    ) async {
      await montarMovimiento(tester, const CampanaNotificaciones(cantidad: 2));
      await montarMovimiento(tester, const CampanaNotificaciones(cantidad: 5));
      expect(find.text('5'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      double salto() => tester
          .widgetList<ScaleTransition>(
            find.descendant(
              of: find.byType(CampanaNotificaciones),
              matching: find.byType(ScaleTransition),
            ),
          )
          .last
          .scale
          .value;
      expect(salto(), greaterThan(1));
      await tester.pumpAndSettle();
      expect(salto(), 1);

      // Si baja, solo cambia el número.
      await montarMovimiento(tester, const CampanaNotificaciones(cantidad: 4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(salto(), 1);
      expect(giro(tester), 0);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('con movimiento reducido ni se mece ni salta', (tester) async {
      await montarMovimiento(
        tester,
        const CampanaNotificaciones(cantidad: 0),
        reducido: true,
      );
      await montarMovimiento(
        tester,
        const CampanaNotificaciones(cantidad: 4),
        reducido: true,
      );
      expect(escalaEn(tester, find.byType(CampanaNotificaciones)), 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(giro(tester), 0);
      expect(find.text('4'), findsOneWidget);
    });
  });

  group('PedidoActivoBanner', () {
    double latido(WidgetTester tester) => tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.byIcon(Icons.check_circle_outline_rounded),
            matching: find.byType(Transform),
          ),
        )
        .map((t) => t.transform.getMaxScaleOnAxis())
        .reduce((a, b) => a * b);

    testWidgets('al cambiar de estado el mensaje rueda al nuevo sin '
        'quedarse duplicado y el ícono late una vez al quedar listo', (
      tester,
    ) async {
      await montarMovimiento(
        tester,
        PedidoActivoBanner(pedido: _pedido('preparando'), alCambiar: (_) {}),
      );
      expect(find.text('Pedido #P-6 en preparación'), findsOneWidget);

      await montarMovimiento(
        tester,
        PedidoActivoBanner(pedido: _pedido('listo'), alCambiar: (_) {}),
      );
      expect(
        find.text('Pedido #P-6 listo, buscando repartidor'),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 225));
      expect(latido(tester), greaterThan(1.05));

      await tester.pumpAndSettle();
      expect(find.text('Pedido #P-6 en preparación'), findsNothing);
      expect(
        find.text('Pedido #P-6 listo, buscando repartidor'),
        findsOneWidget,
      );
      expect(latido(tester), 1);
    });

    testWidgets('si aparece ya listo, late después de abrir su espacio', (
      tester,
    ) async {
      await montarMovimiento(
        tester,
        PedidoActivoBanner(pedido: _pedido('listo'), alCambiar: (_) {}),
      );
      await tester.pump(); // arma y tic 0
      await tester.pump(const Duration(milliseconds: 200));
      expect(latido(tester), 1);
      await tester.pump(const Duration(milliseconds: 325));
      expect(latido(tester), greaterThan(1.05));
      await tester.pumpAndSettle();
      expect(latido(tester), 1);
    });

    testWidgets('con movimiento reducido el ícono no late', (tester) async {
      await montarMovimiento(
        tester,
        PedidoActivoBanner(pedido: _pedido('preparando'), alCambiar: (_) {}),
        reducido: true,
      );
      await montarMovimiento(
        tester,
        PedidoActivoBanner(pedido: _pedido('listo'), alCambiar: (_) {}),
        reducido: true,
      );
      await tester.pump(const Duration(milliseconds: 225));
      expect(latido(tester), 1);
      await tester.pumpAndSettle();
      expect(find.text('Pedido #P-6 en preparación'), findsNothing);
    });
  });

  group('HomeCarrusel', () {
    const slides = HomeViewModel.slidesDeRespaldo;

    // Las fotos del carrusel (la página del MaterialApp tiene las suyas).
    Finder fotos() => find.descendant(
      of: find.byType(HomeCarrusel),
      matching: find.byType(FractionalTranslation),
    );

    Iterable<double> paralaje(WidgetTester tester) => tester
        .widgetList<FractionalTranslation>(fotos())
        .map((t) => t.translation.dx);

    List<double> puntos(WidgetTester tester) => tester
        .widgetList<Container>(
          find.descendant(
            of: find.descendant(
              of: find.byType(HomeCarrusel),
              matching: find.byType(Positioned),
            ),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.constraints!.maxWidth)
        .toList();

    testWidgets('en reposo todo en su lugar; al deslizar la foto y los '
        'puntos siguen al dedo', (tester) async {
      await montarMovimiento(
        tester,
        const SizedBox(
          width: 360,
          child: HomeCarrusel(slides: slides, intervalo: Duration(minutes: 5)),
        ),
      );
      await tester.pump();
      expect(paralaje(tester), everyElement(0));
      expect(puntos(tester), [18, 6, 6]);

      final gesto = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesto.moveBy(const Offset(-30, 0));
      await gesto.moveBy(const Offset(-130, 0));
      await tester.pump();
      // Las dos páginas se ven: sus fotos van desfasadas de la página.
      expect(paralaje(tester).where((dx) => dx != 0), isNotEmpty);
      expect(puntos(tester).first, inExclusiveRange(6, 18));

      await gesto.up();
      await tester.pumpAndSettle();
      expect(paralaje(tester), everyElement(0));
      await _desmontar(tester);
    });

    testWidgets('con movimiento reducido salta de slide sin deslizarse', (
      tester,
    ) async {
      await montarMovimiento(
        tester,
        const SizedBox(
          width: 360,
          child: HomeCarrusel(slides: slides, intervalo: Duration(seconds: 2)),
        ),
        reducido: true,
      );
      expect(fotos(), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      // Ya está en el segundo slide: no hay página a medio camino.
      expect(find.text('Pasteles\nde Autor'), findsOneWidget);
      expect(find.text('Tradición en cada\nRebanada'), findsNothing);
      expect(paralaje(tester), everyElement(0));
      await _desmontar(tester);
    });

    /// Página actual del carrusel (con decimales mientras desliza).
    double pagina(WidgetTester tester) =>
        tester.widget<PageView>(find.byType(PageView)).controller!.page!;

    /// Avanza [total] en cuadros de 100 ms, como una pantalla de verdad.
    Future<void> esperar(WidgetTester tester, Duration total) async {
      for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 100)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('oculto no avanza: al volver a verse no barre de golpe', (
      tester,
    ) async {
      Widget carrusel({required bool visible}) => TickerMode(
        enabled: visible,
        child: const SizedBox(
          width: 360,
          child: HomeCarrusel(slides: slides, intervalo: Duration(seconds: 2)),
        ),
      );
      // Dos intervalos en una pestaña oculta (o bajo otra ruta).
      await montarMovimiento(tester, carrusel(visible: false));
      await esperar(tester, const Duration(milliseconds: 4500));
      expect(pagina(tester), 0);

      // Al volver no quedó un deslizamiento congelado que se suelte ahora.
      await montarMovimiento(tester, carrusel(visible: true));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(pagina(tester), 0);
      }
      expect(puntos(tester), [18, 6, 6]);

      // Y sigue con su ritmo: un slide en el siguiente intervalo.
      await esperar(tester, const Duration(milliseconds: 1600));
      expect(pagina(tester), 1);
      await _desmontar(tester);
    });

    testWidgets('del último slide pasa al primero hacia adelante (sin '
        'rebobinar) y sigue desde el primero', (tester) async {
      await montarMovimiento(
        tester,
        const SizedBox(
          width: 360,
          child: HomeCarrusel(slides: slides, intervalo: Duration(seconds: 2)),
        ),
      );
      await esperar(tester, const Duration(milliseconds: 4900));
      expect(pagina(tester), 2);
      expect(puntos(tester), [6, 6, 18]);

      // A media vuelta va de 2 hacia 3 (la copia del primero), no hacia 0.
      await esperar(tester, const Duration(milliseconds: 1500));
      expect(pagina(tester), inExclusiveRange(2, 3));
      expect(find.text('Tradición en cada\nRebanada'), findsOneWidget);

      // Al quedar quieto salta al primero de verdad, sin que se note.
      await esperar(tester, const Duration(milliseconds: 600));
      expect(pagina(tester), 0);
      expect(puntos(tester), [18, 6, 6]);
      expect(paralaje(tester), everyElement(0));
      expect(find.text('Tradición en cada\nRebanada'), findsOneWidget);

      // El siguiente avanza del primero al segundo, también hacia adelante.
      await esperar(tester, const Duration(milliseconds: 1500));
      expect(pagina(tester), inExclusiveRange(0, 1));
      await esperar(tester, const Duration(milliseconds: 600));
      expect(pagina(tester), 1);
      await _desmontar(tester);
    });
  });

  group('HomeScreen', () {
    testWidgets('la foto de una tarjeta vuela al detalle con el ámbito de su '
        'carrusel', (tester) async {
      _pantalla(tester, alto: 2400);
      await tester.pumpApp(const HomeScreen(), api: _backend());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // Chocoflan está en Destacados y en Mejor calificados: cada tarjeta
      // tiene su propia etiqueta (dos iguales no pueden convivir).
      final etiquetas = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((hero) => hero.tag)
          .toList();
      expect(etiquetas.toSet(), hasLength(etiquetas.length));
      expect(
        etiquetas,
        containsAll(<Object>[
          FotoProductoHero.etiqueta('1', ambito: 'inicio-Destacados'),
          FotoProductoHero.etiqueta('1', ambito: 'inicio-Mejor calificados'),
        ]),
      );

      final tarjeta = find
          .ancestor(
            of: find.text('Rico Rosca'),
            matching: find.byType(TarjetaProductoAngosta),
          )
          .first;
      Finder fotoDe(Finder tarjeta) => find.descendant(
        of: find.descendant(
          of: tarjeta,
          matching: find.byType(FotoProductoHero),
        ),
        matching: find.byType(Image),
      );
      expect(fotoDe(tarjeta), findsOneWidget);

      await tester.tap(find.text('Rico Rosca'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // A medio vuelo la tarjeta deja su hueco (la foto va en el aire).
      expect(fotoDe(tarjeta), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      final galeria = tester.widget<FotoProductoHero>(
        find.descendant(
          of: find.byType(DetalleGaleria),
          matching: find.byType(FotoProductoHero),
        ),
      );
      expect(galeria.productoId, '2');
      expect(galeria.ambito, 'inicio-Mejor calificados');
      await _desmontar(tester);
    });

    testWidgets('la foto de una oferta de temporada o destacada también vuela '
        'al detalle, con su propio ámbito', (tester) async {
      _pantalla(tester);
      await tester.pumpApp(
        const HomeScreen(),
        api: _backend(
          promociones: [
            _promo('temporada', 1, 'Chocoflan'),
            _promo('destacado', 1, 'Chocoflan'),
            _promo('relampago', 2, 'Rosca'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // Chocoflan está en una oferta de temporada, en una destacada y en dos
      // carruseles: cada tarjeta tiene su propia etiqueta.
      final etiquetas = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((hero) => hero.tag)
          .toList();
      expect(etiquetas.toSet(), hasLength(etiquetas.length));
      expect(
        etiquetas,
        containsAll(<Object>[
          FotoProductoHero.etiqueta('1', ambito: 'inicio-temporada-0'),
          FotoProductoHero.etiqueta('1', ambito: 'inicio-destacado-0'),
          FotoProductoHero.etiqueta('1', ambito: 'inicio-Destacados'),
        ]),
      );
      // La relámpago no vuela: su foto es el fondo, bajo el degradado.
      expect(
        find.descendant(
          of: find.byType(HomeOfertasRelampago),
          matching: find.byType(Hero),
        ),
        findsNothing,
      );

      final fotoTemporada = find.descendant(
        of: find.descendant(
          of: find.byType(HomeOfertasTemporada),
          matching: find.byType(FotoProductoHero),
        ),
        matching: find.byType(Image),
      );
      expect(fotoTemporada, findsOneWidget);

      await tester.tap(find.text('Temporada de Chocoflan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // A medio vuelo la foto ya no está en la tarjeta: va en el aire.
      expect(fotoTemporada, findsNothing);

      await tester.pump(const Duration(seconds: 1));
      final galeria = tester.widget<FotoProductoHero>(
        find.descendant(
          of: find.byType(DetalleGaleria),
          matching: find.byType(FotoProductoHero),
        ),
      );
      expect(galeria.productoId, '1');
      expect(galeria.ambito, 'inicio-temporada-0');
      await _desmontar(tester);
    });

    testWidgets('mientras cargan los productos se ve su esqueleto y al '
        'llegar, la sección', (tester) async {
      _pantalla(tester);
      final api = _backend()
        ..demorar(ApiConstants.productos, const Duration(seconds: 1));
      await tester.pumpApp(const HomeScreen(), api: api);
      await tester.pump();
      // Su ranura abre el espacio (en el primer cuadro mide 0).
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(HomeSeccionProductosEsqueleto), findsOneWidget);
      expect(find.text('Destacados'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Destacados'), findsOneWidget);
      expect(find.byType(HomeSeccionProductosEsqueleto), findsNothing);
      await _desmontar(tester);
    });

    testWidgets('lo que ya se ve espera la llegada de la página y lo de '
        'abajo espera al scroll', (tester) async {
      _pantalla(tester, alto: 800);
      await tester.pumpApp(const HomeScreen(), api: _backend());
      await tester.pump(); // tic 0 de la primera tanda
      await tester.pump(const Duration(milliseconds: 60));
      // El encabezado espera a que la página (context.go) empiece a verse.
      expect(_opacidad(tester, _entradaDe('Bienvenido')), 0);

      await tester.pump(const Duration(seconds: 1));
      expect(_opacidad(tester, _entradaDe('Bienvenido')), 1);
      // «¿Por qué elegirnos?» está muy abajo: no gastó su entrada.
      expect(_opacidad(tester, _entradaDe('¿Por qué elegirnos?')), 0);

      await tester.scrollUntilVisible(
        find.text('¿Por qué elegirnos?'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(_opacidad(tester, _entradaDe('¿Por qué elegirnos?')), 1);
      await _desmontar(tester);
    });

    testWidgets('con movimiento reducido todo está en su lugar desde el '
        'primer cuadro', (tester) async {
      activarReducirMovimientoIos(tester);
      _pantalla(tester);
      await tester.pumpApp(const HomeScreen(), api: _backend());
      await tester.pump();
      final entradas = find.byType(EntradaInicio, skipOffstage: false);
      expect(entradas, findsWidgets);
      for (final entrada in entradas.evaluate()) {
        final propia = find.byElementPredicate(
          (elemento) => elemento == entrada,
          skipOffstage: false,
        );
        expect(_opacidad(tester, propia), 1);
        expect(_desplazamiento(tester, propia), Offset.zero);
      }
      await _desmontar(tester);
    });
  });
}
