// lib/domain/models/detalle_producto.dart
//
// Lo que el detalle de un producto (GET /productos/:id) agrega a lo que ya
// trae el catálogo: la galería completa, las reseñas aprobadas con sus "útil"
// y el total y promedio de calificaciones.
import 'dart:convert';

import 'package:pier_pasteleria/domain/models/resena_producto.dart';

class DetalleProducto {
  const DetalleProducto({
    required this.imagenes,
    required this.resenas,
    required this.totalResenas,
    required this.rating,
  });

  /// `{producto: {imagenes, reviews, rating_promedio}, resenas: [...]}`.
  /// `imagenes` puede venir como lista (de textos o de `{url}`) o como texto
  /// JSON con esa lista; si no trae ninguna, queda vacía.
  factory DetalleProducto.fromJson(Map<String, dynamic> json) {
    final producto = json['producto'];
    final datos = producto is Map ? producto : const <String, dynamic>{};
    final resenas = json['resenas'];
    return DetalleProducto(
      imagenes: _urls(datos['imagenes']),
      resenas: resenas is List
          ? resenas
              .whereType<Map<String, dynamic>>()
              .map(ResenaProducto.fromJson)
              .toList()
          : const [],
      totalResenas: int.tryParse(datos['reviews']?.toString() ?? '') ?? 0,
      rating: double.tryParse(datos['rating_promedio']?.toString() ?? '') ?? 0,
    );
  }

  /// Vacía = se usan las imágenes que ya traía el producto.
  final List<String> imagenes;
  final List<ResenaProducto> resenas;
  final int totalResenas;
  final double rating;

  static List<String> _urls(dynamic imagenes) {
    var lista = imagenes;
    if (lista is String && lista.trim().startsWith('[')) {
      try {
        lista = jsonDecode(lista);
      } on FormatException {
        return const [];
      }
    }
    if (lista is! List) return const [];
    return lista
        .map((e) => e is Map ? (e['url'] ?? '').toString() : e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
