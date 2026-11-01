// test/unitarias/actividad/etiquetas_auditoria_test.dart — las etiquetas de
// la bitácora (#139), las mismas de src/utils/etiquetasAuditoria.ts de la
// web: cada entidad y cada rol con su nombre, una clave desconocida
// legible, un movimiento sin entidad como «General» y quién lo hizo con su
// rol.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/actividad/etiquetas_auditoria.dart';

void main() {
  group('etiquetaEntidad', () {
    test('las del catálogo, con sus acentos', () {
      expect(etiquetaEntidad('zona_envio'), 'Zona de envío');
      expect(etiquetaEntidad('resena'), 'Reseña');
      expect(etiquetaEntidad('categoria_opcion'), 'Opción de categoría');
      expect(etiquetaEntidad('comanda_opcion'), 'Opción de comanda');
      expect(etiquetaEntidad('contenido'), 'Contenido del sitio');
      expect(etiquetaEntidad('backup'), 'Respaldo');
      expect(etiquetaEntidad('monitoreo'), 'Monitoreo');
    });

    test('una desconocida se vuelve legible', () {
      expect(etiquetaEntidad('otra_cosa'), 'Otra cosa');
      expect(etiquetaEntidad('sistema'), 'Sistema');
    });

    test('sin entidad es General', () {
      expect(etiquetaEntidad(null), 'General');
      expect(etiquetaEntidad(''), 'General');
      expect(etiquetaEntidad('__'), 'General');
    });
  });

  group('etiquetaRol', () {
    test('cada rol con su nombre; uno desconocido, legible', () {
      expect(etiquetaRol('direccion_general'), 'Dirección');
      expect(etiquetaRol('decoracion'), 'Decoración');
      expect(etiquetaRol('repartidor'), 'Repartidor');
      expect(etiquetaRol('empleado'), 'Empleado');
      expect(etiquetaRol('super_admin'), 'Super admin');
    });

    test('sin rol no dice nada', () {
      expect(etiquetaRol(null), isEmpty);
      expect(etiquetaRol(''), isEmpty);
    });

    test('quién lo hizo con su rol; sin rol, solo el nombre', () {
      expect(conRol('Ana Ruiz', 'gerencia'), 'Ana Ruiz · Gerencia');
      expect(conRol('Sistema', null), 'Sistema');
    });
  });
}
