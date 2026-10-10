// lib/ui/checkout/view_model/checkout_view_model.dart
//
// Estado del checkout (MVVM, Fase 4): modalidad de entrega, direcciones del
// cliente, fecha y hora, dirección de la sucursal y el pago. El pago es un
// Command (guía oficial): valida, crea el intent en el backend (que calcula
// el total con envío), avisa si el pedido queda "por confirmar", cobra con la
// pasarela y confirma el pedido con reintentos.
//
// Si el cobro YA ocurrió y la confirmación falla, el siguiente "Pagar" solo
// reintenta la confirmación: nunca se vuelve a cobrar.
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository.dart';
import 'package:pier_pasteleria/data/services/pasarela_pago.dart';
import 'package:pier_pasteleria/domain/models/direccion_model.dart';
import 'package:pier_pasteleria/domain/models/pago.dart';
import 'package:pier_pasteleria/utils/command.dart';
import 'package:pier_pasteleria/utils/config_format.dart';

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

/// No se pagó o no se registró el pedido. [aviso] es lo que hay que decirle
/// al cliente; null cuando él mismo canceló.
class PagoInterrumpido extends ResultadoPago {
  const PagoInterrumpido([this.aviso]);

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
    bool Function() estaAbierto = _abiertoAhora,
    Future<void> Function(Duration) esperar = Future<void>.delayed,
  })  : _configRepo = configRepo,
        _direccionesRepo = direccionesRepo,
        _pagosRepo = pagosRepo,
        _pasarela = pasarela,
        _totalCarrito = totalCarrito,
        _confirmarPorConfirmar = confirmarPorConfirmar,
        _estaAbierto = estaAbierto,
        _esperar = esperar {
    pagar = Command0<ResultadoPago>(_pagar);
  }

  static bool _abiertoAhora() => BusinessInfo.estaAbierto();

  /// Horarios de recolección/entrega entre semana.
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
  final bool Function() _estaAbierto;
  final Future<void> Function(Duration) _esperar;
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

  /// Aviso de error del último pago (se muestra bajo el método de pago).
  String? get errorPago => _errorPago;

  /// ¿Se aceptan pedidos ahora? (fuera de horario no).
  bool get abierto => _estaAbierto();

  /// Horarios del día elegido (sin día: los de entre semana).
  List<String> get horarios {
    final dia = _fecha?.weekday;
    return (dia == DateTime.saturday || dia == DateTime.sunday)
        ? horariosFinDeSemana
        : horariosEntreSemana;
  }

  /// Envío de la dirección elegida (solo a domicilio y con cobertura).
  double get costoEnvio =>
      esDomicilio ? (_direccion?.tarifa ?? 0) : 0;

  double get totalConEnvio => _totalCarrito() + costoEnvio;

  // ── Carga ────────────────────────────────────────────────────────────────

  Future<void> cargar() =>
      Future.wait([_cargarDireccionSucursal(), cargarDirecciones()]);

  Future<void> _cargarDireccionSucursal() async {
    try {
      final config = await _configRepo.configDe('contacto');
      if (_cerrado) return;
      // El backend guarda la dirección como JSON: se formatea para no
      // mostrar el objeto crudo.
      final dir = formatearDireccion(config['direccion'],
          fallback: BusinessInfo.direccion);
      if (dir.isEmpty) return;
      _direccionSucursal = dir;
      notifyListeners();
    } on ApiException {
      // Se queda la de BusinessInfo.
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

  /// Si el día nuevo es fin de semana y la hora elegida no existe ese día,
  /// se borra la hora.
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
    if (!abierto) {
      return 'Estamos fuera de servicio. Horario: ${BusinessInfo.horario}';
    }
    if (esDomicilio) {
      final d = _direccion;
      if (d == null) return 'Selecciona una dirección de entrega';
      if (!d.tieneCobertura) {
        return 'Esa colonia no tiene cobertura de envío. Elige otra o recoge en sucursal.';
      }
    }
    if (_fecha == null || _hora == null) {
      return esDomicilio
          ? 'Selecciona fecha y hora de entrega'
          : 'Selecciona fecha y hora de recolección';
    }
    return null;
  }

  Future<ResultadoPago> _pagar() async {
    final invalido = _validar();
    if (invalido != null) return PagoInterrumpido(invalido);
    _errorPago = null;
    notifyListeners();

    // Se manda en crear-intent y en confirmar: con fecha FUTURA el backend
    // acepta productos sin stock hoy (pedido "por confirmar").
    final horario = '${DateFormat('yyyy-MM-dd').format(_fecha!)} '
        '${_hora!.split(' - ').first}';

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
        return const PagoInterrumpido();
      }
      try {
        await _pasarela.cobrar(
          clientSecret: intent.clientSecret,
          publishableKey: intent.publishableKey,
        );
      } on PagoCanceladoException {
        return const PagoInterrumpido();
      } on PagoRechazadoException catch (e) {
        return PagoInterrumpido(e.message);
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
    return _fallo(
        'Tu pago fue procesado, pero no pudimos registrar el pedido '
        '(${ultimoError.message ?? 'sin conexión'}). NO pagues de '
        'nuevo: presiona "Pagar" otra vez y solo reintentaremos el registro.');
  }

  PagoInterrumpido _fallo(String mensaje) {
    _errorPago = mensaje;
    if (!_cerrado) notifyListeners();
    return PagoInterrumpido(mensaje);
  }

  @override
  void dispose() {
    _cerrado = true;
    pagar.dispose();
    super.dispose();
  }
}
