// lib/domain/models/actividad_equipo.dart
//
// Lo que gerencia y dirección supervisan en «Actividad del equipo» (#139),
// con el contrato de la web (src/direccion/paginas/ActividadEquipo.tsx y
// Bitacora.tsx):
//   GET /reportes/actividad-equipo -> equipo[{id, nombre, apellido, rol,
//     activo, ultimo_acceso, acciones, ultima_accion, entregadas,
//     entregas_activas}], movimientos[{accion, entidad, entidad_id,
//     detalles, created_at, nombre, apellido, rol}] (los 30 últimos),
//     zonas[{zona, colonia, pedidos}] (las 8 con más pedidos) y
//     kpis{avisos_demora, clientes_atendidos_30d, pedidos_cerrados_30d,
//     productos_movidos_30d, promos_creadas_30d}
//   GET /reportes/auditoria -> auditoria[{id, usuario_id, accion, entidad,
//     entidad_id, detalles, ip, created_at, usuario_nombre,
//     usuario_apellido, usuario_rol}] (del más reciente al más antiguo),
//     hay_mas, siguiente_antes_de_id, entidades[clave] y personas[{id,
//     nombre, apellido, rol}]
// La acción ya llega legible ('Aprobó reembolso'); la entidad y el rol, como
// clave (ui/actividad/etiquetas_auditoria.dart los vuelve legibles). Los
// textos llegan escapados por el sanitizador del backend: aquí quedan como
// se escribieron. Un movimiento sin persona es del «Sistema».
import 'dart:convert';

import 'package:pier_reposteria/utils/texto_sanitizado.dart';

/// Texto sin espacios en las orillas; null si viene vacío.
String? _texto(Object? valor) {
  final t = valor?.toString().trim() ?? '';
  return t.isEmpty ? null : t;
}

/// Como [_texto], pero como lo escribió la persona (sin el escapado).
String? _legible(Object? valor) {
  final t = _texto(valor);
  return t == null ? null : decodificarSanitizado(t);
}

/// Entero de la respuesta (número o texto con dígitos); null si no lo es.
int? _entero(Object? valor) =>
    valor is num ? valor.toInt() : int.tryParse(_texto(valor) ?? '');

/// Una cuenta de la respuesta; 0 si no viene.
int _cuenta(Object? valor) => _entero(valor) ?? 0;

/// Instante de la respuesta (ISO, en UTC); null si no es una fecha.
DateTime? _instante(Object? valor) => DateTime.tryParse(_texto(valor) ?? '');

/// «Ana Ruiz»; 'Sistema' sin nombre (los procesos del sistema), como
/// nombreActor de la web.
String _actor(Object? nombre, Object? apellido) {
  final completo =
      [_legible(nombre), _legible(apellido)].whereType<String>().join(' ');
  return completo.isEmpty ? 'Sistema' : completo;
}

/// Los detalles como texto legible. La API los manda como texto; una
/// respuesta anterior traía el objeto de las filas técnicas, que se muestra
/// como JSON en vez de romper la pantalla. null si no hay.
String? _detalles(Object? valor) =>
    _legible(valor is Map || valor is List ? jsonEncode(valor) : valor);

// ── Actividad del equipo ───────────────────────────────────────────────

/// Una persona del equipo: mostrador, gerencia, repartidores, hornos y
/// decoración (dirección no aparece).
class MiembroEquipo {
  const MiembroEquipo({
    required this.id,
    required this.nombre,
    required this.rol,
    this.activo = true,
    this.ultimoAcceso,
    this.acciones = 0,
    this.entregadas = 0,
    this.entregasActivas = 0,
  });

  /// null si no es un objeto o le falta el id.
  static MiembroEquipo? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _entero(json['id']);
    if (id == null) return null;
    return MiembroEquipo(
      id: id,
      nombre: _actor(json['nombre'], json['apellido']),
      rol: _texto(json['rol']) ?? '',
      activo: json['activo'] != false,
      ultimoAcceso: _instante(json['ultimo_acceso']),
      acciones: _cuenta(json['acciones']),
      entregadas: _cuenta(json['entregadas']),
      entregasActivas: _cuenta(json['entregas_activas']),
    );
  }

  final int id;

  /// «Ana Ruiz».
  final String nombre;

  /// La clave del rol (repartidor, hornos…).
  final String rol;

  /// La cuenta está habilitada; no quiere decir que esté en línea.
  final bool activo;

  /// null si nunca ha entrado.
  final DateTime? ultimoAcceso;

  /// Movimientos que registró en la bitácora (sin lo técnico).
  final int acciones;

  /// Solo repartidores: entregas hechas y las que lleva en curso.
  final int entregadas;
  final int entregasActivas;

  bool get esRepartidor => rol == 'repartidor';
}

/// Un movimiento de la bitácora: qué se hizo, sobre qué, quién y cuándo.
/// Los últimos movimientos de la actividad del equipo no traen id ni IP.
class MovimientoEquipo {
  const MovimientoEquipo({
    required this.accion,
    required this.persona,
    this.id,
    this.entidad,
    this.entidadId,
    this.detalles,
    this.rol,
    this.ip,
    this.fecha,
  });

  /// Los dos contratos solo cambian dónde vienen la persona, su rol, el id
  /// y la IP.
  factory MovimientoEquipo._leer(
    Map<Object?, Object?> json, {
    required Object? nombre,
    required Object? apellido,
    required Object? rol,
    int? id,
    Object? ip,
  }) =>
      MovimientoEquipo(
        id: id,
        accion: _legible(json['accion']) ?? 'Movimiento',
        persona: _actor(nombre, apellido),
        entidad: _texto(json['entidad']),
        entidadId: _entero(json['entidad_id']),
        detalles: _detalles(json['detalles']),
        rol: _texto(rol),
        ip: _texto(ip),
        fecha: _instante(json['created_at']),
      );

  /// Un renglón de la bitácora; null si no es un objeto o le falta el id.
  static MovimientoEquipo? deBitacora(Object? json) {
    if (json is! Map) return null;
    final id = _entero(json['id']);
    if (id == null) return null;
    return MovimientoEquipo._leer(
      json,
      id: id,
      nombre: json['usuario_nombre'],
      apellido: json['usuario_apellido'],
      rol: json['usuario_rol'],
      ip: json['ip'],
    );
  }

  /// Uno de los últimos movimientos de la actividad del equipo; null si no
  /// es un objeto.
  static MovimientoEquipo? deActividad(Object? json) {
    if (json is! Map) return null;
    return MovimientoEquipo._leer(
      json,
      nombre: json['nombre'],
      apellido: json['apellido'],
      rol: json['rol'],
    );
  }

  /// Con él se pide la página siguiente; null en la actividad del equipo.
  final int? id;

  /// Ya legible: 'Aprobó reembolso'.
  final String accion;

  /// «Ana Ruiz»; 'Sistema' si no lo hizo una persona.
  final String persona;

  /// Clave de la entidad (pedido, producto…); null en registros viejos.
  final String? entidad;
  final int? entidadId;

  /// Como se escribieron; null si no hay.
  final String? detalles;

  /// Clave del rol de quien lo hizo.
  final String? rol;
  final String? ip;
  final DateTime? fecha;
}

/// Una colonia y cuántos pedidos a domicilio (no cancelados) se le han
/// enviado.
class ZonaEntregas {
  const ZonaEntregas({
    required this.colonia,
    required this.pedidos,
    this.zona,
  });

  /// null si no es un objeto. Sin colonia, 'Sin colonia' (como la web).
  static ZonaEntregas? fromJson(Object? json) {
    if (json is! Map) return null;
    return ZonaEntregas(
      colonia: _legible(json['colonia']) ?? 'Sin colonia',
      pedidos: _cuenta(json['pedidos']),
      zona: _legible(json['zona']),
    );
  }

  final String colonia;
  final int pedidos;

  /// La zona de envío a la que pertenece; null si no la trae.
  final String? zona;
}

/// Las cifras de la operación: las de los últimos 30 días y los avisos de
/// demora enviados en total.
class KpisActividad {
  const KpisActividad({
    this.clientesAtendidos = 0,
    this.pedidosCerrados = 0,
    this.productosMovidos = 0,
    this.promocionesCreadas = 0,
    this.avisosDemora = 0,
  });

  /// null si no vienen.
  static KpisActividad? fromJson(Object? json) {
    if (json is! Map) return null;
    return KpisActividad(
      clientesAtendidos: _cuenta(json['clientes_atendidos_30d']),
      pedidosCerrados: _cuenta(json['pedidos_cerrados_30d']),
      productosMovidos: _cuenta(json['productos_movidos_30d']),
      promocionesCreadas: _cuenta(json['promos_creadas_30d']),
      avisosDemora: _cuenta(json['avisos_demora']),
    );
  }

  /// Clientes distintos con un pedido (no cancelado).
  final int clientesAtendidos;

  /// Pedidos completados o entregados.
  final int pedidosCerrados;

  /// Productos que se crearon o cambiaron.
  final int productosMovidos;
  final int promocionesCreadas;

  /// «Tu pedido tardará un poco más» enviados a clientes, en total.
  final int avisosDemora;
}

/// La actividad del equipo tal como la manda el backend.
class ActividadEquipo {
  const ActividadEquipo({
    this.equipo = const [],
    this.movimientos = const [],
    this.zonas = const [],
    this.kpis,
  });

  /// Lee la respuesta; los renglones inválidos se descartan.
  factory ActividadEquipo.fromJson(Map<String, dynamic> json) =>
      ActividadEquipo(
        equipo: [
          if (json['equipo'] case final List lista)
            for (final m in lista) ?MiembroEquipo.fromJson(m),
        ],
        movimientos: [
          if (json['movimientos'] case final List lista)
            for (final m in lista) ?MovimientoEquipo.deActividad(m),
        ],
        zonas: [
          if (json['zonas'] case final List lista)
            for (final z in lista) ?ZonaEntregas.fromJson(z),
        ],
        kpis: KpisActividad.fromJson(json['kpis']),
      );

  /// Por rol y nombre, como lo ordena el backend.
  final List<MiembroEquipo> equipo;

  /// Los últimos 30, del más reciente al más antiguo.
  final List<MovimientoEquipo> movimientos;

  /// Las 8 con más pedidos, de más a menos.
  final List<ZonaEntregas> zonas;

  /// null si no vinieron.
  final KpisActividad? kpis;
}

// ── Bitácora ───────────────────────────────────────────────────────────

/// Una persona que aparece en la bitácora: las opciones del filtro
/// «Persona».
class PersonaBitacora {
  const PersonaBitacora({required this.id, required this.nombre, this.rol});

  /// null si no es un objeto o le falta el id.
  static PersonaBitacora? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _entero(json['id']);
    if (id == null) return null;
    return PersonaBitacora(
      id: id,
      nombre: _actor(json['nombre'], json['apellido']),
      rol: _texto(json['rol']),
    );
  }

  final int id;
  final String nombre;

  /// Clave del rol.
  final String? rol;
}

/// Una página de la bitácora y lo que llena sus filtros.
class PaginaBitacora {
  const PaginaBitacora({
    this.movimientos = const [],
    this.hayMas = false,
    this.siguienteAntesDeId,
    this.entidades = const [],
    this.personas = const [],
  });

  /// Lee la respuesta; los renglones inválidos se descartan. Solo hay más si
  /// el backend lo dice y manda con qué pedir la página siguiente.
  factory PaginaBitacora.fromJson(Map<String, dynamic> json) {
    final siguiente = _entero(json['siguiente_antes_de_id']);
    return PaginaBitacora(
      movimientos: [
        if (json['auditoria'] case final List lista)
          for (final m in lista) ?MovimientoEquipo.deBitacora(m),
      ],
      hayMas: json['hay_mas'] == true && siguiente != null,
      siguienteAntesDeId: siguiente,
      entidades: [
        if (json['entidades'] case final List lista)
          for (final e in lista)
            if (e is String && e.trim().isNotEmpty) e.trim(),
      ],
      personas: [
        if (json['personas'] case final List lista)
          for (final p in lista) ?PersonaBitacora.fromJson(p),
      ],
    );
  }

  /// Del más reciente al más antiguo.
  final List<MovimientoEquipo> movimientos;
  final bool hayMas;

  /// El antes_de_id de la página siguiente; null si no hay más.
  final int? siguienteAntesDeId;

  /// Las entidades que puede ver quien consulta (gerencia, sin las
  /// técnicas), como clave.
  final List<String> entidades;

  /// Quienes aparecen en lo que puede ver.
  final List<PersonaBitacora> personas;
}

/// Los filtros de la bitácora; null en cada uno es «todos».
class FiltrosBitacora {
  const FiltrosBitacora({
    this.entidad,
    this.usuarioId,
    this.desde,
    this.hasta,
  });

  /// Clave de la entidad (pedido, producto…).
  final String? entidad;
  final int? usuarioId;

  /// Días del calendario (solo cuentan año, mes y día), ambos inclusive: el
  /// backend los toma completos en la hora de México.
  final DateTime? desde;
  final DateTime? hasta;

  bool get vacios =>
      entidad == null && usuarioId == null && desde == null && hasta == null;
}
