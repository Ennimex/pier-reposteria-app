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
        'https://res.cloudinary.com/x/image/upload/c_limit,q_auto/v1/a.jpg',
        // Una transformación con nombre, un efecto con nivel y una cadena.
        'https://res.cloudinary.com/x/image/upload/t_tarjeta/v1/a.jpg',
        'https://res.cloudinary.com/x/image/upload/e_sepia:50/pier/a.jpg',
        'https://res.cloudinary.com/x/image/upload/c_fill,w_300/dpr_2.0/v1/a.jpg',
        // Con una variable propia.
        r'https://res.cloudinary.com/x/image/upload/$ancho_300,w_$ancho/a.jpg',
      ]) {
        expect(fotoReducida(url), url, reason: url);
      }
    });

    test('una carpeta sin versión que parece transformación se reduce', () {
      // Una a tres letras y un guion bajo, pero no es un parámetro de
      // Cloudinary: es la carpeta, y la foto se pide reducida.
      for (final carpeta in ['img_x', 'mis_fotos', 'ab_c/d']) {
        expect(
          fotoReducida(
            'https://res.cloudinary.com/x/image/upload/$carpeta/a.jpg',
          ),
          'https://res.cloudinary.com/x/image/upload/'
          'w_600,c_limit,q_auto,f_auto/$carpeta/a.jpg',
          reason: carpeta,
        );
      }
    });

    test('firmada se deja igual: la transformación rompería la firma', () {
      const subida = 'https://res.cloudinary.com/x/image/upload';
      for (final url in [
        '$subida/s--Ap2yGxcZ--/v1/a.jpg',
        '$subida/s--Ap2yGxcZ--/pier/a.jpg',
        '$subida/s--A-b_C9xZ--/c_fill,w_300/v1/a.jpg',
        // La firma larga (32 caracteres).
        '$subida/s--2Fz5HmD8kL0pQrStUvWxYz123456789A--/v1/a.jpg',
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
