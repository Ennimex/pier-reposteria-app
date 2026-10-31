// lib/ui/more/view_model/privacidad_view_model.dart
//
// Estado de «Privacidad» (derecho de oposición, #223): dos interruptores que
// se guardan en el teléfono. Apagar los diagnósticos se aplica en el momento
// (Monitoreo deja de mandar a Sentry) y al reabrir la app Sentry ya no se
// inicia; apagar las búsquedas deja de registrarlas.
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/config/monitoreo.dart';
import 'package:pier_reposteria/data/services/preferencias_service.dart';

class PrivacidadViewModel extends ChangeNotifier {
  PrivacidadViewModel({PreferenciasService? preferencias})
      : _preferencias = preferencias ?? PreferenciasService();

  final PreferenciasService _preferencias;
  bool _cerrado = false;
  bool _cargando = true;
  bool _diagnosticos = true;
  bool _busquedas = true;

  bool get cargando => _cargando;
  bool get enviaDiagnosticos => _diagnosticos;
  bool get registraBusquedas => _busquedas;

  Future<void> cargar() async {
    final diagnosticos = await _preferencias.enviaDiagnosticos();
    final busquedas = await _preferencias.registraBusquedas();
    if (_cerrado) return;
    _diagnosticos = diagnosticos;
    _busquedas = busquedas;
    _cargando = false;
    notifyListeners();
  }

  Future<void> cambiarDiagnosticos({required bool envia}) async {
    _diagnosticos = envia;
    Monitoreo.diagnosticosPermitidos = envia;
    notifyListeners();
    await _preferencias.guardarEnviaDiagnosticos(envia: envia);
  }

  Future<void> cambiarBusquedas({required bool registra}) async {
    _busquedas = registra;
    notifyListeners();
    await _preferencias.guardarRegistraBusquedas(registra: registra);
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
