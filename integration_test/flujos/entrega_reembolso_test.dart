// integration_test/flujos/entrega_reembolso_test.dart — #69: la entrega a
// domicilio de punta a punta y el reembolso de ese pedido, con la app real,
// en el celular virtual (emulador), contra el entorno aislado
// (integracion.yml, «Flujos de compra, reseña y entrega en el entorno
// aislado», dentro de pipeline.yml). Junta el panel del repartidor (#45), la
// entrega con el nombre de quien la recibe (#46) y el reembolso (#43).
//
// La semilla (docker/semilla/semilla_pruebas.sql) trae un repartidor sin
// disponibilidad y, de la cuenta de la semilla, un pedido a domicilio pagado
// y listo para salir (PIER-PRUEBA-0002). La prueba inicia sesión como el
// repartidor (REPARTIDOR_PRUEBA y CLAVE_REPARTIDOR_PRUEBA por
// --dart-define): enciende «Disponible para entregas», toma el pedido de
// «Disponibles», sale en camino, avisa que llegó y confirma la entrega con el
// nombre de quien la recibió, sin foto (es opcional); la entrega queda en su
// «Historial». Cierra la sesión, entra como el cliente (USUARIO_PRUEBA y
// CLAVE_PRUEBA) y, en «Más» → «Mis Reembolsos» → «Nueva Solicitud», pide el
// reembolso de ese pedido con un motivo y una descripción, sin fotos (son
// opcionales y subirlas necesita Cloudinary, que el entorno aislado no
// tiene): la solicitud aparece en «Mis Solicitudes» como «Pendiente». Lo que
// muestra la app se compara con lo que contesta la API.
//
// Solo corre con las cuentas de la semilla: la entrega y la solicitud no se
// deshacen desde la app y el servidor real no tiene ese pedido.
// flujo-compra.yml y la regresión completa corren toda la carpeta flujos/
// contra el servidor real: ahí se omite, igual que sin credenciales. El
// pedido se queda entregado y con su solicitud en la base del contenedor;
// para repetir la prueba hay que bajar y levantar el entorno
// (tool/entorno_pruebas.sh).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pier_reposteria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/reembolsos_repository_remote.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:pier_reposteria/domain/models/entrega_model.dart';
import 'package:pier_reposteria/domain/models/order_model.dart';
import 'package:pier_reposteria/domain/models/reembolso.dart';
import 'package:pier_reposteria/ui/more/widgets/more_screen.dart';
import 'package:pier_reposteria/ui/refunds/widgets/refunds_screen.dart';
import 'package:pier_reposteria/ui/repartidor/view_model/confirmar_entrega_view_model.dart';
import 'package:pier_reposteria/ui/repartidor/view_model/entrega_detail_view_model.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/confirmar_entrega_screen.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/entrega_detail_screen.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/entregas_screen.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/entregas_tarjetas.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/historial_repartidor_screen.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/perfil_repartidor_screen.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/repartidor_main_screen.dart';

import '../ayudas/servidor_real.dart';

/// El folio del pedido a domicilio de la semilla.
const _folio = 'PIER-PRUEBA-0002';

/// Quién recibió el pedido, como lo escribe el repartidor.
const _recibio = 'María López';

/// El motivo de la solicitud (su texto en Reembolso.motivos) y la
/// descripción: el formulario pide 10 caracteres o más.
const _motivo = 'Producto dañado';
const _descripcion = 'La caja llegó aplastada y el pastel venía deshecho';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  toquesPerdidosFallan();

  group('#69 Entrega de punta a punta y reembolso en el entorno aislado', () {
    // Escenario: entregar un pedido a domicilio y pedir su reembolso
    //   Dado que hay un pedido a domicilio pagado y listo para salir
    //   Cuando el repartidor se pone disponible, lo toma, sale en camino,
    //     avisa que llegó y confirma la entrega con el nombre de quien lo
    //     recibió
    //   Entonces la entrega queda en su historial
    //   Cuando el cliente pide el reembolso de ese pedido con un motivo y una
    //     descripción
    //   Entonces la solicitud aparece en sus reembolsos como pendiente.
    testWidgets(
      'Escenario: entregar un pedido a domicilio y pedir su reembolso',
      (tester) async {
        if (faltanCredenciales() ||
            faltaLaCuentaDeLaSemilla() ||
            faltaElRepartidorDeLaSemilla()) {
          return;
        }
        final api = await abrirLaApp(tester);

        // Dado que hay un pedido a domicilio pagado y listo para salir
        await iniciarSesionComoRepartidor(tester);
        await _pedidoListoParaSalir(api);

        // Cuando el repartidor se pone disponible, lo toma, sale en camino,
        // avisa que llegó y confirma la entrega
        await _ponerseDisponible(tester, api);
        await _tomarElPedido(tester);
        await _entregar(tester);

        // Entonces la entrega queda en su historial
        await _verEnElHistorial(tester, api);
        await _cerrarSesion(tester);

        // Cuando el cliente pide el reembolso de ese pedido
        await iniciarSesion(tester);
        final pedido = await _pedidoEntregado(api);
        await _abrirMisReembolsos(tester);
        await _solicitarReembolso(tester, pedido);

        // Entonces la solicitud aparece en sus reembolsos como pendiente
        await _verLaSolicitudPendiente(tester, api);
      },
    );
  });
}

/// La entrega se recorre una vez por entorno: el repartidor de la semilla
/// empieza sin disponibilidad y el pedido, en «Disponibles». Si no es así
/// (otra corrida en el mismo entorno), lo dice antes de empezar.
Future<void> _pedidoListoParaSalir(ApiService api) async {
  final entregas = EntregasRepositoryRemote(api: api);
  final disponible = await entregas.disponibilidad();
  final pedidos = await entregas.disponibles();
  if (disponible || !pedidos.any((pedido) => pedido.numero == _folio)) {
    fail(
      'el repartidor ya está disponible o $_folio no está en «Disponibles»: '
      'si la prueba ya corrió en este entorno, bájalo y levántalo otra vez '
      '(bash tool/entorno_pruebas.sh bajar y levantar); si no, revisa '
      'docker/semilla/semilla_pruebas.sql',
    );
  }
}

/// «Mis entregas»: enciende «Disponible para entregas» y espera a que el
/// servidor lo guarde (sin eso no deja tomar pedidos).
Future<void> _ponerseDisponible(WidgetTester tester, ApiService api) async {
  final interruptor = enPantalla(EntregasScreen, find.byType(Switch));
  await esperar(tester, interruptor, limite: esperaDelServidor);
  expect(
    tester.widget<Switch>(interruptor).value,
    isFalse,
    reason: 'el repartidor de la semilla empieza sin disponibilidad',
  );
  await esperarQueSeAsiente(tester, interruptor);
  await tester.tap(interruptor);

  await esperar(
    tester,
    enPantalla(EntregasScreen, find.text('Sin entregas activas por ahora')),
    motivo: 'el panel no dijo que el repartidor ya está disponible',
  );
  await _esperarAlServidor(
    tester,
    () => EntregasRepositoryRemote(api: api).disponibilidad(),
    motivo: 'el servidor no guardó la disponibilidad',
  );
}

/// «Disponibles» → «Tomar entrega» en la tarjeta del pedido → el aviso del
/// servidor → el pedido pasa a «En curso».
Future<void> _tomarElPedido(WidgetTester tester) async {
  final disponible = find.ancestor(
    of: find.text(_folio),
    matching: find.byType(DisponibleCard),
  );
  await esperar(
    tester,
    disponible,
    limite: esperaDelServidor,
    motivo: '$_folio no apareció en «Disponibles»',
  );
  await _tocar(
    tester,
    find.descendant(of: disponible, matching: find.text('Tomar entrega')),
  );
  await _esperarAviso(tester, 'Tomaste el pedido #$_folio');
  await esperar(
    tester,
    _enCurso(),
    limite: esperaDelServidor,
    motivo: '$_folio no pasó a «En curso»',
  );
}

/// La tarjeta en curso → su detalle → «Salir en camino» → «Llegué al
/// domicilio» → «Marcar entregado» → quién lo recibió, sin foto →
/// «Confirmar entrega»: de vuelta en el panel.
Future<void> _entregar(WidgetTester tester) async {
  final tarjeta = _enCurso();
  await tester.ensureVisible(tarjeta);
  await esperarQueSeAsiente(tester, tarjeta);
  await tester.tap(find.descendant(of: tarjeta, matching: find.text(_folio)));

  final detalle = find.byType(EntregaDetailScreen);
  await esperar(tester, detalle);
  Finder enElDetalle(String texto) =>
      find.descendant(of: detalle, matching: find.text(texto));
  await _tocar(tester, enElDetalle('Salir en camino'));
  await _esperarAviso(tester, EntregaDetailViewModel.mensajeEnCamino);
  await _tocar(tester, enElDetalle('Llegué al domicilio (avisar al cliente)'));
  await _esperarAviso(tester, 'Cliente avisado de tu llegada');
  await _tocar(tester, enElDetalle('Marcar entregado'));

  final confirmacion = find.byType(ConfirmarEntregaScreen);
  final recibio = find.descendant(
    of: confirmacion,
    matching: find.byType(TextField),
  );
  await esperar(tester, recibio);
  await tester.ensureVisible(recibio);
  await esperarQueSeAsiente(tester, recibio);
  await escribirYCerrarTeclado(tester, recibio, _recibio);
  await _tocar(
    tester,
    find.descendant(
      of: confirmacion,
      matching: find.widgetWithText(ElevatedButton, 'Confirmar entrega'),
    ),
  );
  await _esperarAviso(tester, ConfirmarEntregaViewModel.mensajeConfirmada);
  await esperarQue(
    tester,
    () => confirmacion.evaluate().isEmpty && detalle.evaluate().isEmpty,
    motivo: 'no se cerraron la confirmación y el detalle de la entrega',
    limite: const Duration(seconds: 10),
  );
}

/// Pestaña «Historial»: la entrega está entre las finalizadas hoy y la API
/// la da por entregada a nombre de quien la recibió.
Future<void> _verEnElHistorial(WidgetTester tester, ApiService api) async {
  await tester.tap(pestana('Historial'));
  await esperar(
    tester,
    enPantalla(HistorialRepartidorScreen, find.text(_folio)),
    limite: esperaDelServidor,
    motivo: '$_folio no apareció en «Historial»',
  );

  final entregas = await EntregasRepositoryRemote(api: api).misEntregas();
  final entrega = entregas.where((e) => e.numero == _folio).firstOrNull;
  expect(
    entrega?.estado,
    EstadoEntrega.entregada,
    reason: 'la API debe dar $_folio por entregado',
  );
  expect(
    entrega?.recibioNombre,
    _recibio,
    reason: 'la entrega guarda quién la recibió',
  );
}

/// Pestaña «Perfil» → «Cerrar sesión» → lo confirma: el panel se cierra y
/// vuelve «Iniciar Sesión».
Future<void> _cerrarSesion(WidgetTester tester) async {
  await tester.tap(pestana('Perfil'));
  await _tocar(
    tester,
    enPantalla(
      PerfilRepartidorScreen,
      find.widgetWithText(ElevatedButton, 'Cerrar sesión'),
    ),
  );
  final confirmar = find.widgetWithText(TextButton, 'Cerrar sesión');
  await esperar(tester, confirmar);
  await esperarQueSeAsiente(tester, confirmar);
  await tester.tap(confirmar);
  await esperarQue(
    tester,
    () => find.byType(RepartidorMainScreen).evaluate().isEmpty,
    limite: esperaDelServidor,
    motivo: 'no se cerró la sesión del repartidor',
  );
}

/// El pedido de la semilla en los pedidos del cliente: ya entregado y sin
/// solicitud de reembolso, así que se puede reembolsar (#172).
Future<Order> _pedidoEntregado(ApiService api) async {
  final pedidos = await PedidosRepositoryRemote(api: api).listarMisPedidos();
  final pedido = pedidos.where((p) => p.numero == _folio).firstOrNull;
  if (pedido == null) {
    fail('$_folio no está en los pedidos de la cuenta de la semilla');
  }
  expect(
    pedido.status,
    OrderStatus.delivered,
    reason: 'al confirmar la entrega, el pedido queda entregado',
  );
  expect(
    pedido.reembolsable,
    isTrue,
    reason: 'un pedido entregado y sin solicitud se puede reembolsar',
  );
  return pedido;
}

/// Pestaña «Más» → «Mis Reembolsos».
Future<void> _abrirMisReembolsos(WidgetTester tester) async {
  await tester.tap(pestana('Más'));
  await _tocar(tester, enPantalla(MoreScreen, find.text('Mis Reembolsos')));
  await esperar(tester, find.byType(RefundsScreen));
}

/// «Nueva Solicitud» → el pedido → el motivo → la descripción, sin fotos →
/// «Enviar Solicitud» → el aviso de que se envió.
Future<void> _solicitarReembolso(WidgetTester tester, Order pedido) async {
  final pantalla = find.byType(RefundsScreen);
  Finder enLaPantalla(Finder buscado) =>
      find.descendant(of: pantalla, matching: buscado);

  final nueva = enLaPantalla(find.widgetWithText(Tab, 'Nueva Solicitud'));
  await esperar(tester, nueva);
  await esperarQueSeAsiente(tester, nueva);
  await tester.tap(nueva);

  // El selector de pedidos aparece cuando llegan los que se pueden
  // reembolsar; muestra el folio y el total.
  final selector = enLaPantalla(find.byType(DropdownButton<Order>));
  await esperar(
    tester,
    selector,
    limite: esperaDelServidor,
    motivo: 'el formulario no ofreció pedidos para reembolsar',
  );
  await _elegir(
    tester,
    selector,
    '#${pedido.numero} — \$${pedido.total.toStringAsFixed(2)}',
  );
  expect(
    tester.widget<DropdownButton<Order>>(selector).value?.numero,
    pedido.numero,
    reason: 'quedó elegido otro pedido',
  );

  // El motivo se elige tocando su selector, no su pista «Selecciona un
  // motivo»: la pista no recibe toques y el toque fallaría.
  await _elegir(
    tester,
    enLaPantalla(find.byType(DropdownButton<String>)),
    _motivo,
  );

  // La descripción es el único campo de texto del formulario.
  final descripcion = enLaPantalla(find.byType(TextField));
  await tester.ensureVisible(descripcion);
  await esperarQueSeAsiente(tester, descripcion);
  await escribirYCerrarTeclado(tester, descripcion, _descripcion);

  await _tocar(tester, enLaPantalla(find.text('Enviar Solicitud')));
  await _esperarAviso(tester, 'Solicitud enviada con éxito');
}

/// La API da la solicitud del pedido por pendiente y «Mis Solicitudes» la
/// muestra así, con su pedido y su motivo.
Future<void> _verLaSolicitudPendiente(
  WidgetTester tester,
  ApiService api,
) async {
  final solicitudes = await ReembolsosRepositoryRemote(
    api: api,
  ).listarMisReembolsos();
  final solicitud = solicitudes
      .where((s) => s.pedidoNumero == _folio)
      .firstOrNull;
  if (solicitud == null) {
    fail('la API no tiene la solicitud de reembolso de $_folio');
  }
  expect(
    solicitud.estado,
    EstadoReembolso.pendiente,
    reason: 'una solicitud nueva queda pendiente',
  );

  final tarjeta = enPantalla(
    RefundsScreen,
    find.byKey(ValueKey<String>(solicitud.id)),
  );
  await esperar(
    tester,
    tarjeta,
    limite: esperaDelServidor,
    motivo: 'la solicitud no apareció en «Mis Solicitudes»',
  );
  for (final texto in ['Pedido #$_folio', 'Pendiente', _motivo]) {
    expect(
      find.descendant(of: tarjeta, matching: find.text(texto)),
      findsOneWidget,
      reason: 'la solicitud debe mostrar «$texto»',
    );
  }
}

/// La tarjeta del pedido en «En curso».
Finder _enCurso() =>
    find.ancestor(of: find.text(_folio), matching: find.byType(EntregaCard));

/// Lleva [boton] a la vista, espera a que se quede quieto y lo toca.
Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await esperar(tester, boton, limite: esperaDelServidor);
  await tester.ensureVisible(boton);
  await esperarQueSeAsiente(tester, boton);
  await tester.tap(boton);
}

/// Toca [selector] (un menú desplegable), toca [opcion] en el menú y espera
/// a que se cierre con ella elegida.
Future<void> _elegir(
  WidgetTester tester,
  Finder selector,
  String opcion,
) async {
  final opciones = find.text(opcion);
  final antes = opciones.evaluate().length;
  await tester.ensureVisible(selector);
  await esperarQueSeAsiente(tester, selector);
  await tester.tap(selector);
  await esperarQue(
    tester,
    () => opciones.evaluate().length > antes,
    motivo: 'no se abrió el menú con «$opcion»',
    limite: const Duration(seconds: 10),
  );
  // El menú va encima de todo: su opción es la última.
  await esperarQueSeAsiente(tester, opciones.last);
  await tester.tap(opciones.last);
  await esperarQue(
    tester,
    () => opciones.evaluate().length == 1,
    motivo: 'el menú no se cerró con «$opcion» elegido',
    limite: const Duration(seconds: 10),
  );
}

/// Espera el aviso [mensaje] (un SnackBar) y a que se quite, para que no
/// tape el siguiente toque. Cada paso empieza sin avisos: si el primero que
/// aparece dice otra cosa (un error del servidor), la prueba falla con lo
/// que dijo.
Future<void> _esperarAviso(WidgetTester tester, String mensaje) async {
  final avisos = find.descendant(
    of: find.byType(SnackBar),
    matching: find.byType(Text),
  );
  await esperar(
    tester,
    avisos,
    limite: esperaDelServidor,
    motivo: 'la app no avisó «$mensaje»',
  );
  expect(
    textosDe(avisos),
    contains(mensaje),
    reason: 'la app avisó otra cosa en lugar de «$mensaje»',
  );
  await esperarQue(
    tester,
    () => find.byType(SnackBar).evaluate().isEmpty,
    limite: const Duration(seconds: 15),
    motivo: 'el aviso «$mensaje» no se quitó',
  );
}

/// Pregunta [consulta] al servidor cada medio segundo (dando cuadros) hasta
/// que conteste true.
Future<void> _esperarAlServidor(
  WidgetTester tester,
  Future<bool> Function() consulta, {
  required String motivo,
}) async {
  final fin = DateTime.now().add(esperaDelServidor);
  while (DateTime.now().isBefore(fin)) {
    if (await consulta()) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
  fail('$motivo (${esperaDelServidor.inSeconds} s)');
}
