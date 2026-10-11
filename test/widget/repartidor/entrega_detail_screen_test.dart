// test/widget/repartidor/entrega_detail_screen_test.dart — el detalle de una
// entrega (MVVM, Fase 5) sin red: tarjetas de cliente, dirección y cobro;
// salir en camino, avisar llegada, confirmar con evidencia y reportar fallo,
// avisando al panel en cada cambio.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/confirmar_entrega_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/entrega_detail_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/confirmar_entrega_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entrega_detail_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/reportar_fallo_sheet.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

final String _estado = ApiConstants.entregaEstado('9');
final String _llegue = ApiConstants.entregaLlegue('9');

EntregaRepartidor _entrega({
  String estado = 'asignada',
  String pago = 'efectivo',
  Object? direccion = const {
    'alias': 'Casa',
    'calle_numero': 'Juárez 12',
    'colonia': 'Centro',
    'referencias': 'Portón azul',
    'telefono_contacto': '7711234567',
  },
  String? notas = 'Tocar fuerte',
}) =>
    EntregaRepartidor.fromJson({
      'id': 9,
      'estado': estado,
      'numero': 'PIER-0041',
      'total': 330,
      'costo_envio': 30,
      'metodo_pago': pago,
      'notas': notas,
      'cliente_nombre': 'Ana',
      'cliente_apellido': 'López',
      'cliente_telefono': '7719998888',
      'direccion_entrega': direccion,
    });

/// Pantalla de partida: abre [destino] y guarda con qué se cerró.
class _Anfitrion extends StatelessWidget {
  const _Anfitrion(this.destino, this.resultado);

  final Widget destino;
  final ValueNotifier<bool?> resultado;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              resultado.value = await Navigator.push<bool>(
                  context, MaterialPageRoute(builder: (_) => destino));
            },
            child: const Text('Abrir'),
          ),
        ),
      );
}

class _Montaje {
  _Montaje(this.api, this.resultado);

  final FakeApiClient api;
  final ValueNotifier<bool?> resultado;
  int avisos = 0;
}

Future<_Montaje> _montar(
  WidgetTester tester, {
  EntregaRepartidor? entrega,
  Map<String, dynamic>? respuestas,
  bool conViewModel = false,
}) async {
  // Pantalla de celular (412×869 lógicos, como el Note 10+).
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  final api = FakeApiClient(respuestas: respuestas);
  final montaje = _Montaje(api, ValueNotifier(null));
  Future<void> alCambiar() async => montaje.avisos++;
  final e = entrega ?? _entrega();
  await tester.pumpApp(
    _Anfitrion(
      EntregaDetailScreen(
        entrega: e,
        alCambiar: alCambiar,
        viewModel: conViewModel
            ? EntregaDetailViewModel(
                repo: EntregasRepositoryRemote(api: api),
                entrega: e,
                alCambiar: alCambiar,
              )
            : null,
      ),
      montaje.resultado,
    ),
    api: api,
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return montaje;
}

/// El botón (Elevated, Outlined o Text) que lleva [texto].
Finder _boton(String texto) => find.ancestor(
    of: find.text(texto), matching: find.bySubtype<ButtonStyleButton>());

/// Quita el aviso visible para que el siguiente no espere en la cola.
void _quitarAviso(WidgetTester tester) => tester
    .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
    .removeCurrentSnackBar();

Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('EntregaDetailScreen', () {
    testWidgets('pinta cliente, dirección, cobro y acciones de asignada',
        (tester) async {
      await _montar(tester);

      expect(find.text('PIER-0041'), findsNWidgets(2)); // barra y tarjeta
      expect(find.text('Asignada'), findsOneWidget);
      expect(find.text('AL'), findsOneWidget);
      expect(find.text('Ana López'), findsOneWidget);
      expect(find.text('7719998888'), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('Juárez 12'), findsOneWidget);
      expect(find.text('Ref: Portón azul'), findsOneWidget);
      expect(find.text('Cómo llegar'), findsOneWidget);
      expect(find.text('Llamar'), findsOneWidget);
      expect(find.text('Salir en camino'), findsOneWidget);
      expect(find.text('¿Ya estás en el domicilio? Marcar entregado'),
          findsOneWidget);
      expect(find.text('Llegué al domicilio (avisar al cliente)'),
          findsNothing);

      await tester.scrollUntilVisible(find.text('Método: Efectivo'), 200);
      expect(find.text(r'$300 MXN'), findsOneWidget); // subtotal
      expect(find.text(r'$330 MXN'), findsOneWidget); // total
      expect(find.text('Tocar fuerte'), findsOneWidget);
      expect(find.text('Cobra en efectivo al entregar'), findsOneWidget);
    });

    testWidgets('sin dirección, notas ni teléfono; pagada con tarjeta',
        (tester) async {
      await _montar(tester,
          entrega: EntregaRepartidor.fromJson(const {
            'id': 9,
            'estado': 'entregada',
            'numero': 'PIER-0041',
            'metodo_pago': 'tarjeta',
          }));

      expect(find.text('Sin dirección registrada'), findsOneWidget);
      expect(find.text('Cómo llegar'), findsNothing);
      expect(find.text('Llamar'), findsNothing);
      expect(find.text('Notas del cliente'), findsNothing);
      expect(find.text('Pagado en la app'), findsOneWidget);
      expect(find.text('Reportar'), findsNothing); // finalizada
    });

    testWidgets('con coordenadas ofrece la ruta por GPS', (tester) async {
      await _montar(tester,
          entrega: _entrega(direccion: {
            'calle_numero': 'Juárez 12',
            'lat': 21.14,
            'lng': -98.42,
          }));
      expect(find.text('Cómo llegar (GPS)'), findsOneWidget);
    });

    testWidgets('si no se puede abrir mapa, marcador o WhatsApp lo avisa',
        (tester) async {
      // Sin plugin de url_launcher en pruebas: contesta que no se abrió.
      const canal = MethodChannel('plugins.flutter.io/url_launcher');
      final abiertos = <Object?>[];
      final mensajero = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(canal, (llamada) async {
          abiertos.add((llamada.arguments as Map)['url']);
          return false;
        });
      addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
      await _montar(tester);

      await _tocar(tester, find.text('Cómo llegar'));
      expect(find.text('No se pudo abrir el mapa'), findsOneWidget);

      _quitarAviso(tester);
      await _tocar(tester, find.text('Llamar'));
      expect(find.text('No se pudo abrir el marcador'), findsOneWidget);

      _quitarAviso(tester);
      await _tocar(tester, find.text('WhatsApp'));
      expect(find.text('No se pudo abrir WhatsApp'), findsOneWidget);
      const mapa = 'https://www.google.com/maps/dir/?api=1&destination='
          'Ju%C3%A1rez%2012%2C%20Centro%2C%20Huejutla%20de%20Reyes'
          '&travelmode=driving';
      expect(abiertos, [
        mapa,
        'tel:7711234567',
        'https://wa.me/527711234567',
      ]);
    });

    testWidgets('salir en camino cambia los botones y avisa al panel',
        (tester) async {
      final m = await _montar(tester,
          conViewModel: true, respuestas: {_estado: {'success': true}});
      m.api.demorar(_estado, const Duration(seconds: 1));

      await _tocar(tester, find.text('Salir en camino'));
      expect(find.text('Actualizando…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text(EntregaDetailViewModel.mensajeEnCamino), findsOneWidget);
      expect(find.text('En camino'), findsOneWidget);
      expect(find.text('Marcar entregado'), findsOneWidget);
      expect(find.text('Llegué al domicilio (avisar al cliente)'),
          findsOneWidget);
      expect(m.avisos, 1);
    });

    testWidgets('si no puede salir en camino lo avisa y sigue asignada',
        (tester) async {
      final m = await _montar(tester);
      m.api.fallar(_estado, 'Entrega no encontrada');

      await _tocar(tester, find.text('Salir en camino'));

      expect(find.text('Entrega no encontrada'), findsOneWidget);
      expect(find.text('Salir en camino'), findsOneWidget);
      expect(m.avisos, 0);
    });

    testWidgets('en camino avisa la llegada al cliente', (tester) async {
      final m = await _montar(tester,
          entrega: _entrega(estado: 'en_camino'),
          respuestas: {
            _llegue: {
              'success': true,
              'message': 'Cliente avisado de tu llegada',
            },
          });
      m.api.demorar(_llegue, const Duration(seconds: 1));

      await _tocar(
          tester, find.text('Llegué al domicilio (avisar al cliente)'));
      expect(find.text('Avisando…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('Cliente avisado de tu llegada'), findsOneWidget);
    });

    testWidgets('marcar entregado confirma y cierra el detalle con true',
        (tester) async {
      final m = await _montar(tester,
          entrega: _entrega(estado: 'en_camino'),
          respuestas: {_estado: {'success': true}});

      await _tocar(tester, find.text('Marcar entregado'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmarEntregaScreen), findsOneWidget);
      expect(find.text('Cobro en efectivo'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'María');
      await _tocar(tester, _boton('Confirmar entrega'));
      await tester.pumpAndSettle();

      expect(find.text(ConfirmarEntregaViewModel.mensajeConfirmada),
          findsOneWidget);
      expect(find.byType(EntregaDetailScreen), findsNothing);
      expect(m.resultado.value, isTrue);
      expect(m.avisos, 1);
      expect(m.api.ultima(_estado)!.body,
          {'estado': 'entregada', 'recibio_nombre': 'María'});
    });

    testWidgets('regresar de la confirmación deja el detalle abierto',
        (tester) async {
      await _montar(tester);

      await _tocar(
          tester, find.text('¿Ya estás en el domicilio? Marcar entregado'));
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Regresar'));
      await tester.pumpAndSettle();

      expect(find.byType(EntregaDetailScreen), findsOneWidget);
    });

    testWidgets('la hoja de reporte se cierra con la «x» o con Cancelar',
        (tester) async {
      await _montar(tester);

      await _tocar(tester, find.text('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(find.byType(ReportarFalloSheet), findsNothing);

      await _tocar(tester, find.text('Reportar'));
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportarFalloSheet), findsNothing);
      expect(find.byType(EntregaDetailScreen), findsOneWidget);
    });

    testWidgets('reportar un fallo cierra la hoja y el detalle con true',
        (tester) async {
      final m = await _montar(tester, respuestas: {_estado: {'success': true}});

      await _tocar(tester, find.text('Reportar'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportarFalloSheet), findsOneWidget);

      await tester.tap(find.text('No contestó'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Nadie abrió');
      await _tocar(tester, find.text('Reportar fallo'));
      await tester.pumpAndSettle();

      expect(find.byType(EntregaDetailScreen), findsNothing);
      expect(m.resultado.value, isTrue);
      expect(m.api.ultima(_estado)!.body,
          {'estado': 'fallida', 'motivo_fallo': 'No contestó: Nadie abrió'});
      expect(m.avisos, 1);
    });
  });

  group('ConfirmarEntregaScreen', () {
    Future<FakeApiClient> abrir(
      WidgetTester tester, {
      ConfirmarEntregaViewModel Function(FakeApiClient api)? viewModel,
      String pago = 'efectivo',
    }) async {
      tester.view
        ..physicalSize = const Size(1440, 3040)
        ..devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      final api = FakeApiClient();
      final e = _entrega(estado: 'en_camino', pago: pago);
      await tester.pumpApp(
        ConfirmarEntregaScreen(entrega: e, viewModel: viewModel?.call(api)),
        api: api,
      );
      return api;
    }

    testWidgets('pide quién recibió', (tester) async {
      final api = await abrir(tester, pago: 'tarjeta');
      expect(find.text('Pagado en la app'), findsOneWidget);

      await _tocar(tester, _boton('Confirmar entrega'));

      expect(find.text(ConfirmarEntregaViewModel.faltaQuienRecibio),
          findsOneWidget);
      expect(api.llamo(_estado), isFalse);
    });

    testWidgets('la cámara sin permiso lo avisa; la galería pone la foto',
        (tester) async {
      // Sin plugin de image_picker en pruebas: la cámara falla y la galería
      // devuelve una ruta.
      const canal = MethodChannel('plugins.flutter.io/image_picker');
      final fuentes = <Object?>[];
      final mensajero = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(canal, (llamada) async {
          final fuente = (llamada.arguments as Map)['source'];
          fuentes.add(fuente);
          if (fuente == 0) {
            throw PlatformException(code: 'camera_access_denied');
          }
          return '/no/existe.jpg';
        });
      addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
      await abrir(tester);

      await _tocar(tester, find.text('Cámara'));
      expect(find.text('No se pudo acceder a la imagen'), findsOneWidget);

      await _tocar(tester, find.text('Galería'));
      expect(fuentes, [0, 1]);
      expect(find.text('Cámara'), findsNothing); // ya hay foto
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
    });

    testWidgets('con foto que no sube confirma sin evidencia y lo avisa',
        (tester) async {
      final api = await abrir(
        tester,
        viewModel: (api) => ConfirmarEntregaViewModel(
          repo: EntregasRepositoryRemote(api: api),
          entrega: _entrega(estado: 'en_camino'),
        )..elegirEvidencia('/no/existe.jpg'),
      );
      api
        ..fallar(ApiConstants.uploadImagen, 'Error al subir imagen')
        ..fallar(_estado, 'Entrega no encontrada')
        ..demorar(_estado, const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Cámara'), findsNothing); // ya hay foto

      await tester.enterText(find.byType(TextField), 'María');
      await _tocar(tester, _boton('Confirmar entrega'));
      expect(find.text('Confirmando…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(
          find.text('No se pudo subir la foto, se confirmará sin evidencia'),
          findsOneWidget);
      expect(find.byType(ConfirmarEntregaScreen), findsOneWidget);
    });

    testWidgets('la «x» quita la foto elegida', (tester) async {
      await abrir(
        tester,
        viewModel: (api) => ConfirmarEntregaViewModel(
          repo: EntregasRepositoryRemote(api: api),
          entrega: _entrega(),
        )..elegirEvidencia('/no/existe.jpg'),
      );
      await tester.pump();
      expect(find.text('Cámara'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();

      expect(find.text('Cámara'), findsOneWidget);
    });
  });

  group('ReportarFalloSheet', () {
    Future<FakeApiClient> abrir(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1440, 3040)
        ..devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      final api = FakeApiClient();
      await tester.pumpApp(
        Scaffold(body: ReportarFalloSheet(entrega: _entrega())),
        api: api,
      );
      return api;
    }

    testWidgets('pide el motivo antes de reportar', (tester) async {
      final api = await abrir(tester);

      await _tocar(tester, find.text('Reportar fallo'));

      expect(find.text('Describe brevemente el motivo del fallo'),
          findsOneWidget);
      expect(api.llamo(_estado), isFalse);
    });

    testWidgets('si el backend lo rechaza lo avisa', (tester) async {
      final api = await abrir(tester);
      api
        ..fallar(_estado, 'Indica el motivo del fallo')
        ..demorar(_estado, const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'Nadie abrió');
      await _tocar(tester, find.text('Reportar fallo'));
      expect(find.text('Reportando…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('Indica el motivo del fallo'), findsOneWidget);
    });
  });
}
