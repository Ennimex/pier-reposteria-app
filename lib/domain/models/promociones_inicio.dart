// lib/domain/models/promociones_inicio.dart
//
// Promociones activas separadas por tipo para las secciones del inicio
// (igual que la web): un banner, ofertas relámpago, de temporada y
// destacadas. Cada promoción se conserva como el Map del backend porque las
// secciones leen muchos campos opcionales (fechas, textos, colores, precios).

class PromocionesInicio {
  const PromocionesInicio({
    this.banner,
    this.relampago = const [],
    this.temporada = const [],
    this.destacado = const [],
  });

  /// Separa [lista] por `tipo`: del banner solo el primero; relámpago,
  /// temporada y destacado solo si traen `producto_id`.
  factory PromocionesInicio.fromLista(List<dynamic> lista) {
    Map<String, dynamic>? banner;
    final relampago = <Map<String, dynamic>>[];
    final temporada = <Map<String, dynamic>>[];
    final destacado = <Map<String, dynamic>>[];
    for (final p in lista.whereType<Map<String, dynamic>>()) {
      final conProducto = p['producto_id'] != null;
      switch (p['tipo']?.toString()) {
        case 'banner':
          banner ??= p;
        case 'relampago' when conProducto:
          relampago.add(p);
        case 'temporada' when conProducto:
          temporada.add(p);
        case 'destacado' when conProducto:
          destacado.add(p);
      }
    }
    return PromocionesInicio(
      banner: banner,
      relampago: relampago,
      temporada: temporada,
      destacado: destacado,
    );
  }

  final Map<String, dynamic>? banner;
  final List<Map<String, dynamic>> relampago;
  final List<Map<String, dynamic>> temporada;
  final List<Map<String, dynamic>> destacado;
}
