// test/aceptacion/repartidor/entrega_test.dart — escenarios Gherkin de una
// entrega en curso: avisar la llegada, pedir quién recibió y confirmarla con
// o sin foto de evidencia (#68; historia #46), más el caso de error de la
// entrega que ya estaba confirmada, sin red.
//
// Cada prueba sale del panel del repartidor (helpers/montar_repartidor.dart)
// como en la app: toca la entrega de «En curso», usa los botones del detalle
// y de «Confirmar entrega» y vuelve al panel. El backend es BackendEntregas,
// que aplica las transiciones de routes/entregasRoutes.js. image_picker no
// tiene plugin en pruebas: se simula su canal.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/confirmar_entrega_screen.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/entrega_detail_screen.dart';

import '../../fakes/entregas_json.dart';
import '../../helpers/montar_repartidor.dart';

/// Abre el detalle de la entrega [numero] desde «En curso».
Future<void> _abrirDetalle(WidgetTester tester, String numero) async {
  await tester.tap(find.text(numero));
  await tester.pumpAndSettle();
  expect(find.byType(EntregaDetailScreen), findsOneWidget);
}

/// Toca [objetivo] y espera a que la pantalla se asiente.
Future<void> _tocar(WidgetTester tester, Finder objetivo) async {
  await tester.ensureVisible(objetivo);
  await tester.tap(objetivo);
  await tester.pumpAndSettle();
}

/// El botón (Elevated, Outlined o Text) que lleva [texto]: en «Confirmar
/// entrega» la barra de arriba dice lo mismo que el botón.
Finder _boton(String texto) => find.ancestor(
  of: find.text(texto),
  matching: find.bySubtype<ButtonStyleButton>(),
);

/// Quita el aviso visible para que el siguiente no espere en la cola.
void _quitarAviso(WidgetTester tester) => tester
    .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
    .removeCurrentSnackBar();

/// image_picker sin plugin: guarda la fuente pedida (0 cámara, 1 galería) y
/// regresa [ruta] como la foto elegida.
List<Object?> _simularFotos(WidgetTester tester, String ruta) {
  const canal = MethodChannel('plugins.flutter.io/image_picker');
  final fuentes = <Object?>[];
  final mensajero = tester.binding.defaultBinaryMessenger
    ..setMockMethodCallHandler(canal, (llamada) async {
      fuentes.add((llamada.arguments as Map)['source']);
      return ruta;
    });
  addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
  return fuentes;
}

void main() {
  group('#46 Repartidor: aviso de llegada y confirmación de entrega', () {
    // Escenario: avisar la llegada
    //   Dado que llevo una entrega en curso
    //   Cuando aviso que ya llegué
    //   Entonces la app registra el aviso para ese pedido
    testWidgets('Escenario: avisar la llegada', (tester) async {
      // Dado que llevo una entrega en curso
      final backend = BackendEntregas(
        entregas: [entregaJson(7, 41, estado: 'en_camino')],
      );
      await abrirPanelRepartidor(tester, backend);
      expect(tarjetaEnCurso('PIER-41'), findsOneWidget);
      await _abrirDetalle(tester, 'PIER-41');
      expect(find.text('En camino'), findsOneWidget);

      // Cuando aviso que ya llegué
      await _tocar(
        tester,
        find.text('Llegué al domicilio (avisar al cliente)'),
      );

      // Entonces la app registra el aviso para ese pedido (el backend avisa
      // al cliente) y lo confirma.
      final aviso = backend.api.ultima(ApiConstants.entregaLlegue('7'))!;
      expect(aviso.metodo, 'POST-Auth');
      expect(aviso.body, isEmpty);
      expect(backend.avisos, ['7']);
      expect(find.text('Cliente avisado de tu llegada'), findsOneWidget);
      // El aviso no cambia el estado: sigue en camino y con «Marcar
      // entregado» a la mano.
      expect(backend.entregas.single['estado'], 'en_camino');
      expect(find.text('En camino'), findsOneWidget);
      expect(find.text('Marcar entregado'), findsOneWidget);
    });

    // Escenario: nombre de quien recibió
    //   Dado que estoy confirmando una entrega
    //   Cuando intento confirmarla sin escribir quién recibió
    //   Entonces la app no la confirma y me pide ese dato
    testWidgets('Escenario: nombre de quien recibió', (tester) async {
      // Dado que estoy confirmando una entrega
      final backend = BackendEntregas(
        entregas: [entregaJson(7, 41, estado: 'en_camino')],
      );
      await abrirPanelRepartidor(tester, backend);
      await _abrirDetalle(tester, 'PIER-41');
      await _tocar(tester, find.text('Marcar entregado'));
      expect(find.byType(ConfirmarEntregaScreen), findsOneWidget);
      expect(find.text('¿Quién recibió el pedido?'), findsOneWidget);

      // Cuando intento confirmarla sin escribir quién recibió
      await _tocar(tester, _boton('Confirmar entrega'));

      // Entonces la app no la confirma y me pide ese dato
      expect(find.text('Indica quién recibió el pedido'), findsOneWidget);
      expect(backend.api.llamo(ApiConstants.entregaEstado('7')), isFalse);
      expect(find.byType(ConfirmarEntregaScreen), findsOneWidget);

      // Solo espacios tampoco cuentan como nombre.
      _quitarAviso(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await _tocar(tester, _boton('Confirmar entrega'));
      expect(find.text('Indica quién recibió el pedido'), findsOneWidget);
      expect(backend.api.llamo(ApiConstants.entregaEstado('7')), isFalse);
      expect(backend.entregas.single['estado'], 'en_camino');
    });

    // Escenario: confirmar con evidencia
    //   Dado que escribí quién recibió el pedido
    //   Cuando confirmo la entrega, con o sin foto de evidencia
    //   Entonces la entrega queda registrada como realizada
    testWidgets('Escenario: confirmar con evidencia', (tester) async {
      final fuentes = _simularFotos(tester, '/fotos/entrega-41.jpg');
      final backend = BackendEntregas(
        entregas: [
          entregaJson(7, 41, estado: 'en_camino'),
          entregaJson(8, 42, estado: 'en_camino', total: 250),
        ],
      );
      await abrirPanelRepartidor(tester, backend);
      expect(find.text('Tienes 2 entregas activas para hoy'), findsOneWidget);

      // Con foto. Dado que escribí quién recibió el pedido (y elegí la foto
      // de la galería)
      await _abrirDetalle(tester, 'PIER-41');
      await _tocar(tester, find.text('Marcar entregado'));
      await _tocar(tester, find.text('Galería'));
      expect(fuentes, [1]); // la galería
      expect(find.text('Galería'), findsNothing); // ya hay foto
      await tester.enterText(find.byType(TextField), 'María López');

      // Cuando confirmo la entrega
      await _tocar(tester, _boton('Confirmar entrega'));

      // Entonces la entrega queda registrada como realizada, con su foto
      expect(backend.api.ultima(ApiConstants.uploadImagen)!.body, {
        'filePath': '/fotos/entrega-41.jpg',
        'tipo': 'entrega',
      });
      expect(backend.api.ultima(ApiConstants.entregaEstado('7'))!.body, {
        'estado': 'entregada',
        'evidencia_url': 'https://res.cloudinary.com/pier/entrega/entrega-41.jpg',
        'recibio_nombre': 'María López',
      });
      expect(backend.entregas.first['estado'], 'entregada');
      expect(find.text('Entrega confirmada'), findsOneWidget);
      expect(find.byType(EntregaDetailScreen), findsNothing); // en el panel
      expect(tarjetaEnCurso('PIER-41'), findsNothing);
      expect(find.text('Tienes 1 entrega activa para hoy'), findsOneWidget);

      // Sin foto: la misma confirmación, sin subir nada.
      _quitarAviso(tester);
      await _abrirDetalle(tester, 'PIER-42');
      await _tocar(tester, find.text('Marcar entregado'));
      await tester.enterText(find.byType(TextField), 'Jorge Ruiz');
      await _tocar(tester, _boton('Confirmar entrega'));
      expect(backend.api.ultima(ApiConstants.entregaEstado('8'))!.body, {
        'estado': 'entregada',
        'recibio_nombre': 'Jorge Ruiz',
      });
      expect(
        backend.api.llamadas.where(
          (l) => l.endpoint == ApiConstants.uploadImagen,
        ),
        hasLength(1),
      );
      expect(backend.entregas.last['estado'], 'entregada');
      expect(find.text('Entrega confirmada'), findsOneWidget);
      expect(find.text('Sin entregas por ahora'), findsOneWidget);

      // Las dos quedan en el historial de hoy como entregadas.
      await irAPestana(tester, 'Historial');
      expect(find.text('PIER-41'), findsOneWidget);
      expect(find.text('PIER-42'), findsOneWidget);
      expect(find.text('1:45 PM'), findsNWidgets(2)); // horaDeCierre
      expect(find.text('2 entregas'), findsOneWidget);
      expect(find.text('0 fallos'), findsOneWidget);
      expect(find.text(r'$580 MXN'), findsOneWidget); // total del día
    });

    // Caso de error (#68): la entrega ya estaba confirmada
    //   Dado que la entrega ya se confirmó por fuera de esta pantalla
    //   Cuando intento confirmarla otra vez
    //   Entonces la app muestra el motivo del backend, no la registra de
    //   nuevo y, al recargar, el panel ya no la muestra en curso
    testWidgets('Caso de error: la entrega ya estaba confirmada', (
      tester,
    ) async {
      // Dado que la entrega ya se confirmó por fuera (desde la web del
      // repartidor) y el panel la cargó antes, todavía en camino
      final backend = BackendEntregas(
        entregas: [entregaJson(7, 41, estado: 'en_camino')],
      );
      await abrirPanelRepartidor(tester, backend);
      backend.confirmadaPorFuera('7', recibio: 'Rosa Martínez');
      expect(tarjetaEnCurso('PIER-41'), findsOneWidget);

      // Cuando intento confirmarla otra vez
      await _abrirDetalle(tester, 'PIER-41');
      await _tocar(tester, find.text('Marcar entregado'));
      await tester.enterText(find.byType(TextField), 'María López');
      await _tocar(tester, _boton('Confirmar entrega'));

      // Entonces la app muestra el motivo del backend, se queda en la
      // confirmación y no la registra de nuevo
      expect(
        find.text('No se puede pasar de "entregada" a "entregada"'),
        findsOneWidget,
      );
      expect(find.text('Entrega confirmada'), findsNothing);
      expect(find.byType(ConfirmarEntregaScreen), findsOneWidget);
      expect(backend.entregas.single['recibio_nombre'], 'Rosa Martínez');

      // Al volver y jalar para recargar, el panel ya no la muestra en curso.
      await _tocar(tester, find.text('Regresar'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await recargarEntregas(tester);
      expect(tarjetaEnCurso('PIER-41'), findsNothing);
      expect(find.text('Sin entregas por ahora'), findsOneWidget);
    });
  });
}
