// lib/ui/home/view_model/home_view_model.dart
//
// Estado del inicio (MVVM, Fase 4): categorías, reseñas destacadas,
// promociones por tipo, datos de contacto y sucursales, slides del carrusel
// (los del panel o los de respaldo) y, con sesión, "Pide de nuevo" y el
// pedido activo. El catálogo, la sesión y las notificaciones siguen en sus
// providers globales; la vista avisa cuando cambia la sesión.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/domain/models/category_model.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/domain/models/promociones_inicio.dart';
import 'package:pier_pasteleria/domain/models/slide_hero.dart';
import 'package:pier_pasteleria/utils/logger.dart';

/// "2d 5h", "3h 20m", "45m", "Expirada"; vacío si no hay fecha válida.
String tiempoRestante(String? fechaFin, {DateTime? ahora}) {
  if (fechaFin == null) return '';
  final fin = DateTime.tryParse(fechaFin);
  if (fin == null) return '';
  final diff = fin.difference(ahora ?? DateTime.now());
  if (diff.isNegative) return 'Expirada';
  if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
  if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
  return '${diff.inMinutes}m';
}

/// Slides del carrusel según la configuración (espejo de Inicio.tsx de la
/// web): los activos de Personalización mandan, ordenados por `orden`, con
/// sus textos; la imagen solo si es URL real, si no la del slide de respaldo
/// de la misma posición. Sin slides, el `hero` de la sección Inicio puede
/// cambiar los textos del primero. null = se quedan los de respaldo.
List<SlideHero>? resolverSlides(
  Map<String, dynamic>? personalizacion,
  Map<String, dynamic>? inicio,
) {
  const respaldo = HomeViewModel.slidesDeRespaldo;
  try {
    final decoded = _json(personalizacion?['slides']);
    if (decoded is List) {
      final activos = decoded
          .whereType<Map<dynamic, dynamic>>()
          .where((s) => s['activo'] == true)
          .toList()
        ..sort((a, b) => _orden(a).compareTo(_orden(b)));
      if (activos.isNotEmpty) {
        return [
          for (var i = 0; i < activos.length; i++)
            _slideDelPanel(activos[i], respaldo[i % respaldo.length].imagen),
        ];
      }
    }
  } on Object catch (e) {
    PierLog.error('Slides configurados con formato inválido: $e');
  }
  try {
    final hero = _json(inicio?['hero']);
    final titulo = hero is Map ? hero['titulo']?.toString() ?? '' : '';
    if (titulo.isEmpty) return null;
    final subtitulo = (hero as Map)['subtitulo']?.toString() ?? '';
    return [
      respaldo.first.copyWith(
        titulo: titulo,
        subtitulo: subtitulo.isNotEmpty ? subtitulo : null,
      ),
      ...respaldo.skip(1),
    ];
  } on Object {
    return null; // conservar los de respaldo
  }
}

dynamic _json(dynamic valor) => valor is String ? jsonDecode(valor) : valor;

num _orden(Map<dynamic, dynamic> s) =>
    num.tryParse(s['orden']?.toString() ?? '0') ?? 0;

SlideHero _slideDelPanel(Map<dynamic, dynamic> s, String imagenDeRespaldo) {
  final imagen = s['imagen']?.toString() ?? '';
  final cta = s['cta']?.toString() ?? '';
  return SlideHero(
    titulo: s['titulo']?.toString() ?? '',
    subtitulo: s['subtitulo']?.toString() ?? '',
    cta: cta.isNotEmpty ? cta : 'Ver Productos',
    imagen: imagen.startsWith('http') ? imagen : imagenDeRespaldo,
  );
}

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required ProductosRepository productosRepo,
    required ResenasRepository resenasRepo,
    required ConfiguracionRepository configRepo,
    required PedidosRepository pedidosRepo,
  })  : _productosRepo = productosRepo,
        _resenasRepo = resenasRepo,
        _configRepo = configRepo,
        _pedidosRepo = pedidosRepo;

  /// Slides de la app si el panel no tiene configurados.
  static const List<SlideHero> slidesDeRespaldo = [
    SlideHero(
      etiqueta: 'ARTESANAL',
      titulo: 'Tradición en cada\nRebanada',
      subtitulo: 'Nuevos sabores de temporada disponibles',
      cta: 'Ver Catálogo',
      imagen:
          'https://images.unsplash.com/photo-1464349095431-e9a21285b5f3?w=600&fit=crop',
    ),
    SlideHero(
      etiqueta: 'PERSONALIZADOS',
      titulo: 'Pasteles\nde Autor',
      subtitulo: 'Diseñados para tu momento especial',
      cta: 'Contáctanos',
      ruta: RutaSlide.contacto,
      imagen:
          'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&fit=crop',
    ),
    SlideHero(
      etiqueta: 'PREMIUM',
      titulo: 'Cafetería\nArtesanal',
      subtitulo: 'Bebidas especiales para acompañar',
      cta: 'Descubrir',
      imagen:
          'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&fit=crop',
    ),
  ];

  /// Chips de categoría mientras el backend no manda las suyas.
  static const List<String> categoriasDeRespaldo = [
    'Pasteles',
    'Roscas',
    'Pays',
    'Postres',
    'Cafetería',
  ];

  final ProductosRepository _productosRepo;
  final ResenasRepository _resenasRepo;
  final ConfiguracionRepository _configRepo;
  final PedidosRepository _pedidosRepo;
  bool _cerrado = false;

  List<Categoria> _categorias = const [];
  List<Map<String, dynamic>> _resenasDestacadas = const [];
  PromocionesInicio _promociones = const PromocionesInicio();
  Map<String, dynamic> _contacto = const {};
  List<SlideHero> _slides = slidesDeRespaldo;
  List<Product> _comprados = const [];
  Order? _pedidoActivo;

  /// Nombres de las categorías del backend, o los de respaldo.
  List<String> get nombresCategorias => _categorias.isEmpty
      ? categoriasDeRespaldo
      : _categorias.map((c) => c.nombre).toList();
  List<Map<String, dynamic>> get resenasDestacadas => _resenasDestacadas;
  PromocionesInicio get promociones => _promociones;

  /// Config de la sección contacto (sucursales, horarios, teléfonos).
  Map<String, dynamic> get contacto => _contacto;
  /// Sucursales de la config de contacto (clave 'horarios': lista de
  /// {sucursal, horario, descripcion}). Como la web, solo cuando hay al
  /// menos 2 (se pintan las 2 primeras); si no, lista vacía y el inicio
  /// muestra la tarjeta única de siempre.
  List<Map<String, dynamic>> get sucursales {
    dynamic raw = _contacto['horarios'];
    if (raw is String && raw.trim().startsWith('[')) {
      try {
        raw = jsonDecode(raw);
      } on FormatException {
        return const [];
      }
    }
    if (raw is! List) return const [];
    final lista = raw
        .whereType<Map<dynamic, dynamic>>()
        .where((s) => (s['sucursal']?.toString() ?? '').isNotEmpty)
        .map(Map<String, dynamic>.from)
        .toList();
    return lista.length >= 2 ? lista.take(2).toList() : const [];
  }

  List<SlideHero> get slides => _slides;
  Order? get pedidoActivo => _pedidoActivo;

  /// "Pide de nuevo": lo comprado, con los datos completos del [catalogo]
  /// cuando el producto sigue a la venta.
  List<Product> pideDeNuevo(List<Product> catalogo) => _comprados
      .map((c) => catalogo.firstWhere((p) => p.id == c.id, orElse: () => c))
      .toList();

  bool get hayCompras => _comprados.isNotEmpty;

  // ── Carga ────────────────────────────────────────────────────────────────

  /// Lo público del inicio (no depende de la sesión).
  Future<void> cargar() => Future.wait([
        cargarCategorias(),
        cargarResenasDestacadas(),
        cargarConfiguracion(),
        cargarPromociones(),
      ]);

  Future<void> cargarCategorias() async {
    try {
      final lista = await _productosRepo.listarCategorias();
      if (_cerrado || lista.isEmpty) return;
      PierLog.info('✅ Categorías: ${lista.length}');
      _categorias = lista;
      notifyListeners();
    } on ApiException catch (e) {
      PierLog.error('Error categorías: ${e.message}');
    }
  }

  Future<void> cargarResenasDestacadas() async {
    try {
      final lista = await _resenasRepo.listarDestacadas();
      if (_cerrado || lista.isEmpty) return;
      PierLog.info('✅ Reseñas destacadas: ${lista.length}');
      _resenasDestacadas = lista;
      notifyListeners();
    } on ApiException catch (e) {
      PierLog.error('Error reseñas: ${e.message}');
    }
  }

  Future<void> cargarPromociones() async {
    try {
      final p = await _productosRepo.promocionesDelInicio();
      if (_cerrado) return;
      _promociones = p;
      notifyListeners();
      PierLog.info('✅ Promociones → banner:${p.banner != null ? 1 : 0} '
          'relámpago:${p.relampago.length} '
          'temporada:${p.temporada.length} '
          'destacado:${p.destacado.length}');
    } on ApiException catch (e) {
      PierLog.error('Error promociones: ${e.message}');
    }
  }

  /// El horario vive en la sección 'contacto' (clave 'horarios'); los
  /// slides en 'personalizacion' y el hero de respaldo en 'inicio' (mismas
  /// fuentes que la web). Una sección que falla no tumba a las demás.
  Future<void> cargarConfiguracion() async {
    PierLog.api('GET configuracion/contacto + personalizacion + inicio');
    final secciones = await Future.wait([
      _seccion('contacto'),
      _seccion('personalizacion'),
      _seccion('inicio'),
    ]);
    if (_cerrado) return;
    if (secciones[0] != null) _contacto = secciones[0]!;
    final slides = resolverSlides(secciones[1], secciones[2]);
    if (slides != null) {
      _slides = slides;
      PierLog.info('✅ Slides del hero configurados: ${slides.length}');
    }
    notifyListeners();
    PierLog.info('✅ Configuración cargada');
  }

  Future<Map<String, dynamic>?> _seccion(String nombre) async {
    try {
      return await _configRepo.configDe(nombre);
    } on ApiException {
      return null;
    }
  }

  /// "Pide de nuevo" y el pedido activo (pendiente, en preparación o listo).
  Future<void> cargarDatosUsuario() async {
    PierLog.info('Cargando datos usuario...');
    await Future.wait([_cargarComprados(), _cargarPedidoActivo()]);
  }

  Future<void> _cargarComprados() async {
    try {
      final lista = await _pedidosRepo.listarProductosComprados();
      if (_cerrado) return;
      _comprados = lista;
      notifyListeners();
      PierLog.debug('Productos comprados: ${lista.length}');
    } on ApiException {
      // Se queda lo anterior.
    }
  }

  Future<void> _cargarPedidoActivo() async {
    const activos = {
      OrderStatus.pending,
      OrderStatus.preparing,
      OrderStatus.ready,
    };
    try {
      final pedidos = await _pedidosRepo.listarMisPedidos();
      if (_cerrado) return;
      _pedidoActivo =
          pedidos.where((p) => activos.contains(p.status)).firstOrNull;
      notifyListeners();
      final activo = _pedidoActivo;
      if (activo != null) {
        PierLog.info('Pedido activo: ${activo.numero} — ${activo.status.name}');
      }
    } on ApiException {
      // Se queda lo anterior.
    }
  }

  /// Al cerrar sesión: sin compras ni pedido activo.
  void limpiarDatosUsuario() {
    _comprados = const [];
    _pedidoActivo = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
