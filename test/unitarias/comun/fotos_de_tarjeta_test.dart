// test/unitarias/comun/fotos_de_tarjeta_test.dart — #284: la foto de tarjeta
// tiene una sola puerta, el widget FotoDeTarjeta. Todo origen del vuelo de la
// foto (las tarjetas, el vuelo al detalle, el vuelo al carrito y la foto de
// abajo de la galería) la pinta con él, así todos piden la misma entrada de
// ImageCache y el vuelo sale con la foto desde el primer cuadro:
//   · solo foto_producto.dart llama a fotoDeTarjeta(…);
//   · el vuelo al detalle y el vuelo al carrito no pintan otra foto;
//   · dentro de cada FotoProductoHero de lib/ no hay otra foto (Image,
//     Image.network, NetworkImage…), y su archivo pinta con FotoDeTarjeta.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cada archivo .dart de lib/ (ruta con /) → su código sin comentarios: un
/// comentario puede nombrar fotoDeTarjeta o Image sin pintar nada. Un //
/// pegado a otro carácter (https://…) no es comentario.
Map<String, String> _codigoDeLib() {
  final comentario = RegExp(r'(^|\s)//.*$', multiLine: true);
  return {
    for (final archivo in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((archivo) => archivo.path.endsWith('.dart')))
      archivo.path.replaceAll(r'\', '/'): archivo
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .replaceAll(comentario, ''),
  };
}

/// Otra manera de pintar una foto.
final RegExp _otraFoto = RegExp(
  r'\b(?:Image[.(]|NetworkImage\(|CachedNetworkImage|DecorationImage\()',
);

/// El texto de cada llamada a [constructor] en [codigo], de su nombre a su
/// paréntesis de cierre.
List<String> _llamadas(String codigo, String constructor) {
  final llamadas = <String>[];
  for (var inicio = codigo.indexOf('$constructor(');
      inicio >= 0;
      inicio = codigo.indexOf('$constructor(', inicio + 1)) {
    var abiertos = 0;
    for (var i = inicio + constructor.length; i < codigo.length; i++) {
      if (codigo[i] == '(') abiertos++;
      if (codigo[i] == ')' && --abiertos == 0) {
        llamadas.add(codigo.substring(inicio, i + 1));
        break;
      }
    }
  }
  return llamadas;
}

void main() {
  final codigo = _codigoDeLib();

  test('solo foto_producto.dart llama a fotoDeTarjeta: lo demás pinta con '
      'FotoDeTarjeta', () {
    final llamadas = [
      for (final MapEntry(key: ruta, value: texto) in codigo.entries)
        if (texto.contains('fotoDeTarjeta(')) ruta,
    ];

    expect(llamadas, ['lib/ui/core/ui/foto_producto.dart']);
  });

  test('el vuelo al detalle y el vuelo al carrito pintan solo '
      'FotoDeTarjeta', () {
    for (final ruta in [
      'lib/ui/core/ui/movimiento/foto_producto_hero.dart',
      'lib/ui/core/ui/movimiento/vuelo_al_carrito.dart',
    ]) {
      expect(codigo[ruta], contains('FotoDeTarjeta('), reason: ruta);
      expect(_otraFoto.hasMatch(codigo[ruta]!), isFalse, reason: ruta);
    }
  });

  test('cada FotoProductoHero de lib/ pinta su foto con FotoDeTarjeta', () {
    final conVuelo = <String>{};

    for (final MapEntry(key: ruta, value: texto) in codigo.entries) {
      for (final llamada in _llamadas(texto, 'FotoProductoHero')) {
        conVuelo.add(ruta);
        expect(_otraFoto.hasMatch(llamada), isFalse, reason: '$ruta: $llamada');
        expect(texto, contains('FotoDeTarjeta('), reason: ruta);
      }
    }

    // La definición, la galería del detalle y las tarjetas del catálogo,
    // angosta, del Inicio, de Favoritos y del Perfil: si no encontrara
    // ninguna, la prueba no revisaría nada.
    expect(conVuelo, hasLength(greaterThanOrEqualTo(7)));
  });
}
