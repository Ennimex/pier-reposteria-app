// test/unit/contact_view_model_test.dart — «Contacto» (MVVM, Fase 3) sin
// red: el repositorio tipa /configuracion/contacto y envía /contacto, y el
// ViewModel lleva los datos de «Otros medios», el tipo, el contador y el
// envío.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';
import 'package:pier_pasteleria/domain/models/info_contacto.dart';
import 'package:pier_pasteleria/ui/public/view_model/contact_view_model.dart';

import '../fakes/fake_api_client.dart';

final String _config = ApiConstants.configuracionSeccion('contacto');
const String _envio = ApiConstants.enviarContacto;

const String _mensaje20 = 'Quiero un pastel de 3 pisos';

ContactViewModel _vm(FakeApiClient api) => ContactViewModel(
      configRepo: ConfiguracionRepository(api: api),
      cuentaRepo: CuentaRepository(api: api),
    );

Future<bool> _enviar(ContactViewModel vm, {String telefono = ''}) =>
    vm.enviar(
      nombre: ' Ana López ',
      email: ' ana@pier.mx ',
      telefono: telefono,
      conSesion: false,
    );

void main() {
  group('InfoContacto.fromConfig', () {
    test('lee los campos y formatea los horarios', () {
      final info = InfoContacto.fromConfig({
        'telefono': '"771 555 0000"',
        'email': 'hola@pier.mx',
        'whatsapp': '',
        'horarios': [
          {'sucursal': 'Centro', 'horario': '9 a 21'},
        ],
      });
      expect(info.telefono, '771 555 0000');
      expect(info.email, 'hola@pier.mx');
      expect(info.whatsapp, isNull);
      expect(info.horario, 'Centro: 9 a 21');
    });

    test('sin horarios capturados el horario queda null', () {
      expect(InfoContacto.fromConfig({}).horario, isNull);
    });
  });

  group('Repositorios', () {
    test('contacto lanza ApiException si el backend falla', () async {
      final api = FakeApiClient()..fallar(_config, 'Sección no pública');
      await expectLater(
        ConfiguracionRepository(api: api).contacto(),
        throwsA(isA<ApiException>()),
      );
    });

    test('enviarContacto manda el teléfono vacío como null', () async {
      final api = FakeApiClient(
        respuestas: {
          _envio: {'success': true},
        },
      );
      await CuentaRepository(api: api).enviarContacto(
        nombre: 'Ana',
        email: 'ana@pier.mx',
        telefono: '',
        tipoProducto: 'Pasteles',
        mensaje: _mensaje20,
        conSesion: true,
      );
      final llamada = api.ultima(_envio)!;
      expect(llamada.metodo, 'POST-Auth');
      expect(llamada.body, {
        'nombre': 'Ana',
        'email': 'ana@pier.mx',
        'telefono': null,
        'tipo_producto': 'Pasteles',
        'mensaje': _mensaje20,
      });
    });

    test('enviarContacto lanza ApiException con el mensaje del backend',
        () async {
      final api = FakeApiClient()..fallar(_envio, 'Demasiados mensajes');
      await expectLater(
        CuentaRepository(api: api).enviarContacto(
          nombre: 'Ana',
          email: 'ana@pier.mx',
          telefono: '',
          tipoProducto: 'Otro',
          mensaje: _mensaje20,
          conSesion: false,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Demasiados mensajes'),
        ),
      );
    });
  });

  group('ContactViewModel', () {
    test('arranca con BusinessInfo y el primer tipo', () {
      final vm = _vm(FakeApiClient());
      expect(vm.telefono, BusinessInfo.telefono);
      expect(vm.email, BusinessInfo.email);
      expect(vm.horario, BusinessInfo.horario);
      expect(vm.numeroWhatsApp, BusinessInfo.whatsappNumero);
      expect(vm.tipoProducto, 'Información general');
    });

    test('reemplaza solo lo que capturó el panel', () async {
      final api = FakeApiClient(
        respuestas: {
          _config: {
            'success': true,
            'config': {'telefono': '771 555 0000', 'whatsapp': '+52 771 555 0000'},
          },
        },
      );
      final vm = _vm(api);
      await vm.cargar();

      expect(vm.telefono, '771 555 0000');
      expect(vm.email, BusinessInfo.email);
      expect(vm.horario, BusinessInfo.horario);
      expect(vm.numeroWhatsApp, '527715550000');
    });

    test('si el backend falla se queda BusinessInfo', () async {
      final vm = _vm(FakeApiClient()..fallar(_config, 'Sin conexión'));
      await vm.cargar();
      expect(vm.telefono, BusinessInfo.telefono);
    });

    test('un WhatsApp sin dígitos usa el de BusinessInfo', () async {
      final api = FakeApiClient(
        respuestas: {
          _config: {
            'success': true,
            'config': {'whatsapp': 'pendiente'},
          },
        },
      );
      final vm = _vm(api);
      await vm.cargar();
      expect(vm.numeroWhatsApp, BusinessInfo.whatsappNumero);
    });

    test('el contador ignora espacios de los extremos', () {
      final vm = _vm(FakeApiClient())..editarMensaje('   corto   ');
      expect(vm.largoMensaje, 5);
      expect(vm.mensajeValido, isFalse);
      vm.editarMensaje(_mensaje20);
      expect(vm.mensajeValido, isTrue);
    });

    test('envía los datos limpios con el tipo elegido', () async {
      final api = FakeApiClient(
        respuestas: {
          _envio: {'success': true},
        },
      );
      final vm = _vm(api)
        ..elegirTipo('Quejas')
        ..editarMensaje('  $_mensaje20  ');

      final enviado = await _enviar(vm, telefono: ' 7711234567 ');

      expect(enviado, isTrue);
      expect(vm.enviando, isFalse);
      expect(vm.largoMensaje, 0);
      final body = api.ultima(_envio)!.body!;
      expect(body['nombre'], 'Ana López');
      expect(body['email'], 'ana@pier.mx');
      expect(body['telefono'], '7711234567');
      expect(body['tipo_producto'], 'Quejas');
      expect(body['mensaje'], _mensaje20);
    });

    test('si el envío falla deja el error y conserva el mensaje', () async {
      final api = FakeApiClient()..fallar(_envio, 'Demasiados mensajes');
      final vm = _vm(api)..editarMensaje(_mensaje20);

      final enviado = await _enviar(vm);

      expect(enviado, isFalse);
      expect(vm.error, 'Demasiados mensajes');
      expect(vm.enviando, isFalse);
      expect(vm.mensajeValido, isTrue);
    });
  });
}
