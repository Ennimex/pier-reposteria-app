// lib/domain/models/nueva_comanda.dart
//
// Captura de comandas desde el teléfono (#130), mismo contrato que el
// formulario de la web (src/comandas/FormularioComanda.tsx):
// - GET /comandas/catalogo -> {opciones{tamano, sabor, forma, decoracion:
//   [{id, nombre, orden}]}, ajustes{anticipo_minimo_pct,
//   dias_anticipacion_minima, …}, productos[{id, nombre, categoria,
//   precio_chico, precio_grande, imagen_url}]} (los precios llegan como
//   texto "450.00"; precio_grande puede ser null).
// - POST /comandas/imagenes (multipart `imagen`) -> imagen{url, public_id}.
// - POST /comandas -> comanda{id, folio}, advertencias[], message.
// - Edición (#228): GET /comandas/:id trae lo capturado con
//   `actualizada_en`, que se devuelve en PUT /comandas/:id; si otra persona
//   la guardó antes, 409 COMANDA_DESACTUALIZADA.
// Los montos se llevan en centavos, como la web, para no perder centavos al
// sumar.

/// Las opciones activas de cada característica del pastel, por nombre.
class OpcionesPastel {
  const OpcionesPastel({
    this.sabores = const [],
    this.tamanos = const [],
    this.formas = const [],
    this.decoraciones = const [],
  });

  factory OpcionesPastel.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    List<String> nombres(Object? lista) => [
          if (lista is List)
            for (final o in lista)
              if (o is Map && (o['nombre']?.toString().trim() ?? '') != '')
                o['nombre'].toString().trim(),
        ];
    return OpcionesPastel(
      sabores: nombres(m['sabor']),
      tamanos: nombres(m['tamano']),
      formas: nombres(m['forma']),
      decoraciones: nombres(m['decoracion']),
    );
  }

  final List<String> sabores;
  final List<String> tamanos;
  final List<String> formas;
  final List<String> decoraciones;
}

/// Un producto del catálogo que se puede agregar a la comanda.
class ProductoCatalogo {
  const ProductoCatalogo({
    required this.id,
    required this.nombre,
    required this.precioChico,
    this.precioGrande,
    this.categoria,
  });

  /// null si falta el id, el nombre o el precio chico.
  static ProductoCatalogo? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = (json['id'] as num?)?.toInt() ??
        int.tryParse(json['id']?.toString() ?? '');
    final nombre = json['nombre']?.toString().trim() ?? '';
    final chico = centavosDe(json['precio_chico']);
    if (id == null || nombre.isEmpty || chico == null) return null;
    return ProductoCatalogo(
      id: id,
      nombre: nombre,
      precioChico: chico,
      precioGrande: centavosDe(json['precio_grande']),
      categoria: json['categoria']?.toString(),
    );
  }

  final int id;
  final String nombre;

  /// En centavos.
  final int precioChico;

  /// En centavos; null si no se vende en tamaño grande.
  final int? precioGrande;
  final String? categoria;
}

/// Reglas de cobro de Dirección.
class AjustesComanda {
  const AjustesComanda({
    this.anticipoMinimoPct = 0,
    this.diasAnticipacion = 0,
  });

  factory AjustesComanda.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    int entero(Object? v) =>
        (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '')) ?? 0;
    return AjustesComanda(
      anticipoMinimoPct: entero(m['anticipo_minimo_pct']),
      diasAnticipacion: entero(m['dias_anticipacion_minima']),
    );
  }

  /// Porcentaje del total que se cobra como mínimo de anticipo (0-100).
  final int anticipoMinimoPct;

  /// Días de anticipación que pide producción (si son menos, solo se avisa).
  final int diasAnticipacion;
}

/// Lo que necesita el formulario para capturar una comanda.
class CatalogoComanda {
  const CatalogoComanda({
    required this.opciones,
    required this.ajustes,
    this.productos = const [],
  });

  factory CatalogoComanda.fromJson(Map<String, dynamic> json) =>
      CatalogoComanda(
        opciones: OpcionesPastel.fromJson(json['opciones']),
        ajustes: AjustesComanda.fromJson(json['ajustes']),
        productos: [
          if (json['productos'] case final List lista)
            for (final p in lista) ?ProductoCatalogo.fromJson(p),
        ],
      );

  final OpcionesPastel opciones;
  final AjustesComanda ajustes;
  final List<ProductoCatalogo> productos;
}

/// Una foto de referencia ya subida (lo que se manda en `imagenes`).
class FotoComanda {
  const FotoComanda({required this.url, required this.publicId});

  Map<String, dynamic> toJson() => {'url': url, 'public_id': publicId};

  final String url;
  final String publicId;
}

/// Respuesta de POST /comandas.
class ComandaCreada {
  const ComandaCreada({
    required this.id,
    required this.folio,
    required this.mensaje,
    this.advertencias = const [],
  });

  final int id;
  final int folio;
  final String mensaje;

  /// P. ej. «La entrega es en menos de 3 días: confirma con producción que
  /// alcanza.»
  final List<String> advertencias;
}

/// Lo capturado de una comanda para editarla (GET /comandas/:id).
class ComandaParaEditar {
  const ComandaParaEditar({
    required this.id,
    required this.folio,
    required this.actualizadaEn,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.fechaEntrega,
    required this.horaEntrega,
    this.notas,
    this.coloresMesa = const {},
    this.descuento = 0,
    this.anticipo = 0,
    this.renglones = const [],
    this.imagenes = const [],
  });

  factory ComandaParaEditar.fromJson(Map<String, dynamic> respuesta) {
    final c = respuesta['comanda'] is Map
        ? Map<String, dynamic>.from(respuesta['comanda'] as Map)
        : <String, dynamic>{};
    String texto(Object? v) => v?.toString().trim() ?? '';
    List<Map<String, dynamic>> mapas(Object? v) => [
          if (v is List)
            for (final x in v)
              if (x is Map) Map<String, dynamic>.from(x),
        ];
    return ComandaParaEditar(
      id: (c['id'] as num?)?.toInt() ?? 0,
      folio: (c['folio'] as num?)?.toInt() ?? 0,
      actualizadaEn: texto(c['actualizada_en']),
      clienteNombre: texto(c['cliente_nombre']),
      clienteTelefono: texto(c['cliente_telefono']),
      fechaEntrega: texto(c['fecha_entrega']),
      horaEntrega: texto(c['hora_entrega']),
      notas: c['notas']?.toString(),
      coloresMesa: {
        for (final clave in const [
          'mesa_color_capacillos',
          'mesa_color_betun',
          'mesa_color_grageas',
        ])
          clave: c[clave]?.toString(),
      },
      descuento: centavosDe(c['descuento']) ?? 0,
      anticipo: centavosDe(c['anticipo']) ?? 0,
      renglones: mapas(c['items']),
      imagenes: [
        for (final im in mapas(c['imagenes']))
          if (texto(im['url']).isNotEmpty && texto(im['public_id']).isNotEmpty)
            FotoComanda(url: texto(im['url']), publicId: texto(im['public_id'])),
      ],
    );
  }

  final int id;
  final int folio;

  /// La versión que se editó; se devuelve al guardar.
  final String actualizadaEn;
  final String clienteNombre;
  final String clienteTelefono;

  /// 'YYYY-MM-DD'.
  final String fechaEntrega;

  /// 'HH:MM'.
  final String horaEntrega;
  final String? notas;

  /// Los colores de la mesa de postres tal como están (el formulario de la
  /// app no los edita, pero se conservan al guardar).
  final Map<String, String?> coloresMesa;

  /// En centavos.
  final int descuento;
  final int anticipo;

  /// Los renglones como llegan (pastel o producto).
  final List<Map<String, dynamic>> renglones;
  final List<FotoComanda> imagenes;
}

/// Pesos de la API ("450.00", 450, 450.5) a centavos; null si no es un
/// número válido.
int? centavosDe(Object? valor) {
  final n = valor is num ? valor : num.tryParse(valor?.toString() ?? '');
  if (n == null || n.isNaN || n.isInfinite) return null;
  return (n * 100).round();
}
