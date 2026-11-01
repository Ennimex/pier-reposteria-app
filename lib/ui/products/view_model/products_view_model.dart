// lib/ui/products/view_model/products_view_model.dart
//
// Estado del catálogo (MVVM, Fase 4): categoría elegida, búsqueda, orden,
// filtros de sabor/tamaño/tipo (globales o propios de la categoría),
// corazones de favoritos (optimistas) y el registro de demanda no atendida
// (búsquedas y "Avísame"). Los productos se piden al servidor de 20 en 20
// con la consulta actual (#37), con el patrón del feed: un turno descarta lo
// que llega de una consulta anterior, una sola petición a la vez, sin
// repetir productos y con los agotados al final cuando ya no hay más. La
// primera página de la consulta por omisión se guarda en el teléfono y se
// muestra al instante la próxima vez, mientras llega la nueva (#265).
//
// La sesión, el carrito y la navegación no se tocan desde aquí: la vista
// decide si manda a iniciar sesión y avisa cuando cambia la sesión.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/demanda_repository.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository.dart';
import 'package:pier_reposteria/data/repositories/productos_repository.dart';
import 'package:pier_reposteria/data/services/catalogo_guardado_service.dart';
import 'package:pier_reposteria/domain/models/category_model.dart';
import 'package:pier_reposteria/domain/models/consulta_catalogo.dart';
import 'package:pier_reposteria/domain/models/filtros_catalogo.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/utils/logger.dart';

// SortOption vive en el dominio (ConsultaCatalogo); se reexporta para quienes
// ya lo importaban desde aquí.
export 'package:pier_reposteria/domain/models/consulta_catalogo.dart' show SortOption;

class ProductsViewModel extends ChangeNotifier {
  ProductsViewModel({
    required ProductosRepository productosRepo,
    required FavoritosRepository favoritosRepo,
    required DemandaRepository demandaRepo,
    CatalogoGuardadoService? catalogoGuardado,
    String categoriaInicial = todas,
    this.esperaBusqueda = const Duration(milliseconds: 400),
    this.esperaRegistroBusqueda = const Duration(milliseconds: 1200),
    double Function(Product producto)? precioFinal,
  })  : _productosRepo = productosRepo,
        _favoritosRepo = favoritosRepo,
        _demandaRepo = demandaRepo,
        _catalogoGuardado = catalogoGuardado,
        _precioFinal = precioFinal ?? _precioBase,
        _categoria = categoriaInicial;

  /// Categoría que muestra todo el catálogo.
  static const String todas = ConsultaCatalogo.todas;

  /// Productos por página, como la web.
  static const int porPagina = 20;

  /// Chips de categoría mientras el backend no manda las suyas.
  static const List<String> categoriasDeRespaldo = [
    todas,
    'Pasteles',
    'Roscas',
    'Pays',
    'Postres',
    'Cafetería',
  ];

  /// Cuánto se espera tras la última tecla para preguntarle al servidor (no
  /// una petición por tecla).
  final Duration esperaBusqueda;

  /// Cuánto se espera tras la última tecla para registrar la búsqueda.
  final Duration esperaRegistroBusqueda;

  final ProductosRepository _productosRepo;
  final FavoritosRepository _favoritosRepo;
  final DemandaRepository _demandaRepo;
  // La copia de la primera página en el teléfono; null = sin copia (pruebas).
  final CatalogoGuardadoService? _catalogoGuardado;
  // El precio que se ve en la tarjeta, con la promoción (lo da la vista con
  // ProductProvider); sin él, el precio base. Con él se ordena por precio
  // (#281).
  final double Function(Product producto) _precioFinal;
  bool _cerrado = false;
  Timer? _esperaDeBusqueda;
  Timer? _registroBusqueda;
  // Término que ya se dejó de teclear y espera a su primera página para
  // registrarse con cuántos resultados dio.
  String? _terminoPorRegistrar;

  String _categoria;
  String _busqueda = '';
  SortOption _orden = SortOption.popular;
  List<Categoria> _categorias = const [];
  FiltrosCatalogo _filtrosGlobales = const FiltrosCatalogo();
  bool _filtrosCargados = false;
  // Opciones de la categoría elegida; vacías = se usa el set global.
  FiltrosCatalogo _opcionesCategoria = const FiltrosCatalogo();
  String? _filtroSabor;
  String? _filtroTamano;
  String? _filtroTipo;
  final Set<String> _favoritos = {};

  // Páginas de la consulta que se ve (la última pedida; con la lista vacía,
  // la que está por llegar). Los agotados esperan aparte hasta que ya no hay
  // más páginas.
  ConsultaCatalogo? _consultaPedida;
  final List<Product> _disponibles = [];
  final List<Product> _agotados = [];
  final Set<String> _ids = {};
  List<Product> _productos = const [];
  // Lo que el servidor mandó completo (órdenes sin páginas del servidor);
  // null = se pide por páginas.
  List<Product>? _todo;
  // Filas ya recibidas (o ya mostradas de _todo): el offset de la siguiente.
  int _offset = 0;
  int _cantidadPrimeraPagina = 0;
  bool _iniciado = false;
  bool _fin = false;
  bool _sinConexion = false;
  bool _cargando = false;
  bool _cargandoMas = false;
  String? _error;
  String? _errorMas;
  int _turno = 0;

  String get categoria => _categoria;
  String get busqueda => _busqueda;
  SortOption get orden => _orden;
  bool get filtrosCargados => _filtrosCargados;
  String? get filtroSabor => _filtroSabor;
  String? get filtroTamano => _filtroTamano;
  String? get filtroTipo => _filtroTipo;

  /// Lo que el cliente pide ver ahora. La búsqueda va recortada: «pay» y
  /// « pay» son la misma consulta.
  ConsultaCatalogo get consulta => ConsultaCatalogo(
        categoria: _categoria,
        busqueda: _busqueda.trim(),
        sabor: _filtroSabor,
        tamano: _filtroTamano,
        tipo: _filtroTipo,
        orden: _orden,
      );

  /// Lo que se ve: los disponibles de las páginas que ya llegaron y, cuando
  /// ya no hay más, los agotados al final (como la web).
  List<Product> get productos => _productos;

  /// Se espera la primera página. Si es de otra consulta, la lista está
  /// vacía mientras tanto; al recargar la misma, se queda lo que se veía.
  bool get cargando => _cargando;

  /// Se espera la siguiente página.
  bool get cargandoMas => _cargandoMas;

  /// Por qué no llegó la primera página (sin nada que mostrar).
  String? get error => _error;

  /// Por qué no llegó la siguiente página (lo que se ve se queda).
  String? get errorMas => _errorMas;

  /// Ya llegó la última página: una que no trae justo [porPagina] (con
  /// menos, vacía o, si el servidor no respetara el límite, con más).
  bool get fin => _fin;

  /// La página 1 no pudo llegar y lo que se ve es la copia guardada en el
  /// teléfono (consulta por omisión) o lo que ya se veía antes de jalar para
  /// refrescar (cualquier consulta, #275): la vista avisa que puede no ser lo
  /// más reciente y ofrece reintentar. Se quita en cuanto el servidor vuelve
  /// a contestar.
  bool get sinConexion => _sinConexion;

  /// 'Todos' y las categorías del backend, o las de respaldo si no hay.
  List<String> get nombresCategorias => _categorias.isEmpty
      ? categoriasDeRespaldo
      : [todas, ..._categorias.map((c) => c.nombre)];

  /// Sabores de la categoría elegida si tiene propios; si no, los globales.
  List<String> get sabores =>
      (_categoria != todas && _opcionesCategoria.sabores.isNotEmpty)
          ? _opcionesCategoria.sabores
          : _filtrosGlobales.sabores;

  List<String> get tamanos => _filtrosGlobales.tamanos;

  /// Tipos de la categoría elegida si tiene propios; si no, los globales.
  List<String> get tipos =>
      (_categoria != todas && _opcionesCategoria.tipos.isNotEmpty)
          ? _opcionesCategoria.tipos
          : _filtrosGlobales.tipos;

  /// ¿Hay algún filtro de sabor, tamaño o tipo puesto?
  bool get hayFiltrosDeOpciones =>
      _filtroSabor != null || _filtroTamano != null || _filtroTipo != null;

  /// ¿Hay algo que "Quitar filtros" pueda limpiar?
  bool get hayFiltros =>
      _busqueda.isNotEmpty || _categoria != todas || hayFiltrosDeOpciones;

  bool esFavorito(String productoId) => _favoritos.contains(productoId);

  // ── Carga ────────────────────────────────────────────────────────────────

  /// Carga la primera página, categorías, filtros y favoritos a la vez.
  Future<void> cargar({required bool autenticado}) => Future.wait([
        cargarProductos(),
        cargarCategorias(),
        cargarFiltros(),
        cargarFavoritos(autenticado: autenticado),
      ]);

  /// Jalar para refrescar y «Reintentar»: la página 1 otra vez, con
  /// categorías y filtros.
  Future<void> recargar() => Future.wait([
        cargarProductos(),
        cargarCategorias(),
        cargarFiltros(),
      ]);

  /// Primera página de la consulta actual. Si la consulta cambió, lo que se
  /// veía se vacía al pedirla (mientras llega, esqueletos); si es la misma
  /// (jalar para refrescar), se queda hasta que llega la nueva. Lo que llegue
  /// de una consulta anterior se descarta. Los órdenes sin páginas del
  /// servidor se piden completos una vez y se muestran de [porPagina] en
  /// [porPagina]; los de precio, por el precio con la promoción (#281).
  ///
  /// La consulta por omisión usa además la copia de su página 1 guardada en el
  /// teléfono (#265): se pone en pantalla en cuanto se lee, sin esperar al
  /// servidor (que al despertar tarda hasta ~20 s), y la página nueva la
  /// reemplaza al llegar. Cada página 1 que llega se guarda. Si la nueva no
  /// llega, se queda lo que se veía (la copia o, al jalar para refrescar
  /// cualquier consulta, lo que ya había llegado, #275) y [sinConexion]
  /// avisa; sin nada que mostrar sale el [error] de siempre.
  Future<void> cargarProductos() async {
    _esperaDeBusqueda?.cancel();
    final turno = ++_turno;
    final pedida = consulta;
    if (pedida != _consultaPedida) _vaciar();
    _consultaPedida = pedida;
    _cargando = true;
    _cargandoMas = false;
    _error = null;
    _errorMas = null;
    _avisar();
    final catalogoGuardado = _catalogoGuardadoDe(pedida);
    // Se lee en paralelo con la petición, que no la espera, y solo si aún no
    // hay nada en pantalla de esta consulta.
    final lecturaCopia = catalogoGuardado != null && !_iniciado
        ? _ponerCopia(catalogoGuardado, turno)
        : null;
    try {
      final respuesta = await _productosRepo.buscarProductos(
        pedida,
        limite: pedida.pideTodo ? null : porPagina,
      );
      if (turno != _turno) return;
      _ponerPrimera(pedida, respuesta);
    } on ApiException catch (e) {
      // Si la copia aún se está leyendo, se espera: de ella depende qué sale.
      if (lecturaCopia != null) await lecturaCopia;
      if (turno != _turno) return;
      PierLog.error('Error al cargar el catálogo: ${e.message}');
      // Ya se ve algo de esta consulta (la copia guardada o, al jalar para
      // refrescar, lo que llegó antes, con cualquier búsqueda, filtro u
      // orden): se queda, con el aviso (#275).
      if (_iniciado) {
        _sinConexion = true;
      } else {
        _vaciar();
        _error = e.message;
      }
    }
    _cargando = false;
    _avisar();
    _registrarBusquedaPendiente();
  }

  /// Pone en pantalla, como si fuera la página 1 (mismas reglas de agotados y
  /// repetidos), la copia guardada. Sobra si ya llegó la del servidor o se
  /// pidió otra consulta mientras se leía.
  Future<void> _ponerCopia(
    CatalogoGuardadoService catalogoGuardado,
    int turno,
  ) async {
    final copia = await catalogoGuardado.leer();
    if (copia == null || turno != _turno || _iniciado) return;
    _agregar(copia);
    _iniciado = true;
    PierLog.info('📦 Catálogo guardado: ${copia.length} en pantalla');
    _avisar();
  }

  /// Pone la página 1 que llegó del servidor en lugar de lo que se veía, en
  /// un solo paso: la lista no pasa por vacía ni salta, y el aviso de
  /// [sinConexion] se quita. Si es de la consulta por omisión, la guarda en
  /// el teléfono sin esperar a que termine (nunca lanza): si el teléfono se
  /// atora, la carga y el «jalar para refrescar» terminan igual (#283).
  void _ponerPrimera(ConsultaCatalogo pedida, List<Product> respuesta) {
    _vaciar();
    final todo = pedida.pideTodo
        ? _ordenarPorPrecioFinal(pedida.orden, respuesta)
        : null;
    _todo = todo;
    final primera = todo == null ? respuesta : _siguientesDe(todo);
    _agregar(primera);
    _cantidadPrimeraPagina = primera.length;
    _iniciado = true;
    PierLog.info('✅ Catálogo: ${primera.length} en la primera página');
    final catalogoGuardado = _catalogoGuardadoDe(pedida);
    if (catalogoGuardado != null) unawaited(catalogoGuardado.guardar(primera));
  }

  /// La siguiente página de lo que se ve: del servidor o, si la consulta se
  /// pidió completa, los siguientes [porPagina] sin red. Se llama al
  /// acercarse al final; no hace nada mientras carga, si ya no hay más o si
  /// la primera página no llegó.
  ///
  /// Con [sinConexion] y solo la primera página en pantalla (la copia
  /// guardada, que puede ser de hace días, o la página 1 de antes de jalar
  /// para refrescar) no se le pega la página 2: se pide otra vez la 1, que
  /// toma su lugar como en [cargarProductos], y las siguientes vienen
  /// después. Con más páginas en pantalla se sigue con la que toca: cambiarlas
  /// por la página 1 movería a la persona de donde iba.
  Future<void> cargarMas() async {
    final pedida = _consultaPedida;
    if (pedida == null || !_iniciado || _cargando || _cargandoMas || _fin) {
      return;
    }
    final todo = _todo;
    if (todo != null) {
      _agregar(_siguientesDe(todo));
      _avisar();
      return;
    }
    final turno = _turno;
    final otraVezLaPrimera = _sinConexion && _offset <= porPagina;
    _cargandoMas = true;
    _errorMas = null;
    _avisar();
    var volvio = false;
    try {
      final pagina = await _productosRepo.buscarProductos(
        pedida,
        limite: porPagina,
        offset: otraVezLaPrimera ? 0 : _offset,
      );
      if (turno != _turno) return;
      volvio = _sinConexion;
      if (otraVezLaPrimera) {
        _ponerPrimera(pedida, pagina);
      } else {
        _agregar(pagina);
        // El servidor volvió a contestar.
        _sinConexion = false;
      }
    } on ApiException catch (e) {
      if (turno != _turno) return;
      PierLog.error('Error al cargar más productos: ${e.message}');
      _errorMas = e.message;
    }
    _cargandoMas = false;
    _avisar();
    if (volvio) await _pedirLoQueFalloSinConexion();
  }

  /// Las promociones cambiaron (llegaron después de la lista o se
  /// recargaron). En los órdenes por precio se vuelve a ordenar con el precio
  /// final solo lo que aún no se muestra: lo que ya se ve se queda donde
  /// está, para no mover a la persona de donde iba, y lo que se revele
  /// después ya sigue las promociones nuevas. La lista completa se acomoda
  /// en la siguiente carga (#281).
  void reordenarPorPromociones() {
    final todo = _todo;
    final pedida = _consultaPedida;
    if (todo == null ||
        pedida == null ||
        !_esPorPrecio(pedida.orden) ||
        _offset >= todo.length) {
      return;
    }
    _todo = [
      ...todo.take(_offset),
      ..._ordenarPorPrecioFinal(pedida.orden, todo.skip(_offset).toList()),
    ];
  }

  /// Al abrir sin internet fallan también las categorías (quedan las de
  /// respaldo) y los filtros. «Reintentar» del pie solo pide productos: cuando
  /// el servidor vuelve a contestar, se piden otra vez los que no llegaron.
  Future<void> _pedirLoQueFalloSinConexion() => Future.wait([
        if (_categorias.isEmpty) cargarCategorias(),
        if (!_filtrosCargados) cargarFiltros(),
      ]);

  Future<void> cargarCategorias() async {
    try {
      final lista = await _productosRepo.listarCategorias();
      if (_cerrado || lista.isEmpty) return;
      PierLog.info('✅ Categorías cargadas: ${lista.length}');
      _categorias = lista;
      notifyListeners();
      // Con los ids ya disponibles, cargar opciones si se entró con una
      // categoría preseleccionada (p. ej. desde el home).
      if (_categoria != todas) await _cargarOpcionesCategoria();
    } on ApiException catch (e) {
      PierLog.error('Error al cargar categorías: ${e.message}');
    }
  }

  Future<void> cargarFiltros() async {
    try {
      final filtros = await _productosRepo.filtrosDelCatalogo();
      if (_cerrado) return;
      _filtrosGlobales = filtros;
      _filtrosCargados = true;
      notifyListeners();
      PierLog.info('✅ Filtros cargados — sabores:${filtros.sabores.length} '
          'tamaños:${filtros.tamanos.length} tipos:${filtros.tipos.length}');
    } on ApiException catch (e) {
      PierLog.error('Error al cargar filtros: ${e.message}');
    }
  }

  /// Corazones del cliente. Sin sesión se limpian (la pestaña vive en el
  /// IndexedStack y conservaría los del usuario anterior).
  Future<void> cargarFavoritos({required bool autenticado}) async {
    if (!autenticado) {
      if (_favoritos.isNotEmpty) {
        _favoritos.clear();
        notifyListeners();
      }
      return;
    }
    try {
      final ids = await _favoritosRepo.listarIds();
      if (_cerrado) return;
      _favoritos
        ..clear()
        ..addAll(ids);
      notifyListeners();
      PierLog.info('✅ Favoritos cargados: ${ids.length}');
    } on ApiException catch (e) {
      PierLog.error('Error al cargar favoritos: ${e.message}');
    }
  }

  /// Sabores/tipos propios de la categoría elegida. Si no tiene (o falla la
  /// llamada) se queda el set global.
  Future<void> _cargarOpcionesCategoria() async {
    final solicitada = _categoria;
    if (solicitada == todas) {
      _opcionesCategoria = const FiltrosCatalogo();
      notifyListeners();
      return;
    }
    final id = _categorias
        .where((c) => c.nombre == solicitada)
        .map((c) => c.id)
        .firstOrNull;
    if (id == null || id.isEmpty) return;
    try {
      final opciones = await _productosRepo.opcionesDeLaCategoria(id);
      // Si el cliente ya cambió de categoría, se descarta esta respuesta.
      if (_cerrado || _categoria != solicitada) return;
      _opcionesCategoria = opciones;
      // Filtros puestos que ya no existen en esta categoría se limpian.
      var limpio = false;
      if (_filtroSabor != null && !sabores.contains(_filtroSabor)) {
        _filtroSabor = null;
        limpio = true;
      }
      if (_filtroTipo != null && !tipos.contains(_filtroTipo)) {
        _filtroTipo = null;
        limpio = true;
      }
      notifyListeners();
      // Si se limpió alguno, la página 1 otra vez sin él. Si no, nada: una
      // búsqueda a medio escribir espera a su última tecla (#283).
      if (limpio) _reiniciarSiCambio();
      PierLog.info('✅ Opciones de "$solicitada" — '
          'sabores:${opciones.sabores.length} tipos:${opciones.tipos.length}');
    } on ApiException {
      // Se queda el set global.
    }
  }

  // ── Acciones del cliente ─────────────────────────────────────────────────
  // Cada cambio de búsqueda, categoría, filtro u orden vuelve a la página 1.

  Future<void> seleccionarCategoria(String nombre) {
    _categoria = nombre;
    notifyListeners();
    _reiniciarSiCambio();
    return _cargarOpcionesCategoria();
  }

  /// Pide la búsqueda [esperaBusqueda] después de la última tecla y registra
  /// el término [esperaRegistroBusqueda] después, con cuántos resultados dio
  /// su primera página, como la web.
  void buscar(String texto) {
    _busqueda = texto;
    notifyListeners();
    _olvidarBusquedaPendiente();
    _esperaDeBusqueda = Timer(esperaBusqueda, _reiniciarSiCambio);
    final termino = texto.trim();
    if (termino.length < 2) return;
    _registroBusqueda = Timer(esperaRegistroBusqueda, () {
      _terminoPorRegistrar = termino;
      _registrarBusquedaPendiente();
    });
  }

  void limpiarBusqueda() {
    _olvidarBusquedaPendiente();
    _busqueda = '';
    notifyListeners();
    _reiniciarSiCambio();
  }

  void ordenarPor(SortOption orden) {
    _orden = orden;
    notifyListeners();
    _reiniciarSiCambio();
  }

  /// Pone el sabor, o lo quita si ya estaba puesto.
  void alternarSabor(String sabor) {
    _filtroSabor = _filtroSabor == sabor ? null : sabor;
    notifyListeners();
    _reiniciarSiCambio();
  }

  void alternarTamano(String tamano) {
    _filtroTamano = _filtroTamano == tamano ? null : tamano;
    notifyListeners();
    _reiniciarSiCambio();
  }

  void alternarTipo(String tipo) {
    _filtroTipo = _filtroTipo == tipo ? null : tipo;
    notifyListeners();
    _reiniciarSiCambio();
  }

  /// "Limpiar" de la hoja de filtros: solo sabor, tamaño y tipo.
  void limpiarFiltrosDeOpciones() {
    _filtroSabor = null;
    _filtroTamano = null;
    _filtroTipo = null;
    notifyListeners();
    _reiniciarSiCambio();
  }

  /// "Quitar filtros": búsqueda, categoría, orden y filtros.
  void limpiarTodo() {
    PierLog.debug('Filtros limpiados');
    _olvidarBusquedaPendiente();
    _busqueda = '';
    _categoria = todas;
    _orden = SortOption.popular;
    _filtroSabor = null;
    _filtroTamano = null;
    _filtroTipo = null;
    _opcionesCategoria = const FiltrosCatalogo();
    notifyListeners();
    _reiniciarSiCambio();
  }

  /// Pone o quita el corazón al instante y lo confirma con el backend; si
  /// falla lo regresa y devuelve el mensaje de error (null = todo bien).
  Future<String?> alternarFavorito(String productoId) async {
    final yaEsFav = _favoritos.contains(productoId);
    _ponerFavorito(productoId, !yaEsFav);
    try {
      if (yaEsFav) {
        await _favoritosRepo.quitarFavorito(productoId);
      } else {
        await _favoritosRepo.agregarFavorito(productoId);
      }
      return null;
    } on ApiException catch (e) {
      PierLog.error(
          'Error al ${yaEsFav ? 'quitar' : 'agregar'} favorito $productoId');
      if (!_cerrado) _ponerFavorito(productoId, yaEsFav);
      return e.message;
    }
  }

  void _ponerFavorito(String productoId, bool favorito) {
    if (favorito) {
      _favoritos.add(productoId);
    } else {
      _favoritos.remove(productoId);
    }
    notifyListeners();
  }

  /// "Avísame": registra el interés en un agotado (no bloquea ni falla).
  void avisarme(Product producto) =>
      _demandaRepo.registrarClicAgotado(producto.id);

  // ── Páginas ──────────────────────────────────────────────────────────────

  /// La copia en el teléfono es solo de la consulta por omisión: con
  /// búsqueda o filtros siempre se le pregunta al servidor (#265).
  CatalogoGuardadoService? _catalogoGuardadoDe(ConsultaCatalogo pedida) =>
      pedida.esPorOmision ? _catalogoGuardado : null;

  /// Vuelve a la página 1 si lo que se pide ya no es lo que se pidió.
  void _reiniciarSiCambio() {
    if (consulta != _consultaPedida) unawaited(cargarProductos());
  }

  /// Suma una página a lo que se ve: sin repetir productos y con los
  /// agotados aparte hasta que ya no hay más.
  void _agregar(List<Product> pagina) {
    _offset += pagina.length;
    for (final p in pagina) {
      if (!_ids.add(p.id)) continue;
      (p.agotado ? _agotados : _disponibles).add(p);
    }
    final todo = _todo;
    // Una página que no trae justo lo pedido es la última: con menos ya no
    // hay más y, si el servidor ignorara el límite y mandara de más, pedir
    // otra traería los mismos sin fin (#272).
    _fin = todo == null ? pagina.length != porPagina : _offset >= todo.length;
    _productos = List.unmodifiable([..._disponibles, if (_fin) ..._agotados]);
  }

  /// Los siguientes [porPagina] de [todo] que aún no se muestran.
  List<Product> _siguientesDe(List<Product> todo) =>
      todo.skip(_offset).take(porPagina).toList();

  static double _precioBase(Product producto) => producto.precio;

  static bool _esPorPrecio(SortOption orden) =>
      orden == SortOption.priceAsc || orden == SortOption.priceDesc;

  /// En los órdenes por precio, [lista] por el precio que se ve en la
  /// tarjeta (con la promoción) y no por el base con el que ordena el
  /// servidor (#281); en los empates se queda el orden del servidor. Los
  /// demás órdenes llegan como el servidor los mandó. Los agotados siguen al
  /// final porque [_agregar] los aparta.
  List<Product> _ordenarPorPrecioFinal(SortOption orden, List<Product> lista) {
    if (!_esPorPrecio(orden)) return lista;
    final signo = orden == SortOption.priceDesc ? -1 : 1;
    // Con su lugar en la lista: el desempate que hace estable el orden.
    final conPrecio = [
      for (final (lugar, producto) in lista.indexed)
        (lugar: lugar, precio: _precioFinal(producto), producto: producto),
    ]..sort((a, b) {
        final porPrecio = signo * a.precio.compareTo(b.precio);
        return porPrecio != 0 ? porPrecio : a.lugar.compareTo(b.lugar);
      });
    return [for (final p in conPrecio) p.producto];
  }

  /// Olvida las páginas de la consulta anterior.
  void _vaciar() {
    _disponibles.clear();
    _agotados.clear();
    _ids.clear();
    _productos = const [];
    _todo = null;
    _offset = 0;
    _iniciado = false;
    _fin = false;
    _sinConexion = false;
  }

  /// Registra el término que se dejó de teclear con cuántos productos trajo
  /// la primera página de su búsqueda, en cuanto esa página llega.
  void _registrarBusquedaPendiente() {
    final termino = _terminoPorRegistrar;
    if (termino == null ||
        _cargando ||
        !_iniciado ||
        _consultaPedida?.busqueda != termino) {
      return;
    }
    _terminoPorRegistrar = null;
    _demandaRepo.registrarBusqueda(termino, _cantidadPrimeraPagina);
  }

  /// Cancela la búsqueda y el registro que esperaban a la última tecla.
  void _olvidarBusquedaPendiente() {
    _esperaDeBusqueda?.cancel();
    _registroBusqueda?.cancel();
    _terminoPorRegistrar = null;
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _olvidarBusquedaPendiente();
    super.dispose();
  }
}
