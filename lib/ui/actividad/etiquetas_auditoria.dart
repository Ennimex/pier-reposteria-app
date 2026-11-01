// lib/ui/actividad/etiquetas_auditoria.dart
//
// Cómo se ven en «Actividad del equipo» (#139) la entidad de cada
// movimiento de la bitácora y el rol de quien lo hizo: las etiquetas de
// src/utils/etiquetasAuditoria.ts de la web. La API manda la clave tal como
// se registró (singular, minúsculas, snake_case y sin acentos); aquí se
// vuelve legible. Una clave que no está en el catálogo se muestra legible
// ('otra_cosa' → 'Otra cosa') y un movimiento sin entidad (registros
// viejos), como «General».

/// Cada entidad de la bitácora con su nombre (las técnicas, solo para
/// dirección, al final).
const Map<String, String> _entidades = {
  'usuario': 'Usuario',
  'configuracion': 'Configuración',
  'zona_envio': 'Zona de envío',
  'sorteo': 'Sorteo',
  'queja': 'Queja',
  'reembolso': 'Reembolso',
  'resena': 'Reseña',
  'categoria': 'Categoría',
  'categoria_opcion': 'Opción de categoría',
  'notificacion': 'Notificación',
  'pedido': 'Pedido',
  'producto': 'Producto',
  'promocion': 'Promoción',
  'fecha_especial': 'Fecha especial',
  'comanda': 'Comanda',
  'comanda_opcion': 'Opción de comanda',
  'publicacion': 'Publicación',
  'comentario': 'Comentario',
  'contenido': 'Contenido del sitio',
  'backup': 'Respaldo',
  'seguridad': 'Seguridad',
  'monitoreo': 'Monitoreo',
};

/// Cada rol con su nombre ('decoracion' llega sin acento).
const Map<String, String> _roles = {
  'cliente': 'Cliente',
  'empleado': 'Empleado',
  'repartidor': 'Repartidor',
  'hornos': 'Hornos',
  'decoracion': 'Decoración',
  'gerencia': 'Gerencia',
  'direccion_general': 'Dirección',
};

/// Una clave sin catálogo, legible: 'otra_cosa' → 'Otra cosa'.
String _claveLegible(String clave) {
  final texto = clave.replaceAll('_', ' ').trim();
  return texto.isEmpty
      ? texto
      : '${texto[0].toUpperCase()}${texto.substring(1)}';
}

/// La entidad legible ('Zona de envío'); una desconocida, legible, y sin
/// entidad, 'General'.
String etiquetaEntidad(String? entidad) {
  if (entidad == null) return 'General';
  final legible = _entidades[entidad] ?? _claveLegible(entidad);
  return legible.isEmpty ? 'General' : legible;
}

/// El rol legible ('Dirección'); uno desconocido, legible, y sin rol, ''.
String etiquetaRol(String? rol) =>
    rol == null ? '' : _roles[rol] ?? _claveLegible(rol);

/// Quién lo hizo con su rol: «Ana Ruiz · Gerencia»; sin rol, solo el
/// nombre.
String conRol(String persona, String? rol) {
  final etiqueta = etiquetaRol(rol);
  return etiqueta.isEmpty ? persona : '$persona · $etiqueta';
}
