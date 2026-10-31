// lib/ui/actividad/widgets/equipo_tab.dart
//
// Pestaña «Equipo» de Actividad del equipo (#139), con los textos de la web
// (ActividadEquipo.tsx): las cifras de la operación de los últimos 30 días;
// «Tu equipo», con el rol de cada persona, su último acceso, la marca
// «Inactiva» si su cuenta está deshabilitada y lo que ha registrado
// (entregas los repartidores, movimientos los demás); las zonas con más
// entregas y los últimos movimientos, con el atajo a la bitácora completa.
// Se pone al día al jalar hacia abajo.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/actividad_equipo.dart';
import 'package:pier_reposteria/ui/actividad/etiquetas_auditoria.dart';
import 'package:pier_reposteria/ui/actividad/view_model/actividad_equipo_view_model.dart';
import 'package:pier_reposteria/ui/actividad/widgets/actividad_partes.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_partes.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

class EquipoTab extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pestaña crea el suyo.
  const EquipoTab({super.key, this.viewModel});

  final ActividadEquipoViewModel? viewModel;

  @override
  State<EquipoTab> createState() => _EquipoTabState();
}

class _EquipoTabState extends State<EquipoTab>
    with AutomaticKeepAliveClientMixin {
  late final ActividadEquipoViewModel _vm =
      widget.viewModel ?? ActividadEquipoViewModel(repo: context.read());

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Observa el tema de temporada: repinta la pestaña si cambia la paleta
    context.watch<TemaProvider>();
    // Las pestañas de la pantalla, para el atajo a la bitácora.
    final pestanas = DefaultTabController.maybeOf(context);
    return ListenableBuilder(
      listenable: _vm,
      builder: (_, _) => _contenido(pestanas),
    );
  }

  Widget _contenido(TabController? pestanas) {
    if (_vm.cargando) return const Center(child: CircularProgressIndicator());
    final actividad = _vm.actividad;
    if (actividad == null) {
      return SingleChildScrollView(
        child: EstadoAgenda(
          icono: LucideIcons.circleAlert,
          titulo: 'No pudimos cargar la actividad del equipo',
          detalle: _vm.error,
          accion: 'Reintentar',
          alAccion: () => unawaited(_vm.cargar()),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.pierVerde,
      onRefresh: _refrescar,
      child: ListView(
        key: const PageStorageKey<String>('equipo'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (actividad.kpis case final kpis?) _Cifras(kpis),
          const TituloActividad(
            'Tu equipo',
            detalle: 'Último acceso y lo que ha registrado cada persona.',
          ),
          if (actividad.equipo.isEmpty)
            const SinDatosActividad('Aún no hay personal registrado'),
          for (final m in actividad.equipo)
            _TarjetaMiembro(
              key: ValueKey('miembro-${m.id}'),
              miembro: m,
              ultimoAcceso: _vm.haceCuanto(m.ultimoAcceso),
              actividad: _vm.actividadDe(m),
            ),
          const TituloActividad(
            'Zonas con más entregas',
            detalle: 'Colonias y comunidades a donde más se envía (pedidos a domicilio no cancelados).',
          ),
          if (actividad.zonas.isEmpty)
            const SinDatosActividad('Aún no hay entregas a domicilio')
          else
            _Zonas(vm: _vm, zonas: actividad.zonas),
          const TituloActividad(
            'Últimos movimientos del equipo',
            detalle: 'Productos, promociones, estados de pedido, aprobaciones y avisos, con quién lo hizo.',
          ),
          if (actividad.movimientos.isEmpty)
            const SinDatosActividad('Aún no hay movimientos registrados'),
          for (final m in actividad.movimientos)
            _TarjetaMovimiento(m, cuando: _vm.haceCuanto(m.fecha)),
          if (pestanas case final controlador?)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => controlador.animateTo(1),
                icon: const Icon(LucideIcons.history, size: 18),
                label: const Text('Ver la bitácora completa'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Las cifras de la operación, dos por renglón; con letra grande crecen
/// hacia abajo en vez de cortarse.
class _Cifras extends StatelessWidget {
  const _Cifras(this.kpis);

  final KpisActividad kpis;

  @override
  Widget build(BuildContext context) {
    final cifras = [
      (
        'Clientes atendidos',
        kpis.clientesAtendidos,
        'Con pedido en los últimos 30 días',
      ),
      (
        'Pedidos cerrados',
        kpis.pedidosCerrados,
        'Completados o entregados, 30 días',
      ),
      ('Productos con cambios', kpis.productosMovidos, 'Últimos 30 días'),
      ('Promociones creadas', kpis.promocionesCreadas, 'Últimos 30 días'),
      (
        'Avisos de demora',
        kpis.avisosDemora,
        'Enviados a clientes, en total',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloActividad('Cifras de la operación'),
        LayoutBuilder(
          builder: (context, limites) {
            final ancho = (limites.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (etiqueta, valor, nota) in cifras)
                  SizedBox(
                    width: ancho,
                    child: _Cifra(
                      etiqueta: etiqueta,
                      valor: ActividadEquipoViewModel.cifra(valor),
                      nota: nota,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.etiqueta,
    required this.valor,
    required this.nota,
  });

  final String etiqueta;
  final String valor;
  final String nota;

  @override
  Widget build(BuildContext context) {
    // Se lee de corrido: «1,234, Clientes atendidos, …».
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.pierVerde,
              ),
            ),
            Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              nota,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una persona del equipo: su rol, cuándo entró por última vez y lo que ha
/// registrado.
class _TarjetaMiembro extends StatelessWidget {
  const _TarjetaMiembro({
    required this.miembro,
    required this.ultimoAcceso,
    required this.actividad,
    super.key,
  });

  final MiembroEquipo miembro;
  final String ultimoAcceso;
  final String actividad;

  @override
  Widget build(BuildContext context) {
    final m = miembro;
    return TarjetaActividad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                m.nombre,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (!m.activo)
                const InsigniaActividad('Inactiva', color: AppColors.error),
            ],
          ),
          Text(
            etiquetaRol(m.rol),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _Dato(LucideIcons.clock, 'Último acceso: $ultimoAcceso'),
          _Dato(
            m.esRepartidor ? LucideIcons.truck : LucideIcons.activity,
            actividad,
          ),
        ],
      ),
    );
  }
}

/// Un dato con su ícono; el texto baja de renglón si no cabe.
class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icono, size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Las zonas a donde más se envía, cada una con una barra frente a la de
/// más pedidos.
class _Zonas extends StatelessWidget {
  const _Zonas({required this.vm, required this.zonas});

  final ActividadEquipoViewModel vm;
  final List<ZonaEntregas> zonas;

  @override
  Widget build(BuildContext context) {
    return TarjetaActividad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final z in zonas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          z.colonia,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ActividadEquipoViewModel.cifra(z.pedidos),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (z.zona case final zona? when zona != z.colonia)
                    Text(
                      zona,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // La cifra ya se lee; la barra solo se ve.
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: vm.proporcion(z),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                      color: AppColors.pierVerde,
                      backgroundColor: AppColors.pierArena,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Un movimiento reciente: quién y qué hizo, sobre qué, los detalles (en
/// dos renglones) y cuánto hace.
class _TarjetaMovimiento extends StatelessWidget {
  const _TarjetaMovimiento(this.movimiento, {required this.cuando});

  final MovimientoEquipo movimiento;

  /// «Hace 5 min»; no se muestra si el movimiento no trae fecha.
  final String cuando;

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    return TarjetaActividad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: m.persona,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' · ${m.accion}'),
              ],
            ),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          InsigniaActividad(etiquetaEntidad(m.entidad)),
          if (m.detalles case final detalles?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                detalles,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (m.fecha != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                cuando,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
