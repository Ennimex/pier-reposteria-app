// test/config_format_test.dart — helpers puros de configuracion/* (utils).
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/utils/config_format.dart';

void main() {
  group('parseConfigValor', () {
    test('decodifica una lista serializada como JSON', () {
      expect(parseConfigValor('[{"pregunta":"a","respuesta":"b"}]'), [
        {'pregunta': 'a', 'respuesta': 'b'},
      ]);
    });

    test('decodifica un mapa serializado como JSON', () {
      expect(parseConfigValor('{"titulo":"Historia"}'), {'titulo': 'Historia'});
    });

    test('un string serializado como JSON devuelve el texto interno', () {
      expect(parseConfigValor('"hola"'), 'hola');
    });

    test('texto plano se devuelve recortado', () {
      expect(parseConfigValor('  hola mundo  '), 'hola mundo');
    });

    test('vacío, espacios o null -> null', () {
      expect(parseConfigValor(null), isNull);
      expect(parseConfigValor(''), isNull);
      expect(parseConfigValor('   '), isNull);
    });

    test('JSON inválido no lanza: devuelve el texto tal cual', () {
      expect(parseConfigValor('{rota'), '{rota');
    });

    test('Map/List/num ya decodificados pasan tal cual', () {
      final m = {'a': 1};
      expect(identical(parseConfigValor(m), m), true);
      expect(parseConfigValor(7), 7);
    });
  });

  group('configTexto', () {
    test('texto no vacío, recortado', () => expect(configTexto(' x '), 'x'));
    test('vacío -> null', () => expect(configTexto('   '), isNull));
    test('null -> null', () => expect(configTexto(null), isNull));
    test('número -> su texto', () => expect(configTexto(5), '5'));
    test('JSON string -> su contenido', () => expect(configTexto('"ok"'), 'ok'));
  });

  group('formatearHorario', () {
    test('null usa el fallback', () {
      expect(formatearHorario(null, fallback: 'F'), 'F');
    });
    test('array [{sucursal, horario}] produce texto no vacío', () {
      final t = formatearHorario([
        {'sucursal': 'Matriz', 'horario': 'Lun-Sab 9:00-21:00'},
      ]);
      expect(t, isNotEmpty);
      expect(t, contains('9:00'));
    });
  });
}
