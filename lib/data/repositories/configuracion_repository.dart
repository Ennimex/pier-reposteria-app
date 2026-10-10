// lib/data/repositories/configuracion_repository.dart
//
// Única puerta a los datos de la configuración pública del panel (contacto, personalización, inicio, faq, nosotros, legales). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es ConfiguracionRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
//
// Fase 3: las secciones que ya tienen ViewModel tienen su método tipado
// (contacto, nosotros, faq, legales) y lanzan ApiException si el backend
// falla.
import 'package:pier_pasteleria/domain/models/info_contacto.dart';
import 'package:pier_pasteleria/domain/models/info_nosotros.dart';
import 'package:pier_pasteleria/domain/models/pregunta_frecuente.dart';
import 'package:pier_pasteleria/domain/models/textos_legales.dart';

abstract class ConfiguracionRepository {
  /// GET /configuracion/:seccion -> {success, config: {clave: valor}}.
  /// Solo secciones de la whitelist pública del backend; el resto da 403.
  Future<Map<String, dynamic>> seccion(String nombre);

  /// GET /configuracion/contacto. Sin `config` devuelve todo null.
  Future<InfoContacto> contacto();

  /// GET /configuracion/nosotros. Sin `config` devuelve todo vacío.
  Future<InfoNosotros> nosotros();

  /// GET /configuracion/faq. Sin preguntas capturadas devuelve lista vacía.
  Future<List<PreguntaFrecuente>> faq();

  /// GET /configuracion/legales. Sin `config` devuelve todo null.
  Future<TextosLegales> legales();
}
