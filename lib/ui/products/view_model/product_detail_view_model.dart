// lib/ui/products/view_model/product_detail_view_model.dart
//
// Estado del detalle de un producto (MVVM, Fase 4): galería y reseñas del
// backend, corazón de favorito (optimista), "útil" de cada reseña
// (optimista), recomendaciones por co-compra, tamaño y cantidad elegidos, y
// "Avísame" de los agotados. Precios con descuento y carrito siguen en sus
// providers globales; la vista decide si manda a iniciar sesión.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';
import 'package:pier_reposteria/data/repositories/demanda_repository.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository.dart';
import 'package:pier_reposteria/data/repositories/productos_repository.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/domain/models/resena_producto.dart';
import 'package:pier_reposteria/ui/reviews/view_model/reporte_resena.dart';
import 'package:pier_reposteria/utils/logger.dart';

class ProductDetailViewModel extends ChangeNotifier {
  ProductDetailViewModel({
    required this.producto,
    required ProductosRepository productosRepo,
    required FavoritosRepository favoritosRepo,
    required ResenasRepository resenasRepo,
    required DemandaRepository demandaRepo,
    ConfiguracionRepository? configRepo,
    bool esFavorito = false,
  })  : _productosRepo = productosRepo,
        _configRepo = configRepo,
        _favoritosRepo = favoritosRepo,
        _resenasRepo = resenasRepo,
        _demandaRepo = demandaRepo,
        _imagenes = producto.imagenes.isNotEmpty
            ? producto.imagenes
            : [producto.imagenUrl],
        _totalResenas = producto.totalResenas,
        _rating = producto.rating,
        _esFavorito = esFavorito {
    _cambiosDeFavoritos = favoritosRepo.cambios.listen(_alCambiarFavorito);
  }

  /// Etiquetas del selector (el backend no tiene porciones por tamaño).
  static const List<String> tamanos = ['Chico', 'Grande'];

  /// Tope de piezas por producto desde el detalle.
  static const int cantidadMaxima = 10;

  final Product producto;
  final ProductosRepository _productosRepo;
  final FavoritosRepository _favoritosRepo;
  final ResenasRepository _resenasRepo;
  final DemandaRepository _demandaRepo;

  /// De dónde sale la dirección de contacto para «Reportar» (#328); sin él,
  /// la de BusinessInfo.
  final ConfiguracionRepository? _configRepo;
  bool _cerrado = false;

  // Quién ve el detalle, para no ofrecerle reportar su propia reseña (#328).
  bool _conSesion = false;
  String? _usuarioSesion;

  List<String> _imagenes;
  List<ResenaProducto> _resenas = const [];
  bool _cargandoResenas = true;
  int _totalResenas;
  double _rating;
  // Lo que sabía quien abrió el detalle (el catálogo, favoritos) hasta que
  // conteste el servidor; si no contesta (sin red), se queda (#275).
  bool _esFavorito;
  // Este mismo producto pudo cambiar en otra pantalla, p. ej. en otro
  // detalle abierto desde las recomendaciones (#308).
  late final StreamSubscription<CambioFavorito> _cambiosDeFavoritos;
  List<Product> _recomendaciones = const [];
  int _cantidad = 1;
  int _tamano = 0;
  final Set<String> _utilesEnCurso = {};

  List<String> get imagenes => _imagenes;
  List<ResenaProducto> get resenas => _resenas;
  bool get cargandoResenas => _cargandoResenas;
  int get totalResenas => _totalResenas;
  double get rating => _rating;
  bool get esFavorito => _esFavorito;
  List<Product> get recomendaciones => _recomendaciones;
  int get cantidad => _cantidad;

  /// 0 = Chico, 1 = Grande.
  int get tamano => _tamano;

  /// Solo hay selector de tamaño si el producto tiene precio grande.
  bool get tieneTamanos => producto.precioGrande != null;

  /// Precio sin descuento del tamaño [indice] (grande estimado si falta).
  double precioDeTamano(int indice) => indice == 0
      ? producto.precio
      : (producto.precioGrande ?? producto.precio * 1.4);

  /// Precio sin descuento del tamaño elegido.
  double get precioBase => precioDeTamano(_tamano);

  /// Página pública del producto en la web: se abre sin sesión (#343).
  String get enlaceWeb =>
      '${BusinessInfo.sitioWeb}/producto/${Uri.encodeComponent(producto.id)}';

  /// Lo que se manda al compartir (con foto o sin ella): nombre, precio y el
  /// enlace al producto, para que quien lo recibe pueda abrirlo (#343).
  String get textoParaCompartir =>
      '¡Mira este delicioso producto!\n\n'
      '${producto.nombre} por solo \$${producto.precio.toStringAsFixed(2)}\n\n'
      'Encuéntralo en ${BusinessInfo.marca}: $enlaceWeb';

  /// Como lo espera el carrito: 'chico' o 'grande'.
  String get tamanoParaCarrito => _tamano == 1 ? 'grande' : 'chico';

  // ── Carga ────────────────────────────────────────────────────────────────

  /// [usuarioId] es el del cliente con sesión: con él se sabe cuáles
  /// reseñas son suyas (#328).
  Future<void> cargar({required bool autenticado, String? usuarioId}) {
    _conSesion = autenticado;
    _usuarioSesion = usuarioId;
    return Future.wait([
      cargarDetalle(),
      cargarFavorito(autenticado: autenticado),
      cargarRecomendaciones(),
    ]);
  }

  /// ¿Se ofrece «Reportar»? Solo en las de otros clientes (#328).
  bool puedeReportar(ResenaProducto resena) => ReporteResena.esDeOtroCliente(
        autorId: resena.usuarioId,
        conSesion: _conSesion,
        usuarioSesion: _usuarioSesion,
      );

  /// El correo ya escrito para reportar [resena] (#328).
  Future<Uri> correoParaReportar(ResenaProducto resena) =>
      ReporteResena.correoConContacto(
        _configRepo,
        resena: resena,
        productoId: producto.id,
        productoNombre: producto.nombre,
      );

  /// Galería, reseñas, total y promedio. También al volver de escribir o de
  /// ver todas las reseñas.
  Future<void> cargarDetalle() async {
    PierLog.info('Cargando detalle: ${producto.id}');
    try {
      final detalle = await _productosRepo.detalleDelProducto(producto.id);
      if (_cerrado) return;
      PierLog.info('✅ ${detalle.resenas.length} reseñas cargadas');
      _resenas = detalle.resenas;
      _totalResenas = detalle.totalResenas;
      _rating = detalle.rating;
      if (detalle.imagenes.isNotEmpty) _imagenes = detalle.imagenes;
    } on ApiException {
      PierLog.error('No se pudo cargar detalle de ${producto.id}');
      if (_cerrado) return;
    }
    _cargandoResenas = false;
    notifyListeners();
  }

  /// Pregunta si el producto es favorito. Si falla (sin red), el corazón
  /// conserva lo último que se supo (#275).
  Future<void> cargarFavorito({required bool autenticado}) async {
    if (!autenticado) return;
    try {
      final ids = await _favoritosRepo.listarIds();
      if (_cerrado) return;
      _esFavorito = ids.contains(producto.id);
      notifyListeners();
    } on ApiException catch (e) {
      PierLog.error('Error al cargar favorito: ${e.message}');
    }
  }

  void _alCambiarFavorito(CambioFavorito cambio) {
    if (_cerrado ||
        cambio.productoId != producto.id ||
        cambio.favorito == _esFavorito) {
      return;
    }
    _esFavorito = cambio.favorito;
    notifyListeners();
  }

  /// Otros clientes también pidieron (sin el producto actual).
  Future<void> cargarRecomendaciones() async {
    try {
      final lista = await _productosRepo.recomendacionesDe(producto.id);
      if (_cerrado) return;
      _recomendaciones = lista.where((p) => p.id != producto.id).toList();
      PierLog.info('✅ ${_recomendaciones.length} recomendaciones cargadas');
      notifyListeners();
    } on ApiException catch (e) {
      PierLog.debug('Sin recomendaciones: ${e.message}');
    }
  }

  // ── Acciones del cliente ─────────────────────────────────────────────────

  /// Pone o quita el corazón al instante y lo confirma con el backend; si
  /// falla lo regresa y devuelve el mensaje de error (null = todo bien).
  Future<String?> alternarFavorito() async {
    final yaEsFav = _esFavorito;
    _esFavorito = !yaEsFav;
    notifyListeners();
    try {
      if (yaEsFav) {
        await _favoritosRepo.quitarFavorito(producto.id);
      } else {
        await _favoritosRepo.agregarFavorito(producto.id);
      }
      PierLog.info('Favorito ${yaEsFav ? 'removido' : 'agregado'}');
      return null;
    } on ApiException catch (e) {
      PierLog.error('Error al actualizar favorito: ${e.message}');
      if (!_cerrado) {
        _esFavorito = yaEsFav;
        notifyListeners();
      }
      return e.message;
    }
  }

  /// Marca o desmarca "útil" una reseña al instante; si el backend falla la
  /// regresa y devuelve su mensaje. Ignora toques mientras va la anterior.
  Future<String?> alternarUtil(String resenaId) async {
    final i = _resenas.indexWhere((r) => r.id == resenaId);
    if (i == -1 || resenaId.isEmpty || !_utilesEnCurso.add(resenaId)) {
      return null;
    }
    final antes = _resenas[i];
    _ponerResena(antes.copyWith(
      marcadaUtil: !antes.marcadaUtil,
      utilCount: antes.utilCount + (antes.marcadaUtil ? -1 : 1),
    ));
    try {
      await _resenasRepo.alternarUtil(resenaId);
      PierLog.info('Like ${antes.marcadaUtil ? 'removido' : 'agregado'} '
          '— reseña $resenaId');
      return null;
    } on ApiException catch (e) {
      PierLog.error('Error al dar like a reseña $resenaId');
      if (!_cerrado) _ponerResena(antes);
      return e.message;
    } finally {
      _utilesEnCurso.remove(resenaId);
    }
  }

  void _ponerResena(ResenaProducto resena) {
    _resenas =
        _resenas.map((r) => r.id == resena.id ? resena : r).toList();
    notifyListeners();
  }

  void elegirTamano(int indice) {
    _tamano = indice;
    notifyListeners();
  }

  void sumarPieza() {
    if (_cantidad >= cantidadMaxima) return;
    _cantidad++;
    notifyListeners();
  }

  void quitarPieza() {
    if (_cantidad <= 1) return;
    _cantidad--;
    notifyListeners();
  }

  /// "Avísame": registra el interés en el agotado (no bloquea ni falla).
  void avisarme() => _demandaRepo.registrarClicAgotado(producto.id);

  @override
  void dispose() {
    _cerrado = true;
    unawaited(_cambiosDeFavoritos.cancel());
    super.dispose();
  }
}
