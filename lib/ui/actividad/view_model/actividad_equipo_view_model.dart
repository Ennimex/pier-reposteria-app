// lib/ui/actividad/view_model/actividad_equipo_view_model.dart
//
// Estado de la pestaña «Equipo» de Actividad del equipo (#139): la
// actividad que manda el backend, ponerla al día al jalar hacia abajo y los
// textos que la web calcula al pintarla (ActividadEquipo.tsx): cuánto hace
// del último acceso o de un movimiento, con un reloj que las pruebas fijan,
// lo que ha registrado cada persona y las cifras con separador de miles.
// Lo crea EquipoTab.
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/actividad_repository.dart';
import 'package:pier_reposteria/domain/models/actividad_equipo.dart';

class ActividadEquipoViewModel extends ChangeNotifier {
  /// [ahora] solo se pasa en pruebas (reloj fijo).
  ActividadEquipoViewModel({
    required ActividadRepository repo,
    DateTime Function()? ahora,
  })  : _repo = repo,
        _ahora = ahora ?? DateTime.now;

  /// Separador de miles como la web (es-MX): «1,234».
  static final NumberFormat _miles = NumberFormat.decimalPattern('es_MX');

  final ActividadRepository _repo;
  final DateTime Function() _ahora;
  bool _cerrado = false;

  ActividadEquipo? _actividad;
  bool _cargando = false;
  String? _error;

  /// Lo último que mandó el backend; null mientras no ha cargado.
  ActividadEquipo? get actividad => _actividad;

  bool get cargando => _cargando && _actividad == null;

  /// Por qué no se cargó; solo si no hay nada que mostrar.
  String? get error => _actividad == null ? _error : null;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    _avisar();
    final error = await refrescar();
    _error = error;
    _cargando = false;
    _avisar();
  }

  /// Pone al día la actividad; devuelve el motivo si el backend no
  /// respondió (lo cargado se queda).
  Future<String?> refrescar() async {
    try {
      final actividad = await _repo.actividadEquipo();
      if (_cerrado) return null;
      _actividad = actividad;
      _avisar();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Cuánto pasó desde [fecha], como la web: 'Nunca', 'Ahora mismo',
  /// 'Hace 5 min', 'Hace 3 h', 'Hace 1 día' o 'Hace 4 días'.
  String haceCuanto(DateTime? fecha) {
    if (fecha == null) return 'Nunca';
    final minutos = _ahora().difference(fecha).inMinutes;
    if (minutos < 1) return 'Ahora mismo';
    if (minutos < 60) return 'Hace $minutos min';
    final horas = minutos ~/ 60;
    if (horas < 24) return 'Hace $horas h';
    final dias = horas ~/ 24;
    return dias == 1 ? 'Hace 1 día' : 'Hace $dias días';
  }

  /// Lo que ha registrado [miembro], como la web: los repartidores, sus
  /// entregas (y las que llevan en curso); los demás, sus movimientos en la
  /// bitácora.
  String actividadDe(MiembroEquipo miembro) {
    if (!miembro.esRepartidor) {
      final n = miembro.acciones;
      return '${cifra(n)} ${n == 1 ? 'movimiento' : 'movimientos'}';
    }
    final n = miembro.entregadas;
    final entregas = '${cifra(n)} ${n == 1 ? 'entrega' : 'entregas'}';
    final enCurso = miembro.entregasActivas;
    return enCurso > 0 ? '$entregas · ${cifra(enCurso)} en curso' : entregas;
  }

  /// Lo que se llena la barra de [zona] (de 0 a 1) frente a la zona con
  /// más pedidos.
  double proporcion(ZonaEntregas zona) {
    final zonas = _actividad?.zonas ?? const <ZonaEntregas>[];
    final maximo = zonas.fold(0, (mas, z) => z.pedidos > mas ? z.pedidos : mas);
    return maximo == 0 ? 0 : zona.pedidos / maximo;
  }

  /// [n] con separador de miles, como la web: «1,234».
  static String cifra(int n) => _miles.format(n);

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
