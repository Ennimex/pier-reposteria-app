// test/unit/checkout_view_model_test.dart — ViewModel del checkout (MVVM,
// Fase 4) sin red ni Stripe: validaciones, direcciones, horarios y cada
// camino del pago (incluido no volver a cobrar si la confirmación falla).
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository_remote.dart';
import 'package:pier_pasteleria/data/services/pasarela_pago.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/direccion_form_view_model.dart';

import '../fakes/fake_api_client.dart';

/// Pasarela sin Stripe: cuenta los cobros y puede cancelar o rechazar.
class _PasarelaFalsa implements PasarelaPago {
  int cobros = 0;
  Exception? falla;

  @override
  Future<void> cobrar({
    required String clientSecret,
    required String publishableKey,
  }) async {
    cobros++;
    final f = falla;
    if (f != null) throw f;
  }
}

const Map<String, dynamic> _direcciones = {
  'success': true,
  'direcciones': [
    {'id': 1, 'alias': 'Casa', 'calle_numero': 'Hidalgo 1', 'colonia': 'Lejos'},
    {
      'id': 2,
      'alias': 'Trabajo',
      'calle_numero': 'Juárez 9',
      'colonia': 'Centro',
      'tarifa': 40,
    },
  ],
};

FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.configuracionSeccion('contacto'): {
        'success': true,
        'config': {'direccion': 'Av. Revolución 100, Pachuca'},
      },
      ApiConstants.direcciones: _direcciones,
      ApiConstants.crearPaymentIntent: {
        'success': true,
        'clientSecret': 'pi_123_secret_abc',
        'publishableKey': 'pk_test',
        'total': 540,
      },
      ApiConstants.confirmarPago: {
        'success': true,
        'pedido': {'numero': 'P-77', 'por_confirmar': false},
      },
      ApiConstants.zonasColonias: {
        'success': true,
        'colonias': [
          {'colonia': 'Centro', 'tarifa': '40.00'},
        ],
      },
      ApiConstants.direccionById('1'): {'success': true},
    });

class _Prueba {
  _Prueba({bool abierto = true, bool aceptaPorConfirmar = true})
      : api = _backend() {
    vm = CheckoutViewModel(
      configRepo: ConfiguracionRepositoryRemote(api: api),
      direccionesRepo: DireccionesRepositoryRemote(api: api),
      pagosRepo: PagosRepositoryRemote(api: api),
      pasarela: pasarela,
      totalCarrito: () => 500,
      confirmarPorConfirmar: (faltantes) async {
        preguntas.add(faltantes);
        return aceptaPorConfirmar;
      },
      estaAbierto: () => abierto,
      esperar: (d) async => esperas.add(d),
    );
  }

  final FakeApiClient api;
  final pasarela = _PasarelaFalsa();
  final preguntas = <List<String>>[];
  final esperas = <Duration>[];
  late final CheckoutViewModel vm;

  /// Deja todo listo para pagar recogiendo en sucursal un martes.
  void listoParaRecoger() {
    vm
      ..elegirFecha(DateTime(2026, 10, 13))
      ..elegirHora('17:00 - 18:00');
  }

  Future<ResultadoPago?> pagar() async {
    await vm.pagar.execute();
    return vm.pagar.resultado;
  }

  int confirmaciones() => api.llamadas
      .where((l) => l.endpoint == ApiConstants.confirmarPago)
      .length;
}

void main() {
  group('CheckoutViewModel: carga y elecciones', () {
    test('carga la dirección de la sucursal y preselecciona una con '
        'cobertura', () async {
      final p = _Prueba();
      await p.vm.cargar();

      expect(p.vm.direccionSucursal, contains('Revolución 100'));
      expect(p.vm.direcciones, hasLength(2));
      expect(p.vm.direccion!.alias, 'Trabajo');
      expect(p.vm.cargandoDirecciones, isFalse);
    });

    test('a domicilio suma el envío; recoger no', () async {
      final p = _Prueba();
      await p.vm.cargar();
      expect(p.vm.totalConEnvio, 500);

      p.vm.elegirEntrega(TipoEntrega.domicilio);
      expect(p.vm.costoEnvio, 40);
      expect(p.vm.totalConEnvio, 540);
    });

    test('el fin de semana tiene menos horarios y borra la hora que ya no '
        'existe', () {
      final p = _Prueba();
      p.vm
        ..elegirHora('17:00 - 18:00')
        ..elegirFecha(DateTime(2026, 10, 17)); // sábado
      expect(p.vm.horarios, CheckoutViewModel.horariosFinDeSemana);
      expect(p.vm.hora, isNull);

      p.vm
        ..elegirHora('10:00 - 11:00')
        ..elegirFecha(DateTime(2026, 10, 18)); // domingo
      expect(p.vm.hora, '10:00 - 11:00');
    });

    test('eliminar la dirección elegida preselecciona otra; si falla avisa',
        () async {
      final p = _Prueba();
      await p.vm.cargar();
      p.vm.elegirDireccion(p.vm.direcciones.first);

      expect(await p.vm.eliminarDireccion(p.vm.direcciones.first), isNull);
      expect(p.vm.direccion!.alias, 'Trabajo');

      p.api.fallar(ApiConstants.direccionById('2'), 'Tiene pedidos');
      expect(await p.vm.eliminarDireccion(p.vm.direcciones.last),
          'Tiene pedidos');
    });

    test('al guardar una dirección la deja elegida', () async {
      final p = _Prueba();
      await p.vm.cargar();
      final form = DireccionFormViewModel(
          repo: DireccionesRepositoryRemote(api: p.api));
      p.api.responder(ApiConstants.direcciones, {
        ..._direcciones,
        'direccion': {'id': 1, 'alias': 'Casa', 'colonia': 'Lejos'},
      });
      await form.cargarColonias();
      form.elegirColonia('Centro');
      final (guardada, _) = await form.guardar(
          alias: 'Casa', calle: 'Hidalgo 1', referencias: '', telefono: '');

      await p.vm.alGuardarDireccion(guardada!);

      expect(p.vm.direccion!.id, '1');
    });
  });

  group('CheckoutViewModel: validaciones antes de cobrar', () {
    test('fuera de horario no se paga', () async {
      final p = _Prueba(abierto: false)..listoParaRecoger();
      final r = await p.pagar() as PagoInterrumpido?;
      expect(r!.aviso, contains('fuera de servicio'));
      expect(p.pasarela.cobros, 0);
    });

    test('sin fecha u hora no se paga', () async {
      final p = _Prueba();
      final r = await p.pagar() as PagoInterrumpido?;
      expect(r!.aviso, 'Selecciona fecha y hora de recolección');
    });

    test('a domicilio exige una dirección con cobertura', () async {
      final p = _Prueba()..listoParaRecoger();
      p.vm.elegirEntrega(TipoEntrega.domicilio);
      expect((await p.pagar() as PagoInterrumpido?)!.aviso,
          'Selecciona una dirección de entrega');

      await p.vm.cargar();
      p.vm.elegirDireccion(p.vm.direcciones.first); // sin cobertura
      expect((await p.pagar() as PagoInterrumpido?)!.aviso,
          contains('no tiene cobertura'));
      expect(p.api.llamo(ApiConstants.crearPaymentIntent), isFalse);
    });
  });

  group('CheckoutViewModel: pago', () {
    test('recoger: crea el intent con el horario, cobra y confirma', () async {
      final p = _Prueba()..listoParaRecoger();

      final r = await p.pagar() as PagoExitoso?;

      expect(r!.pedido.numero, 'P-77');
      expect(r.total, 540);
      expect(p.pasarela.cobros, 1);
      expect(p.api.ultima(ApiConstants.crearPaymentIntent)!.body,
          {'horario_recogida': '2026-10-13 17:00'});
      expect(p.api.ultima(ApiConstants.confirmarPago)!.body, {
        'payment_intent_id': 'pi_123',
        'notas': '',
        'horario_recogida': '2026-10-13 17:00',
      });
      expect(p.vm.errorPago, isNull);
    });

    test('domicilio: manda la dirección y confirma con horario de entrega',
        () async {
      final p = _Prueba()..listoParaRecoger();
      await p.vm.cargar();
      p.vm.elegirEntrega(TipoEntrega.domicilio);

      await p.pagar();

      expect(p.api.ultima(ApiConstants.crearPaymentIntent)!.body,
          {'tipo_entrega': 'domicilio', 'direccion_id': '2'});
      expect(p.api.ultima(ApiConstants.confirmarPago)!.body!['horario_entrega'],
          '2026-10-13 17:00');
    });

    test('si el backend no crea el intent avisa y no cobra', () async {
      final p = _Prueba()..listoParaRecoger();
      p.api.fallar(ApiConstants.crearPaymentIntent, 'Carrito vacío');

      final r = await p.pagar() as PagoInterrumpido?;

      expect(r!.aviso, 'Carrito vacío');
      expect(p.vm.errorPago, 'Carrito vacío');
      expect(p.pasarela.cobros, 0);
    });

    test('un intent sin clientSecret es respuesta incompleta', () async {
      final p = _Prueba()..listoParaRecoger();
      p.api.responder(ApiConstants.crearPaymentIntent, {'success': true});
      final r = await p.pagar() as PagoInterrumpido?;
      expect(r!.aviso, 'Respuesta de pago incompleta. Intenta de nuevo.');
    });

    test('pedido por confirmar: pregunta antes de cobrar', () async {
      final p = _Prueba(aceptaPorConfirmar: false)..listoParaRecoger();
      p.api.responder(ApiConstants.crearPaymentIntent, {
        'success': true,
        'clientSecret': 'pi_9_secret_x',
        'publishableKey': 'pk',
        'por_confirmar': true,
        'productos_por_confirmar': ['Rosca'],
      });

      final r = await p.pagar() as PagoInterrumpido?;

      expect(p.preguntas.single, ['Rosca']);
      expect(r!.aviso, isNull);
      expect(p.pasarela.cobros, 0);
    });

    test('cancelar la hoja de pago no avisa; un rechazo sí', () async {
      final p = _Prueba()..listoParaRecoger();
      p.pasarela.falla = const PagoCanceladoException();
      expect((await p.pagar() as PagoInterrumpido?)!.aviso, isNull);

      p.pasarela.falla = const PagoRechazadoException('Tarjeta declinada');
      expect((await p.pagar() as PagoInterrumpido?)!.aviso, 'Tarjeta declinada');
      expect(p.vm.errorPago, isNull);
      expect(p.api.llamo(ApiConstants.confirmarPago), isFalse);
    });

    test('si la confirmación falla tras cobrar, reintenta y el siguiente '
        'Pagar NO vuelve a cobrar', () async {
      final p = _Prueba()..listoParaRecoger();
      p.api.fallar(ApiConstants.confirmarPago, 'Sin conexión');

      final r = await p.pagar() as PagoInterrumpido?;

      expect(p.confirmaciones(), CheckoutViewModel.intentosConfirmacion);
      expect(p.esperas, [const Duration(seconds: 2), const Duration(seconds: 4)]);
      expect(r!.aviso, contains('NO pagues de nuevo'));
      expect(p.vm.errorPago, contains('Sin conexión'));

      // Vuelve la red: solo se reintenta la confirmación.
      p.api.responder(ApiConstants.confirmarPago, {
        'success': true,
        'pedido': {'numero': 'P-78', 'por_confirmar': true},
      });
      final otra = await p.pagar() as PagoExitoso?;

      expect(otra!.pedido.numero, 'P-78');
      expect(otra.pedido.porConfirmar, isTrue);
      expect(otra.total, 540);
      expect(p.pasarela.cobros, 1);
      expect(p.api.llamadas
          .where((l) => l.endpoint == ApiConstants.crearPaymentIntent),
          hasLength(1));
    });

    test('si el backend dice que el cobro no ocurrió, se empieza de cero',
        () async {
      final p = _Prueba()..listoParaRecoger();
      p.api.responder(ApiConstants.confirmarPago, {
        'success': false,
        'status': 'requires_payment_method',
        'message': 'El pago no se completó',
      });

      final r = await p.pagar() as PagoInterrumpido?;
      expect(r!.aviso, 'El pago no se completó');

      p.api.responder(ApiConstants.confirmarPago, {
        'success': true,
        'pedido': {'numero': 'P-79'},
      });
      await p.pagar();
      expect(p.pasarela.cobros, 2);
    });

    test('un error inesperado queda en el Command', () async {
      final p = _Prueba()..listoParaRecoger();
      p.pasarela.falla = Exception('se cayó el plugin');

      await p.vm.pagar.execute();

      expect(p.vm.pagar.error, isA<Exception>());
      expect(p.vm.pagar.resultado, isNull);
      p.vm.pagar.limpiar();
      expect(p.vm.pagar.error, isNull);
    });
  });

  group('DireccionFormViewModel', () {
    test('al crear exige alias, calle y colonia', () async {
      final api = _backend();
      final form = DireccionFormViewModel(repo: DireccionesRepositoryRemote(api: api));
      final (_, error) = await form.guardar(
          alias: 'Casa', calle: ' ', referencias: '', telefono: '');
      expect(error, 'Completa alias, calle y número, y colonia');
    });

    test('en edición precarga la colonia y si falla devuelve el mensaje',
        () async {
      final p = _Prueba();
      await p.vm.cargar();
      final form = DireccionFormViewModel(
        repo: DireccionesRepositoryRemote(api: p.api),
        editar: p.vm.direcciones.last,
      );
      await form.cargarColonias();
      expect(form.esEdicion, isTrue);
      expect(form.colonia, 'Centro');
      expect(form.tarifa, 40);

      p.api.fallar(ApiConstants.direccionById('2'), 'Colonia inválida');
      final (guardada, error) = await form.guardar(
          alias: 'Oficina', calle: 'Juárez 9', referencias: '', telefono: '');
      expect(guardada, isNull);
      expect(error, 'Colonia inválida');
      expect(p.api.ultima(ApiConstants.direccionById('2'))!.metodo, 'PUT-Auth');
      expect(form.guardando, isFalse);
    });

    test('sin colonias con cobertura deja la lista vacía', () async {
      final api = FakeApiClient()..fallar(ApiConstants.zonasColonias, 'x');
      final form = DireccionFormViewModel(repo: DireccionesRepositoryRemote(api: api));
      await form.cargarColonias();
      expect(form.colonias, isEmpty);
      expect(form.cargandoColonias, isFalse);
    });
  });
}
