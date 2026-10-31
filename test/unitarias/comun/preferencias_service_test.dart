// test/unitarias/comun/preferencias_service_test.dart — PreferenciasService
// (#220): la aceptación del aviso de privacidad se guarda en el teléfono con
// fecha, versión de la app y vía.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/data/services/preferencias_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _llave = 'pierreposteria_privacidad_aceptada';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sin aceptación guardada devuelve null', () async {
    expect(await PreferenciasService().aceptacionPrivacidad(), isNull);
  });

  test('guarda y recupera la aceptación del aviso', () async {
    final fecha = DateTime.utc(2026, 10, 28, 9, 30);
    await PreferenciasService().guardarAceptacionPrivacidad(
      AceptacionPrivacidad(fecha: fecha, versionApp: '2.1.1+5', via: 'google'),
    );

    final leida = await PreferenciasService().aceptacionPrivacidad();

    expect(leida?.fecha, fecha);
    expect(leida?.versionApp, '2.1.1+5');
    expect(leida?.via, 'google');
  });

  test('la fecha se guarda en UTC', () async {
    await PreferenciasService().guardarAceptacionPrivacidad(
      AceptacionPrivacidad(
        fecha: DateTime.utc(2026, 10, 28, 15),
        versionApp: '2.1.1+5',
        via: 'correo',
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_llave), contains('2026-10-28T15:00:00.000Z'));
  });

  test('un valor ilegible cuenta como sin aceptación', () async {
    SharedPreferences.setMockInitialValues({_llave: 'no es json'});

    expect(await PreferenciasService().aceptacionPrivacidad(), isNull);
  });
}
