// test/unitarias/comun/contenido_sitio_test.dart — cómo la app traduce lo que
// guarda el editor del sitio de Dirección (#168): las fotos «local:» de la web
// a sus propios assets y las rutas de la web a sus pantallas.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/domain/models/imagen_sitio.dart';
import 'package:pier_reposteria/domain/models/slide_hero.dart';

void main() {
  group('imagenDelSitio', () {
    test('cada foto incluida en la web usa su equivalente en la app', () {
      const casos = {
        'local:producto1.webp': 'assets/images/sitio/producto1.webp',
        'local:producto1.jpg': 'assets/images/sitio/producto1.webp',
        'local:producto2-tarjeta.webp': 'assets/images/sitio/producto2.webp',
        'local:producto3.webp': 'assets/images/sitio/producto3.webp',
        'local:producto4.jpg': 'assets/images/sitio/producto4.webp',
        'local:producto5-tarjeta.webp': 'assets/images/sitio/producto5.webp',
        'local:producto6.jpg': 'assets/images/sitio/producto6.webp',
        'local:producto6-tarjeta.webp': 'assets/images/sitio/producto6.webp',
      };
      for (final MapEntry(key: valor, value: asset) in casos.entries) {
        expect(imagenDelSitio(valor), asset, reason: valor);
      }
    });

    test('una foto subida a Cloudinary se usa tal cual', () {
      const url = 'https://res.cloudinary.com/pier/image/upload/v1/rosca.jpg';
      expect(imagenDelSitio(url), url);
    });

    test('lo que la app no puede pintar no da imagen', () {
      for (final valor in [
        null,
        '',
        'local:producto7.webp',
        'local:otra.png',
        'local:producto1.png',
        'http://inseguro.mx/foto.jpg',
        'javascript:alert(1)',
      ]) {
        expect(imagenDelSitio(valor), isNull, reason: '$valor');
      }
    });
  });

  group('rutaDeEnlace', () {
    test('las rutas de la web abren su pantalla en la app', () {
      const casos = {
        '/productos': RutaSlide.catalogo,
        '/productos?categoria=Roscas': RutaSlide.catalogo,
        '/contacto': RutaSlide.contacto,
        '/nosotros': RutaSlide.nosotros,
        '/conocenos': RutaSlide.nosotros,
        '/preguntas-frecuentes': RutaSlide.faq,
        '/legales': RutaSlide.legales,
      };
      for (final MapEntry(key: enlace, value: ruta) in casos.entries) {
        expect(rutaDeEnlace(enlace), ruta, reason: enlace);
      }
    });

    test('una ruta sin pantalla en la app abre el catálogo', () {
      for (final enlace in ['/login', '/registro', '/', '', '/no-existe']) {
        expect(rutaDeEnlace(enlace), RutaSlide.catalogo, reason: enlace);
      }
    });
  });
}
