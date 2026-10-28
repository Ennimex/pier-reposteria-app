// lib/ui/notifications/view_model/notifications_view_model.dart
//
// Estado de «Notificaciones» (MVVM, Fase 5): al abrir se ponen al día (con
// error y reintento si no hay nada que mostrar), se agrupan en Hoy, Ayer y
// Anteriores con su «hace cuánto», y se marcan como leídas una o todas. La
// lista vive en NotificationProvider, que comparten la campana de inicio y
// su sondeo; este ViewModel lo observa y devuelve a la vista el motivo de
// cada rechazo del backend. Para el personal (#136) además encuentra la
// comanda de la que habla cada aviso.
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository.dart';
import 'package:pier_reposteria/domain/models/comanda.dart';
import 'package:pier_reposteria/domain/models/notificacion.dart';
import 'package:pier_reposteria/ui/core/state/notification_provider.dart';
import 'package:pier_reposteria/utils/formatters.dart';

/// Un bloque de la lista: «Hoy», «Ayer» o «Anteriores».
typedef GrupoNotificaciones = ({
  String titulo,
  List<Notificacion> notificaciones,
});

class NotificationsViewModel extends ChangeNotifier {
  /// [comandas] solo para el personal (abre la comanda de cada aviso);
  /// [ahora] solo se pasa en pruebas (reloj fijo).
  NotificationsViewModel({
    required NotificationProvider notificaciones,
    ComandasRepository? comandas,
    DateTime Function()? ahora,
  })  : _notificaciones = notificaciones,
        _comandas = comandas,
        _ahora = ahora ?? DateTime.now {
    _notificaciones.addListener(_avisar);
  }

  final NotificationProvider _notificaciones;
  final ComandasRepository? _comandas;
  final DateTime Function() _ahora;
  bool _cerrado = false;
  bool _cargando = false;
  String? _errorCarga;

  List<Notificacion> get notificaciones => _notificaciones.notificaciones;
  int get noLeidas => _notificaciones.noLeidas;

  /// Solo cuando no hay nada que mostrar: si ya había notificaciones se
  /// quedan en pantalla mientras se ponen al día.
  bool get cargando => _cargando && notificaciones.isEmpty;

  /// Por qué no se pudieron cargar; solo cuando no hay nada que mostrar.
  String? get errorCarga => notificaciones.isEmpty ? _errorCarga : null;

  /// Pone al día la lista al abrir la pantalla (y al reintentar).
  Future<void> cargar() async {
    _cargando = true;
    _errorCarga = null;
    notifyListeners();
    final error = await refrescar();
    if (_cerrado) return;
    _errorCarga = error;
    _cargando = false;
    notifyListeners();
  }

  /// Pull-to-refresh: devuelve el motivo si el backend no respondió.
  Future<String?> refrescar() async {
    try {
      await _notificaciones.cargar();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> marcarLeida(Notificacion notificacion) =>
      _notificaciones.marcarLeida(notificacion.id);

  Future<String?> marcarTodas() => _notificaciones.marcarTodasLeidas();

  /// true si la sesión es del personal: sus avisos son de comandas.
  bool get esPersonal => _comandas != null;

  /// true si tocar [notificacion] lleva a una comanda (o a la agenda).
  bool abreComanda(Notificacion notificacion) =>
      esPersonal && notificacion.esDeComanda;

  /// El id de la comanda de la que habla [notificacion], buscada por el
  /// folio del título: primero entre las activas y luego en el historial
  /// (una cancelada, primero entre las canceladas). null si el título no
  /// trae folio, no se encontró o el backend no respondió: la vista abre
  /// entonces la agenda.
  Future<int?> comandaDe(Notificacion notificacion) async {
    final repo = _comandas;
    final folio = notificacion.folioComanda;
    if (repo == null || folio == null) return null;
    final cancelada =
        notificacion.titulo.toLowerCase().contains('cancelada');
    final vistas = cancelada
        ? const [VistaAgenda.canceladas, VistaAgenda.activas]
        : const [VistaAgenda.activas, VistaAgenda.entregadas];
    try {
      for (final vista in vistas) {
        final agenda = await repo.agenda(vista: vista, busqueda: '$folio');
        for (final c in agenda.comandas) {
          if (c.folio == folio) return c.id;
        }
      }
    } on ApiException {
      // La agenda dirá qué pasa (y cierra la sesión si ya no es válida).
    }
    return null;
  }

  /// Las notificaciones por día de calendario, sin grupos vacíos. Sin fecha
  /// van a «Anteriores».
  List<GrupoNotificaciones> get grupos {
    final ahora = _ahora();
    final porGrupo = <String, List<Notificacion>>{
      'Hoy': [],
      'Ayer': [],
      'Anteriores': [],
    };
    for (final n in notificaciones) {
      final fecha = n.creadaEn;
      final dias = fecha == null ? 2 : _diasAtras(fecha, ahora);
      porGrupo[dias <= 0 ? 'Hoy' : (dias == 1 ? 'Ayer' : 'Anteriores')]!
          .add(n);
    }
    return [
      for (final MapEntry(:key, :value) in porGrupo.entries)
        if (value.isNotEmpty) (titulo: key, notificaciones: value),
    ];
  }

  /// «Ahora», «Hace 5 min», «Hace 2 horas», «Ayer, 6:30 PM» o «8 Oct 2026».
  String cuando(Notificacion notificacion) {
    final fecha = notificacion.creadaEn;
    if (fecha == null) return '';
    final ahora = _ahora();
    final pasado = ahora.difference(fecha);
    if (pasado.inMinutes < 1) return 'Ahora';
    if (pasado.inMinutes < 60) return 'Hace ${pasado.inMinutes} min';
    if (pasado.inHours < 24) {
      return 'Hace ${pasado.inHours} ${pasado.inHours == 1 ? 'hora' : 'horas'}';
    }
    if (_diasAtras(fecha, ahora) == 1) return 'Ayer, ${_hora12(fecha)}';
    return fechaCorta(fecha);
  }

  /// Días de calendario entre [fecha] y [ahora] (0 = hoy). En UTC para que
  /// el cambio de horario no mueva la cuenta.
  static int _diasAtras(DateTime fecha, DateTime ahora) =>
      DateTime.utc(ahora.year, ahora.month, ahora.day)
          .difference(DateTime.utc(fecha.year, fecha.month, fecha.day))
          .inDays;

  /// «6:30 PM».
  static String _hora12(DateTime fecha) {
    final hora = fecha.hour % 12 == 0 ? 12 : fecha.hour % 12;
    final minutos = fecha.minute.toString().padLeft(2, '0');
    return '$hora:$minutos ${fecha.hour < 12 ? 'AM' : 'PM'}';
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _notificaciones.removeListener(_avisar);
    super.dispose();
  }
}
