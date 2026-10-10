// lib/domain/models/zona_colonia.dart
//
// Colonia con cobertura de envío a domicilio y su tarifa (GET
// /zonas-envio/colonias).

class ZonaColonia {
  const ZonaColonia({required this.colonia, required this.tarifaTexto});

  factory ZonaColonia.fromJson(Map<dynamic, dynamic> json) => ZonaColonia(
        colonia: json['colonia']?.toString() ?? '',
        tarifaTexto: json['tarifa']?.toString() ?? '',
      );

  final String colonia;

  /// La tarifa tal como la manda el backend (se muestra en la lista).
  final String tarifaTexto;

  double? get tarifa => double.tryParse(tarifaTexto);
}
