// lib/ui/atencion/view_model/lista_atencion_view_model.dart
//
// Lo que comparten las tres pestañas de «Atención a clientes» (#138):
// cargar la lista del backend, ponerla al día al jalar hacia abajo, saber
// qué elemento tiene una acción en curso y correr cada acción, que al
// terminar recarga la lista (también tras un error: otra persona pudo
// cambiarlo), como «Pedidos del día» (#137).
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';

/// Resultado de una acción: el aviso para el personal y si salió bien.
typedef ResultadoAtencion = ({String mensaje, bool ok});

abstract class ListaAtencionViewModel<T> extends ChangeNotifier {
  bool _cerrado = false;
  List<T> _elementos = const [];
  bool _cargando = false;
  String? _error;
  final Set<String> _ocupados = {};

  /// La lista tal como la manda el backend.
  List<T> get elementos => _elementos;

  bool get cargando => _cargando && _elementos.isEmpty;

  /// Por qué no se cargó; solo si no hay nada que mostrar.
  String? get error => _elementos.isEmpty ? _error : null;

  /// true mientras corre una acción sobre [elemento].
  bool ocupado(T elemento) => _ocupados.contains(idDe(elemento));

  /// Pide la lista al repositorio (lanza ApiException si no responde).
  @protected
  Future<List<T>> pedirLista();

  /// Con qué se distingue cada elemento.
  @protected
  String idDe(T elemento);

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
      final lista = await pedirLista();
      if (_cerrado) return null;
      _elementos = lista;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Corre [llamada] sobre [elemento]: devuelve [exito] si salió bien o el
  /// mensaje del backend si no, y recarga la lista.
  @protected
  Future<ResultadoAtencion> accion(
    T elemento,
    Future<Object?> Function() llamada,
    String exito,
  ) async {
    final id = idDe(elemento);
    if (_ocupados.contains(id)) {
      return (mensaje: 'Espera a que termine la acción anterior', ok: false);
    }
    _ocupados.add(id);
    notifyListeners();
    ResultadoAtencion resultado;
    try {
      await llamada();
      resultado = (mensaje: exito, ok: true);
    } on ApiException catch (e) {
      resultado = (mensaje: e.message, ok: false);
    }
    _ocupados.remove(id);
    if (_cerrado) return resultado;
    notifyListeners();
    // También tras un error: otra persona pudo cambiarlo.
    await refrescar();
    return resultado;
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
