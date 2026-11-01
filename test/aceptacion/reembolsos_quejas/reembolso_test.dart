// test/aceptacion/reembolsos_quejas/reembolso_test.dart — escenarios Gherkin
// de «Reembolsos»: el formulario solo ofrece los pedidos que se pueden
// reembolsar, el motivo es obligatorio y la solicitud enviada aparece en el
// historial con su estado (#68; historia #43), más el caso de error del
// pedido que ya no se puede reembolsar, sin red.
//
// La pantalla se abre como en la app (arma su ViewModel con los
// repositorios de dependencies.dart) y cada prueba usa los mismos
// selectores y botones que el cliente. El backend guarda los pedidos y las
// solicitudes en memoria sobre FakeApiClient y aplica las reglas de
// POST /reembolsos: solo pedidos recogidos o entregados, y una solicitud
// viva por pedido (#172).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/domain/models/order_model.dart';
import 'package:pier_reposteria/ui/refunds/widgets/refunds_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

/// Un pedido de GET /pedidos/mis-pedidos; [reembolso] es su última
/// solicitud (#172).
Map<String, dynamic> _pedido(
  int id,
  String estado,
  String total, {
  String tipoEntrega = 'pickup',
  Map<String, dynamic>? reembolso,
}) => {
  'id': id,
  'numero': 'PIER-$id',
  'estado': estado,
  'total': total,
  'tipo_entrega': tipoEntrega,
  'reembolso': reembolso,
};

/// Mis pedidos: uno de cada caso.
List<Map<String, dynamic>> _misPedidos() => [
  _pedido(9, 'completado', '640'), // recogido en la sucursal
  _pedido(10, 'entregado', '300', tipoEntrega: 'domicilio'),
  _pedido(11, 'pendiente', '150'),
  _pedido(12, 'en_camino', '420', tipoEntrega: 'domicilio'),
  _pedido(13, 'cancelado', '200'),
  // Recogido, pero ya tiene una solicitud en revisión.
  _pedido(
    14,
    'completado',
    '500',
    reembolso: {'id': 2, 'estado': 'en_revision', 'monto': '500'},
  ),
];

/// Backend en memoria: mis pedidos, mis solicitudes y POST /reembolsos con
/// las reglas y los mensajes de routes/reembolsosRoutes.js.
class _BackendReembolsos {
  _BackendReembolsos({List<Map<String, dynamic>>? pedidos})
    : pedidos = pedidos ?? _misPedidos() {
    api = FakeApiClient(
      respuestas: {
        ApiConstants.misPedidos: _listarPedidos,
        ApiConstants.misReembolsos: _listarReembolsos,
        ApiConstants.crearReembolso: _crear,
      },
    );
  }

  /// Estados de una solicitud viva (no deja pedir otra) y cómo los nombra
  /// el backend en su mensaje.
  static const Map<String, String> _vivas = {
    'pendiente': 'pendiente',
    'en_revision': 'en revisión',
    'aprobado': 'aprobado',
    'procesado': 'devuelto',
  };

  late final FakeApiClient api;
  final List<Map<String, dynamic>> pedidos;

  /// Mis solicitudes, de la más vieja a la más nueva.
  final List<Map<String, dynamic>> reembolsos = [];
  int _siguienteId = 31;

  /// Otra sesión del cliente (la web) pide el reembolso del pedido [id]
  /// mientras la app tiene el formulario abierto.
  void solicitarDesdeLaWeb(int id) {
    final pedido = pedidos.firstWhere((p) => p['id'] == id);
    _registrar(
      pedido,
      monto: num.parse(pedido['total'] as String),
      motivo: 'pedido_incorrecto',
      descripcion: 'Desde la web',
    );
  }

  Map<String, dynamic> _listarPedidos(LlamadaApi _) => {
    'success': true,
    'pedidos': [for (final p in pedidos) {...p}],
  };

  /// El backend las devuelve de la más nueva a la más vieja.
  Map<String, dynamic> _listarReembolsos(LlamadaApi _) => {
    'success': true,
    'reembolsos': [for (final r in reembolsos.reversed) {...r}],
  };

  Map<String, dynamic> _crear(LlamadaApi llamada) {
    final body = llamada.body!;
    final pedido = pedidos
        .where((p) => p['id'] == body['pedido_id'])
        .firstOrNull;
    if (pedido == null) return _rechazo('Pedido no encontrado');
    if (pedido['estado'] != 'completado' && pedido['estado'] != 'entregado') {
      return _rechazo(
        'Solo puedes pedir reembolso de pedidos entregados o recogidos',
      );
    }
    final viva = _vivas[(pedido['reembolso'] as Map?)?['estado']];
    if (viva != null) {
      return _rechazo('Este pedido ya tiene una solicitud de reembolso ($viva)');
    }
    final reembolso = _registrar(
      pedido,
      monto: body['monto'] as num,
      motivo: body['motivo'] as String,
      descripcion: body['descripcion'] as String,
    );
    return {'success': true, 'reembolso': reembolso};
  }

  /// Guarda una solicitud pendiente de [pedido] y la deja como su última
  /// solicitud (lo que trae mis-pedidos en `reembolso`).
  Map<String, dynamic> _registrar(
    Map<String, dynamic> pedido, {
    required num monto,
    required String motivo,
    required String descripcion,
  }) {
    final reembolso = <String, dynamic>{
      'id': _siguienteId++,
      'pedido_id': pedido['id'],
      'pedido_numero': pedido['numero'],
      'monto': monto.toStringAsFixed(2),
      'motivo': motivo,
      'descripcion': descripcion,
      'estado': 'pendiente',
      // Sin zona horaria: se lee como hora local y la fecha que se ve no
      // depende del huso de la máquina (CI corre en UTC).
      'created_at': '2026-10-20T12:00:00',
    };
    reembolsos.add(reembolso);
    pedido['reembolso'] = {
      'id': reembolso['id'],
      'estado': 'pendiente',
      'monto': reembolso['monto'],
    };
    return reembolso;
  }

  static Map<String, dynamic> _rechazo(String mensaje) => {
    'success': false,
    'message': mensaje,
  };
}

/// Abre «Reembolsos» sin ViewModel inyectado, como la abre «Más», y espera
/// a que carguen las solicitudes y los pedidos.
Future<void> _abrirReembolsos(
  WidgetTester tester,
  _BackendReembolsos backend,
) async {
  await tester.pumpApp(const RefundsScreen(), api: backend.api);
  await tester.pumpAndSettle();
}

/// Cambia a la pestaña «Nueva Solicitud» (el formulario).
Future<void> _abrirFormulario(WidgetTester tester) async {
  await tester.tap(find.text('Nueva Solicitud').first);
  await tester.pumpAndSettle();
}

/// Abre el [selector] y elige [opcion]. El menú abierto repite la opción ya
/// elegida: se toca la del menú (la última).
Future<void> _elegir(WidgetTester tester, Finder selector, String opcion) async {
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcion).last);
  await tester.pumpAndSettle();
}

/// Toca «Enviar Solicitud», al fondo del formulario.
Future<void> _enviar(WidgetTester tester) async {
  final boton = find.text('Enviar Solicitud');
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

/// El selector de pedido del formulario.
Finder get _selectorPedido => find.byType(DropdownButton<Order>);

/// El selector de motivo (un DropdownButtonFormField).
Finder get _selectorMotivo => find.byType(DropdownButton<String>);

void main() {
  group('#43 Reembolsos: solicitar el reembolso de un pedido completado', () {
    // Escenario: solo pedidos completados
    //   Dado que quiero solicitar un reembolso
    //   Cuando abro el formulario
    //   Entonces solo puedo elegir entre mis pedidos completados
    testWidgets('Escenario: solo pedidos completados', (tester) async {
      // Dado que quiero solicitar un reembolso (tengo pedidos en todos los
      // estados)
      final backend = _BackendReembolsos();
      await _abrirReembolsos(tester, backend);

      // Cuando abro el formulario
      await _abrirFormulario(tester);
      expect(find.text('Solicitar Reembolso'), findsOneWidget);
      expect(
        backend.api.llamo(ApiConstants.misPedidos, metodo: 'GET-Auth'),
        isTrue,
      );

      // Entonces solo puedo elegir entre mis pedidos completados.
      // Ajuste: la app también ofrece el pedido entregado a domicilio
      // (estado «entregado») y deja fuera el que ya tiene una solicitud
      // viva, igual que valida POST /reembolsos (#172); el aviso del
      // formulario lo explica.
      expect(
        find.textContaining(
          'un pedido recogido o entregado a domicilio, una solicitud por pedido',
        ),
        findsOneWidget,
      );
      expect(find.text(r'#PIER-9 — $640.00'), findsOneWidget); // ya elegido
      final opciones = tester.widget<DropdownButton<Order>>(_selectorPedido);
      expect(
        [for (final o in opciones.items!) o.value!.numero],
        ['PIER-9', 'PIER-10'],
      );
      await tester.tap(_selectorPedido);
      await tester.pumpAndSettle();
      expect(find.text(r'#PIER-10 — $300.00'), findsOneWidget);
      for (final fuera in [
        r'#PIER-11 — $150.00', // pendiente
        r'#PIER-12 — $420.00', // en camino
        r'#PIER-13 — $200.00', // cancelado
        r'#PIER-14 — $500.00', // con solicitud en revisión
      ]) {
        expect(find.text(fuera), findsNothing);
      }
      await tester.tap(find.text(r'#PIER-10 — $300.00'));
      await tester.pumpAndSettle();
      expect(find.text(r'#PIER-10 — $300.00'), findsOneWidget);
      expect(find.text(r'#PIER-9 — $640.00'), findsNothing);
    });

    // Escenario: motivo obligatorio
    //   Dado que elegí un pedido completado
    //   Cuando intento enviar la solicitud sin elegir un motivo
    //   Entonces la app no la envía y me pide seleccionar uno
    testWidgets('Escenario: motivo obligatorio', (tester) async {
      final backend = _BackendReembolsos();
      await _abrirReembolsos(tester, backend);

      // Dado que elegí un pedido completado
      await _abrirFormulario(tester);
      await _elegir(tester, _selectorPedido, r'#PIER-9 — $640.00');
      expect(find.text(r'#PIER-9 — $640.00'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'El pan llegó duro y seco.',
      );

      // Cuando intento enviar la solicitud sin elegir un motivo
      await _enviar(tester);

      // Entonces la app no la envía y me pide seleccionar uno: el aviso bajo
      // el selector (además de su pista) y sigo en el formulario.
      expect(backend.api.llamo(ApiConstants.crearReembolso), isFalse);
      expect(backend.reembolsos, isEmpty);
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .errorText,
        'Selecciona un motivo',
      );
      expect(find.text('Selecciona un motivo'), findsNWidgets(2));
      expect(find.text('Mínimo 10 caracteres'), findsNothing);
      expect(find.text('Solicitar Reembolso'), findsOneWidget);
      expect(find.text('Solicitud enviada con éxito'), findsNothing);

      // Ajuste: la historia habla de 7 motivos, con «Pedido incompleto» y
      // «Otro»; la app ofrece los 6 del ENUM motivo_reembolso de la base (los
      // mismos que la web y el panel; el backend rechaza cualquier otro,
      // #118), y el último se llama «Otro motivo».
      final motivos = tester.widget<DropdownButton<String>>(_selectorMotivo);
      expect([for (final m in motivos.items!) (m.child as Text).data], [
        'Producto dañado',
        'No satisfecho con el producto',
        'Pedido incorrecto',
        'Tardanza en preparación',
        'Cantidad incorrecta',
        'Otro motivo',
      ]);
    });

    // Escenario: solicitud enviada
    //   Dado que elegí un pedido, un motivo y escribí la descripción
    //   Cuando envío la solicitud
    //   Entonces aparece en mi lista de reembolsos con su estado
    testWidgets('Escenario: solicitud enviada', (tester) async {
      final backend = _BackendReembolsos();
      await _abrirReembolsos(tester, backend);
      expect(find.text('Sin solicitudes'), findsOneWidget);

      // Dado que elegí un pedido, un motivo y escribí la descripción
      await _abrirFormulario(tester);
      await _elegir(tester, _selectorPedido, r'#PIER-10 — $300.00');
      await _elegir(tester, _selectorMotivo, 'Producto dañado');
      await tester.enterText(
        find.byType(TextFormField),
        '  El pastel llegó aplastado de un lado.  ',
      );

      // Cuando envío la solicitud
      await _enviar(tester);

      // Entonces aparece en mi lista de reembolsos con su estado: se manda
      // el pedido, el total como monto, el código del motivo y la
      // descripción sin espacios de sobra, y la app vuelve a «Mis
      // Solicitudes».
      final solicitud = backend.api.ultima(ApiConstants.crearReembolso)!;
      expect(solicitud.metodo, 'POST-Auth');
      expect(solicitud.body, {
        'pedido_id': 10,
        'monto': 300.0,
        'motivo': 'producto_danado',
        'descripcion': 'El pastel llegó aplastado de un lado.',
      });
      expect(find.text('Solicitud enviada con éxito'), findsOneWidget);
      expect(find.text('Reembolsos'), findsOneWidget);
      expect(find.text('Sin solicitudes'), findsNothing);
      expect(find.text('Pedido #PIER-10'), findsOneWidget);
      expect(find.text('20 Oct, 2026'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Producto dañado'), findsOneWidget);
      expect(find.text(r'$300.00'), findsOneWidget);
    });

    // Caso de error (#68): el pedido ya no se puede reembolsar
    //   Dado que el formulario me ofrece un pedido completado
    //   Y mientras tanto se pidió su reembolso desde la web
    //   Cuando envío la solicitud
    //   Entonces la app muestra el motivo del backend, no la registra y ese
    //   pedido deja de ofrecerse
    testWidgets('Caso de error: el pedido ya no se puede reembolsar', (
      tester,
    ) async {
      // Dado que el formulario me ofrece un pedido completado…
      final backend = _BackendReembolsos(
        pedidos: [_pedido(9, 'completado', '640')],
      );
      await _abrirReembolsos(tester, backend);
      await _abrirFormulario(tester);
      expect(find.text(r'#PIER-9 — $640.00'), findsOneWidget);
      // …y mientras tanto se pidió su reembolso desde la web
      backend.solicitarDesdeLaWeb(9);

      // Cuando envío la solicitud
      await _elegir(tester, _selectorMotivo, 'Producto dañado');
      await tester.enterText(
        find.byType(TextFormField),
        'Le faltaba la mitad del relleno.',
      );
      await _enviar(tester);

      // Entonces la app muestra el motivo del backend, no la registra…
      expect(backend.api.ultima(ApiConstants.crearReembolso)!.body, {
        'pedido_id': 9,
        'monto': 640.0,
        'motivo': 'producto_danado',
        'descripcion': 'Le faltaba la mitad del relleno.',
      });
      expect(
        find.text('Este pedido ya tiene una solicitud de reembolso (pendiente)'),
        findsOneWidget,
      );
      expect(find.text('Solicitud enviada con éxito'), findsNothing);
      expect(backend.reembolsos, hasLength(1)); // solo la de la web
      expect(find.text('Solicitar Reembolso'), findsOneWidget);
      // …y ese pedido deja de ofrecerse (la app vuelve a pedir los pedidos)
      expect(find.text(r'#PIER-9 — $640.00'), findsNothing);
      expect(find.text('No tienes pedidos para reembolsar'), findsOneWidget);
      final enviar = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Enviar Solicitud'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(enviar.enabled, isFalse);
    });
  });
}
