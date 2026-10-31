// lib/data/repositories/actividad_repository.dart
//
// Única puerta a «Actividad del equipo» (#139), de solo lectura y solo para
// gerencia y dirección (el backend toma el rol del JWT): la actividad del
// equipo y la bitácora de cambios por páginas, con sus filtros. A gerencia
// el servidor ya le quita las operaciones técnicas. Devuelve modelos y
// lanza ApiException con el mensaje del backend. La implementación HTTP es
// ActividadRepositoryRemote, registrada en lib/config/dependencies.dart.
import 'package:pier_reposteria/domain/models/actividad_equipo.dart';

abstract class ActividadRepository {
  /// Movimientos por página de la bitácora (como la web).
  static const porPagina = 50;

  /// GET /reportes/actividad-equipo: el equipo con su último acceso y lo
  /// que ha registrado, los últimos 30 movimientos, las 8 zonas con más
  /// entregas y las cifras de los últimos 30 días.
  Future<ActividadEquipo> actividadEquipo();

  /// GET /reportes/auditoria: una página de la bitácora con [filtros], del
  /// movimiento más reciente al más antiguo. Sin [antesDeId] es la primera;
  /// la siguiente se pide con el siguienteAntesDeId de la anterior.
  Future<PaginaBitacora> bitacora(FiltrosBitacora filtros, {int? antesDeId});
}
