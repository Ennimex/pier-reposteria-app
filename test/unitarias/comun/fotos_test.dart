// test/unitarias/comun/fotos_test.dart — fotoReducida (#267): la dirección de la
// foto de una tarjeta que Cloudinary entrega reducida; cualquier otra
// dirección se queda tal cual.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/utils/fotos.dart';

void main() {
  group('fotoReducida', () {
    test('Cloudinary sin transformar', () {
      expect(
        fotoReducida('https://res.cloudinary.com/x/image/upload/v1/a.jpg'),
        'https://res.cloudinary.com/x/image/upload/'
        'w_600,c_limit,q_auto,f_auto/v1/a.jpg',
      );
    });

    test('sin versión, la carpeta queda después de la transformación', () {
      expect(
        fotoReducida(
          'https://res.cloudinary.com/x/image/upload/pier/rosca.webp',
        ),
        'https://res.cloudinary.com/x/image/upload/'
        'w_600,c_limit,q_auto,f_auto/pier/rosca.webp',
      );
    });

    test('la consulta de la dirección se conserva', () {
      expect(
        fotoReducida(
          'https://res.cloudinary.com/x/image/upload/v1/a.jpg?_a=BAMAMiGM0',
        ),
        'https://res.cloudinary.com/x/image/upload/'
        'w_600,c_limit,q_auto,f_auto/v1/a.jpg?_a=BAMAMiGM0',
      );
    });

    test('ancho propio', () {
      expect(
        fotoReducida(
          'https://res.cloudinary.com/x/image/upload/v1/a.jpg',
          ancho: 200,
        ),
        'https://res.cloudinary.com/x/image/upload/'
        'w_200,c_limit,q_auto,f_auto/v1/a.jpg',
      );
    });

    test('ya transformada se deja igual', () {
      for (final url in [
        'https://res.cloudinary.com/x/image/upload/w_300/v1/a.jpg',
        'https://res.cloudinary.com/x/image/upload/c_fill,w_300,h_200/v1/a.jpg',
        'https://res.cloudinary.com/x/image/upload/f_auto,q_auto/a.jpg',
      ]) {
        expect(fotoReducida(url), url, reason: url);
      }
    });

    test('otra dirección se deja igual', () {
      for (final url in [
        'https://pier.mx/fotos/a.jpg',
        'https://otro.com/res.cloudinary.com/image/upload/v1/a.jpg',
        // Se parece a Cloudinary pero es otro dominio.
        'https://res.cloudinary.com.otro.mx/x/image/upload/v1/a.jpg',
        // De Cloudinary, pero sin /upload/ en la ruta.
        'https://res.cloudinary.com/x/image/fetch/v1/a.jpg',
        'https://res.cloudinary.com/x/a.jpg?ruta=/upload/v1/b.jpg',
      ]) {
        expect(fotoReducida(url), url, reason: url);
      }
    });

    test('vacía se deja igual', () {
      expect(fotoReducida(''), '');
    });

    test('local: se deja igual', () {
      expect(fotoReducida('local:producto1.webp'), 'local:producto1.webp');
    });
  });
}
