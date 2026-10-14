// test/widget/repartidor/movimiento_repartidor_test.dart — el movimiento del
// panel del repartidor: las piezas de movimiento_repartidor.dart (cambios que
// solo se animan si se ven, la columna que abre y cierra espacios, la
// primera vista de una pestaña, el contorno dorado, la campana y el latido),
// la píldora de conteo, el chip de estado y el ícono de carga; en el panel,
// la cascada de la primera carga (que no se repite), la entrega recién
// tomada, el número que vuela al detalle, la primera visita de Historial y
// Perfil, la barra de acciones del detalle, la confirmación y la hoja de
// reporte; con movimiento reducido todo llega quieto. Sin red.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/confirmar_entrega_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entrega_detail_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entregas_tarjetas.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/historial_repartidor_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/movimiento_repartidor.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/perfil_repartidor_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_main_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/reportar_fallo_sheet.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

// ── Datos del backend falso ─────────────────────────────────────────────

const Map<String, Object> _usuario = {
  'id': 9,
  'nombre': 'Luis',
  'apellido': 'Hernández',
  'email': 'luis@pier.mx',
  'telefono': '7711234567',
  'rol': 'repartidor',
};

Map<String, dynamic> _entrega(
  String id,
  String estado, {
  num total = 100,
  String? pago,
  String? finalizado,
}) => {
  'id': id,
  'estado': estado,
  'numero': 'PIER-$id',
  'total': total,
  'metodo_pago': pago,
  'cliente_nombre': 'Cliente',
  'cliente_apellido': id,
  'horario_entrega': '2026-10-10T09:00:00',
  'finalizado_at': finalizado,
  'direccion_entrega': {'colonia': 'Colonia $id'},
};

Map<String, dynamic> _pedido(int id) => {
  'pedido_id': id,
  'numero': 'PIER-$id',
  'total': 300,
  'cliente_nombre': 'Ana',
  'cliente_apellido': 'López',
  'horario_entrega': '2026-10-10T11:00:00',
  'direccion_entrega': {'colonia': 'Aviación'},
};

Map<String, dynamic> _misEntregas(List<Map<String, dynamic>> entregas) => {
  'success': true,
  'entregas': entregas,
};

Map<String, dynamic> _pool(List<Map<String, dynamic>> pedidos) => {
  'success': true,
  'pedidos': pedidos,
};

FakeApiClient _backend({
  List<Map<String, dynamic>>? entregas,
  List<Map<String, dynamic>>? pool,
}) => FakeApiClient(
  respuestas: {
    ApiConstants.login: {'success': true, 'token': 'jwt', 'user': _usuario},
    ApiConstants.misEntregas: _misEntregas(
      entregas ??
          [
            _entrega('1', 'asignada', pago: 'efectivo'),
            _entrega('2', 'en_camino', total: 1250, pago: 'tarjeta'),
            _entrega(
              '3',
              'entregada',
              total: 250,
              finalizado: '2026-10-10T15:30:00',
            ),
            _entrega('4', 'fallida'),
          ],
    ),
    ApiConstants.disponibilidad: {'success': true, 'disponible': true},
    ApiConstants.entregasDisponibles: _pool(pool ?? [_pedido(41)]),
  },
);

/// Pantalla de celular (412×869 lógicos), como las demás pruebas del panel.
void _celular(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
}

Future<FakeApiClient> _montar(WidgetTester tester, {FakeApiClient? api}) async {
  _celular(tester);
  final backend = api ?? _backend();
  await tester.pumpApp(const RepartidorMainScreen(), api: backend);
  await tester.iniciarSesion(find.byType(RepartidorMainScreen));
  await tester.pump();
  await tester.pump();
  return backend;
}

Future<void> _irA(WidgetTester tester, String pestana) async {
  await tester.tap(find.text(pestana).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// La entrada (EntradaSuave) más cercana que envuelve a [texto].
Finder _entradaDe(String texto) => find
    .ancestor(of: find.text(texto), matching: find.byType(EntradaSuave))
    .first;

/// Las ScaleTransition de la píldora de una sección: [presencia, salto].
List<ScaleTransition> _escalasPildora(WidgetTester tester, String titulo) =>
    tester
        .widgetList<ScaleTransition>(
          find.descendant(
            of: find.ancestor(
              of: find.text(titulo),
              matching: find.byType(TituloSeccion),
            ),
            matching: find.byType(ScaleTransition),
          ),
        )
        .toList();

/// Si la tarjeta en curso de [numero] tiene armado su contorno dorado (se
/// montó como recién llegada): ContornoDorado pinta encima de ella.
bool _conContorno(WidgetTester tester, String numero) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.ancestor(
          of: find.text(numero),
          matching: find.byType(EntregaCard),
        ),
        matching: find.byType(CustomPaint),
      ),
    )
    .any((c) => c.foregroundPainter != null);

/// Desplazamiento horizontal que pinta la primera Sacudida.
double _sacudidaX(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(Sacudida),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getTranslation()
    .x;

/// Un CambioEnVista con su texto, encendido o apagado por TickerMode.
class _Anfitrion extends StatelessWidget {
  const _Anfitrion({required this.visible, required this.texto});

  final ValueNotifier<bool> visible;
  final ValueNotifier<String> texto;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (_, enVista, _) => TickerMode(
          enabled: enVista,
          child: ValueListenableBuilder<String>(
            valueListenable: texto,
            builder: (_, t, _) => CambioEnVista(clave: t, child: Text(t)),
          ),
        ),
      ),
    ),
  );
}

/// Una ColumnaAnimada de renglones de 50 dp, uno por id.
class _Columna extends StatelessWidget {
  const _Columna({required this.ids, required this.visible});

  final ValueNotifier<List<String>> ids;
  final ValueNotifier<bool> visible;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, enVista, _) => TickerMode(
            enabled: enVista,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: ids,
              builder: (_, lista, _) => ColumnaAnimada(
                children: [
                  for (final id in lista)
                    SizedBox(
                      key: ValueKey<String>(id),
                      height: 50,
                      child: GestureDetector(
                        onTap: () {},
                        child: Text(id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('piezas de movimiento del repartidor', () {
    testWidgets(
      'CambioEnVista anima lo que se ve y resuelve en silencio lo oculto',
      (tester) async {
        final visible = ValueNotifier<bool>(true);
        final texto = ValueNotifier<String>('A');
        await tester.pumpWidget(_Anfitrion(visible: visible, texto: texto));

        // A la vista: el anterior se apaga mientras entra el nuevo.
        texto.value = 'B';
        await tester.pump();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing);

        // Oculto: el nuevo toma su lugar en el mismo cuadro y al volver a
        // verse no queda una transición pendiente.
        visible.value = false;
        await tester.pump();
        texto.value = 'C';
        await tester.pump();
        expect(find.text('B'), findsNothing);
        expect(find.text('C'), findsOneWidget);
        visible.value = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('B'), findsNothing);
        expect(opacidadEn(tester, find.byType(CambioEnVista)), 1);
      },
    );

    testWidgets('ColumnaAnimada abre el espacio de lo que llega y deja salir '
        'lo que se va', (tester) async {
      final ids = ValueNotifier<List<String>>(['a', 'b']);
      final visible = ValueNotifier<bool>(true);
      await tester.pumpWidget(_Columna(ids: ids, visible: visible));
      double alto() => tester.getSize(find.byType(ColumnaAnimada)).height;
      expect(alto(), 100);

      // Llega «c»: su espacio se abre poco a poco.
      ids.value = ['a', 'b', 'c'];
      await tester.pump();
      expect(find.text('c'), findsOneWidget);
      expect(alto(), 100);
      await tester.pump(const Duration(milliseconds: 120));
      expect(alto(), inExclusiveRange(100, 150));
      await tester.pumpAndSettle();
      expect(alto(), 150);

      // Se va «a»: sigue un momento (sin recibir toques) y luego sale.
      ids.value = ['b', 'c'];
      await tester.pump();
      expect(find.text('a'), findsOneWidget);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.text('a'),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );
      expect(alto(), 150);
      await tester.pumpAndSettle();
      expect(find.text('a'), findsNothing);
      expect(alto(), 100);

      // Llega y se va antes de empezar a abrirse: sale en ese mismo cuadro.
      ids.value = ['b', 'c', 'z'];
      await tester.pump();
      ids.value = ['b', 'c'];
      await tester.pump();
      expect(find.text('z'), findsNothing);
      expect(alto(), 100);

      // Sin verse, todo es inmediato.
      visible.value = false;
      await tester.pump();
      ids.value = ['b', 'c', 'd'];
      await tester.pump();
      expect(alto(), 150);
      ids.value = ['c', 'd'];
      await tester.pump();
      expect(find.text('b'), findsNothing);
      expect(alto(), 100);
    });

    testWidgets('ColumnaAnimada con movimiento reducido cambia al instante', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      final ids = ValueNotifier<List<String>>(['a']);
      await tester.pumpWidget(
        _Columna(ids: ids, visible: ValueNotifier<bool>(true)),
      );
      ids.value = ['a', 'b'];
      await tester.pump();
      expect(tester.getSize(find.byType(ColumnaAnimada)).height, 100);
      ids.value = ['b'];
      await tester.pump();
      expect(find.text('a'), findsNothing);
      expect(tester.getSize(find.byType(ColumnaAnimada)).height, 50);
    });

    testWidgets('PrimeraVista espera a que la pantalla se vea y no se olvida', (
      tester,
    ) async {
      final visible = ValueNotifier<bool>(false);
      final vistas = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, enVista, _) => TickerMode(
              enabled: enVista,
              child: PrimeraVista(
                builder: (_, vista, _) {
                  vistas.add(vista);
                  return Text(vista ? 'vista' : 'oculta');
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('oculta'), findsOneWidget);

      // Se reconstruye en el mismo cuadro en que se enciende.
      visible.value = true;
      await tester.pump();
      expect(find.text('vista'), findsOneWidget);

      visible.value = false;
      await tester.pump();
      expect(find.text('vista'), findsOneWidget);
      expect(vistas.last, isTrue);
    });

    testWidgets('la píldora de la sección salta solo cuando la cantidad sube', (
      tester,
    ) async {
      final cantidad = ValueNotifier<int>(1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: cantidad,
              builder: (_, n, _) => TituloSeccion('En curso', count: n),
            ),
          ),
        ),
      );
      // Montarse con una cantidad no anima.
      expect(_escalasPildora(tester, 'En curso').last.scale.value, 1);

      cantidad.value = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('2'), findsOneWidget);
      expect(
        _escalasPildora(tester, 'En curso').last.scale.value,
        greaterThan(1),
      );
      await tester.pumpAndSettle();
      expect(_escalasPildora(tester, 'En curso').last.scale.value, 1);

      // Bajar no salta.
      cantidad.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_escalasPildora(tester, 'En curso').last.scale.value, 1);

      // A cero se encoge conservando su número y sale; de cero crece.
      cantidad.value = 0;
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);
      expect(_escalasPildora(tester, 'En curso'), isEmpty);

      cantidad.value = 3;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        _escalasPildora(tester, 'En curso').first.scale.value,
        lessThan(1),
      );
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('IconoCargando: el indicador mide lo mismo que el ícono', (
      tester,
    ) async {
      final cargando = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: cargando,
                builder: (_, c, _) => IconoCargando(
                  icono: LucideIcons.check,
                  cargando: c,
                  tamano: 20,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(IconoCargando)), const Size(20, 20));

      cargando.value = true;
      await tester.pump();
      // El ícono sale con un pop mientras el indicador entra en su lugar.
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(20, 20),
      );
      expect(tester.getSize(find.byType(IconoCargando)), const Size(20, 20));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(LucideIcons.check), findsNothing);

      cargando.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });

    testWidgets('EstadoEntregaChip cambia la etiqueta en su lugar con el color '
        'del estado nuevo', (tester) async {
      final estado = ValueNotifier<EstadoEntrega>(EstadoEntrega.asignada);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<EstadoEntrega>(
                valueListenable: estado,
                builder: (_, e, _) => EstadoEntregaChip(estado: e),
              ),
            ),
          ),
        ),
      );
      estado.value = EstadoEntrega.enCamino;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // A medio cambio el texto ya tiene el color de destino (nunca uno a
      // medio camino).
      expect(
        tester.widget<Text>(find.text('En camino')).style!.color,
        AppColors.estadoEnCamino,
      );
      expect(find.text('Asignada'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Asignada'), findsNothing);
      expect(find.text('En camino'), findsOneWidget);
    });

    testWidgets('ContornoDorado brilla una vez y solo en la tarjeta nueva', (
      tester,
    ) async {
      Iterable<CustomPaint> brillos() => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(ContornoDorado),
              matching: find.byType(CustomPaint),
            ),
          )
          .where((c) => c.foregroundPainter != null);

      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              ContornoDorado(activo: true, child: SizedBox(height: 50)),
              ContornoDorado(activo: false, child: SizedBox(height: 50)),
            ],
          ),
        ),
      );
      expect(brillos(), hasLength(1));
      await tester.pump();
      await tester.pump(
        ContornoDorado.brillo +
            AppMovimiento.media +
            const Duration(milliseconds: 20),
      );
      await tester.pump();
      // Terminó: no quedan cuadros pendientes.
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Con movimiento reducido no brilla.
      activarReducirMovimientoIos(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(
          home: ContornoDorado(activo: true, child: SizedBox(height: 50)),
        ),
      );
      expect(brillos(), isEmpty);
    });

    testWidgets('Campaneo mece una vez y PulsoAtencion late una vez', (
      tester,
    ) async {
      final disparo = ValueNotifier<int?>(null);
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              ValueListenableBuilder<int?>(
                valueListenable: disparo,
                builder: (_, d, _) => Campaneo(
                  disparo: d,
                  child: const Icon(LucideIcons.bellRing),
                ),
              ),
              const PulsoAtencion(
                retraso: Duration(milliseconds: 100),
                child: Icon(LucideIcons.banknote),
              ),
            ],
          ),
        ),
      );
      double giro() {
        final m = tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(Campaneo),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform;
        return math.atan2(m.entry(1, 0), m.entry(0, 0));
      }

      double latido() => escalaEn(tester, find.byType(PulsoAtencion));

      // El latido espera su retraso desde el primer cuadro y luego crece.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(latido(), 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(latido(), greaterThan(1));

      expect(giro(), 0);
      disparo.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(giro(), isNot(0));

      await tester.pumpAndSettle();
      expect(giro(), closeTo(0, 1e-9));
      expect(latido(), 1);
    });
  });

  group('Mis entregas', () {
    testWidgets('la barra del panel usa IconoPestana en las dos ranuras', (
      tester,
    ) async {
      await _montar(tester);
      final barra = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      for (final item in barra.items) {
        expect(item.icon, isA<IconoPestana>());
        expect((item.icon as IconoPestana).activo, isFalse);
        expect(item.activeIcon, isA<IconoPestana>());
        expect((item.activeIcon as IconoPestana).activo, isTrue);
      }
      await tester.pumpAndSettle();
    });

    testWidgets('la primera carga entra en cascada y recargar no la repite', (
      tester,
    ) async {
      await _montar(tester);

      // Recién llegada la lista: nada se ve aún y lo de abajo espera más.
      expect(opacidadEn(tester, _entradaDe('Disponible para entregas')), 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        opacidadEn(tester, _entradaDe('Disponible para entregas')),
        greaterThan(opacidadEn(tester, _entradaDe('PIER-2'))),
      );
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, _entradaDe('PIER-2')), 1);

      // Jalar para refrescar con los mismos datos: nada vuelve a entrar.
      await tester.fling(
        find.text('Disponible para entregas'),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(opacidadEn(tester, _entradaDe('Disponible para entregas')), 1);
      await tester.pump(const Duration(seconds: 1));
      expect(opacidadEn(tester, _entradaDe('PIER-1')), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('si recargar falla, el aviso abre su espacio y se sacude', (
      tester,
    ) async {
      final api = await _montar(tester);
      await tester.pumpAndSettle();
      // Sin error el lugar del aviso existe, sin alto (los finders lo
      // cuentan fuera de escena).
      expect(find.byType(Sacudida, skipOffstage: false), findsOneWidget);

      api.fallar(ApiConstants.misEntregas, 'Error al obtener entregas');
      await tester.fling(
        find.text('Disponible para entregas'),
        const Offset(0, 400),
        1000,
      );
      final aviso = find.text(
        'Error al obtener entregas. Desliza hacia abajo para reintentar.',
      );
      for (var i = 0; i < 40 && aviso.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(aviso, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_sacudidaX(tester), isNot(0));
      await tester.pumpAndSettle();
      expect(_sacudidaX(tester), 0);
      expect(aviso, findsOneWidget);
    });

    testWidgets('tomar un pedido: su tarjeta se va del pool y la entrega '
        'llega a «En curso» con su brillo', (tester) async {
      final api = await _montar(
        tester,
        api: _backend(
          entregas: [_entrega('1', 'asignada')],
          pool: [_pedido(41), _pedido(42)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PIER-41'), findsOneWidget);

      // El backend acepta y, al recargar, el pedido ya es una entrega.
      api
        ..responder(ApiConstants.entregasAceptar, {
          'success': true,
          'message': 'Tomaste el pedido #PIER-41',
        })
        ..responder(
          ApiConstants.misEntregas,
          _misEntregas([_entrega('1', 'asignada'), _entrega('41', 'asignada')]),
        )
        ..responder(ApiConstants.entregasDisponibles, _pool([_pedido(42)]));
      await tester.tap(find.text('Tomar entrega').first);
      await tester.pump();
      await tester.pump();

      expect(find.text('Tomaste el pedido #PIER-41'), findsOneWidget);
      // La tarjeta del pool se apaga sin recibir toques mientras la entrega
      // abre su espacio en «En curso», marcada como nueva.
      final delPool = find.ancestor(
        of: find.text('PIER-41'),
        matching: find.byType(DisponibleCard),
      );
      expect(delPool, findsOneWidget);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: delPool, matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );
      final nueva = find.ancestor(
        of: find.text('PIER-41'),
        matching: find.byType(EntregaCard),
      );
      // Se montó marcada como nueva: su contorno dorado quedó armado (la
      // marca ya se quitó de la lista tras ese cuadro); el de PIER-1 no.
      expect(_conContorno(tester, 'PIER-41'), isTrue);
      expect(
        find.descendant(of: nueva, matching: find.byType(ContornoDorado)),
        findsOneWidget,
      );
      expect(_conContorno(tester, 'PIER-1'), isFalse);

      // La píldora de «En curso» salta (1 → 2); la de «Disponibles» no.
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _escalasPildora(tester, 'En curso').last.scale.value,
        greaterThan(1),
      );
      expect(_escalasPildora(tester, 'Disponibles').last.scale.value, 1);

      await tester.pumpAndSettle();
      expect(find.text('PIER-41'), findsOneWidget);
      expect(delPool, findsNothing);
      expect(find.text('PIER-42'), findsOneWidget);
      expect(find.text('Tienes 2 entregas activas para hoy'), findsOneWidget);
    });

    testWidgets('el brillo de la entrega recién tomada no se repite al volver '
        'con scroll', (tester) async {
      final api = await _montar(
        tester,
        api: _backend(
          entregas: [_entrega('1', 'asignada')],
          pool: [for (var id = 41; id <= 46; id++) _pedido(id)],
        ),
      );
      await tester.pumpAndSettle();
      api
        ..responder(ApiConstants.entregasAceptar, {
          'success': true,
          'message': 'Tomaste el pedido #PIER-46',
        })
        ..responder(
          ApiConstants.misEntregas,
          _misEntregas([_entrega('1', 'asignada'), _entrega('46', 'asignada')]),
        )
        ..responder(
          ApiConstants.entregasDisponibles,
          _pool([for (var id = 41; id <= 45; id++) _pedido(id)]),
        );

      // Toma el último pedido del pool con «En curso» a la vista: la entrega
      // llega y su contorno se arma.
      await tester.scrollUntilVisible(find.text('PIER-46'), 300);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('PIER-46'),
            matching: find.byType(DisponibleCard),
          ),
          matching: find.text('Tomar entrega'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(_conContorno(tester, 'PIER-46'), isTrue);
      await tester.pumpAndSettle();

      // Arriba del todo la sección «En curso» sale de la caché de la lista;
      // al regresar, su tarjeta se monta otra vez, ya sin brillo.
      await tester.scrollUntilVisible(
        find.text('Disponible para entregas'),
        -300,
      );
      await tester.pump();
      expect(find.byType(EntregaCard, skipOffstage: false), findsNothing);
      await tester.scrollUntilVisible(
        find.descendant(
          of: find.byType(EntregaCard),
          matching: find.text('PIER-46'),
        ),
        300,
      );
      await tester.pump();
      expect(_conContorno(tester, 'PIER-46'), isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('el número y el estado vuelan de la tarjeta al detalle', (
      tester,
    ) async {
      await _montar(tester);
      await tester.pumpAndSettle();

      Finder enVuelo(String texto) => find.ancestor(
        of: find.text(texto),
        matching: find.byType(FittedBox),
      );
      await tester.tap(find.text('PIER-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // A medio vuelo, el número de la tarjeta y el del detalle se funden
      // dentro de un Material transparente (sin subrayado amarillo).
      expect(enVuelo('PIER-1'), findsNWidgets(2));
      expect(enVuelo('Asignada'), findsNWidgets(2));
      expect(
        tester
            .widget<Material>(
              find
                  .ancestor(
                    of: enVuelo('PIER-1').first,
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .type,
        MaterialType.transparency,
      );

      await tester.pumpAndSettle();
      expect(find.byType(EntregaDetailScreen), findsOneWidget);
      expect(enVuelo('PIER-1'), findsNothing);
      expect(find.text('PIER-1'), findsNWidgets(2)); // barra y tarjeta

      // De regreso vuela a su tarjeta.
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(enVuelo('PIER-1'), findsNWidgets(2));
      await tester.pumpAndSettle();
      expect(find.byType(EntregaDetailScreen), findsNothing);
      expect(find.text('PIER-1'), findsOneWidget);
    });

    testWidgets('si el estado cambió con el detalle encima, el chip aterriza '
        'con su ancho nuevo', (tester) async {
      final api = await _montar(
        tester,
        api: _backend(entregas: [_entrega('1', 'asignada')], pool: []),
      );
      await tester.pumpAndSettle();
      // El chip de la tarjeta de la lista (también su lugar mientras vuela).
      final chip = find.descendant(
        of: find.byType(EntregaCard, skipOffstage: false),
        matching: find.byWidgetPredicate(
          (w) => w is Hero && w.tag == HeroEntrega.estado('1'),
          skipOffstage: false,
        ),
      );
      final anchoAsignada = tester.getSize(chip).width;

      api
        ..responder(ApiConstants.entregaEstado('1'), {'success': true})
        ..responder(
          ApiConstants.misEntregas,
          _misEntregas([_entrega('1', 'en_camino')]),
        );
      await tester.tap(find.text('PIER-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir en camino'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // De regreso, el lugar del chip ya mide «En camino»: el vuelo no
      // aterriza con el ancho de «Asignada» para luego saltar.
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final enVuelo = tester.getSize(chip);
      await tester.pumpAndSettle();
      expect(find.text('En camino'), findsOneWidget);
      expect(tester.getSize(chip), enVuelo);
      expect(enVuelo.width, isNot(anchoAsignada));
    });

    testWidgets('con movimiento reducido el panel llega quieto y sin vuelos', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      await _montar(tester);
      expect(opacidadEn(tester, _entradaDe('Disponible para entregas')), 1);
      expect(opacidadEn(tester, _entradaDe('PIER-2')), 1);

      await tester.tap(find.text('PIER-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.ancestor(
          of: find.text('PIER-1'),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(find.byType(EntregaDetailScreen), findsOneWidget);
    });
  });

  group('Historial y Perfil', () {
    testWidgets('Historial entra en cascada solo la primera vez que se abre', (
      tester,
    ) async {
      await _montar(tester);
      await tester.pumpAndSettle();
      // Oculta, la pestaña no deja entradas pendientes.
      expect(
        find.descendant(
          of: find.byType(HistorialRepartidorScreen, skipOffstage: false),
          matching: find.byType(EntradaSuave, skipOffstage: false),
        ),
        findsNothing,
      );

      FractionallySizedBox barraDe(String numero) =>
          tester.widget<FractionallySizedBox>(
            find
                .descendant(
                  of: find
                      .ancestor(
                        of: find.text(numero),
                        matching: find.byType(Row),
                      )
                      .first,
                  matching: find.byType(FractionallySizedBox),
                )
                .first,
          );

      await _irA(tester, 'Historial');
      expect(opacidadEn(tester, _entradaDe('PIER-3')), 0);
      expect(opacidadEn(tester, _entradaDe('Total del día')), 0);
      expect(barraDe('PIER-3').widthFactor, 0);
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, _entradaDe('PIER-4')), 1);
      expect(opacidadEn(tester, _entradaDe('Total del día')), 1);
      expect(barraDe('PIER-3').widthFactor, 1);

      // La segunda visita ya no se repite.
      await _irA(tester, 'Entregas');
      await _irA(tester, 'Historial');
      expect(opacidadEn(tester, _entradaDe('PIER-3')), 1);
      expect(barraDe('PIER-4').widthFactor, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('Perfil sube sus tarjetas la primera vez y su estado de '
        'servicio cambia en su lugar', (tester) async {
      final api = await _montar(tester);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(PerfilRepartidorScreen, skipOffstage: false),
          matching: find.byType(EntradaSuave, skipOffstage: false),
        ),
        findsNothing,
      );

      await _irA(tester, 'Perfil');
      expect(opacidadEn(tester, _entradaDe('Luis Hernández')), 0);
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, _entradaDe('Luis Hernández')), 1);

      api.responder(ApiConstants.disponibilidad, {
        'success': true,
        'disponible': false,
      });
      await tester.tap(find.byType(Switch).last);
      await tester.pump();
      await tester.pump();
      expect(find.text('No disponible'), findsOneWidget);
      expect(find.text('Disponible para entregas'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Disponible para entregas'), findsNothing);
      expect(find.text('No disponible'), findsOneWidget);

      // Lo que se construye al bajar ya llega quieto.
      await tester.dragUntilVisible(
        find.text('Cerrar sesión'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump();
      expect(opacidadEn(tester, _entradaDe('Cerrar sesión')), 1);
      await tester.pumpAndSettle();
    });
  });

  group('detalle, confirmación y reporte', () {
    final estado = ApiConstants.entregaEstado('9');
    final llegue = ApiConstants.entregaLlegue('9');

    EntregaRepartidor entrega({String estado = 'asignada'}) =>
        EntregaRepartidor.fromJson({
          'id': 9,
          'estado': estado,
          'numero': 'PIER-0041',
          'total': 330,
          'costo_envio': 30,
          'metodo_pago': 'efectivo',
          'cliente_nombre': 'Ana',
          'cliente_apellido': 'López',
          'cliente_telefono': '7719998888',
          'direccion_entrega': const {
            'calle_numero': 'Juárez 12',
            'colonia': 'Centro',
          },
        });

    Future<FakeApiClient> abrirDetalle(
      WidgetTester tester,
      EntregaRepartidor e,
      Map<String, dynamic> respuestas,
    ) async {
      _celular(tester);
      final api = FakeApiClient(respuestas: respuestas);
      await tester.pumpApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EntregaDetailScreen(
                      entrega: e,
                      alCambiar: () async {},
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
        api: api,
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('la barra de acciones cambia con un fundido a través al salir '
        'en camino', (tester) async {
      await abrirDetalle(tester, entrega(), {
        estado: {'success': true},
      });
      expect(find.text('Reportar'), findsOneWidget);

      await tester.tap(find.text('Salir en camino'));
      await tester.pump();
      await tester.pump();
      // Un instante conviven la barra que sale y la que entra (y la etiqueta
      // del chip), luego queda solo la nueva.
      expect(find.text('Reportar'), findsNWidgets(2));
      expect(find.text('Asignada'), findsOneWidget);
      expect(find.text('En camino'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Reportar'), findsOneWidget);
      expect(find.text('Asignada'), findsNothing);
      expect(find.text('Marcar entregado'), findsOneWidget);
    });

    testWidgets('la campana suena cuando el cliente ya fue avisado', (
      tester,
    ) async {
      await abrirDetalle(tester, entrega(estado: 'en_camino'), {
        llegue: {'success': true, 'message': 'Cliente avisado de tu llegada'},
      });
      double giro() {
        final m = tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(Campaneo),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform;
        return math.atan2(m.entry(1, 0), m.entry(0, 0));
      }

      expect(giro(), 0);
      await tester.tap(find.text('Llegué al domicilio (avisar al cliente)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Cliente avisado de tu llegada'), findsOneWidget);
      expect(giro(), isNot(0));
      await tester.pumpAndSettle();
      expect(giro(), closeTo(0, 1e-9));
    });

    testWidgets('confirmar: sin quién recibió se sacude y la foto abre su '
        'espacio', (tester) async {
      _celular(tester);
      const canal = MethodChannel('plugins.flutter.io/image_picker');
      final mensajero = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(canal, (_) async => '/no/existe.jpg');
      addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
      await tester.pumpApp(
        ConfirmarEntregaScreen(entrega: entrega(estado: 'en_camino')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.ancestor(
          of: find.text('Confirmar entrega'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_sacudidaX(tester), isNot(0));
      await tester.pumpAndSettle();
      expect(_sacudidaX(tester), 0);

      double alto() => tester.getSize(find.byType(TamanoSuave)).height;
      expect(alto(), 110);
      await tester.tap(find.text('Galería'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Cámara'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(alto(), inExclusiveRange(110, 180));
      await tester.pumpAndSettle();
      expect(alto(), 180);
    });

    testWidgets('la hoja de reporte: elegir motivo no cambia el tamaño del '
        'chip y sin detalle el campo se sacude', (tester) async {
      _celular(tester);
      await tester.pumpApp(
        Scaffold(body: ReportarFalloSheet(entrega: entrega())),
      );
      await tester.pumpAndSettle();
      final chip = find.text('No contestó');
      final antes = tester.getSize(
        find.ancestor(of: chip, matching: find.byType(AnimatedContainer)),
      );
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(
          find.ancestor(of: chip, matching: find.byType(AnimatedContainer)),
        ),
        antes,
      );

      await tester.tap(find.text('Reportar fallo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_sacudidaX(tester), isNot(0));
      await tester.pumpAndSettle();
      expect(_sacudidaX(tester), 0);
    });
  });

  testWidgets('el detalle de una entrega finalizada no tiene barra', (
    tester,
  ) async {
    _celular(tester);
    await tester.pumpApp(
      EntregaDetailScreen(
        entrega: EntregaRepartidor.fromJson(const {
          'id': 9,
          'estado': 'entregada',
          'numero': 'PIER-0041',
        }),
      ),
    );
    // Ni siquiera un instante: desde el primer cuadro no hay barra.
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
      isNull,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CambioEnVista), findsOneWidget); // solo el del chip
    expect(find.text('Reportar'), findsNothing);
  });
}
