// lib/ui/checkout/view_model/checkout_view_model.dart
//
// Estado del checkout (MVVM, Fase 4): modalidad de entrega, direcciones del
// cliente, fecha y hora, dirección de la sucursal y el pago. El pago es un
// Command (guía oficial): valida, crea el intent en el backend (que calcula
// el total con envío), avisa si el pedido queda "por confirmar", cobra con la
// pasarela y confirma el pedido con reintentos.
//
// Si el cobro YA ocurrió y la confirmación falla, el siguiente "Pagar" solo
// reintenta la confirmación: nunca se vuelve a cobrar. Las respuestas que no
// cambian al reintentar (cobro devuelto o cobro sin pedido, #171) cortan los
// reintentos y muestran el mensaje del backend.
//
// Cada intento (ya validado) se mide en Sentry con su resultado (#24): solo
// las fallas del servidor o de la conexión cuentan contra el objetivo de
// errores del pago (docs/SLO.md).
//
// El horario de atención sale de la configuración de contacto (#320): el
// calendario solo ofrece días en que se abre, la lista de horas solo las que
// caben en ese horario y, fuera de él, el aviso dice cuándo se prepara el
// pedido. Se puede pagar igual (#188).
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/config/monitoreo.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';
import 'package:pier_reposteria/data/repositories/direcciones_repository.dart';
import 'package:pier_reposteria/data/repositories/pagos_repository.dart';
import 'package:pier_reposteria/data/services/pasarela_pago.dart';
import 'package:pier_reposteria/domain/models/direccion_model.dart';
import 'package:pier_reposteria/domain/models/horario_atencion.dart';
import 'package:pier_reposteria/domain/models/pago.dart';
import 'package:pier_reposteria/utils/command.dart';
import 'package:pier_reposteria/utils/config_format.dart';
import 'package:pier_reposteria/utils/formatters.dart';

enum TipoEntrega { pickup, domicilio }

/// Cómo terminó un intento de pago.
sealed class ResultadoPago {
  const ResultadoPago();
}

/// El pedido quedó registrado.
class PagoExitoso extends ResultadoPago {
  const PagoExitoso({required this.pedido, required this.total});

  final PedidoConfirmado pedido;

  /// Total cobrado (el del backend, con envío).
  final double total;
}

/// Por qué se interrumpió un pago.
enum MotivoInterrupcion {
  /// Faltaba elegir algo (horario, dirección, fecha): no se intentó pagar.
  incompleto,

  /// El cliente canceló la hoja de pago o el aviso de «por confirmar».
  cancelado,

  /// El banco rechazó la tarjeta.
  rechazado,

  /// Falló el servidor o la conexión: cuenta contra el objetivo de errores.
  error,
}

/// No se pagó o no se registró el pedido. [aviso] es lo que hay que decirle
/// al cliente; null cuando él mismo canceló.
class PagoInterrumpido extends ResultadoPago {
  const PagoInterrumpido(this.motivo, [this.aviso]);

  final MotivoInterrupcion motivo;
  final String? aviso;
}

class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel({
    required ConfiguracionRepository configRepo,
    required DireccionesRepository direccionesRepo,
    required PagosRepository pagosRepo,
    required PasarelaPago pasarela,
    required double Function() totalCarrito,
    required Future<bool> Function(List<String> faltantes) confirmarPorConfirmar,
    bool Function()? estaAbierto,
    DateTime Function() ahora = DateTime.now,
    Future<void> Function(Duration) esperar = Future<void>.delayed,
    MonitorDePagos monitor = const MonitorDePagosSentry(),
  })  : _configRepo = configRepo,
        _direccionesRepo = direccionesRepo,
        _pagosRepo = pagosRepo,
        _pasarela = pasarela,
        _totalCarrito = totalCarrito,
        _confirmarPorConfirmar = confirmarPorConfirmar,
        _estaAbierto = estaAbierto,
        _ahora = ahora,
        _esperar = esperar,
        _monitor = monitor {
    pagar = Command0<ResultadoPago>(_pagar);
  }

  /// Lunes a sábado de 9 a 21 (BusinessInfo): cuando la configuración no
  /// trae un horario que se entienda (#320).
  static final HorarioAtencion horarioDeRespaldo = HorarioAtencion.semanal(
    dias: BusinessInfo.diasAbiertos,
    abre: BusinessInfo.horaApertura,
    cierra: BusinessInfo.horaCierre,
  );

  static const List<String> _nombresDeDia = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];

  /// Horarios de recolección/entrega entre semana. Solo se ofrecen los que
  /// caben en el horario de atención del día (#320).
  static const List<String> horariosEntreSemana = [
    '09:00 - 10:00', '10:00 - 11:00', '11:00 - 12:00',
    '12:00 - 13:00', '13:00 - 14:00', '14:00 - 15:00',
    '15:00 - 16:00', '16:00 - 17:00', '17:00 - 18:00', '18:00 - 19:00',
  ];

  /// Horarios de sábado y domingo.
  static const List<String> horariosFinDeSemana = [
    '09:00 - 10:00', '10:00 - 11:00', '11:00 - 12:00',
    '12:00 - 13:00', '13:00 - 14:00', '14:00 - 15:00',
  ];

  /// Intentos de confirmar el pedido tras el cobro.
  static const int intentosConfirmacion = 3;

  final ConfiguracionRepository _configRepo;
  final DireccionesRepository _direccionesRepo;
  final PagosRepository _pagosRepo;
  final PasarelaPago _pasarela;
  final double Function() _totalCarrito;
  final Future<bool> Function(List<String>) _confirmarPorConfirmar;
  // Solo en pruebas: decide si está abierto sin mirar el horario ni el reloj.
  final bool Function()? _estaAbierto;
  final DateTime Function() _ahora;
  final Future<void> Function(Duration) _esperar;
  final MonitorDePagos _monitor;
  bool _cerrado = false;

  /// Pagar el pedido.
  late final Command0<ResultadoPago> pagar;

  TipoEntrega _tipoEntrega = TipoEntrega.pickup;
  DateTime? _fecha;
  String? _hora;
  List<DireccionCliente> _direcciones = const [];
  DireccionCliente? _direccion;
  bool _cargandoDirecciones = false;
  String _direccionSucursal = BusinessInfo.direccion;
  HorarioAtencion _horarioAtencion = horarioDeRespaldo;
  String? _errorPago;

  // Cobro hecho cuya confirmación falló: se reintenta solo la confirmación.
  String? _intentPendiente;
  double? _totalPendiente;

  TipoEntrega get tipoEntrega => _tipoEntrega;
  bool get esDomicilio => _tipoEntrega == TipoEntrega.domicilio;
  DateTime? get fecha => _fecha;
  String? get hora => _hora;
  List<DireccionCliente> get direcciones => _direcciones;
  DireccionCliente? get direccion => _direccion;
  bool get cargandoDirecciones => _cargandoDirecciones;
  String get direccionSucursal => _direccionSucursal;

  /// El de la configuración o, mientras no llega o si no se entiende, el de
  /// respaldo.
  HorarioAtencion get horarioAtencion => _horarioAtencion;

  /// Ahora mismo (el reloj del teléfono; en pruebas, uno fijo).
  DateTime get ahora => _ahora();

  /// Aviso de error del último pago (se muestra bajo el método de pago).
  String? get errorPago => _errorPago;

  /// ¿La tienda está abierta ahora, según su horario de atención? Solo
  /// decide si se muestra el aviso: el pedido siempre es para otro día, así
  /// que se paga igual (#188).
  bool get abierto =>
      _estaAbierto?.call() ?? _horarioAtencion.abiertoEn(_ahora());

  /// Horarios del día elegido que caben en el horario de atención (sin día:
  /// los de entre semana).
  List<String> get horarios {
    final fecha = _fecha;
    return fecha == null ? horariosEntreSemana : horariosDel(fecha);
  }

  /// Horarios para recoger o entregar el día de [dia].
  List<String> horariosDel(DateTime dia) {
    final finDeSemana =
        dia.weekday == DateTime.saturday || dia.weekday == DateTime.sunday;
    return _horarioAtencion.franjasDel(
        dia, finDeSemana ? horariosFinDeSemana : horariosEntreSemana);
  }

  /// ¿Se puede recoger o entregar el día de [dia]? (el calendario solo deja
  /// elegir estos).
  bool diaDisponible(DateTime dia) => horariosDel(dia).isNotEmpty;

  /// El primer día disponible de [desde] a [hasta] (null si ninguno).
  DateTime? primerDiaDisponible(DateTime desde, {required DateTime hasta}) {
    for (var dia = DateTime(desde.year, desde.month, desde.day);
        !dia.isAfter(hasta);
        dia = DateTime(dia.year, dia.month, dia.day + 1)) {
      if (diaDisponible(dia)) return dia;
    }
    return null;
  }

  /// Cuándo vuelve a abrir, para el aviso de fuera de horario: «hoy a partir
  /// de las 9:00», «mañana …» o «el lunes …». null si no abre ningún día.
  String? get siguienteAtencion {
    final ahora = _ahora();
    final abre = _horarioAtencion.siguienteApertura(ahora);
    if (abre == null) return null;
    final dias = DateTime(abre.year, abre.month, abre.day)
        .difference(DateTime(ahora.year, ahora.month, ahora.day))
        .inDays;
    final cuando = switch (dias) {
      0 => 'hoy',
      1 => 'mañana',
      _ => 'el ${_nombresDeDia[abre.weekday - 1]}',
    };
    final minutos = abre.minute.toString().padLeft(2, '0');
    return '$cuando a partir de las ${abre.hour}:$minutos';
  }

  /// Envío de la dirección elegida (solo a domicilio y con cobertura).
  double get costoEnvio =>
      esDomicilio ? (_direccion?.tarifa ?? 0) : 0;

  double get totalConEnvio => _totalCarrito() + costoEnvio;

  // ── Carga ────────────────────────────────────────────────────────────────

  Future<void> cargar() =>
      Future.wait([_cargarSucursal(), cargarDirecciones()]);

  /// Dirección y horario de atención de la configuración de contacto.
  Future<void> _cargarSucursal() async {
    try {
      final config = await _configRepo.configDe('contacto');
      if (_cerrado) return;
      // El backend guarda la dirección como JSON: se formatea para no
      // mostrar el objeto crudo.
      final dir = formatearDireccion(config['direccion'],
          fallback: BusinessInfo.direccion);
      if (dir.isNotEmpty) _direccionSucursal = dir;
      // Sin un horario que se entienda se queda el de respaldo (#320).
      _horarioAtencion =
          HorarioAtencion.desdeConfig(config['horarios']) ?? horarioDeRespaldo;
      // Lo elegido antes de que llegara el horario puede ya no ofrecerse.
      if (_hora != null && !horarios.contains(_hora)) _hora = null;
      notifyListeners();
    } on ApiException {
      // Se quedan la dirección y el horario de BusinessInfo.
    }
  }

  /// Direcciones del cliente; si no hay una elegida, preselecciona la
  /// primera con cobertura.
  Future<void> cargarDirecciones() async {
    _cargandoDirecciones = true;
    notifyListeners();
    try {
      final lista = await _direccionesRepo.listarDirecciones();
      if (_cerrado) return;
      _direcciones = lista;
      _direccion ??= lista.where((d) => d.tieneCobertura).firstOrNull;
    } on ApiException {
      // Se quedan las anteriores.
    }
    if (_cerrado) return;
    _cargandoDirecciones = false;
    notifyListeners();
  }

  // ── Elecciones del cliente ───────────────────────────────────────────────

  void elegirEntrega(TipoEntrega tipo) {
    _tipoEntrega = tipo;
    notifyListeners();
  }

  /// Si la hora elegida no se ofrece el día nuevo (fin de semana o fuera del
  /// horario de atención), se borra la hora.
  void elegirFecha(DateTime fecha) {
    _fecha = fecha;
    if (_hora != null && !horarios.contains(_hora)) _hora = null;
    notifyListeners();
  }

  void elegirHora(String? hora) {
    _hora = hora;
    notifyListeners();
  }

  void elegirDireccion(DireccionCliente direccion) {
    _direccion = direccion;
    notifyListeners();
  }

  /// Tras crear o editar una dirección: recarga y la deja elegida.
  Future<void> alGuardarDireccion(DireccionCliente guardada) async {
    await cargarDirecciones();
    if (_cerrado) return;
    _direccion = _direcciones.firstWhere((d) => d.id == guardada.id,
        orElse: () => guardada);
    notifyListeners();
  }

  /// Borra [direccion]; si era la elegida se preselecciona otra con
  /// cobertura. Devuelve el mensaje de error (null = se borró).
  Future<String?> eliminarDireccion(DireccionCliente direccion) async {
    try {
      await _direccionesRepo.eliminarDireccion(direccion.id);
    } on ApiException catch (e) {
      return e.message;
    }
    if (_direccion?.id == direccion.id) _direccion = null;
    await cargarDirecciones();
    return null;
  }

  // ── Pago ─────────────────────────────────────────────────────────────────

  /// Por qué todavía no se puede pagar (null = todo listo).
  String? _validar() {
    if (esDomicilio) {
      final d = _direccion;
      if (d == null) return 'Selecciona una dirección de entrega';
      if (!d.tieneCobertura) {
        return 'Esa colonia no tiene cobertura de envío. Elige otra o recoge en sucursal.';
      }
    }
    final fecha = _fecha;
    if (fecha != null && !diaDisponible(fecha)) {
      return esDomicilio
          ? 'Ese día no hay entregas: elige otra fecha'
          : 'Ese día no abrimos: elige otra fecha';
    }
    if (fecha == null || _hora == null) {
      return esDomicilio
          ? 'Selecciona fecha y hora de entrega'
          : 'Selecciona fecha y hora de recolección';
    }
    return null;
  }

  Future<ResultadoPago> _pagar() async {
    final invalido = _validar();
    if (invalido != null) {
      return PagoInterrumpido(MotivoInterrupcion.incompleto, invalido);
    }
    return _monitor.medir(_intentarPago, _desenlace);
  }

  /// Lo que Sentry anota de cada intento (#24).
  static DesenlacePago _desenlace(ResultadoPago resultado) =>
      switch (resultado) {
        PagoExitoso() => (resultado: 'pagado', fallo: false),
        PagoInterrumpido(:final motivo) => (
          resultado: motivo.name,
          fallo: motivo == MotivoInterrupcion.error,
        ),
      };

  Future<ResultadoPago> _intentarPago() async {
    _errorPago = null;
    notifyListeners();

    // Se manda en crear-intent y en confirmar: con fecha FUTURA el backend
    // acepta productos sin stock hoy (pedido "por confirmar"). Va en UTC,
    // como lo manda la web: sin zona, el backend la guardaba 6 h antes (#216).
    final horario = horarioEnUtc(_fecha!, _hora!.split(' - ').first);

    final String intentId;
    final double total;
    final pendiente = _intentPendiente;
    if (pendiente != null) {
      // Cobro hecho pendiente de confirmar: no se crea otro intent.
      intentId = pendiente;
      total = _totalPendiente ?? totalConEnvio;
    } else {
      final IntentDePago intent;
      try {
        intent = await _pagosRepo.crearIntentDePago(esDomicilio
            ? {'tipo_entrega': 'domicilio', 'direccion_id': _direccion!.id}
            : {'horario_recogida': horario});
      } on ApiException catch (e) {
        return _fallo(e.message);
      }
      total = intent.total ?? totalConEnvio;
      // Productos sin stock hoy para otra fecha: avisar ANTES de cobrar.
      if (intent.porConfirmar &&
          !await _confirmarPorConfirmar(intent.productosPorConfirmar)) {
        return const PagoInterrumpido(MotivoInterrupcion.cancelado);
      }
      try {
        await _pasarela.cobrar(
          clientSecret: intent.clientSecret,
          publishableKey: intent.publishableKey,
        );
      } on PagoCanceladoException {
        return const PagoInterrumpido(MotivoInterrupcion.cancelado);
      } on PagoRechazadoException catch (e) {
        return PagoInterrumpido(MotivoInterrupcion.rechazado, e.message);
      }
      // El cobro YA ocurrió: recordarlo por si la confirmación falla.
      intentId = intent.paymentIntentId;
      _intentPendiente = intentId;
      _totalPendiente = total;
    }
    return _confirmar(intentId, horario, total);
  }

  /// Confirma el pedido hasta [intentosConfirmacion] veces (el backend crea
  /// el pedido y vacía el carrito en la misma transacción: reintentar no
  /// duplica).
  Future<ResultadoPago> _confirmar(
      String intentId, String horario, double total) async {
    final datos = <String, dynamic>{
      'payment_intent_id': intentId,
      'notas': '',
      if (esDomicilio) 'horario_entrega': horario else 'horario_recogida': horario,
    };
    ConfirmacionFallidaException? ultimoError;
    for (var intento = 1; intento <= intentosConfirmacion; intento++) {
      try {
        final pedido = await _pagosRepo.confirmarPago(datos);
        _intentPendiente = null;
        _totalPendiente = null;
        return PagoExitoso(pedido: pedido, total: total);
      } on ConfirmacionFallidaException catch (e) {
        ultimoError = e;
        if (e.esDefinitiva) break;
        if (intento < intentosConfirmacion) {
          await _esperar(Duration(seconds: 2 * intento));
        }
      }
    }
    if (ultimoError!.cobroNoOcurrio) {
      // El pago no se completó: el siguiente intento empieza de cero.
      _intentPendiente = null;
      _totalPendiente = null;
      return _fallo(
          ultimoError.message ?? 'El pago no se completó. Intenta de nuevo.');
    }
    if (ultimoError.cobroSinPedido) {
      // La sucursal lo devuelve a mano. El intent se conserva: otro «Pagar»
      // solo vuelve a preguntar, nunca cobra de nuevo.
      return _fallo(ultimoError.message ??
          'Tu pago se cobró pero no pudimos registrar el pedido. Ya avisamos '
              'a la sucursal para devolvértelo.');
    }
    return _fallo(
        'Tu pago fue procesado, pero no pudimos registrar el pedido '
        '(${ultimoError.message ?? 'sin conexión'}). NO pagues de '
        'nuevo: presiona "Pagar" otra vez y solo reintentaremos el registro.');
  }

  PagoInterrumpido _fallo(String mensaje) {
    _errorPago = mensaje;
    if (!_cerrado) notifyListeners();
    return PagoInterrumpido(MotivoInterrupcion.error, mensaje);
  }

  @override
  void dispose() {
    _cerrado = true;
    pagar.dispose();
    super.dispose();
  }
}
