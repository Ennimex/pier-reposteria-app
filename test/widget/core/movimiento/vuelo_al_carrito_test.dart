// test/widget/core/movimiento/vuelo_al_carrito_test.dart — VueloAlCarrito:
// sin ámbito (pruebas sueltas) no hace nada; con ámbito la miniatura vuela
// en el Overlay raíz del botón al ícono del carrito, se quita sola y el ícono
// da un trago; la miniatura reusa la foto en caché de la tarjeta y mientras
// carga es un disco dorado; no vuela con «reducir movimiento», sin destino,
// con un contexto desmontado ni desde una ruta tapada, admite tres vuelos a
// la vez y se limpia si el ámbito se desmonta a medio vuelo. lanzarAlConfirmar
// (alta que espera al backend) reserva el vuelo al tocar, vuela solo si el
// backend acepta y devuelve lo mismo que el alta.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/foto_producto.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

/// La miniatura en vuelo (lo único con ClipOval en estas pruebas).
Finder get _miniatura => find.byType(ClipOval);

Finder get _boton => find.text('Agregar');

/// Pantalla con un botón «Agregar» arriba y el carrito abajo.
class _Tienda extends StatelessWidget {
  const _Tienda({
    this.conDestino = true,
    this.origen,
    this.desde,
    this.imagenUrl = '',
  });

  final bool conDestino;
  final GlobalKey? origen;
  final Rect? desde;
  final String imagenUrl;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(key: origen, dimension: 60),
          Builder(
            builder: (contexto) => ElevatedButton(
              onPressed: () => VueloAlCarrito.lanzar(
                contexto,
                imagenUrl: imagenUrl,
                origen: origen,
                desde: desde,
              ),
              child: const Text('Agregar'),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SizedBox(
      height: 56,
      child: Center(
        child: conDestino
            ? const DestinoVuelo(child: Icon(Icons.shopping_cart))
            : const Icon(Icons.shopping_cart),
      ),
    ),
  );
}

Widget _app(Widget tienda, {bool conAmbito = true, bool reducido = false}) {
  var pantalla = conAmbito ? VueloAlCarrito(child: tienda) : tienda;
  if (reducido) pantalla = ConMovimientoReducido(child: pantalla);
  return MaterialApp(home: pantalla);
}

/// Cliente HTTP cuya petición nunca responde (la foto nunca termina de
/// cargar).
class _RedSinRespuesta extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Completer<HttpClientRequest>().future;
}

double _escalaDestino(WidgetTester tester) => escalaEn(
  tester,
  find.ancestor(
    of: find.byIcon(Icons.shopping_cart),
    matching: find.byType(DestinoVuelo),
  ),
);

/// Miniaturas en el aire o reservadas, como las ve la insignia del carrito.
int _enCamino(WidgetTester tester) => DestinoVuelo.enCamino(
  tester.element(find.byIcon(Icons.shopping_cart, skipOffstage: false)),
)!.value;

/// Como el detalle: «Añadir» espera al backend ([respuesta], que completa la
/// prueba) con lanzarAlConfirmar y anota lo que devuelve. Mientras espera, la
/// prueba puede ocultar el botón (como en una pestaña oculta) o quitarlo (la
/// pantalla se cerró).
class _Detalle extends StatefulWidget {
  const _Detalle({required this.respuesta, required this.resultados});

  final Completer<String?> respuesta;
  final List<Object?> resultados;

  @override
  State<_Detalle> createState() => _DetalleState();
}

class _DetalleState extends State<_Detalle> {
  bool _oculto = false;
  bool _cerrado = false;

  void ocultar() => setState(() => _oculto = true);

  void cerrar() => setState(() => _cerrado = true);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: _cerrado
          ? const SizedBox.shrink()
          : TickerMode(
              enabled: !_oculto,
              child: Builder(
                builder: (contexto) => ElevatedButton(
                  onPressed: () async {
                    try {
                      widget.resultados.add(
                        await VueloAlCarrito.lanzarAlConfirmar(
                          contexto,
                          widget.respuesta.future,
                          imagenUrl: '',
                        ),
                      );
                    } on SocketException catch (error) {
                      widget.resultados.add(error);
                    }
                  },
                  child: const Text('Añadir'),
                ),
              ),
            ),
    ),
    bottomNavigationBar: const SizedBox(
      height: 56,
      child: Center(child: DestinoVuelo(child: Icon(Icons.shopping_cart))),
    ),
  );
}

/// Toca «Añadir» y deja pasar 300 ms sin respuesta del backend.
Future<void> _anadirYEsperar(WidgetTester tester) async {
  await tester.tap(find.text('Añadir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Deja correr la respuesta del backend: el primer pump vacía las microtareas
/// (sigue lanzarAlConfirmar) y el segundo pinta lo que haya lanzado.
Future<void> _trasResponder(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('sin ámbito no hace nada', (tester) async {
    await tester.pumpWidget(_app(const _Tienda(), conAmbito: false));
    await tester.tap(_boton);
    await tester.pump();
    expect(_miniatura, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vuela del botón al carrito en el Overlay raíz y se quita', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Tienda()));
    final boton = tester.getCenter(_boton);
    final carrito = tester.getCenter(find.byIcon(Icons.shopping_cart));

    await tester.tap(_boton);
    await tester.pump();
    expect(_miniatura, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Overlay).first,
        matching: _miniatura,
      ),
      findsOneWidget,
    );
    expect(tester.getCenter(_miniatura), boton);

    await tester.pump(const Duration(milliseconds: 280));
    final enMedio = tester.getCenter(_miniatura);
    expect(enMedio.dy, inExclusiveRange(boton.dy - 200, carrito.dy));

    await tester.pump(const Duration(milliseconds: 300));
    expect(_miniatura, findsNothing);
    // Al aterrizar, el ícono del carrito da un trago.
    await tester.pump(const Duration(milliseconds: 100));
    expect(_escalaDestino(tester), greaterThan(1));
    await tester.pump(AppMovimiento.media);
    expect(_escalaDestino(tester), 1);
  });

  testWidgets('el origen puede ser una GlobalKey o un rectángulo', (
    tester,
  ) async {
    final foto = GlobalKey();
    await tester.pumpWidget(_app(_Tienda(origen: foto)));
    await tester.tap(_boton);
    await tester.pump();
    expect(
      tester.getCenter(_miniatura),
      tester.getCenter(find.byKey(foto)),
    );
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(AppMovimiento.media);

    const rect = Rect.fromLTWH(10, 400, 40, 40);
    await tester.pumpWidget(_app(const _Tienda(desde: rect)));
    await tester.tap(_boton);
    await tester.pump();
    expect(tester.getCenter(_miniatura), rect.center);
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(AppMovimiento.media);
  });

  testWidgets('con una URL muestra la foto (y arena dorada si falla)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const _Tienda(imagenUrl: 'https://pier.mx/pastel.png')),
    );
    await tester.tap(_boton);
    await tester.pump();
    expect(
      find.descendant(of: _miniatura, matching: find.byType(Image)),
      findsOneWidget,
    );
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(AppMovimiento.media);
  });

  testWidgets('la miniatura reusa la foto que ya pintó la tarjeta', (
    tester,
  ) async {
    const url = 'https://res.cloudinary.com/pier/image/upload/v1/pastel.png';
    await tester.pumpWidget(_app(const _Tienda(imagenUrl: url)));
    await tester.tap(_boton);
    await tester.pump();
    final miniatura = tester.widget<Image>(
      find.descendant(of: _miniatura, matching: find.byType(Image)),
    );
    // El mismo proveedor (y la misma entrada de ImageCache) que la foto
    // reducida de la tarjeta, fotoDeTarjeta(url): sin ResizeImage ni otra
    // descarga, y no la foto completa.
    expect(miniatura.image, fotoDeTarjeta(url));
    expect(miniatura.image, isNot(Image.network(url).image));
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(AppMovimiento.media);
  });

  testWidgets('mientras la foto carga vuela el disco dorado', (tester) async {
    // Una red que nunca responde: la foto se queda cargando todo el vuelo.
    debugNetworkImageHttpClientProvider = _RedSinRespuesta.new;
    try {
      await tester.pumpWidget(
        _app(const _Tienda(imagenUrl: 'https://pier.mx/lenta.png')),
      );
      await tester.tap(_boton);
      await tester.pump();
      final disco = find.descendant(
        of: _miniatura,
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.pierDorado,
        ),
      );
      expect(disco, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 280));
      expect(disco, findsOneWidget);
      await tester.pump(AppMovimiento.vuelo);
      await tester.pump(AppMovimiento.media);
      expect(_miniatura, findsNothing);
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets('con un contexto ya desmontado no hace nada', (tester) async {
    late BuildContext viejo;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            viejo = context;
            return const _Tienda();
          },
        ),
      ),
    );
    await tester.pumpWidget(_app(const _Tienda()));
    expect(viejo.mounted, isFalse);

    VueloAlCarrito.lanzar(viejo, imagenUrl: '');
    await tester.pump();
    expect(_miniatura, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desde una ruta tapada por otra no vuela', (tester) async {
    await tester.pumpWidget(_app(const _Tienda()));
    final tapado = tester.element(find.text('Agregar'));
    final tapa = MaterialPageRoute<void>(builder: (_) => const Scaffold());
    Navigator.of(tapado).push(tapa).ignore();
    await tester.pumpAndSettle();

    VueloAlCarrito.lanzar(tapado, imagenUrl: '');
    await tester.pump();
    expect(_miniatura, findsNothing);
    expect(_enCamino(tester), 0);
  });

  testWidgets('con movimiento reducido no vuela', (tester) async {
    await tester.pumpWidget(_app(const _Tienda(), reducido: true));
    await tester.tap(_boton);
    await tester.pump();
    expect(_miniatura, findsNothing);
  });

  testWidgets('sin destino visible no vuela', (tester) async {
    await tester.pumpWidget(_app(const _Tienda(conDestino: false)));
    await tester.tap(_boton);
    await tester.pump();
    expect(_miniatura, findsNothing);
  });

  testWidgets('como máximo tres vuelos a la vez', (tester) async {
    await tester.pumpWidget(_app(const _Tienda()));
    for (var i = 0; i < 5; i++) {
      await tester.tap(_boton);
    }
    await tester.pump();
    expect(_miniatura, findsNWidgets(3));
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(AppMovimiento.media);
    expect(_miniatura, findsNothing);
  });

  testWidgets('si el ámbito se desmonta a medio vuelo, el vuelo se quita', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Tienda()));
    await tester.tap(_boton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_miniatura, findsOneWidget);

    // Como cerrar sesión: el shell se va con un vuelo en el aire.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(_miniatura, findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('lanzarAlConfirmar (alta que espera al backend)', () {
    testWidgets('sin ámbito o con movimiento reducido: el mismo Future', (
      tester,
    ) async {
      final alta = Completer<String?>().future;
      late BuildContext suelto;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              suelto = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        VueloAlCarrito.lanzarAlConfirmar(suelto, alta, imagenUrl: ''),
        same(alta),
      );

      late BuildContext reducido;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              reducido = context;
              return const _Tienda();
            },
          ),
          reducido: true,
        ),
      );
      expect(
        VueloAlCarrito.lanzarAlConfirmar(reducido, alta, imagenUrl: ''),
        same(alta),
      );
      expect(_enCamino(tester), 0); // sin reserva
    });

    testWidgets('reserva al tocar y, si el backend acepta, vuela del botón', (
      tester,
    ) async {
      final respuesta = Completer<String?>();
      final resultados = <Object?>[];
      await tester.pumpWidget(
        _app(_Detalle(respuesta: respuesta, resultados: resultados)),
      );
      final boton = tester.getCenter(find.text('Añadir'));

      await _anadirYEsperar(tester);
      // Mientras el backend responde: reservado, sin nada en el aire.
      expect(_enCamino(tester), 1);
      expect(_miniatura, findsNothing);

      respuesta.complete();
      await _trasResponder(tester);
      expect(resultados, [null]);
      expect(_miniatura, findsOneWidget);
      expect(tester.getCenter(_miniatura), boton);
      expect(_enCamino(tester), 1); // la reserva pasó a ser el vuelo

      await tester.pump(AppMovimiento.vuelo);
      await tester.pump(const Duration(milliseconds: 100)); // aterriza
      expect(_miniatura, findsNothing);
      expect(_enCamino(tester), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_escalaDestino(tester), greaterThan(1));
      await tester.pump(AppMovimiento.media);
    });

    testWidgets('si el backend rechaza, devuelve el motivo y no reacciona', (
      tester,
    ) async {
      final respuesta = Completer<String?>();
      final resultados = <Object?>[];
      await tester.pumpWidget(
        _app(_Detalle(respuesta: respuesta, resultados: resultados)),
      );
      await _anadirYEsperar(tester);

      respuesta.complete('No hay stock suficiente');
      await _trasResponder(tester);
      expect(resultados, ['No hay stock suficiente']);
      expect(_enCamino(tester), 0);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(_miniatura, findsNothing);
        expect(_escalaDestino(tester), 1);
      }
    });

    testWidgets('si el alta lanza un error, lo devuelve y suelta la reserva', (
      tester,
    ) async {
      final respuesta = Completer<String?>();
      final resultados = <Object?>[];
      await tester.pumpWidget(
        _app(_Detalle(respuesta: respuesta, resultados: resultados)),
      );
      await _anadirYEsperar(tester);

      const error = SocketException('sin red');
      respuesta.completeError(error);
      await _trasResponder(tester);
      expect(resultados, [same(error)]);
      expect(_enCamino(tester), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_miniatura, findsNothing);
      expect(_escalaDestino(tester), 1);
    });

    testWidgets('si el shell se va mientras espera, devuelve el resultado', (
      tester,
    ) async {
      final respuesta = Completer<String?>();
      final resultados = <Object?>[];
      await tester.pumpWidget(
        _app(_Detalle(respuesta: respuesta, resultados: resultados)),
      );
      await _anadirYEsperar(tester);

      // Como cerrar sesión mientras el backend responde: la reserva se va
      // con el ámbito.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      respuesta.complete();
      await _trasResponder(tester);
      expect(resultados, [null]);
      expect(_miniatura, findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final (caso, apartar) in <(String, void Function(_DetalleState))>[
      ('el botón se desmontó', (detalle) => detalle.cerrar()),
      ('el botón quedó fuera de la vista', (detalle) => detalle.ocultar()),
    ]) {
      testWidgets('aceptada pero $caso: el trago sale sin miniatura', (
        tester,
      ) async {
        final respuesta = Completer<String?>();
        final resultados = <Object?>[];
        await tester.pumpWidget(
          _app(_Detalle(respuesta: respuesta, resultados: resultados)),
        );
        await _anadirYEsperar(tester);
        apartar(tester.state<_DetalleState>(find.byType(_Detalle)));
        await tester.pump();

        respuesta.complete();
        await _trasResponder(tester);
        expect(resultados, [null]);
        expect(_miniatura, findsNothing);
        expect(_enCamino(tester), 0);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_escalaDestino(tester), greaterThan(1));
        await tester.pump(AppMovimiento.media);
        expect(_escalaDestino(tester), 1);
      });
    }
  });
}
