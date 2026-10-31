// lib/ui/actividad/widgets/bitacora_tab.dart
//
// Pestaña «Bitácora» de Actividad del equipo (#139), con los textos de la
// web (Bitacora.tsx): los filtros «Entidad», «Persona», «Desde» y «Hasta»
// (las fechas con el calendario, hasta hoy en la hora de México), cuántos
// movimientos se muestran y «Limpiar filtros»; cada movimiento con su fecha
// y hora de México, la acción, la entidad, los detalles (los largos se
// abren con «Ver completo») y quién lo hizo, con su rol, o «Sistema». Pide
// la página siguiente al acercarse al final o con «Cargar más», y se pone
// al día al jalar hacia abajo.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/actividad_equipo.dart';
import 'package:pier_reposteria/ui/actividad/etiquetas_auditoria.dart';
import 'package:pier_reposteria/ui/actividad/view_model/bitacora_view_model.dart';
import 'package:pier_reposteria/ui/actividad/widgets/actividad_partes.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_partes.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/utils/formatters.dart';
import 'package:provider/provider.dart';

class BitacoraTab extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pestaña crea el suyo.
  const BitacoraTab({super.key, this.viewModel});

  final BitacoraViewModel? viewModel;

  @override
  State<BitacoraTab> createState() => _BitacoraTabState();
}

class _BitacoraTabState extends State<BitacoraTab>
    with AutomaticKeepAliveClientMixin {
  late final BitacoraViewModel _vm =
      widget.viewModel ?? BitacoraViewModel(repo: context.read());

  /// Margen (px) antes del final en el que se pide la página siguiente.
  static const _margenCargarMas = 600.0;

  // Lo cargado se conserva al cambiar de pestaña.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  /// Si el backend no respondió, lo cargado se queda y se avisa.
  Future<void> _refrescar() async {
    final motivo = await _vm.refrescar();
    if (motivo == null || !mounted) return;
    avisarActividad(context, motivo);
  }

  /// Al bajar cerca del final pide la página siguiente; tras un error
  /// espera a que la persona toque «Reintentar».
  bool _alDesplazar(ScrollUpdateNotification n) {
    if ((n.scrollDelta ?? 0) > 0 &&
        n.metrics.axis == Axis.vertical &&
        n.metrics.extentAfter < _margenCargarMas &&
        _vm.errorMas == null) {
      unawaited(_vm.cargarMas());
    }
    return false;
  }

  /// Abre el calendario de «Desde» (con [desde]) o de «Hasta» y aplica el
  /// día elegido. Antes suelta el foco para que no se abra el teclado.
  Future<void> _elegirFecha({required bool desde}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final calendario = _vm.calendario(desde: desde);
    final elegida = await showDatePicker(
      context: context,
      initialDate: calendario.inicial,
      firstDate: calendario.primero,
      lastDate: calendario.ultimo,
      currentDate: _vm.hoy,
      helpText: desde ? 'Desde' : 'Hasta',
    );
    if (elegida == null || !mounted) return;
    if (desde) {
      await _vm.elegirDesde(elegida);
    } else {
      await _vm.elegirHasta(elegida);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Observa el tema de temporada: repinta la pestaña si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (_, _) => RefreshIndicator(
        color: AppColors.pierVerde,
        onRefresh: _refrescar,
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: _alDesplazar,
          child: ListView(
            key: const PageStorageKey<String>('bitacora'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _Filtros(vm: _vm, alElegirFecha: _elegirFecha),
              ..._contenido(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _contenido() {
    if (_vm.cargando) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_vm.error case final error?) {
      return [
        EstadoAgenda(
          icono: LucideIcons.circleAlert,
          titulo: 'No pudimos cargar la bitácora',
          detalle: error,
          accion: 'Reintentar',
          alAccion: () => unawaited(_vm.cargar()),
        ),
      ];
    }
    if (_vm.movimientos.isEmpty) {
      return [
        if (_vm.hayFiltros)
          EstadoAgenda(
            icono: LucideIcons.searchX,
            titulo: 'No hay movimientos con estos filtros',
            detalle: 'Prueba con otra entidad, otra persona o un rango de fechas más amplio.',
            accion: 'Limpiar filtros',
            alAccion: () => unawaited(_vm.limpiarFiltros()),
          )
        else
          const EstadoAgenda(
            icono: LucideIcons.history,
            titulo: 'Aún no hay movimientos registrados',
            detalle: 'Cada cambio del personal (productos, precios, usuarios, comandas…) aparecerá aquí con quién lo hizo y cuándo.',
          ),
      ];
    }
    return [
      if (_vm.actualizando)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: LinearProgressIndicator(),
        ),
      for (final m in _vm.movimientos)
        _Registro(key: ValueKey('movimiento-${m.id}'), movimiento: m),
      _Pie(vm: _vm),
    ];
  }
}

/// El borde y la etiqueta de un filtro.
InputDecoration _decoracion(String etiqueta, {Widget? sufijo}) =>
    InputDecoration(
      labelText: etiqueta,
      suffixIcon: sufijo,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

/// Los filtros, cuántos movimientos se ven y «Limpiar filtros».
class _Filtros extends StatelessWidget {
  const _Filtros({required this.vm, required this.alElegirFecha});

  final BitacoraViewModel vm;

  /// Abre el calendario de «Desde» (desde: true) o de «Hasta».
  final Future<void> Function({required bool desde}) alElegirFecha;

  @override
  Widget build(BuildContext context) {
    final filtros = vm.filtros;
    return TarjetaActividad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Lista<String>(
            etiqueta: 'Entidad',
            todas: 'Todas las entidades',
            opciones: vm.opcionesEntidad,
            valor: filtros.entidad,
            alElegir: (clave) => unawaited(vm.elegirEntidad(clave)),
          ),
          const SizedBox(height: 12),
          _Lista<int>(
            etiqueta: 'Persona',
            todas: 'Todas las personas',
            opciones: vm.opcionesPersona,
            valor: filtros.usuarioId,
            alElegir: (id) => unawaited(vm.elegirPersona(id)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CampoFecha(
                  etiqueta: 'Desde',
                  dia: filtros.desde,
                  alTocar: () => unawaited(alElegirFecha(desde: true)),
                  alQuitar: () => unawaited(vm.elegirDesde(null)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CampoFecha(
                  etiqueta: 'Hasta',
                  dia: filtros.hasta,
                  alTocar: () => unawaited(alElegirFecha(desde: false)),
                  alQuitar: () => unawaited(vm.elegirHasta(null)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              if (vm.resumen case final resumen?)
                Text(
                  resumen,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (vm.hayFiltros)
                TextButton(
                  onPressed: () => unawaited(vm.limpiarFiltros()),
                  child: const Text('Limpiar filtros'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Un filtro de lista; la primera opción, la de «todas», quita el filtro.
class _Lista<T extends Object> extends StatelessWidget {
  const _Lista({
    required this.etiqueta,
    required this.todas,
    required this.opciones,
    required this.valor,
    required this.alElegir,
  });

  final String etiqueta;
  final String todas;

  /// Cada valor con su texto, en el orden en que se ofrecen.
  final Map<T, String> opciones;
  final T? valor;
  final ValueChanged<T?> alElegir;

  static Widget _texto(String texto) =>
      Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis);

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: _decoracion(etiqueta),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: valor,
          isExpanded: true,
          isDense: true,
          items: [
            DropdownMenuItem<T?>(child: _texto(todas)),
            for (final MapEntry(:key, :value) in opciones.entries)
              DropdownMenuItem<T?>(value: key, child: _texto(value)),
          ],
          onChanged: alElegir,
        ),
      ),
    );
  }
}

/// «Desde» o «Hasta»: al tocarlo abre el calendario; con un día elegido, la
/// tache lo quita.
class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.etiqueta,
    required this.dia,
    required this.alTocar,
    required this.alQuitar,
  });

  final String etiqueta;
  final DateTime? dia;
  final VoidCallback alTocar;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final elegido = dia;
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _decoracion(
          etiqueta,
          sufijo: elegido == null
              ? const Icon(LucideIcons.calendar, size: 18)
              : IconButton(
                  tooltip: 'Quitar la fecha «$etiqueta»',
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: alQuitar,
                ),
        ),
        child: Text(
          elegido == null
              ? 'Cualquier día'
              : BitacoraViewModel.textoDia(elegido),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Un movimiento: cuándo (en la hora de México), qué se hizo, sobre qué,
/// los detalles y quién lo hizo, con su rol, desde qué IP.
class _Registro extends StatelessWidget {
  const _Registro({required this.movimiento, super.key});

  final MovimientoEquipo movimiento;

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    final entidad = etiquetaEntidad(m.entidad);
    return TarjetaActividad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.fecha case final fecha?)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                fechaConHora(fecha),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Text(
            m.accion,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          InsigniaActividad(
            m.entidadId == null ? entidad : '$entidad · ID ${m.entidadId}',
          ),
          if (m.detalles case final detalles?) _Detalles(detalles),
          const SizedBox(height: 6),
          Text(
            conRol(m.persona, m.rol),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (m.ip case final ip?)
            Text(
              'IP $ip',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Los detalles de un movimiento. Los largos (como el JSON de lo técnico)
/// se ven en tres renglones hasta tocar «Ver completo».
class _Detalles extends StatefulWidget {
  const _Detalles(this.texto);

  final String texto;

  @override
  State<_Detalles> createState() => _DetallesState();
}

class _DetallesState extends State<_Detalles> {
  /// Desde cuántos caracteres se recortan (como la web).
  static const _largo = 160;

  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final recortable = widget.texto.length > _largo;
    final recortado = recortable && !_abierto;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.texto,
            maxLines: recortado ? 3 : null,
            overflow: recortado ? TextOverflow.ellipsis : null,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (recortable)
            TextButton(
              onPressed: () => setState(() => _abierto = !_abierto),
              child: Text(_abierto ? 'Ver menos' : 'Ver completo'),
            ),
        ],
      ),
    );
  }
}

/// «Cargar más» al final; si la página siguiente no llegó, el motivo y
/// «Reintentar».
class _Pie extends StatelessWidget {
  const _Pie({required this.vm});

  final BitacoraViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (!vm.hayMas) return const SizedBox.shrink();
    final error = vm.errorMas;
    return Column(
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        OutlinedButton.icon(
          onPressed: vm.cargandoMas || vm.actualizando
              ? null
              : () => unawaited(vm.cargarMas()),
          icon: Icon(
            error == null ? LucideIcons.chevronDown : LucideIcons.refreshCw,
            size: 18,
          ),
          label: Text(
            vm.cargandoMas
                ? 'Cargando…'
                : error == null
                    ? 'Cargar más'
                    : 'Reintentar',
          ),
        ),
      ],
    );
  }
}
