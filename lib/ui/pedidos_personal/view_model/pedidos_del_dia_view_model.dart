// lib/ui/pedidos_personal/view_model/pedidos_del_dia_view_model.dart
//
// Estado de «Pedidos del día» (#137): los pedidos abiertos de la sucursal
// agrupados por lo que falta hacer (como GestionPedidos.tsx de la web), por
// defecto solo los de hoy y los vencidos (en la hora de México), y las
// acciones de cada estado: aprobar o rechazar, marcar listo, entregar al
// cliente, asignar repartidor, avisar una demora, volver a enviar y
// cancelar. Después de cada acción la lista se pone al día. Lo crea
// PedidosDelDiaScreen.
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/gestion_pedidos_repository.dart';
import 'package:pier_reposteria/domain/models/pedido_del_dia.dart';

/// Lo que el personal puede hacer con un pedido (textos de la web).
enum AccionPedido {
  aprobar('Aprobar'),
  rechazar('Rechazar'),
  marcarListo('Marcar listo'),
  entregar('Entregar al cliente'),
  asignar('Asignar repartidor'),
  avisarDemora('Avisar demora'),
  volverAEnviar('Volver a enviar'),
  cancelar('Cancelar pedido');

  const AccionPedido(this.etiqueta);

  final String etiqueta;
}

/// Resultado de una acción: el mensaje del backend y si salió bien.
typedef ResultadoAccion = ({String mensaje, bool ok});

class PedidosDelDiaViewModel extends ChangeNotifier {
  /// [ahora] solo se pasa en pruebas (reloj fijo).
  PedidosDelDiaViewModel({
    required GestionPedidosRepository repo,
    DateTime Function()? ahora,
  })  : _repo = repo,
        _ahora = ahora ?? DateTime.now;

  final GestionPedidosRepository _repo;
  final DateTime Function() _ahora;
  bool _cerrado = false;

  List<PedidoDelDia> _pedidos = const [];
  bool _cargando = false;
  String? _error;
  bool _soloHoy = true;
  final Set<String> _ocupados = {};

  bool get cargando => _cargando && _pedidos.isEmpty;

  /// Por qué no se cargaron; solo si no hay nada que mostrar.
  String? get error => _pedidos.isEmpty ? _error : null;

  /// Solo los de hoy y los vencidos (por defecto) o todos los abiertos.
  bool get soloHoy => _soloHoy;

  /// true mientras corre una acción sobre [pedido].
  bool ocupado(PedidoDelDia pedido) => _ocupados.contains(pedido.id);

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    final error = await refrescar();
    if (_cerrado) return;
    _error = error;
    _cargando = false;
    notifyListeners();
  }

  /// Pone al día la lista; devuelve el motivo si el backend no respondió.
  Future<String?> refrescar() async {
    try {
      final pedidos = await _repo.abiertos();
      if (_cerrado) return null;
      _pedidos = pedidos;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void verSoloHoy({required bool valor}) {
    _soloHoy = valor;
    notifyListeners();
  }

  // ── Fechas (hora de México) ───────────────────────────────────────

  DateTime get _hoy {
    final m = horaDeMexico(_ahora());
    return DateTime.utc(m.year, m.month, m.day);
  }

  /// Hoy, vencido o sin hora: entra en la vista de hoy.
  bool esDeHoy(PedidoDelDia pedido) {
    final dia = pedido.diaComprometido;
    return dia == null || !dia.isAfter(_hoy);
  }

  bool vencido(PedidoDelDia pedido) {
    final c = pedido.compromiso;
    return c != null && c.isBefore(_ahora().toUtc());
  }

  /// «Hoy 14:30», «Vencido · 11 Oct 14:30» o «14 Oct 14:30»; null sin hora.
  String? cuando(PedidoDelDia pedido) {
    final c = pedido.compromiso;
    if (c == null) return null;
    final m = horaDeMexico(c);
    final hora = '${m.hour.toString().padLeft(2, '0')}:'
        '${m.minute.toString().padLeft(2, '0')}';
    final fecha = '${m.day} ${_meses[m.month - 1]} $hora';
    if (vencido(pedido)) {
      return pedido.diaComprometido == _hoy
          ? 'Vencido · hoy $hora'
          : 'Vencido · $fecha';
    }
    return pedido.diaComprometido == _hoy ? 'Hoy $hora' : fecha;
  }

  static const _meses = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  // ── Lista ─────────────────────────────────────────────────────────

  List<PedidoDelDia> get _visibles =>
      _soloHoy ? _pedidos.where(esDeHoy).toList() : _pedidos;

  /// Las secciones con pedidos, en orden; dentro, del compromiso más
  /// próximo al más lejano (como los manda el backend).
  List<(GrupoPedido, List<PedidoDelDia>)> get grupos {
    final visibles = _visibles;
    return [
      for (final g in GrupoPedido.values)
        if (visibles.where((p) => p.grupo == g).toList() case final lista
            when lista.isNotEmpty)
          (g, lista),
    ];
  }

  /// Pedidos abiertos de días siguientes que la vista de hoy no muestra.
  int get deOtrosDias => _soloHoy ? _pedidos.length - _visibles.length : 0;

  /// Las acciones de [pedido] según su estado, como la web.
  List<AccionPedido> acciones(PedidoDelDia pedido) {
    if (pedido.porConfirmar) {
      return const [AccionPedido.aprobar, AccionPedido.rechazar];
    }
    return [
      ...switch (pedido.estado) {
        'pendiente' || 'en_preparacion' => const [AccionPedido.marcarListo],
        'listo' when !pedido.esDomicilio => const [AccionPedido.entregar],
        'listo' when pedido.entregaId == null => const [
            AccionPedido.asignar,
            AccionPedido.avisarDemora,
          ],
        'entrega_fallida' => const [AccionPedido.volverAEnviar],
        _ => const <AccionPedido>[],
      },
      AccionPedido.cancelar,
    ];
  }

  // ── Acciones ──────────────────────────────────────────────────────

  Future<ResultadoAccion> marcarListo(PedidoDelDia p) =>
      _accion(p, () => _repo.cambiarEstado(p.id, 'listo'));

  Future<ResultadoAccion> entregar(PedidoDelDia p) =>
      _accion(p, () => _repo.cambiarEstado(p.id, 'completado'));

  Future<ResultadoAccion> volverAEnviar(PedidoDelDia p) =>
      _accion(p, () => _repo.cambiarEstado(p.id, 'listo'));

  Future<ResultadoAccion> cancelar(PedidoDelDia p, String motivo) => _accion(
      p, () => _repo.cambiarEstado(p.id, 'cancelado', nota: motivo.trim()));

  Future<ResultadoAccion> aprobar(PedidoDelDia p) =>
      _accion(p, () => _repo.aprobar(p.id));

  Future<ResultadoAccion> rechazar(PedidoDelDia p, String motivo) =>
      _accion(p, () => _repo.rechazar(p.id, motivo: motivo.trim()));

  Future<ResultadoAccion> asignar(PedidoDelDia p, int repartidorId) =>
      _accion(p, () => _repo.asignar(p.id, repartidorId));

  /// No cambia el pedido: no hace falta recargar.
  Future<ResultadoAccion> avisarDemora(PedidoDelDia p) =>
      _accion(p, () => _repo.avisarDemora(p.id), recargar: false);

  /// Los repartidores para elegir; lanza ApiException si no cargan.
  Future<List<RepartidorDisponible>> repartidores() => _repo.repartidores();

  /// El motivo de cancelar o rechazar (5 a 300 caracteres, como la web);
  /// null si está bien.
  static String? validarMotivo(String motivo) {
    final t = motivo.trim();
    if (t.length < 5) return 'Escribe el motivo (mínimo 5 caracteres).';
    if (t.length > 300) return 'Máximo 300 caracteres (llevas ${t.length}).';
    return null;
  }

  Future<ResultadoAccion> _accion(
    PedidoDelDia pedido,
    Future<String> Function() llamada, {
    bool recargar = true,
  }) async {
    if (_ocupados.contains(pedido.id)) {
      return (mensaje: 'Espera a que termine la acción anterior', ok: false);
    }
    _ocupados.add(pedido.id);
    notifyListeners();
    ResultadoAccion resultado;
    try {
      resultado = (mensaje: await llamada(), ok: true);
    } on ApiException catch (e) {
      resultado = (mensaje: e.message, ok: false);
    }
    _ocupados.remove(pedido.id);
    if (_cerrado) return resultado;
    notifyListeners();
    // También tras un error: otra persona pudo cambiar el pedido.
    if (recargar || !resultado.ok) await refrescar();
    return resultado;
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
