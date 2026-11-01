// lib/ui/actividad/view_model/bitacora_view_model.dart
//
// Estado de la pestaña «Bitácora» de Actividad del equipo (#139): quién
// cambió qué y cuándo, de 50 en 50 movimientos del más reciente al más
// antiguo, como Bitacora.tsx de la web. Los filtros (entidad, persona y las
// fechas «desde» y «hasta», días completos en la hora de México) se aplican
// en el servidor y vuelven a la primera página; «Cargar más» pide la
// siguiente con antes_de_id. La respuesta de una consulta vieja (con otros
// filtros) se descarta: gana la más reciente. «Hoy» sale de un reloj que
// las pruebas fijan. Lo crea BitacoraTab.
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/actividad_repository.dart';
import 'package:pier_reposteria/domain/models/actividad_equipo.dart';
import 'package:pier_reposteria/ui/actividad/etiquetas_auditoria.dart';
import 'package:pier_reposteria/utils/formatters.dart';

/// Lo que ofrece el calendario de una fecha: el día con que abre y los días
/// que se pueden elegir.
typedef CalendarioFiltro = ({
  DateTime inicial,
  DateTime primero,
  DateTime ultimo,
});

class BitacoraViewModel extends ChangeNotifier {
  /// [ahora] solo se pasa en pruebas (reloj fijo).
  BitacoraViewModel({
    required ActividadRepository repo,
    DateTime Function()? ahora,
  })  : _repo = repo,
        _ahora = ahora ?? DateTime.now;

  /// El primer día que se puede elegir en las fechas (como la web).
  static final DateTime primerDia = DateTime(2000);

  final ActividadRepository _repo;
  final DateTime Function() _ahora;
  bool _cerrado = false;

  String? _entidad;
  int? _usuarioId;
  DateTime? _desde;
  DateTime? _hasta;

  List<MovimientoEquipo> _movimientos = const [];
  bool _hayMas = false;
  int? _siguiente;
  List<String> _entidades = const [];
  List<PersonaBitacora> _personas = const [];
  bool _consultando = false;
  String? _error;
  bool _cargandoMas = false;
  String? _errorMas;

  /// Turno de la consulta más reciente de la primera página: la respuesta
  /// de una anterior ya no corresponde a los filtros y se descarta.
  int _turno = 0;

  // ── Lo que se muestra ─────────────────────────────────────────────

  /// Los filtros elegidos.
  FiltrosBitacora get filtros => FiltrosBitacora(
        entidad: _entidad,
        usuarioId: _usuarioId,
        desde: _desde,
        hasta: _hasta,
      );

  bool get hayFiltros => !filtros.vacios;

  /// Lo cargado, del más reciente al más antiguo.
  List<MovimientoEquipo> get movimientos => _movimientos;

  /// Quedan movimientos más antiguos por pedir.
  bool get hayMas => _hayMas;

  /// Se pide la primera página y no hay nada que mostrar mientras.
  bool get cargando => _consultando && _movimientos.isEmpty;

  /// Se pide la primera página con filtros nuevos; lo anterior sigue a la
  /// vista mientras llega.
  bool get actualizando => _consultando && _movimientos.isNotEmpty;

  /// Por qué no llegó la primera página.
  String? get error => _error;

  bool get cargandoMas => _cargandoMas;

  /// Por qué no llegó la página siguiente (se reintenta con el botón).
  String? get errorMas => _errorMas;

  /// «Mostrando 3 movimientos; hay más antiguos», «Cargando movimientos…»
  /// o «Actualizando…»; null si la primera página no llegó.
  String? get resumen {
    if (cargando) return 'Cargando movimientos…';
    if (actualizando) return 'Actualizando…';
    if (_error != null) return null;
    final n = _movimientos.length;
    final mostrando = 'Mostrando $n ${n == 1 ? 'movimiento' : 'movimientos'}';
    return _hayMas ? '$mostrando; hay más antiguos' : mostrando;
  }

  /// Opciones del filtro «Entidad» con su etiqueta, ordenadas por ella: las
  /// que manda el servidor y la elegida aunque ya no venga.
  Map<String, String> get opcionesEntidad {
    final claves = {..._entidades, ?_entidad}.toList()
      ..sort((a, b) => etiquetaEntidad(a).compareTo(etiquetaEntidad(b)));
    return {for (final clave in claves) clave: etiquetaEntidad(clave)};
  }

  /// Opciones del filtro «Persona» («Ana Ruiz · Gerencia»), con la elegida
  /// aunque ya no venga en la lista del servidor.
  Map<int, String> get opcionesPersona {
    final elegida = _usuarioId;
    return {
      for (final p in _personas) p.id: conRol(p.nombre, p.rol),
      if (elegida != null && !_personas.any((p) => p.id == elegida))
        elegida: 'Persona ID $elegida',
    };
  }

  /// Hoy en la hora de México, sin hora: el último día que se puede elegir.
  DateTime get hoy {
    final mexico = enHoraDeMexico(_ahora());
    return DateTime(mexico.year, mexico.month, mexico.day);
  }

  /// El calendario de «Desde» (con [desde]) o de «Hasta»: no deja elegir un
  /// día después de hoy ni que «Desde» quede después de «Hasta».
  CalendarioFiltro calendario({required bool desde}) {
    final ultimoPosible = hoy;
    final ultimo = desde ? _hasta ?? ultimoPosible : ultimoPosible;
    final minimo = desde ? primerDia : _desde ?? primerDia;
    final primero = minimo.isAfter(ultimo) ? ultimo : minimo;
    final actual = (desde ? _desde : _hasta) ?? ultimo;
    final inicial = actual.isBefore(primero)
        ? primero
        : actual.isAfter(ultimo)
            ? ultimo
            : actual;
    return (inicial: inicial, primero: primero, ultimo: ultimo);
  }

  /// Un día elegido como lo muestra su filtro: «05/10/2026».
  static String textoDia(DateTime dia) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(dia.day)}/${dos(dia.month)}/${dia.year}';
  }

  // ── Filtros ───────────────────────────────────────────────────────

  Future<void> elegirEntidad(String? entidad) async {
    if (entidad == _entidad) return;
    _entidad = entidad;
    await cargar();
  }

  Future<void> elegirPersona(int? usuarioId) async {
    if (usuarioId == _usuarioId) return;
    _usuarioId = usuarioId;
    await cargar();
  }

  /// «Desde» (null la quita). Si queda después de «Hasta», «Hasta» se
  /// recorre a ese día.
  Future<void> elegirDesde(DateTime? dia) async {
    if (dia == _desde) return;
    _desde = dia;
    final hasta = _hasta;
    if (dia != null && hasta != null && dia.isAfter(hasta)) _hasta = dia;
    await cargar();
  }

  /// «Hasta» (null la quita). Si queda antes de «Desde», «Desde» se recorre
  /// a ese día.
  Future<void> elegirHasta(DateTime? dia) async {
    if (dia == _hasta) return;
    _hasta = dia;
    final desde = _desde;
    if (dia != null && desde != null && dia.isBefore(desde)) _desde = dia;
    await cargar();
  }

  /// Vuelve a todos los movimientos.
  Future<void> limpiarFiltros() async {
    if (!hayFiltros) return;
    _entidad = null;
    _usuarioId = null;
    _desde = null;
    _hasta = null;
    await cargar();
  }

  // ── Páginas ───────────────────────────────────────────────────────

  /// La primera página con los filtros elegidos (también «Reintentar»).
  Future<void> cargar() async {
    await _primeraPagina(silenciosa: false);
  }

  /// Pone al día la primera página con los mismos filtros (al jalar hacia
  /// abajo). Si el backend no respondió devuelve el motivo y lo cargado se
  /// queda; si ya se pedía con filtros nuevos, cuenta como esa consulta.
  Future<String?> refrescar() => _primeraPagina(silenciosa: !_consultando);

  /// La página siguiente (antes_de_id); nada si no hay más o si ya se está
  /// pidiendo una.
  Future<void> cargarMas() async {
    final antesDe = _siguiente;
    if (!_hayMas || antesDe == null || _cargandoMas || _consultando) return;
    final turno = _turno;
    _cargandoMas = true;
    _errorMas = null;
    _avisar();
    try {
      final pagina = await _repo.bitacora(filtros, antesDeId: antesDe);
      if (turno != _turno) return;
      final vistos = {for (final m in _movimientos) m.id};
      _movimientos = [
        ..._movimientos,
        ...pagina.movimientos.where((m) => !vistos.contains(m.id)),
      ];
      _hayMas = pagina.hayMas;
      _siguiente = pagina.siguienteAntesDeId;
    } on ApiException catch (e) {
      if (turno != _turno) return;
      _errorMas = e.message;
    }
    _cargandoMas = false;
    _avisar();
  }

  /// Pide la primera página. Si falla, sin [silenciosa] lo anterior se
  /// descarta (ya no corresponde a los filtros) y se muestra el motivo.
  Future<String?> _primeraPagina({required bool silenciosa}) async {
    final turno = ++_turno;
    // Una página siguiente que aún no llega ya no corresponde.
    _cargandoMas = false;
    _errorMas = null;
    if (!silenciosa) {
      _consultando = true;
      _error = null;
      _avisar();
    }
    String? motivo;
    try {
      final pagina = await _repo.bitacora(filtros);
      if (turno != _turno) return null;
      _movimientos = pagina.movimientos;
      _hayMas = pagina.hayMas;
      _siguiente = pagina.siguienteAntesDeId;
      _entidades = pagina.entidades;
      _personas = pagina.personas;
      _error = null;
    } on ApiException catch (e) {
      if (turno != _turno) return null;
      motivo = e.message;
      if (!silenciosa) {
        _movimientos = const [];
        _hayMas = false;
        _siguiente = null;
        _error = motivo;
      }
    }
    _consultando = false;
    _avisar();
    return motivo;
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
