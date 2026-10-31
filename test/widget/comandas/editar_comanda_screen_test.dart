// test/widget/comandas/editar_comanda_screen_test.dart — editar una comanda
// desde su detalle (#228) sin red: quién ve «Editar», el formulario ya
// lleno, guardar y volver al detalle, y el aviso de edición simultánea con
// «Recargar la comanda».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository_remote.dart';
import 'package:pier_reposteria/ui/comandas/view_model/nueva_comanda_view_model.dart';
import 'package:pier_reposteria/ui/comandas/widgets/detalle_comanda_screen.dart';
import 'package:pier_reposteria/ui/comandas/widgets/nueva_comanda_screen.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_comandas.dart';

/// El detalle de la comanda 7 con «Editar» si [editar] (lo mismo lee el
/// formulario); al guardar (PUT) responde [alGuardar].
FakeApiClient _backend({
  bool editar = true,
  Map<String, dynamic> alGuardar = const {
    'success': true,
    'comanda': {'id': 7, 'folio': 5003, 'version': 2},
    'message': 'Comanda #5003 actualizada',
  },
}) {
  // El formulario abierto desde el detalle usa el reloj real: la entrega
  // queda 10 días adelante.
  final dia = DateTime.now().add(const Duration(days: 10));
  final fecha = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-'
      '${dia.day.toString().padLeft(2, '0')}';
  final d = detalleJson(editar: editar, confirmar: null);
  final detalle = {
    ...d,
    'comanda': {
      ...d['comanda'] as Map<String, dynamic>,
      ...comandaEditableJson(fecha: fecha)['comanda'] as Map<String, dynamic>,
    },
  };
  return FakeApiClient(respuestas: {
    ApiConstants.comandasCatalogo: catalogoJson(),
    ApiConstants.comandaDetalle(7): (LlamadaApi l) =>
        l.metodo == 'PUT-Auth' ? alGuardar : detalle,
  });
}

void main() {
  group('Editar comanda', () {
    testWidgets('sin permiso no aparece «Editar»', (tester) async {
      await montarComandas(
        tester,
        _backend(editar: false),
        pantalla: const DetalleComandaScreen(id: 7),
        rol: 'empleado',
      );
      expect(find.byTooltip('Editar'), findsNothing);
    });

    testWidgets('abre el formulario lleno, guarda y vuelve al detalle',
        (tester) async {
      final api = _backend();
      await montarComandas(
        tester,
        api,
        pantalla: const DetalleComandaScreen(id: 7),
        rol: 'empleado',
      );

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar comanda #5003'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'María López'),
          findsOneWidget);
      expect(find.text('Gelatina'), findsOneWidget);

      await tester.tap(find.textContaining('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.byType(NuevaComandaScreen), findsNothing);
      expect(find.byType(DetalleComandaScreen), findsOneWidget);
      expect(find.text('Comanda #5003 actualizada'), findsOneWidget);
      final guardado =
          api.llamadas.lastWhere((l) => l.metodo == 'PUT-Auth').body;
      expect(guardado,
          containsPair('actualizada_en', '2026-10-12T15:00:00.123Z'));
    });

    testWidgets('si otra persona la guardó antes ofrece recargarla',
        (tester) async {
      final api = _backend(alGuardar: const {
        'success': false,
        'codigo': 'COMANDA_DESACTUALIZADA',
        'message': 'Alguien más modificó esta comanda mientras la editabas.',
      });
      final vm = NuevaComandaViewModel(
        repo: ComandasRepositoryRemote(api: api),
        editarId: 7,
      );
      await montarComandas(
        tester,
        api,
        pantalla: NuevaComandaScreen(viewModel: vm),
        rol: 'gerencia',
      );
      await tester.tap(find.textContaining('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('• Alguien más modificó esta comanda mientras la '
          'editabas.'), findsOneWidget);
      await tester.tap(find.text('Recargar la comanda'));
      await tester.pumpAndSettle();

      expect(find.text('Recargar la comanda'), findsNothing);
      expect(vm.desactualizada, isFalse);
    });
  });
}
