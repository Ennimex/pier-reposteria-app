// test/unitarias/pedidos/notifications_view_model_test.dart — «Notificaciones» (MVVM,
// Fase 5) sin red y con reloj fijo: carga con error y reintento, agrupa por
// día (Hoy, Ayer, Anteriores), dice «hace cuánto» y reenvía al
// NotificationProvider compartido marcar una o todas como leídas.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/notificaciones_repository_remote.dart';
import 'package:pier_reposteria/domain/models/notificacion.dart';
import 'package:pier_reposteria/ui/core/state/notification_provider.dart';
import 'package:pier_reposteria/ui/notifications/view_model/notifications_view_model.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';

/// Sábado 10 de octubre de 2026, 18:00 (hora local).
final DateTime _ahora = DateTime(2026, 10, 10, 18);

Map<String, dynamic> _n(int id, String fecha, {bool leida = false}) => {
      'id': id,
      'tipo': 'pedido',
      'titulo': 'Aviso $id',
      'mensaje': 'Mensaje $id',
      'leida': leida,
      'created_at': fecha,
    };

Map<String, dynamic> get _lista => {
      'success': true,
      'notificaciones': [
        _n(1, '2026-10-10T17:30:00'),
        _n(2, '2026-10-09T09:00:00', leida: true),
        _n(3, '2026-10-01T12:00:00'),
      ],
    };

(NotificationsViewModel, NotificationProvider, FakeApiClient) _armar(
    [Map<String, dynamic>? extra]) {
  final api = FakeApiClient(respuestas: {
    ApiConstants.notificaciones: _lista,
    ...?extra,
  });
  final provider =
      NotificationProvider(repo: NotificacionesRepositoryRemote(api: api));
  final vm = NotificationsViewModel(
      notificaciones: provider, ahora: () => _ahora);
  return (vm, provider, api);
}

Notificacion _deTitulo(String titulo) =>
    Notificacion(id: '5', tipo: 'pedido', titulo: titulo, mensaje: '');

/// ViewModel del personal: busca las comandas en [api].
NotificationsViewModel _personal(FakeApiClient api) => NotificationsViewModel(
      notificaciones:
          NotificationProvider(repo: NotificacionesRepositoryRemote(api: api)),
      comandas: ComandasRepositoryRemote(api: api),
    );

String _agenda(String vista, int folio) =>
    ApiConstants.agendaComandas(vista, busqueda: '$folio');

Notificacion _creada(DateTime? fecha) =>
    Notificacion(id: '9', tipo: 'aviso', titulo: '', mensaje: '', creadaEn: fecha);

void main() {
  group('NotificationsViewModel: carga', () {
    test('carga la lista y expone las no leídas', () async {
      final (vm, _, _) = _armar();
      final pendiente = vm.cargar();
      expect(vm.cargando, isTrue);

      await pendiente;

      expect(vm.cargando, isFalse);
      expect(vm.errorCarga, isNull);
      expect(vm.notificaciones, hasLength(3));
      expect(vm.noLeidas, 2);
    });

    test('con notificaciones ya en el provider no muestra el spinner',
        () async {
      final (vm, provider, _) = _armar();
      await provider.cargar();

      final pendiente = vm.cargar();
      expect(vm.cargando, isFalse);
      await pendiente;
    });

    test('si falla sin nada que mostrar expone el motivo y reintenta',
        () async {
      final (vm, _, api) = _armar({
        ApiConstants.notificaciones: {'success': false, 'message': 'Sin conexión'},
      });

      await vm.cargar();
      expect(vm.errorCarga, 'Sin conexión');

      api.responder(ApiConstants.notificaciones, _lista);
      await vm.cargar();
      expect(vm.errorCarga, isNull);
      expect(vm.notificaciones, hasLength(3));
    });

    test('si falla pero ya había notificaciones se quedan en pantalla',
        () async {
      final (vm, provider, api) = _armar();
      await provider.cargar();
      api.fallar(ApiConstants.notificaciones, 'Sin conexión');

      await vm.cargar();

      expect(vm.errorCarga, isNull);
      expect(vm.notificaciones, hasLength(3));
    });

    test('refrescar devuelve el motivo si el backend no respondió', () async {
      final (vm, _, api) = _armar();
      expect(await vm.refrescar(), isNull);

      api.fallar(ApiConstants.notificaciones, 'Sin conexión');
      expect(await vm.refrescar(), 'Sin conexión');
    });

    test('reenvía los avisos del provider y deja de hacerlo tras dispose',
        () async {
      final (vm, provider, api) = _armar();
      var avisos = 0;
      vm.addListener(() => avisos++);

      await provider.cargar();
      expect(avisos, 1);

      api.demorar(ApiConstants.notificaciones, const Duration(milliseconds: 20));
      final pendiente = vm.cargar();
      vm.dispose();
      await pendiente;
      provider.stopPolling();
      expect(avisos, 2); // el «cargando» de vm.cargar(), nada después
    });
  });

  group('NotificationsViewModel: agrupar y fechas', () {
    test('agrupa por día de calendario, sin grupos vacíos', () async {
      final (vm, provider, _) = _armar();
      await provider.cargar();

      final grupos = vm.grupos;

      expect(grupos.map((g) => g.titulo), ['Hoy', 'Ayer', 'Anteriores']);
      expect(grupos.map((g) => g.notificaciones.single.id), ['1', '2', '3']);
    });

    test('sin fecha va a Anteriores; futura a Hoy', () async {
      final (vm, provider, api) = _armar();
      api.responder(ApiConstants.notificaciones, {
        'success': true,
        'notificaciones': [
          _n(1, '2026-10-11T08:00:00'),
          _n(2, 'sin fecha'),
        ],
      });
      await provider.cargar();

      expect(vm.grupos.map((g) => g.titulo), ['Hoy', 'Anteriores']);
    });

    test('«hace cuánto» según el tiempo transcurrido', () {
      final (vm, _, _) = _armar();
      String cuando(DateTime? fecha) => vm.cuando(_creada(fecha));

      expect(cuando(null), '');
      expect(cuando(DateTime(2026, 10, 10, 17, 59, 30)), 'Ahora');
      expect(cuando(DateTime(2026, 10, 10, 17, 55)), 'Hace 5 min');
      expect(cuando(DateTime(2026, 10, 10, 17)), 'Hace 1 hora');
      expect(cuando(DateTime(2026, 10, 9, 20)), 'Hace 22 horas');
      expect(cuando(DateTime(2026, 10, 9, 9, 5)), 'Ayer, 9:05 AM');
      expect(cuando(DateTime(2026, 10, 9, 0, 30)), 'Ayer, 12:30 AM');
      expect(cuando(DateTime(2026, 10, 9, 14, 30)), 'Ayer, 2:30 PM');
      // Más de 24 h pero de anteayer: ya no es «Ayer».
      expect(cuando(DateTime(2026, 10, 8, 23)), '8 Oct 2026');
      expect(cuando(DateTime(2026, 10, 1, 12)), '1 Oct 2026');
    });
  });

  group('NotificationsViewModel: marcar como leídas', () {
    test('marcar una y todas pasan por el provider compartido', () async {
      final (vm, provider, api) = _armar({
        ApiConstants.marcarNotificacionLeida('1'): {'success': true},
        ApiConstants.notificacionesLeerTodas: {'success': true},
      });
      await vm.cargar();

      expect(await vm.marcarLeida(vm.notificaciones.first), isNull);
      expect(provider.noLeidas, 1);

      expect(await vm.marcarTodas(), isNull);
      expect(vm.noLeidas, 0);
      expect(api.llamo(ApiConstants.notificacionesLeerTodas), isTrue);
    });

    test('devuelve el motivo si el backend lo rechaza', () async {
      final (vm, _, api) = _armar();
      await vm.cargar();
      api.fallar(ApiConstants.notificacionesLeerTodas, 'Error al marcar');

      expect(await vm.marcarTodas(), 'Error al marcar');
      expect(vm.noLeidas, 2);
    });
  });

  group('Notificacion: folio de la comanda (#136)', () {
    test('lee el folio de los títulos que manda el backend', () {
      expect(_deTitulo('Nueva comanda #5001').folioComanda, 5001);
      expect(_deTitulo('Cambió la comanda #42').folioComanda, 42);
      expect(_deTitulo('Comanda #7 cancelada').folioComanda, 7);
      expect(_deTitulo('Comanda sin folio').folioComanda, isNull);
    });

    test('solo los avisos que hablan de una comanda', () {
      expect(_deTitulo('Comanda #7 cancelada').esDeComanda, isTrue);
      expect(_deTitulo('Cobro sin pedido').esDeComanda, isFalse);
    });
  });

  group('NotificationsViewModel: comandas del personal (#136)', () {
    test('el cliente no abre comandas', () {
      final (vm, _, _) = _armar();
      expect(vm.esPersonal, isFalse);
      expect(vm.abreComanda(_deTitulo('Nueva comanda #5001')), isFalse);
    });

    test('encuentra la comanda activa por su folio', () async {
      final api = FakeApiClient()
        ..responder(_agenda('activas', 5001), agendaJson([
          comandaJson(id: 3, folio: 5010),
          comandaJson(id: 11),
        ]));
      final vm = _personal(api);

      expect(vm.esPersonal, isTrue);
      expect(vm.abreComanda(_deTitulo('Nueva comanda #5001')), isTrue);
      expect(vm.abreComanda(_deTitulo('Cobro sin pedido')), isFalse);
      expect(await vm.comandaDe(_deTitulo('Nueva comanda #5001')), 11);
    });

    test('si no está activa la busca entre las entregadas', () async {
      final api = FakeApiClient()
        ..responder(_agenda('activas', 5001), agendaJson([]))
        ..responder(_agenda('entregadas', 5001), agendaJson([
          comandaJson(id: 12, estado: 'entregada'),
        ]));

      expect(await _personal(api).comandaDe(_deTitulo('Cambió la comanda #5001')),
          12);
    });

    test('una cancelada se busca primero entre las canceladas', () async {
      final api = FakeApiClient()
        ..responder(_agenda('canceladas', 5001), agendaJson([
          comandaJson(id: 13, estado: 'cancelada'),
        ]));

      expect(await _personal(api).comandaDe(_deTitulo('Comanda #5001 cancelada')),
          13);
      expect(api.llamo(_agenda('activas', 5001)), isFalse);
    });

    test('sin folio, sin encontrarla o si falla devuelve null', () async {
      final api = FakeApiClient()
        ..responder(_agenda('activas', 5001), agendaJson([]))
        ..responder(_agenda('entregadas', 5001), agendaJson([]))
        ..fallar(_agenda('activas', 5002), 'Sin conexión');
      final vm = _personal(api);

      expect(await vm.comandaDe(_deTitulo('Comanda sin folio')), isNull);
      expect(api.llamadas, isEmpty);
      expect(await vm.comandaDe(_deTitulo('Nueva comanda #5001')), isNull);
      expect(await vm.comandaDe(_deTitulo('Nueva comanda #5002')), isNull);
    });
  });
}
