// lib/data/repositories/demanda_repository.dart
//
// Registro silencioso de "demanda no atendida": qué busca la gente en el
// catálogo y qué intenta comprar cuando está agotado. Espejo de
// src/utils/demandaNoAtendida.ts de la web. Nunca bloquea ni interrumpe al
// cliente: si el registro falla, la navegación sigue igual.
// Contrato (Fase 4, antes DemandaService estático): la implementación HTTP es
// DemandaRepositoryRemote, registrada una sola vez en
// lib/config/dependencies.dart.

abstract class DemandaRepository {
  /// POST /busquedas: un término buscado y cuántos resultados dio (0 = oro
  /// puro). Ignora términos de menos de 2 caracteres y recorta a 120.
  void registrarBusqueda(String texto, int numResultados);

  /// POST /clics-agotados: interés en un producto agotado (botón "Avísame").
  /// Ignora ids que no sean numéricos.
  void registrarClicAgotado(String productoId);
}
