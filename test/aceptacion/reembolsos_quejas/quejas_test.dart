// test/aceptacion/reembolsos_quejas/quejas_test.dart — escenarios Gherkin de
// «Mis Quejas»: elegir el tipo (queja, sugerencia o comentario), enviar el
// mensaje y seguir su estado hasta que la repostería lo resuelve (#68;
// historia #44), sin red.
//
// La pantalla se abre como en la app (arma su ViewModel con los
// repositorios de dependencies.dart) y el formulario es su hoja «Nueva». El
// backend guarda las quejas en memoria sobre FakeApiClient: POST /quejas las
// crea pendientes con su ticket, y la prueba hace de la repostería que las
// atiende desde su panel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/domain/models/queja.dart';
import 'package:pier_reposteria/ui/more/widgets/quejas_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

/// Una queja que el cliente ya envió y sigue pendiente.
Map<String, dynamic> _quejaEnviada() => {
  'id': 7,
  'ticket': 'QJ-0007',
  'tipo': 'queja',
  'categoria': 'producto',
  'asunto': 'Pastel aplastado',
  'descripcion': 'El pastel de tres leches llegó aplastado de un lado.',
  'estado': 'pendiente',
  'respuesta': null,
  // Sin zona horaria: la fecha que se ve no depende del huso de la máquina.
  'created_at': '2026-10-18T10:00:00',
};

/// Backend en memoria de «Mis Quejas».
class _BackendQuejas {
  _BackendQuejas({List<Map<String, dynamic>> iniciales = const []})
    : quejas = [for (final q in iniciales) {...q}] {
    api = FakeApiClient(
      respuestas: {
        ApiConstants.misPedidos: {'success': true, 'pedidos': <Object>[]},
        ApiConstants.misQuejas: _listar,
        ApiConstants.crearQueja: _crear,
      },
    );
  }

  late final FakeApiClient api;

  /// Mis quejas, de la más vieja a la más nueva.
  final List<Map<String, dynamic>> quejas;
  int _siguienteId = 8;

  /// La repostería atiende la queja [ticket] desde su panel: cambia su
  /// [estado] y, si la contesta, guarda la [respuesta].
  void atender(String ticket, String estado, {String? respuesta}) {
    quejas.firstWhere((q) => q['ticket'] == ticket).addAll({
      'estado': estado,
      'respuesta': ?respuesta,
    });
  }

  /// GET /quejas/mis-quejas: de la más nueva a la más vieja.
  Map<String, dynamic> _listar(LlamadaApi _) => {
    'success': true,
    'quejas': [for (final q in quejas.reversed) {...q}],
  };

  /// POST /quejas: la guarda pendiente, con su ticket.
  Map<String, dynamic> _crear(LlamadaApi llamada) {
    final id = _siguienteId++;
    final queja = <String, dynamic>{
      'id': id,
      'ticket': 'QJ-${id.toString().padLeft(4, '0')}',
      ...llamada.body!,
      'estado': 'pendiente',
      'respuesta': null,
      'created_at': '2026-10-20T12:00:00',
    };
    quejas.add(queja);
    return {
      'success': true,
      'queja': {...queja},
      'message': 'Ticket ${queja['ticket']} creado',
    };
  }
}

/// Abre «Mis Quejas» sin ViewModel inyectado, como la abre «Más», en un
/// celular: la hoja del formulario no cabe en 800×600.
Future<void> _abrirQuejas(WidgetTester tester, _BackendQuejas backend) async {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  await tester.pumpApp(const QuejasScreen(), api: backend.api);
  await tester.pumpAndSettle();
}

/// Abre la hoja «Nueva» (el formulario).
Future<void> _abrirFormulario(WidgetTester tester) async {
  await tester.tap(find.text('Nueva'));
  await tester.pumpAndSettle();
}

/// El selector del tipo en la hoja.
Finder get _selectorTipo => find.byType(DropdownButton<TipoQueja>);

/// Jala la lista hacia abajo para volver a pedir mis quejas.
Future<void> _recargar(WidgetTester tester) async {
  await tester.fling(
    find.text('Pastel aplastado'),
    const Offset(0, 400),
    1000,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('#44 Quejas: enviar una queja, sugerencia o comentario y ver su estado', () {
    // Escenario: elegir el tipo
    //   Dado que quiero escribirle a la repostería
    //   Cuando abro el formulario
    //   Entonces puedo elegir entre queja, sugerencia y comentario
    testWidgets('Escenario: elegir el tipo', (tester) async {
      // Dado que quiero escribirle a la repostería
      final backend = _BackendQuejas();
      await _abrirQuejas(tester, backend);
      expect(find.text('Mis Quejas'), findsOneWidget);

      // Cuando abro el formulario
      await _abrirFormulario(tester);
      expect(find.text('Nueva queja o sugerencia'), findsOneWidget);
      expect(find.text('Tipo'), findsOneWidget);
      expect(find.text('Queja'), findsOneWidget); // el tipo de partida

      // Entonces puedo elegir entre queja, sugerencia y comentario.
      // Ajuste: la app escribe los tipos con mayúscula inicial («Queja»,
      // «Sugerencia», «Comentario»).
      final tipos = tester.widget<DropdownButton<TipoQueja>>(_selectorTipo);
      expect([for (final t in tipos.items!) t.value], [
        TipoQueja.queja,
        TipoQueja.sugerencia,
        TipoQueja.comentario,
      ]);
      await tester.tap(_selectorTipo);
      await tester.pumpAndSettle();
      expect(find.text('Queja'), findsWidgets); // el elegido y en el menú
      expect(find.text('Sugerencia'), findsOneWidget);
      expect(find.text('Comentario'), findsOneWidget);
      await tester.tap(find.text('Comentario'));
      await tester.pumpAndSettle();
      expect(find.text('Comentario'), findsOneWidget);
      expect(find.text('Queja'), findsNothing);
      expect(backend.api.llamo(ApiConstants.crearQueja), isFalse);
    });

    // Escenario: enviar el mensaje
    //   Dado que elegí un tipo y escribí el asunto y la descripción
    //   Cuando lo envío
    //   Entonces aparece en mi lista con estado «pendiente»
    testWidgets('Escenario: enviar el mensaje', (tester) async {
      final backend = _BackendQuejas();
      await _abrirQuejas(tester, backend);
      expect(find.text('Sin quejas registradas'), findsOneWidget);

      // Dado que elegí un tipo y escribí el asunto y la descripción
      await _abrirFormulario(tester);
      await tester.tap(_selectorTipo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sugerencia').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Describe brevemente tu queja'),
        'Pasteles sin azúcar',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Detalla tu queja o sugerencia...'),
        'Me gustaría que el catálogo tuviera pasteles sin azúcar.',
      );

      // Cuando lo envío
      final enviar = find.text('Enviar queja');
      await tester.ensureVisible(enviar);
      await tester.pumpAndSettle();
      await tester.tap(enviar);
      await tester.pumpAndSettle();

      // Entonces aparece en mi lista con estado «pendiente»: la hoja se
      // cierra, avisa el ticket y la lista se vuelve a pedir.
      final envio = backend.api.ultima(ApiConstants.crearQueja)!;
      expect(envio.metodo, 'POST-Auth');
      expect(envio.body, {
        'tipo': 'sugerencia',
        'categoria': 'producto',
        'asunto': 'Pasteles sin azúcar',
        'descripcion': 'Me gustaría que el catálogo tuviera pasteles sin azúcar.',
      });
      expect(find.text('Nueva queja o sugerencia'), findsNothing);
      expect(find.text('Queja enviada — ticket QJ-0008'), findsOneWidget);
      expect(find.text('Sin quejas registradas'), findsNothing);
      expect(find.text('1 registro'), findsOneWidget);
      expect(find.text('QJ-0008'), findsOneWidget);
      expect(find.text('Pasteles sin azúcar'), findsOneWidget);
      expect(find.text('Sugerencia'), findsOneWidget);
      expect(find.text('20 Oct, 2026'), findsOneWidget);
      // Ajuste: la app muestra el estado con mayúscula inicial.
      expect(find.text('Pendiente'), findsOneWidget);
    });

    // Escenario: seguimiento
    //   Dado que envié una queja
    //   Cuando la repostería la atiende
    //   Entonces mi lista muestra su estado como «en proceso» o «resuelto»
    testWidgets('Escenario: seguimiento', (tester) async {
      // Dado que envié una queja
      final backend = _BackendQuejas(iniciales: [_quejaEnviada()]);
      await _abrirQuejas(tester, backend);
      expect(find.text('QJ-0007'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);

      // Cuando la repostería la atiende (y jalo la lista para ver lo nuevo)
      backend.atender('QJ-0007', 'en_proceso');
      await _recargar(tester);

      // Entonces mi lista muestra su estado como «en proceso»…
      // Ajuste: con mayúscula inicial («En proceso», «Resuelto»).
      expect(find.text('En proceso'), findsOneWidget);
      expect(find.text('Pendiente'), findsNothing);

      // …o «resuelto», con la respuesta del equipo al abrirla
      backend.atender(
        'QJ-0007',
        'resuelto',
        respuesta: 'Te reponemos el pastel en tu siguiente pedido.',
      );
      await _recargar(tester);
      expect(find.text('Resuelto'), findsOneWidget);
      expect(find.text('En proceso'), findsNothing);
      await tester.tap(find.text('Pastel aplastado'));
      await tester.pumpAndSettle();
      expect(find.text('Respuesta del equipo'), findsOneWidget);
      expect(
        find.text('Te reponemos el pastel en tu siguiente pedido.'),
        findsOneWidget,
      );
      expect(
        find.text('El pastel de tres leches llegó aplastado de un lado.'),
        findsOneWidget,
      );
    });
  });
}
