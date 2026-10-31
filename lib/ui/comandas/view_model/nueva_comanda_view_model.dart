// lib/ui/comandas/view_model/nueva_comanda_view_model.dart
//
// Estado de «Nueva comanda» (#130): carga el catálogo (opciones del pastel,
// reglas de cobro y productos), lleva lo capturado, suma en centavos, sube
// las fotos de referencia una por una y valida con las mismas reglas y
// mensajes que la web (src/comandas/formulario/validacion.ts) antes de
// mandarla. Si el backend la rechaza se muestran todos sus motivos. Lo crea
// NuevaComandaScreen.
//
// Con [NuevaComandaViewModel.editarId] edita una comanda (#228): la carga
// con su versión, conserva lo que este formulario no muestra (colores de la
// mesa de postres, color de fondo e insumos del pastel, indicaciones del
// producto) y, si otra persona la guardó antes, lo dice y deja recargarla.
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository.dart';
import 'package:pier_reposteria/domain/models/nueva_comanda.dart';
import 'package:pier_reposteria/utils/moneda.dart';

/// Un renglón de la comanda mientras se captura.
sealed class RenglonBorrador {
  RenglonBorrador(this.clave);

  /// Identifica al renglón en la vista aunque se quiten otros.
  final int clave;

  String cantidad = '1';
}

/// Un pastel personalizado: las características son nombres de las opciones
/// activas; el precio se escribe a mano.
class PastelBorrador extends RenglonBorrador {
  PastelBorrador(super.clave);

  String sabor = '';
  String tamano = '';
  String forma = '';
  String decoracion = '';
  int pisos = 1;
  String precio = '';
  String leyenda = '';
  String descripcion = '';

  /// Solo al editar: se conservan tal como estaban (#228).
  String? colorFondo;
  String? insumos;
}

/// Un producto del catálogo en tamaño chico o grande, con su precio.
class ProductoBorrador extends RenglonBorrador {
  ProductoBorrador(super.clave, this.producto);

  final ProductoCatalogo producto;
  bool grande = false;

  /// Solo al editar: se conservan tal como estaban (#228).
  String? indicaciones;

  /// Al editar, el producto ya no está en el catálogo.
  bool descontinuado = false;

  /// Precio unitario en centavos según el tamaño (null: no hay grande).
  int? get precio => grande ? producto.precioGrande : producto.precioChico;
}

enum EstadoFoto { subiendo, lista, fallo }

/// Una foto de referencia: la ruta local y, ya subida, lo que se manda.
class FotoBorrador {
  FotoBorrador(this.clave, this.ruta);

  final int clave;
  final String ruta;
  EstadoFoto estado = EstadoFoto.subiendo;
  FotoComanda? subida;
  String? error;
}

class NuevaComandaViewModel extends ChangeNotifier {
  /// [editarId]: la comanda que se edita (null para una nueva). [ahora]
  /// solo se pasa en pruebas (reloj fijo).
  NuevaComandaViewModel({
    required ComandasRepository repo,
    this.editarId,
    DateTime Function()? ahora,
  })  : _repo = repo,
        _ahora = ahora ?? DateTime.now;

  final int? editarId;

  final ComandasRepository _repo;
  final DateTime Function() _ahora;
  bool _cerrado = false;

  static const int maxRenglones = 30;
  static const int maxFotos = 10;
  static const int maxDias = 400;

  CatalogoComanda? _catalogo;
  ComandaParaEditar? _original;
  bool _desactualizada = false;
  bool _cargando = false;
  String? _errorCarga;
  bool _guardando = false;
  bool _sesionInvalida = false;
  List<String> _errores = const [];
  int _siguiente = 0;

  // Lo capturado. La vista lo cambia con [editar].
  String nombre = '';
  String telefono = '';
  DateTime? fecha;

  /// 'HH:MM'.
  String? hora;
  String notas = '';
  String descuento = '';
  String anticipo = '';
  final List<RenglonBorrador> renglones = [];
  final List<FotoBorrador> fotos = [];

  CatalogoComanda? get catalogo => _catalogo;

  bool get editando => editarId != null;

  /// El folio de la comanda que se edita.
  int? get folio => _original?.folio;

  /// Otra persona la guardó mientras se editaba: hay que recargarla.
  bool get desactualizada => _desactualizada;
  bool get cargando => _cargando;
  String? get errorCarga => _errorCarga;
  bool get guardando => _guardando;

  /// La cuenta ya no está vigente: la vista cierra la sesión.
  bool get sesionInvalida => _sesionInvalida;

  /// Lo que hay que corregir (de la validación o del backend).
  List<String> get errores => _errores;

  bool get puedeAgregar => renglones.length < maxRenglones;
  bool get puedeAgregarFoto => fotos.length < maxFotos;

  /// Hoy, sin hora.
  DateTime get hoy {
    final a = _ahora();
    return DateTime(a.year, a.month, a.day);
  }

  Future<void> cargar() async {
    _cargando = true;
    _errorCarga = null;
    notifyListeners();
    try {
      final c = await _repo.catalogo();
      final id = editarId;
      final original = id == null || _original != null
          ? _original
          : await _repo.paraEditar(id);
      if (_cerrado) return;
      _catalogo = c;
      if (original != null && _original == null) _llenar(original);
    } on SesionInvalidaException catch (e) {
      _errorCarga = e.message;
      _sesionInvalida = true;
    } on ApiException catch (e) {
      _errorCarga = e.message;
    }
    if (_cerrado) return;
    _cargando = false;
    notifyListeners();
  }

  /// Vuelve a traer la comanda que se edita (la versión que otra persona
  /// guardó) y descarta lo que se había cambiado aquí.
  Future<void> recargarComanda() async {
    final id = editarId;
    if (id == null) return;
    try {
      final original = await _repo.paraEditar(id);
      if (_cerrado) return;
      _llenar(original);
      _desactualizada = false;
      _errores = const [];
    } on ApiException catch (e) {
      _errores = [e.message];
    }
    if (!_cerrado) notifyListeners();
  }

  /// Llena el formulario con [c].
  void _llenar(ComandaParaEditar c) {
    _original = c;
    nombre = c.clienteNombre;
    telefono = c.clienteTelefono;
    final f = c.fechaEntrega.split('-').map(int.tryParse).toList();
    fecha = f.length == 3 && !f.contains(null)
        ? DateTime(f[0]!, f[1]!, f[2]!)
        : null;
    hora = c.horaEntrega.length >= 5 ? c.horaEntrega.substring(0, 5) : null;
    notas = c.notas ?? '';
    descuento = c.descuento == 0 ? '' : _pesos(c.descuento);
    anticipo = _pesos(c.anticipo);
    renglones.clear();
    fotos.clear();
    final productos = _catalogo?.productos ?? const <ProductoCatalogo>[];
    for (final r in c.renglones) {
      String? opcional(Object? v) {
        final t = v?.toString().trim() ?? '';
        return t.isEmpty ? null : t;
      }

      final precio = centavosDe(r['precio_unitario']) ?? 0;
      if (r['tipo'] == 'producto') {
        final id = (r['producto_id'] as num?)?.toInt() ?? 0;
        final grande = r['tamano_catalogo'] == 'grande';
        final delCatalogo = productos.where((p) => p.id == id).firstOrNull;
        renglones.add(ProductoBorrador(
          _siguiente++,
          delCatalogo ??
              ProductoCatalogo(
                id: id,
                nombre: opcional(r['nombre']) ?? 'Producto',
                precioChico: precio,
                precioGrande: grande ? precio : null,
              ),
        )
          ..grande = grande
          ..cantidad = '${r['cantidad'] ?? 1}'
          ..indicaciones = opcional(r['indicaciones'])
          ..descontinuado = delCatalogo == null);
      } else {
        renglones.add(PastelBorrador(_siguiente++)
          ..sabor = opcional(r['sabor']) ?? ''
          ..tamano = opcional(r['tamano']) ?? ''
          ..forma = opcional(r['forma']) ?? ''
          ..decoracion = opcional(r['decoracion']) ?? ''
          ..pisos = (r['num_pisos'] as num?)?.toInt() ?? 1
          ..cantidad = '${r['cantidad'] ?? 1}'
          ..precio = _pesos(precio)
          ..leyenda = opcional(r['leyenda']) ?? ''
          ..descripcion = opcional(r['descripcion']) ?? ''
          ..colorFondo = opcional(r['color_fondo'])
          ..insumos = opcional(r['insumos']));
      }
    }
    for (final im in c.imagenes) {
      fotos.add(FotoBorrador(_siguiente++, im.url)
        ..estado = EstadoFoto.lista
        ..subida = im);
    }
  }

  /// «450.00» (sin separador de miles: es lo que se edita).
  static String _pesos(int centavos) =>
      '${centavos ~/ 100}.${(centavos % 100).toString().padLeft(2, '0')}';

  /// Aplica [cambio] a lo capturado y repinta (los totales se recalculan).
  void editar(VoidCallback cambio) {
    cambio();
    notifyListeners();
  }

  PastelBorrador agregarPastel() {
    final p = PastelBorrador(_siguiente++);
    editar(() => renglones.add(p));
    return p;
  }

  void agregarProducto(ProductoCatalogo producto) =>
      editar(() => renglones.add(ProductoBorrador(_siguiente++, producto)));

  void quitar(RenglonBorrador renglon) =>
      editar(() => renglones.remove(renglon));

  /// Número del pastel entre los pasteles («Pastel 2»).
  int numeroDePastel(PastelBorrador pastel) =>
      renglones.whereType<PastelBorrador>().toList().indexOf(pastel) + 1;

  // ── Fotos ─────────────────────────────────────────────────────────

  /// Sube la foto de [ruta]; si falla queda marcada para reintentar o
  /// quitar, sin perder lo capturado.
  Future<void> agregarFoto(String ruta) async {
    if (!puedeAgregarFoto) return;
    final foto = FotoBorrador(_siguiente++, ruta);
    editar(() => fotos.add(foto));
    await _subir(foto);
  }

  Future<void> reintentarFoto(FotoBorrador foto) async {
    editar(() {
      foto
        ..estado = EstadoFoto.subiendo
        ..error = null;
    });
    await _subir(foto);
  }

  void quitarFoto(FotoBorrador foto) => editar(() => fotos.remove(foto));

  Future<void> _subir(FotoBorrador foto) async {
    try {
      final subida = await _repo.subirFoto(foto.ruta);
      foto
        ..subida = subida
        ..estado = EstadoFoto.lista;
    } on ApiException catch (e) {
      foto
        ..error = e.message
        ..estado = EstadoFoto.fallo;
    }
    if (!_cerrado) notifyListeners();
  }

  // ── Cuentas (en centavos) ─────────────────────────────────────────

  /// Importe de [renglon] en centavos (0 si falta el precio o la cantidad).
  int importe(RenglonBorrador renglon) {
    final cantidad = int.tryParse(renglon.cantidad.trim()) ?? 0;
    final precio = switch (renglon) {
      PastelBorrador(:final precio) => leerCentavos(precio) ?? 0,
      ProductoBorrador(:final precio) => precio ?? 0,
    };
    return precio * cantidad;
  }

  int get subtotal => renglones.fold(0, (s, r) => s + importe(r));
  int get _descuento => leerCentavos(descuento) ?? 0;
  int get total => subtotal - _descuento < 0 ? 0 : subtotal - _descuento;
  int get _pct => _catalogo?.ajustes.anticipoMinimoPct ?? 0;

  /// Anticipo mínimo en centavos (redondeado hacia arriba, como el backend).
  int get anticipoMinimo => (total * _pct + 99) ~/ 100;

  int get saldo {
    final s = total - (leerCentavos(anticipo) ?? 0);
    return s < 0 ? 0 : s;
  }

  /// «Mínimo $150.00 (50 % del total)»; null sin mínimo.
  String? get textoMinimo => _pct == 0
      ? null
      : 'Mínimo ${moneda(anticipoMinimo / 100)} ($_pct % del total)';

  /// Aviso que no impide guardar: la entrega llega antes de los días que
  /// pide producción.
  String? get advertencia {
    final f = fecha;
    final dias = _catalogo?.ajustes.diasAnticipacion ?? 0;
    if (f == null || dias == 0) return null;
    final faltan = _diasDesdeHoy(f);
    if (faltan < 0 || faltan >= dias) return null;
    return 'La entrega es en menos de $dias días: confirma con producción '
        'que alcanza. Puedes guardarla de todos modos.';
  }

  // ── Validación (mismos mensajes que la web) ───────────────────────

  List<String> validar() {
    final e = <String>[];
    final n = nombre.trim();
    if (n.isEmpty) {
      e.add('Escribe el nombre del cliente');
    } else if (n.length < 2) {
      e.add('El nombre debe tener al menos 2 letras');
    } else {
      _largo(e, 'Nombre', n, 120);
    }

    final t = telefono.trim();
    if (t.isEmpty) {
      e.add('Escribe el teléfono del cliente');
    } else if (!RegExp(r'^[\d\s\-.()]+$').hasMatch(t)) {
      e.add('Usa solo números (puedes separarlos con espacios o guiones)');
    } else if (_digitos(t).length != 10) {
      e.add('El teléfono debe tener 10 dígitos (llevas ${_digitos(t).length})');
    }

    final f = fecha;
    if (f == null) {
      e.add('Elige la fecha de entrega');
    } else if (f.isBefore(hoy)) {
      e.add('Esa fecha ya pasó; elige hoy o una fecha posterior');
    } else if (_diasDesdeHoy(f) > maxDias) {
      e.add('La entrega no puede ser a más de $maxDias días');
    }
    if (hora == null) e.add('Elige la hora de entrega');

    if (renglones.isEmpty) {
      e.add('Agrega al menos un pastel o un producto');
    } else if (renglones.length > maxRenglones) {
      e.add('Una comanda admite hasta $maxRenglones renglones (llevas '
          '${renglones.length}); divide el pedido en dos comandas');
    }
    for (final r in renglones) {
      switch (r) {
        case PastelBorrador():
          _validarPastel(e, r);
        case ProductoBorrador():
          _validarProducto(e, r);
      }
    }

    if (fotos.any((f) => f.estado == EstadoFoto.subiendo)) {
      e.add('Espera a que terminen de subir las imágenes');
    } else if (fotos.any((f) => f.estado == EstadoFoto.fallo)) {
      e.add('Hay imágenes que no se subieron: reinténtalas o quítalas');
    }

    if (descuento.trim().isNotEmpty) {
      final d = leerCentavos(descuento);
      if (d == null) {
        e.add('Escribe un descuento válido, por ejemplo 50 o 50.00');
      } else if (d > subtotal) {
        e.add('El descuento no puede ser mayor que el subtotal '
            '(${moneda(subtotal / 100)})');
      }
    }

    final a = leerCentavos(anticipo);
    if (a == null) {
      e.add('Escribe un anticipo válido, por ejemplo 200 o 200.50');
    } else if (a < anticipoMinimo) {
      e.add('El anticipo mínimo es ${moneda(anticipoMinimo / 100)} '
          '($_pct % del total)');
    } else if (a > total) {
      e.add('El anticipo no puede ser mayor que el total '
          '(${moneda(total / 100)})');
    }

    _largo(e, 'Notas', notas.trim(), 1000);
    return e;
  }

  void _validarPastel(List<String> e, PastelBorrador p) {
    final pre = 'Pastel ${numeroDePastel(p)} · ';
    final o = _catalogo?.opciones ?? const OpcionesPastel();
    void opcion(String valor, List<String> activas, String elige,
        String yaNo) {
      if (valor.isEmpty) {
        e.add('$pre$elige');
      } else if (!activas.contains(valor)) {
        e.add('$pre$yaNo');
      }
    }

    opcion(p.sabor, o.sabores, 'Elige el sabor',
        'Ese sabor ya no se ofrece; elige otro');
    opcion(p.tamano, o.tamanos, 'Elige el tamaño',
        'Ese tamaño ya no se ofrece; elige otro');
    opcion(p.forma, o.formas, 'Elige la forma',
        'Esa forma ya no se ofrece; elige otra');
    opcion(p.decoracion, o.decoraciones, 'Elige la decoración',
        'Esa decoración ya no se ofrece; elige otra');
    if (p.pisos < 1 || p.pisos > 6) e.add('${pre}Elige de 1 a 6 pisos');
    final c = int.tryParse(p.cantidad.trim());
    if (c == null || c < 1 || c > 20) {
      e.add('${pre}La cantidad va de 1 a 20 pasteles');
    }
    final precio = p.precio.trim();
    final centavos = leerCentavos(precio);
    if (precio.isEmpty) {
      e.add('${pre}Escribe el precio del pastel');
    } else if (centavos == null) {
      e.add('${pre}Escribe un precio válido, por ejemplo 450 o 450.50');
    } else if (centavos > 10000000) {
      e.add('${pre}El precio no puede pasar de \$100,000');
    }
    _largo(e, '${pre}Leyenda', p.leyenda.trim(), 200);
    _largo(e, '${pre}Descripción', p.descripcion.trim(), 2000);
  }

  void _validarProducto(List<String> e, ProductoBorrador p) {
    final pre = '${p.producto.nombre} · ';
    if (p.descontinuado) {
      e.add('${pre}Este producto ya no está disponible; quítalo de la '
          'comanda');
    }
    if (p.precio == null) {
      e.add('${pre}Este producto solo se vende en tamaño chico');
    }
    final c = int.tryParse(p.cantidad.trim());
    if (c == null || c < 1 || c > 999) {
      e.add('${pre}La cantidad va de 1 a 999 piezas');
    }
  }

  static void _largo(List<String> e, String campo, String texto, int max) {
    if (texto.length > max) {
      e.add('$campo: máximo $max caracteres (llevas ${texto.length})');
    }
  }

  /// Días de calendario de hoy a [fecha] (en UTC: el cambio de horario no
  /// mueve la cuenta).
  int _diasDesdeHoy(DateTime fecha) {
    final h = hoy;
    return DateTime.utc(fecha.year, fecha.month, fecha.day)
        .difference(DateTime.utc(h.year, h.month, h.day))
        .inDays;
  }

  static String _digitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

  // ── Guardar ───────────────────────────────────────────────────────

  /// El cuerpo de POST /comandas, como lo arma la web (entradaDesdeForm).
  Map<String, dynamic> cuerpo() {
    String? opcional(String t) => t.trim().isEmpty ? null : t.trim();
    double pesos(int centavos) => centavos / 100;
    final f = fecha!;
    return {
      'cliente_nombre': nombre.trim(),
      'cliente_telefono': _digitos(telefono),
      'fecha_entrega': '${f.year.toString().padLeft(4, '0')}-'
          '${f.month.toString().padLeft(2, '0')}-'
          '${f.day.toString().padLeft(2, '0')}',
      'hora_entrega': hora,
      'notas': opcional(notas),
      'descuento': pesos(_descuento),
      'anticipo': pesos(leerCentavos(anticipo) ?? 0),
      'items': [
        for (final r in renglones)
          switch (r) {
            PastelBorrador() => {
                'tipo': 'pastel',
                'cantidad': int.parse(r.cantidad.trim()),
                'sabor': r.sabor,
                'tamano': r.tamano,
                'forma': r.forma,
                'decoracion': r.decoracion,
                'num_pisos': r.pisos,
                'leyenda': opcional(r.leyenda),
                'descripcion': opcional(r.descripcion),
                'precio_unitario': pesos(leerCentavos(r.precio) ?? 0),
                'color_fondo': ?r.colorFondo,
                'insumos': ?r.insumos,
              },
            ProductoBorrador() => {
                'tipo': 'producto',
                'producto_id': r.producto.id,
                'tamano_catalogo': r.grande ? 'grande' : 'chico',
                'cantidad': int.parse(r.cantidad.trim()),
                'indicaciones': ?r.indicaciones,
              },
          },
      ],
      'imagenes': [
        for (final f in fotos)
          if (f.subida case final subida?) subida.toJson(),
      ],
      // Al editar, los colores de la mesa de postres se quedan como estaban.
      ...?_original?.coloresMesa,
    };
  }

  /// Valida y la manda. Devuelve la comanda creada, o null si hay algo que
  /// corregir ([errores]) o el backend la rechazó.
  Future<ComandaCreada?> guardar() async {
    if (_guardando) return null;
    final e = validar();
    _errores = e;
    if (e.isNotEmpty) {
      notifyListeners();
      return null;
    }
    _guardando = true;
    notifyListeners();
    ComandaCreada? creada;
    try {
      final id = editarId;
      final original = _original;
      if (id != null && original != null) {
        final r = await _repo.guardarCambios(id, cuerpo(),
            actualizadaEn: original.actualizadaEn);
        creada = ComandaCreada(
          id: id,
          folio: original.folio,
          mensaje: r.mensaje,
          advertencias: r.advertencias,
        );
      } else {
        creada = await _repo.crear(cuerpo());
      }
    } on ConflictoComandaException catch (e) {
      _errores = [e.message];
      _desactualizada = true;
    } on SesionInvalidaException catch (e) {
      _errores = [e.message];
      _sesionInvalida = true;
    } on ApiException catch (e) {
      _errores = e.message.split('\n');
    }
    if (_cerrado) return creada;
    _guardando = false;
    notifyListeners();
    return creada;
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}

/// Pesos escritos («450», «450.5», «1,250.50») a centavos; null si no es un
/// monto válido (como leerCentavos de la web: la coma solo separa miles).
int? leerCentavos(String texto) {
  final t = texto.trim();
  if (!RegExp(r'^(\d{1,3}(,\d{3})+|\d+)(\.\d{1,2})?$').hasMatch(t)) {
    return null;
  }
  final partes = t.replaceAll(',', '').split('.');
  final decimales = partes.length > 1 ? partes[1].padRight(2, '0') : '00';
  return int.parse(partes[0]) * 100 + int.parse(decimales);
}
