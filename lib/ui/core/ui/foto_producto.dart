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
// del carrusel del detalle siguen completas (Image.network).
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
/// Cloudinary), para `Image(image: fotoDeTarjeta(url), …)`.
ImageProvider fotoDeTarjeta(String url) => proveedorDeFoto(fotoReducida(url));
