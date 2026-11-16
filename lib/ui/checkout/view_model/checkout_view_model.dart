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
// El horario de atención sale de la configuración de contacto (#320): al
// recoger, el de la sucursal que elige el cliente (viene marcada la que está
// abierta); a domicilio, las horas en que abren todas. El calendario solo
// ofrece días en que se abre, las horas son franjas de una hora dentro de
// ese horario y, fuera de él, el aviso dice cuándo se prepara el pedido. Se
// puede pagar igual (#188). Sin red se usa el último contacto que llegó y, si
// nunca llegó, las sucursales de BusinessInfo. La sucursal, quién recoge y
// su teléfono viajan en las notas con el formato de la web.
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
import 'package:pier_reposteria/domain/models/sucursal_atencion.dart';
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
    ({String nombre, String telefono}) Function()? quienRecoge,
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
        _quienRecoge =
            quienRecoge ?? (() => (nombre: '', telefono: '')),
        _estaAbierto = estaAbierto,
        _ahora = ahora,
        _esperar = esperar,
        _monitor = monitor {
    pagar = Command0<ResultadoPago>(_pagar);
  }

  /// Las sucursales de BusinessInfo: cuando el contacto nunca llegó (#320).
  static final List<SucursalAtencion> sucursalesDeRespaldo =
      SucursalAtencion.listaDesdeConfig([
    for (final s in BusinessInfo.sucursales)
      {'sucursal': s.sucursal, 'horario': s.horario},
  ]);

  /// Las horas en que abren las sucursales de BusinessInfo: para una
  /// sucursal cuyo horario no se entiende (#320).
  static final HorarioAtencion horarioDeRespaldo = SucursalAtencion
          .horarioComun(sucursalesDeRespaldo) ??
      HorarioAtencion.semanal(
        dias: BusinessInfo.diasAbiertos,
        abre: BusinessInfo.horaApertura,
        cierra: BusinessInfo.horaCierre,
      );

  static const List<String> _nombresDeDia = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];

  /// Intentos de confirmar el pedido tras el cobro.
  static const int intentosConfirmacion = 3;

  final ConfiguracionRepository _configRepo;
  final DireccionesRepository _direccionesRepo;
  final PagosRepository _pagosRepo;
  final PasarelaPago _pasarela;
  final double Function() _totalCarrito;
  final Future<bool> Function(List<String>) _confirmarPorConfirmar;
  final ({String nombre, String telefono}) Function() _quienRecoge;
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
  List<SucursalAtencion> _sucursales = sucursalesDeRespaldo;
  late SucursalAtencion? _sucursal = _sucursalInicial();
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

  /// Las sucursales de la configuración (o de respaldo) con su horario.
  List<SucursalAtencion> get sucursales => _sucursales;

  /// Donde se recoge (la elegida o, si no se ha elegido, la que estaba
  /// abierta al llegar).
  SucursalAtencion? get sucursal => _sucursal;

  /// Al recoger, el de la sucursal elegida; a domicilio, las horas en que
  /// abren todas. Si no se entiende, el de respaldo.
  HorarioAtencion get horarioAtencion => esDomicilio
      ? SucursalAtencion.horarioComun(_sucursales) ?? horarioDeRespaldo
      : _sucursal?.horario ?? horarioDeRespaldo;

  /// Ahora mismo (el reloj del teléfono; en pruebas, uno fijo).
  DateTime get ahora => _ahora();

  /// Aviso de error del último pago (se muestra bajo el método de pago).
  String? get errorPago => _errorPago;

  /// ¿La tienda está abierta ahora, según su horario de atención? Solo
  /// decide si se muestra el aviso: el pedido siempre es para otro día, así
  /// que se paga igual (#188).
  bool get abierto =>
      _estaAbierto?.call() ?? horarioAtencion.abiertoEn(_ahora());

  /// Horas del día elegido, dentro del horario de atención (sin día, ninguna).
  List<String> get horarios {
    final fecha = _fecha;
    return fecha == null ? const [] : horariosDel(fecha);
  }

  /// Horas para recoger o entregar el día de [dia]: franjas de una hora
  /// dentro del horario de atención.
  List<String> horariosDel(DateTime dia) => horarioAtencion.franjasDelDia(dia);

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
    final abre = horarioAtencion.siguienteApertura(ahora);
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

  /// Dirección y sucursales con su horario, de la configuración de contacto;
  /// sin red, del último contacto que llegó y, si nunca llegó, de
  /// BusinessInfo (#320).
  Future<void> _cargarSucursal() async {
    Map<String, dynamic>? config;
    try {
      config = await _configRepo.configDe('contacto');
    } on ApiException {
      config = await _configRepo.configContactoGuardada();
    }
    if (_cerrado || config == null) return;
    // El backend guarda la dirección como JSON: se formatea para no
    // mostrar el objeto crudo.
    final dir = formatearDireccion(config['direccion'],
        fallback: BusinessInfo.direccion);
    if (dir.isNotEmpty) _direccionSucursal = dir;
    final sucursales = SucursalAtencion.listaDesdeConfig(config['horarios']);
    _sucursales = sucursales.isEmpty ? sucursalesDeRespaldo : sucursales;
    // Se conserva la que ya se eligió si sigue en la lista.
    final elegida = _sucursal?.nombre;
    _sucursal = _sucursales.where((s) => s.nombre == elegida).firstOrNull ??
        _sucursalInicial();
    _quitarHoraQueYaNoSeOfrece();
    notifyListeners();
  }

  /// La primera sucursal abierta ahora; si ninguna, la primera (como la web).
  SucursalAtencion? _sucursalInicial() {
    final ahora = _ahora();
    return _sucursales
            .where((s) => (s.horario ?? horarioDeRespaldo).abiertoEn(ahora))
            .firstOrNull ??
        _sucursales.firstOrNull;
  }

  /// Lo elegido antes de cambiar de sucursal, de modalidad o de que llegara
  /// el horario puede ya no ofrecerse.
  void _quitarHoraQueYaNoSeOfrece() {
    if (_hora != null && !horarios.contains(_hora)) _hora = null;
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
    _quitarHoraQueYaNoSeOfrece();
    notifyListeners();
  }

  /// Donde se recoge: las horas que se ofrecen salen de su horario.
  void elegirSucursal(SucursalAtencion sucursal) {
    _sucursal = sucursal;
    _quitarHoraQueYaNoSeOfrece();
    notifyListeners();
  }

  /// Si la hora elegida no se ofrece el día nuevo (fuera del horario de
  /// atención), se borra la hora.
  void elegirFecha(DateTime fecha) {
    _fecha = fecha;
    _quitarHoraQueYaNoSeOfrece();
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

  /// Las notas de un pedido para recoger, con el formato de la web
  /// (notasPedido.ts), que leen Mis pedidos y el comprobante: «Sucursal:
  /// Sucursal Aviacion · Recoge: Ana López · Tel. 7710000011». Lo que falta
  /// no se escribe.
  String get notasDeRecoger {
    final cliente = _quienRecoge();
    final sucursal = _sucursal?.nombre ?? '';
    final nombre = cliente.nombre.trim();
    final telefono = cliente.telefono.trim();
    return [
      if (sucursal.isNotEmpty) 'Sucursal: $sucursal',
      if (nombre.isNotEmpty) 'Recoge: $nombre',
      if (telefono.isNotEmpty) 'Tel. $telefono',
    ].join(' · ');
  }

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
      'notas': esDomicilio ? '' : notasDeRecoger,
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
