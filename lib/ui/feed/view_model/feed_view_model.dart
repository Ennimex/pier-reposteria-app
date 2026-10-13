// lib/ui/feed/view_model/feed_view_model.dart
//
// Estado de las publicaciones del inicio del cliente (#132) y cómo se arma
// lo que se pinta, igual que la web (src/cliente/feed/estado.ts): las
// publicaciones con una promoción después de cada 5 y, al acabarse, las
// sugerencias en bloques de 6 con las promociones que falten. Ninguna
// promoción se repite y las sugerencias no repiten productos que ya salieron
// como promoción. Lo crea HomeScreen solo con sesión de cliente.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/publicaciones_repository.dart';
import 'package:pier_pasteleria/domain/models/publicacion.dart';

/// Una promoción después de cada tantas publicaciones.
const publicacionesPorPromocion = 5;

/// Productos por bloque de «Te podría gustar».
const sugerenciasPorBloque = 6;

/// publicaciones → sugerencias → fin («Ya viste todo por hoy»).
enum FaseFeed { publicaciones, sugerencias, fin }

/// Lo que se ha traído del feed (inmutable).
class EstadoFeed {
  const EstadoFeed({
    this.publicaciones = const [],
    this.siguiente,
    this.feedTerminado = false,
    this.promociones = const [],
    this.sugerencias = const [],
    this.paginaSugerencias = 0,
    this.sugerenciasTerminadas = false,
  });

  final List<Publicacion> publicaciones;
  final CursorFeed? siguiente;

  /// El servidor ya no tiene publicaciones más viejas.
  final bool feedTerminado;
  final List<PromocionFeed> promociones;
  final List<ProductoSugerido> sugerencias;

  /// Última página de sugerencias pedida (0 = ninguna).
  final int paginaSugerencias;
  final bool sugerenciasTerminadas;

  FaseFeed get fase => !feedTerminado
      ? FaseFeed.publicaciones
      : !sugerenciasTerminadas
      ? FaseFeed.sugerencias
      : FaseFeed.fin;
}

/// Lo que se pinta en el feed, en orden.
sealed class ElementoFeed {
  const ElementoFeed();
}

class ElementoPublicacion extends ElementoFeed {
  const ElementoPublicacion(this.publicacion);
  final Publicacion publicacion;
}

class ElementoPromocion extends ElementoFeed {
  const ElementoPromocion(this.promocion);
  final PromocionFeed promocion;
}

class ElementoSugerencias extends ElementoFeed {
  const ElementoSugerencias(this.productos, {required this.primero});
  final List<ProductoSugerido> productos;

  /// El primer bloque lleva el título «Te podría gustar».
  final bool primero;
}

/// Arma el feed a partir de [estado] (función pura).
List<ElementoFeed> componerFeed(EstadoFeed estado) {
  final elementos = <ElementoFeed>[];
  final promociones = estado.promociones;
  var usadas = 0;
  // Las promociones se van tomando en orden y cada una sale una sola vez
  void intercalarPromocion() {
    if (usadas >= promociones.length) return;
    elementos.add(ElementoPromocion(promociones[usadas]));
    usadas++;
  }

  for (final (i, publicacion) in estado.publicaciones.indexed) {
    elementos.add(ElementoPublicacion(publicacion));
    if ((i + 1) % publicacionesPorPromocion == 0) intercalarPromocion();
  }
  if (!estado.feedTerminado) return elementos;

  final sugerencias = estado.sugerencias;
  for (var i = 0; i < sugerencias.length; i += sugerenciasPorBloque) {
    final fin = (i + sugerenciasPorBloque).clamp(0, sugerencias.length);
    final bloque = sugerencias.sublist(i, fin);
    elementos.add(ElementoSugerencias(bloque, primero: i == 0));
    // Solo tras un bloque completo (o el último): si el bloque todavía va a
    // crecer con la siguiente página, la promoción no brinca de lugar
    if (bloque.length == sugerenciasPorBloque || estado.sugerenciasTerminadas) {
      intercalarPromocion();
    }
  }
  // Al final del todo salen las promociones que no alcanzaron lugar
  if (estado.sugerenciasTerminadas) {
    while (usadas < promociones.length) {
      intercalarPromocion();
    }
  }
  return elementos;
}

/// [base] más los elementos de [nuevos] cuyo id no esté ya ni en [excluir].
List<T> _unirSinRepetir<T>(
  List<T> base,
  List<T> nuevos,
  int Function(T) id, {
  Iterable<int> excluir = const [],
}) {
  final vistos = {...excluir, ...base.map(id)};
  return [
    ...base,
    for (final e in nuevos)
      if (vistos.add(id(e))) e,
  ];
}

class FeedViewModel extends ChangeNotifier {
  FeedViewModel({required PublicacionesRepository repo}) : _repo = repo;

  final PublicacionesRepository _repo;

  EstadoFeed _estado = const EstadoFeed();
  bool _iniciado = false;
  bool _cargando = false;
  bool _cargandoMas = false;
  String? _error;
  String? _errorMas;
  int _turno = 0;
  bool _cerrado = false;

  /// Ya llegó la primera página (aunque viniera vacía).
  bool get iniciado => _iniciado;
  bool get cargando => _cargando;
  bool get cargandoMas => _cargandoMas;

  /// Por qué falló la primera carga (sin nada que mostrar).
  String? get error => _error;

  /// Por qué falló la última carga de más (se conserva lo que había).
  String? get errorMas => _errorMas;
  FaseFeed get fase => _estado.fase;

  /// La repostería aún no ha publicado nada.
  bool get sinPublicaciones =>
      _iniciado && _estado.feedTerminado && _estado.publicaciones.isEmpty;

  List<ElementoFeed> get elementos => componerFeed(_estado);

  /// Promociones y la primera página. Si fallan las promociones, el feed
  /// sigue igual (no amerita un error en pantalla).
  Future<void> cargar() async {
    final turno = ++_turno;
    _cargando = true;
    _error = null;
    _avisar();
    final promociones = _repo
        .promociones()
        .then<List<PromocionFeed>?>((p) => p)
        .catchError((Object _) => null, test: (e) => e is ApiException);
    try {
      final pagina = await _repo.feed();
      final promos = await promociones;
      if (turno != _turno) return;
      _estado = EstadoFeed(
        publicaciones: pagina.publicaciones,
        siguiente: pagina.siguiente,
        feedTerminado: pagina.siguiente == null,
        promociones: _unirSinRepetir(const [], promos ?? const [], _idPromo),
      );
      _iniciado = true;
    } on ApiException catch (e) {
      if (turno != _turno) return;
      _error = e.message;
    }
    _cargando = false;
    _avisar();
  }

  /// Empieza de nuevo (jalar para refrescar).
  Future<void> recargar() => cargar();

  /// La siguiente página de publicaciones o, al acabarse, de sugerencias.
  /// Se llama al acercarse al final; no hace nada si ya está cargando o si
  /// ya no hay más.
  Future<void> cargarMas() async {
    if (!_iniciado || _cargando || _cargandoMas || fase == FaseFeed.fin) {
      return;
    }
    final turno = _turno;
    _cargandoMas = true;
    _errorMas = null;
    _avisar();
    try {
      if (fase == FaseFeed.publicaciones) {
        final pagina = await _repo.feed(despues: _estado.siguiente);
        if (turno != _turno) return;
        _estado = _conPublicaciones(pagina);
      } else {
        final numero = _estado.paginaSugerencias + 1;
        final pagina = await _repo.sugerencias(pagina: numero);
        if (turno != _turno) return;
        _estado = _conSugerencias(pagina, numero);
      }
    } on ApiException catch (e) {
      if (turno != _turno) return;
      _errorMas = e.message;
    }
    _cargandoMas = false;
    _avisar();
  }

  /// Olvida todo (al cerrar sesión).
  void limpiar() {
    _turno++;
    _estado = const EstadoFeed();
    _iniciado = false;
    _cargando = false;
    _cargandoMas = false;
    _error = null;
    _errorMas = null;
    _avisar();
  }

  EstadoFeed _conPublicaciones(PaginaFeed pagina) => EstadoFeed(
    publicaciones: _unirSinRepetir(
      _estado.publicaciones,
      pagina.publicaciones,
      _idPublicacion,
    ),
    siguiente: pagina.siguiente,
    feedTerminado: pagina.siguiente == null,
    promociones: _estado.promociones,
  );

  EstadoFeed _conSugerencias(PaginaSugerencias pagina, int numero) =>
      EstadoFeed(
        publicaciones: _estado.publicaciones,
        feedTerminado: true,
        promociones: _estado.promociones,
        sugerencias: _unirSinRepetir(
          _estado.sugerencias,
          pagina.productos,
          _idSugerido,
          excluir: _estado.promociones.map((p) => p.productoId),
        ),
        paginaSugerencias: numero,
        sugerenciasTerminadas: !pagina.hayMas || pagina.productos.isEmpty,
      );

  static int _idPromo(PromocionFeed p) => p.id;
  static int _idPublicacion(Publicacion p) => p.id;
  static int _idSugerido(ProductoSugerido p) => p.id;

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
