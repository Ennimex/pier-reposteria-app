// lib/ui/core/ui/foto_producto.dart
//
// La foto de las tarjetas de producto (#267): la versión reducida que entrega
// Cloudinary (fotoReducida), guardada en el teléfono con cached_network_image
// para no bajarla otra vez al volver a una pantalla ni al abrir la app.
//
// Un solo ancho (600) para todo uso chico de la foto: la tarjeta, el vuelo al
// detalle, el vuelo al carrito y la foto de abajo de la galería comparten la
// misma entrada de ImageCache, y por eso el aterrizaje del Hero y la
// miniatura del carrito salen con la foto desde el primer cuadro. Las fotos
// del carrusel del detalle siguen completas (Image.network), salvo la primera
// cuando es la de la tarjeta y no es de Cloudinary: esa ya es la completa y
// la galería usa su misma entrada.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:pier_reposteria/utils/fotos.dart';

/// Crea el proveedor de cada foto de tarjeta; las pruebas lo cambian por
/// NetworkImage (test/flutter_test_config.dart): cached_network_image usa
/// disco y los plugins sqflite y path_provider, que no existen en pruebas.
@visibleForTesting
ImageProvider Function(String url) proveedorDeFoto =
    CachedNetworkImageProvider.new;

/// El proveedor de la foto de tarjeta de [url] (reducida si es de
/// Cloudinary). Para pintarla está [FotoDeTarjeta]; las pruebas lo usan para
/// comparar la foto que se pintó.
ImageProvider fotoDeTarjeta(String url) => proveedorDeFoto(fotoReducida(url));

/// La foto de tarjeta de [url] (fotoDeTarjeta): todo origen del vuelo de la
/// foto (las tarjetas, el vuelo al detalle, el vuelo al carrito y la foto de
/// abajo de la galería) la pinta con este widget, así todos piden la misma
/// entrada de ImageCache (test/unitarias/comun/fotos_de_tarjeta_test.dart lo
/// revisa). Lo demás es lo mismo que en [Image].
class FotoDeTarjeta extends StatelessWidget {
  const FotoDeTarjeta(
    this.url, {
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.gaplessPlayback = false,
    this.frameBuilder,
    this.errorBuilder,
    super.key,
  });

  /// La dirección de la foto completa (`producto.imagenUrl`).
  final String url;

  final double? width;
  final double? height;

  /// Cubre su lugar, como en todas las tarjetas.
  final BoxFit fit;

  /// true sigue mostrando la foto de antes mientras llega otra.
  final bool gaplessPlayback;

  /// Lo que se ve según la foto ya llegó o no (un fundido, un relleno).
  final ImageFrameBuilder? frameBuilder;

  /// Lo que se ve si la foto no llega.
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) => Image(
    image: fotoDeTarjeta(url),
    width: width,
    height: height,
    fit: fit,
    gaplessPlayback: gaplessPlayback,
    frameBuilder: frameBuilder,
    errorBuilder: errorBuilder,
  );
}
