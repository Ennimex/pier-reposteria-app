// test/widget/comandas/nueva_comanda_screen_test.dart — «Nueva comanda»
// (#130) sin red: quién la ve en la agenda, las secciones, agregar pastel y
// producto del catálogo, lo que hay que corregir, la foto que falló con
// reintento, el error del catálogo, guardar hasta abrir la comanda creada y
// que cerrar los selectores de fecha y hora no regresa el foco (#241).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository_remote.dart';
import 'package:pier_reposteria/domain/models/nueva_comanda.dart';
import 'package:pier_reposteria/ui/comandas/view_model/nueva_comanda_view_model.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_screen.dart';
import 'package:pier_reposteria/ui/comandas/widgets/detalle_comanda_screen.dart';
import 'package:pier_reposteria/ui/comandas/widgets/nueva_comanda_partes.dart';
import 'package:pier_reposteria/ui/comandas/widgets/nueva_comanda_screen.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_comandas.dart';

FakeApiClient _backend() => FakeApiClient()
  ..responder(ApiConstants.agendaComandas('proximas'), agendaJson([]))
  ..responder(ApiConstants.comandasCatalogo, catalogoJson());

/// Monta el formulario con su ViewModel (reloj del 12 de octubre de 2026).
Future<NuevaComandaViewModel> _formulario(
  WidgetTester tester,
  FakeApiClient api,
) async {
  final vm = NuevaComandaViewModel(
    repo: ComandasRepositoryRemote(api: api),
    ahora: () => DateTime(2026, 10, 12, 10),
  );
  await montarComandas(
    tester,
    api,
    pantalla: NuevaComandaScreen(viewModel: vm),
    rol: 'empleado',
  );
  return vm;
}

/// Si algún campo de texto tiene el foco (el teclado estaría abierto).
bool _algunCampoConFoco(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .any((campo) => campo.focusNode.hasFocus);

void main() {
  group('NuevaComandaScreen', () {
    testWidgets('el mostrador la abre desde la agenda; producción no',
        (tester) async {
      final api = _backend();
      await montarComandas(
        tester,
        api,
        pantalla: const AgendaComandasScreen(),
        rol: 'empleado',
      );

      await tester.tap(find.text('Nueva comanda'));
      await tester.pumpAndSettle();

      expect(find.byType(NuevaComandaScreen), findsOneWidget);
      expect(api.llamo(ApiConstants.comandasCatalogo), isTrue);
      for (final seccion in [
        'Cliente',
        'Entrega',
        'Productos',
        'Imágenes de referencia',
        'Cobro',
        'Notas',
      ]) {
        expect(find.text(seccion), findsOneWidget);
      }
    });

    testWidgets('hornos no ve «Nueva comanda»', (tester) async {
      await montarComandas(
        tester,
        _backend(),
        pantalla: const AgendaComandasScreen(),
      );
      expect(find.text('Nueva comanda'), findsNothing);
    });

    testWidgets('agrega un pastel y un producto grande con su precio',
        (tester) async {
      final vm = await _formulario(tester, _backend());

      await tester.tap(find.text('Agregar pastel personalizado'));
      await tester.pumpAndSettle();
      expect(find.byType(TarjetaPastel), findsOneWidget);
      expect(find.text('Pastel 1'), findsOneWidget);

      await tester.tap(find.text('Agregar producto del catálogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gelatina'));
      await tester.pumpAndSettle();
      expect(find.byType(TarjetaProducto), findsOneWidget);

      await tester.tap(find.text(r'Grande · $120.00'));
      await tester.pumpAndSettle();
      expect((vm.renglones.last as ProductoBorrador).grande, isTrue);
      expect(vm.subtotal, 12000);
      expect(find.text(r'Guardar · $120.00'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar Pastel 1'));
      await tester.pumpAndSettle();
      expect(find.byType(TarjetaPastel), findsNothing);
    });

    testWidgets('al guardar sin datos dice qué corregir', (tester) async {
      final api = _backend();
      await _formulario(tester, api);

      await tester.tap(find.text(r'Guardar · $0.00'));
      await tester.pumpAndSettle();

      expect(find.text('Revisa lo siguiente:'), findsOneWidget);
      expect(find.text('• Escribe el nombre del cliente'), findsOneWidget);
      expect(find.text('• Agrega al menos un pastel o un producto'),
          findsOneWidget);
      expect(api.llamo(ApiConstants.comandas, metodo: 'POST-Auth'), isFalse);
    });

    testWidgets('guarda y abre la comanda creada con su folio',
        (tester) async {
      final api = _backend()
        ..responder(ApiConstants.comandas, {
          'success': true,
          'comanda': {'id': 7, 'folio': 5120},
          'advertencias': <String>[],
          'message': 'Comanda #5120 creada',
        })
        ..responder(ApiConstants.comandaDetalle(7), detalleJson());
      final vm = await _formulario(tester, api);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre del cliente'),
          'María López');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Teléfono (10 dígitos)'),
          '7711234567');
      vm.editar(() {
        vm
          ..fecha = DateTime(2026, 10, 20)
          ..hora = '16:30';
        vm.agregarProducto(vm.catalogo!.productos.first);
      });
      await tester.pumpAndSettle();
      expect(find.text('20 Oct 2026'), findsOneWidget);
      expect(find.text('16:30'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Anticipo'), '45.50');
      await tester.pumpAndSettle();

      await tester.tap(find.text(r'Guardar · $45.50'));
      await tester.pumpAndSettle();

      expect(find.byType(DetalleComandaScreen), findsOneWidget);
      expect(find.text('Comanda #5120 creada'), findsOneWidget);
      final body = api.ultima(ApiConstants.comandas)!.body!;
      expect(body['cliente_nombre'], 'María López');
      expect(body['anticipo'], 45.5);
    });

    testWidgets('abierta desde la agenda, regresa con la comanda creada',
        (tester) async {
      final api = _backend()
        ..responder(ApiConstants.comandas, {
          'success': true,
          'comanda': {'id': 7, 'folio': 5120},
          'message': 'Comanda #5120 creada',
        });
      final vm = NuevaComandaViewModel(
        repo: ComandasRepositoryRemote(api: api),
        ahora: () => DateTime(2026, 10, 12, 10),
      );
      Object? resultado;
      await montarComandas(
        tester,
        api,
        // Con Scaffold, como la agenda: ahí se ve el aviso al regresar.
        pantalla: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => resultado = await Navigator.push<Object?>(
                context,
                MaterialPageRoute<Object?>(
                  builder: (_) => NuevaComandaScreen(viewModel: vm),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
        rol: 'empleado',
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      vm.editar(() {
        vm
          ..nombre = 'María López'
          ..telefono = '7711234567'
          ..fecha = DateTime(2026, 10, 20)
          ..hora = '16:30'
          ..anticipo = '45.50';
        vm.agregarProducto(vm.catalogo!.productos.first);
      });
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(NuevaComandaScreen), findsNothing);
      expect(find.byType(DetalleComandaScreen), findsNothing);
      expect((resultado! as ComandaCreada).folio, 5120);
      expect(find.text('Comanda #5120 creada'), findsOneWidget);
    });

    testWidgets('la entrega cercana avisa sin impedir guardar',
        (tester) async {
      final vm = await _formulario(tester, _backend());
      vm.editar(() => vm.fecha = DateTime(2026, 10, 13));
      await tester.pumpAndSettle();

      expect(find.textContaining('Puedes guardarla de todos modos'),
          findsOneWidget);
    });

    testWidgets('una foto que falló se reintenta desde su miniatura',
        (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.comandasImagenes, 'La imagen pesa más de 10 MB');
      final vm = await _formulario(tester, api);

      await vm.agregarFoto('/no/existe.jpg');
      await tester.pump();
      expect(find.byTooltip('Reintentar foto'), findsOneWidget);

      api.responder(ApiConstants.comandasImagenes, {
        'success': true,
        'imagen': {
          'url': 'https://res.cloudinary.com/x.jpg',
          'public_id': 'pier-reposteria/comandas/x',
        },
      });
      await tester.tap(find.byTooltip('Reintentar foto'));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Reintentar foto'), findsNothing);
      expect(vm.fotos.single.estado, EstadoFoto.lista);

      await tester.tap(find.byTooltip('Quitar foto'));
      await tester.pump();
      expect(vm.fotos, isEmpty);
    });

    testWidgets('si el catálogo no carga ofrece reintentar', (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.comandasCatalogo, 'Sin conexión');
      await _formulario(tester, api);

      expect(find.text('Sin conexión'), findsOneWidget);
      api.responder(ApiConstants.comandasCatalogo, catalogoJson());
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Cliente'), findsOneWidget);
    });

    // #241: al cerrar el selector de fecha u hora (con un valor o cancelado)
    // el foco no regresa al teléfono ni se abre el teclado.
    for (final (selector, cierre) in [
      ('Hora', 'OK'),
      ('Hora', 'Cancel'),
      ('Fecha', 'OK'),
      ('Fecha', 'Cancel'),
    ]) {
      testWidgets(
          'cerrar el selector de «$selector» con «$cierre» no regresa el foco '
          'al teléfono', (tester) async {
        await _formulario(tester, _backend());
        await tester.tap(
            find.widgetWithText(TextFormField, 'Teléfono (10 dígitos)'));
        await tester.pump();
        expect(_algunCampoConFoco(tester), isTrue);

        await tester.tap(find.text(selector));
        await tester.pumpAndSettle();
        await tester.tap(find.text(cierre));
        await tester.pumpAndSettle();

        expect(_algunCampoConFoco(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
      });
    }
  });
}
