// lib/ui/comandas/view_model/agenda_comandas_view_model.dart
//
// Estado de la agenda de comandas (#127): la vista elegida, la búsqueda, las
// comandas agrupadas por día y, para hornos y decoración, los pendientes de
// su área. Como en la web (src/comandas/AgendaComandas.tsx), los pendientes
// salen de TODAS las activas, sin importar la vista ni la búsqueda en
// pantalla. Lo crea AgendaComandasScreen.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/comandas_repository.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';
import 'package:pier_pasteleria/ui/comandas/widgets/comandas_formato.dart';

/// Comandas de un mismo día en la agenda.
class GrupoDia {
  const GrupoDia({
    required this.titulo,
    required this.dias,
    required this.comandas,
  });

  /// 'Hoy · lunes 12 de octubre'
  final String titulo;

  /// Días respecto a hoy (negativo: ya pasó).
  final int dias;
  final List<ResumenComanda> comandas;
}

class AgendaComandasViewModel extends ChangeNotifier {
  /// [area] es el área del usuario si es de producción (hornos o
  /// decoración); con ella se calculan sus pendientes.
  AgendaComandasViewModel({
    required ComandasRepository repo,
    this.area,
  }) : _repo = repo;

  final ComandasRepository _repo;
  final AreaProduccion? area;

  VistaAgenda _vista = VistaAgenda.proximas;
  String _busqueda = '';
  AgendaComandas? _agenda;
  List<ResumenComanda>? _activas;
  bool _cargando = false;
  String? _error;
  bool _sesionInvalida = false;
  int _turno = 0;
  bool _cerrado = false;

  VistaAgenda get vista => _vista;
  String get busqueda => _busqueda;
  bool get cargando => _cargando;

  /// Por qué falló la última consulta (se conserva la lista que había).
  String? get error => _error;

  /// El backend rechazó la sesión: la vista debe cerrarla ([error] trae el
  /// mensaje para la persona).
  bool get sesionInvalida => _sesionInvalida;

  /// Ya llegó al menos una respuesta.
  bool get tieneDatos => _agenda != null;
  String get hoy => _agenda?.hoy ?? '';
  int get total => _agenda?.comandas.length ?? 0;

  /// Activas sin la confirmación vigente de mi área, la más urgente primero;
  /// null si no soy de producción o aún no llegan.
  List<ResumenComanda>? get pendientes {
    final a = area;
    final activas = _activas;
    if (a == null || activas == null) return null;
    return activas.where((c) => c.pendientePara(a)).toList()
      ..sort(_porUrgencia);
  }

  /// Activas: por día de entrega (el backend ya las manda en orden).
  /// Entregadas y canceladas: por el día en que se cerraron (más reciente
  /// primero, como llegan).
  List<GrupoDia> get grupos {
    final agenda = _agenda;
    if (agenda == null) return const [];
    final anio = int.tryParse(agenda.hoy.split('-').first);
    final grupos = <String, GrupoDia>{};
    for (final c in agenda.comandas) {
      var fecha = c.fechaEntrega;
      var dias = c.diasRestantes;
      final cierre = _vista == VistaAgenda.entregadas
          ? c.entregadaAt
          : _vista == VistaAgenda.canceladas
              ? c.canceladaAt
              : null;
      final diaCierre = cierre == null ? null : diaDeEvento(cierre);
      if (diaCierre != null) {
        fecha = diaCierre;
        dias = diasEntre(agenda.hoy, diaCierre);
      }
      grupos.putIfAbsent(
        fecha,
        () => GrupoDia(
          titulo: etiquetaDia(fecha, dias, anioActual: anio),
          dias: dias,
          comandas: [],
        ),
      ).comandas.add(c);
    }
    return grupos.values.toList();
  }

  /// Primera carga, con indicador.
  Future<void> cargar() {
    _cargando = true;
    notifyListeners();
    return recargar();
  }

  /// Vuelve a pedir la vista actual y los pendientes (jalar para refrescar,
  /// volver a la app).
  Future<void> recargar() => _consultar(conPendientes: true);

  Future<void> cambiarVista(VistaAgenda vista) async {
    if (vista == _vista && tieneDatos) return;
    _vista = vista;
    _cargando = true;
    notifyListeners();
    await _consultar(conPendientes: true);
  }

  /// Busca por folio (acepta '#5003') o por parte del nombre del cliente.
  Future<void> buscar(String texto) async {
    final limpio = texto.trim().replaceFirst(RegExp(r'^#\s*'), '').trim();
    if (limpio == _busqueda) return;
    _busqueda = limpio;
    await _consultar(conPendientes: false);
  }

  /// Una respuesta vieja (de una vista o búsqueda anterior) no pisa a la
  /// más reciente: cada consulta lleva su turno.
  Future<void> _consultar({required bool conPendientes}) async {
    final turno = ++_turno;
    final vista = _vista;
    final busqueda = _busqueda;
    final listaSirveDeActivas =
        vista == VistaAgenda.activas && busqueda.isEmpty;
    final pedirActivas =
        area != null && conPendientes && !listaSirveDeActivas;
    try {
      final respuestas = await Future.wait([
        _repo.agenda(vista: vista, busqueda: busqueda),
        if (pedirActivas) _repo.agenda(vista: VistaAgenda.activas),
      ]);
      if (turno != _turno) return;
      _agenda = respuestas.first;
      if (listaSirveDeActivas) _activas = respuestas.first.comandas;
      if (pedirActivas) _activas = respuestas.last.comandas;
      _error = null;
    } on SesionInvalidaException catch (e) {
      if (turno != _turno) return;
      _sesionInvalida = true;
      _error = e.message;
    } on ApiException catch (e) {
      if (turno != _turno) return;
      _error = e.message;
    }
    _cargando = false;
    _avisar();
  }

  /// Primero la que vence antes; a igual día, la de hora más temprana.
  static int _porUrgencia(ResumenComanda a, ResumenComanda b) {
    final dias = a.diasRestantes.compareTo(b.diasRestantes);
    if (dias != 0) return dias;
    final hora = a.horaEntrega.compareTo(b.horaEntrega);
    return hora != 0 ? hora : a.folio.compareTo(b.folio);
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
