// test/widget/feed/imagen_feed_test.dart — las fotos de las publicaciones se
// decodifican al tamaño en que se ven (#324): el ancho de su caja (o el que
// ocupa al cubrir una caja más angosta que la foto) por la densidad de la
// pantalla; sin proporción, o sin ancho finito, van completas. Sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/feed/widgets/tarjeta_publicacion.dart';

const _url = 'https://res.cloudinary.com/foto.jpg';

/// El proveedor de la foto que pintó la ImagenFeed.
ImageProvider _proveedor(WidgetTester tester) =>
    tester.widget<Image>(find.byType(Image)).image;

Future<void> _montar(
  WidgetTester tester,
  ImagenFeed imagen, {
  Size caja = const Size(300, 300),
}) async {
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox.fromSize(size: caja, child: imagen),
      ),
    ),
  );
}

void main() {
  group('anchoDeDecodificacion', () {
    test('la foto tan ancha como su caja: el ancho de la caja', () {
      expect(
        anchoDeDecodificacion(
          BoxConstraints.tight(const Size(300, 300)),
          1,
          3,
        ),
        900,
      );
    });

    test('una foto más ancha que su caja la cubre por el alto', () {
      // Caja cuadrada de 300 y foto 1.91:1: se ve de 573 dp de ancho.
      expect(
        anchoDeDecodificacion(
          BoxConstraints.tight(const Size(300, 300)),
          1.91,
          2,
        ),
        1146,
      );
    });

    test('una foto más alta que su caja: el ancho de la caja', () {
      expect(
        anchoDeDecodificacion(
          BoxConstraints.tight(const Size(400, 200)),
          0.8,
          2.5,
        ),
        1000,
      );
    });

    test('sin alto finito, el ancho; sin ancho finito, completa', () {
      expect(
        anchoDeDecodificacion(const BoxConstraints(maxWidth: 360), 1.5, 2),
        720,
      );
      expect(anchoDeDecodificacion(const BoxConstraints(), 1, 2), isNull);
      expect(
        anchoDeDecodificacion(const BoxConstraints(maxWidth: 0), 1, 2),
        isNull,
      );
    });
  });

  group('ImagenFeed', () {
    testWidgets('con proporción se decodifica al tamaño de su caja', (
      tester,
    ) async {
      await _montar(tester, const ImagenFeed(_url, proporcion: 1));
      final proveedor = _proveedor(tester);
      expect(proveedor, isA<ResizeImage>());
      final reducida = proveedor as ResizeImage;
      expect(reducida.width, 600);
      expect(reducida.height, isNull);
      expect(reducida.imageProvider, isA<NetworkImage>());
      // Igual que antes: cubre su lugar.
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    });

    testWidgets('sin proporción va completa', (tester) async {
      await _montar(tester, const ImagenFeed(_url));
      expect(_proveedor(tester), isA<NetworkImage>());
      expect((_proveedor(tester) as NetworkImage).url, _url);
    });
  });
}
