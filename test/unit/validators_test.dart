// test/unit/validators_test.dart — reglas de los formularios de login y
// registro (#16). Los mensajes son los que ve el usuario.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('vacío o nulo pide el email', () {
      expect(Validators.email(null), 'Ingresa tu email');
      expect(Validators.email(''), 'Ingresa tu email');
    });

    test('sin @ es inválido', () {
      expect(Validators.email('cliente.example.com'), 'Email inválido');
    });

    test('con @ es válido', () {
      expect(Validators.email('cliente@example.com'), isNull);
    });
  });

  group('Validators.passwordLogin', () {
    test('vacía o nula pide la contraseña', () {
      expect(Validators.passwordLogin(null), 'Ingresa tu contraseña');
      expect(Validators.passwordLogin(''), 'Ingresa tu contraseña');
    });

    test('menos de 6 caracteres es corta', () {
      expect(Validators.passwordLogin('12345'), 'Mínimo 6 caracteres');
    });

    test('6 o más caracteres es válida', () {
      expect(Validators.passwordLogin('123456'), isNull);
    });
  });

  group('Validators.passwordNueva', () {
    test('nula o de menos de 6 caracteres es corta', () {
      expect(Validators.passwordNueva(null), 'Mínimo 6 caracteres');
      expect(Validators.passwordNueva('ab12'), 'Mínimo 6 caracteres');
    });

    test('sin letras pide al menos una letra', () {
      expect(Validators.passwordNueva('123456'),
          'Debe contener al menos 1 letra');
    });

    test('sin números pide al menos un número', () {
      expect(Validators.passwordNueva('abcdef'),
          'Debe contener al menos 1 número');
    });

    test('con letras y números es válida', () {
      expect(Validators.passwordNueva('pastel123'), isNull);
    });
  });

  group('Validators.confirmarPassword', () {
    test('distinta de la original no coincide', () {
      expect(Validators.confirmarPassword('pastel124', 'pastel123'),
          'Las contraseñas no coinciden');
      expect(Validators.confirmarPassword(null, 'pastel123'),
          'Las contraseñas no coinciden');
    });

    test('igual a la original es válida', () {
      expect(Validators.confirmarPassword('pastel123', 'pastel123'), isNull);
    });
  });

  group('Validators.telefono', () {
    test('distinto de 10 dígitos es inválido', () {
      expect(Validators.telefono(null), 'Debe tener 10 dígitos');
      expect(Validators.telefono('771123456'), 'Debe tener 10 dígitos');
      expect(Validators.telefono('77112345678'), 'Debe tener 10 dígitos');
    });

    test('exactamente 10 dígitos es válido', () {
      expect(Validators.telefono('7711234567'), isNull);
    });
  });

  group('Validators.nombre', () {
    test('nulo o de menos de 2 caracteres es corto', () {
      expect(Validators.nombre(null), 'Mínimo 2 caracteres');
      expect(Validators.nombre('A'), 'Mínimo 2 caracteres');
    });

    test('2 o más caracteres es válido', () {
      expect(Validators.nombre('Al'), isNull);
    });
  });
}
