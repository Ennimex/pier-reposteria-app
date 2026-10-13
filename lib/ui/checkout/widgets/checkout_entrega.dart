// lib/ui/checkout/widgets/checkout_entrega.dart
//
// Entrega del checkout: "¿Cómo lo quieres?" (recoger o domicilio), la
// sucursal o las direcciones del cliente, y fecha y hora. Leen y modifican
// el CheckoutViewModel; abrir el calendario y la hoja de dirección, y
// confirmar el borrado, lo hace la pantalla por callbacks.
//
// Movimiento: la tinta del toque va ENCIMA del fondo de cada tarjeta (antes
// quedaba tapada) y la tarjeta elegida cambia de color y borde con suavidad;
// el ícono de la modalidad elegida da un pop y el radio de la dirección se
// rellena con otro. La lista de direcciones se funde con su indicador de
// carga sin saltos, la fecha elegida rueda a su lugar, el pin de la sucursal
// cae una sola vez y, si al pagar falta un dato, su fila se sacude.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/domain/models/direccion_model.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_partes.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/tamano_animado.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

/// Las dos tarjetas de modalidad.
class CheckoutModalidad extends StatelessWidget {
  const CheckoutModalidad({required this.viewModel, super.key});

  final CheckoutViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final domicilio = viewModel.esDomicilio;
    return Row(
      children: [
        Expanded(
          child: _ModalidadCard(
            seleccionada: !domicilio,
            icon: LucideIcons.store,
            titulo: 'Recoger',
            sub: 'En sucursal',
            onTap: () => viewModel.elegirEntrega(TipoEntrega.pickup),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModalidadCard(
            seleccionada: domicilio,
            icon: LucideIcons.bike,
            titulo: 'Domicilio',
            sub: 'Envío a tu casa',
            onTap: () => viewModel.elegirEntrega(TipoEntrega.domicilio),
          ),
        ),
      ],
    );
  }
}

class _ModalidadCard extends StatefulWidget {
  const _ModalidadCard({
    required this.seleccionada,
    required this.icon,
    required this.titulo,
    required this.sub,
    required this.onTap,
  });

  final bool seleccionada;
  final IconData icon;
  final String titulo;
  final String sub;
  final VoidCallback onTap;

  @override
  State<_ModalidadCard> createState() => _ModalidadCardState();
}

class _ModalidadCardState extends State<_ModalidadCard>
    with SingleTickerProviderStateMixin {
  // Pop del ícono al quedar elegida: crece un poco y asienta con rebote.
  static final Animatable<double> _pop = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.18,
          end: 1,
        ).chain(CurveTween(curve: AppMovimiento.curvaRebote)),
        weight: 65,
      ),
    ],
  );

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: AppMovimiento.enfasis,
  );
  late final Animation<double> _escala = _control.drive(_pop);

  @override
  void didUpdateWidget(_ModalidadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seleccionada &&
        !oldWidget.seleccionada &&
        !AppMovimiento.reducido(context)) {
      _control.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seleccionada = widget.seleccionada;
    final duracion = AppMovimiento.duracion(context, AppMovimiento.corta);
    // Fondo y borde DEBAJO de la tinta: AnimatedContainer → Material
    // transparente → InkWell, así la onda del toque se ve sobre la tarjeta.
    return AnimatedContainer(
      duration: duracion,
      curve: AppMovimiento.curvaEstandar,
      decoration: BoxDecoration(
        color: seleccionada
            ? AppColors.pierVerde.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seleccionada
              ? AppColors.pierVerde
              : AppColors.textSecondary.withValues(alpha: 0.15),
          width: seleccionada ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                ScaleTransition(
                  scale: _escala,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      end: seleccionada
                          ? AppColors.pierVerde
                          : AppColors.textSecondary,
                    ),
                    duration: duracion,
                    builder: (context, color, _) =>
                        Icon(widget.icon, color: color, size: 28),
                  ),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: seleccionada
                        ? AppColors.pierVerde
                        : AppColors.textPrimary,
                  ),
                  duration: duracion,
                  builder: (context, color, _) => Text(widget.titulo,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: color)),
                ),
                const SizedBox(height: 2),
                Text(widget.sub,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "¿Dónde recoges?" con la sucursal y "¿Cuándo pasas?".
class CheckoutRecoger extends StatelessWidget {
  const CheckoutRecoger({
    required this.viewModel,
    required this.onElegirFecha,
    this.sacudidaFecha,
    super.key,
  });

  final CheckoutViewModel viewModel;
  final VoidCallback onElegirFecha;

  /// Cambia cuando al pagar falta la fecha o la hora: esa fila se sacude.
  final Object? sacudidaFecha;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSeccion('¿Dónde recoges?'),
        Container(
          decoration: decoracionTarjeta(),
          child: ListTile(
            // Pin de ubicación animado (Lottie local, paleta Pier): gira y
            // sube una sola vez, y otra vez al volver a «Recoger». Con
            // movimiento reducido queda en su pose final.
            leading: Lottie.asset(
              'assets/lottie/store_location.json',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              repeat: false,
              controller: AppMovimiento.reducido(context)
                  ? const AlwaysStoppedAnimation<double>(1)
                  : null,
            ),
            title: const Text(BusinessInfo.sucursal,
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(viewModel.direccionSucursal),
            trailing: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: AppColors.pierVerde, shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, color: Colors.white, size: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const TituloSeccion('¿Cuándo pasas?'),
        CheckoutFechaHora(
          viewModel: viewModel,
          onElegirFecha: onElegirFecha,
          sacudida: sacudidaFecha,
        ),
      ],
    );
  }
}

/// "Dirección de entrega" con las del cliente y "¿Cuándo lo entregamos?".
class CheckoutDomicilio extends StatelessWidget {
  const CheckoutDomicilio({
    required this.viewModel,
    required this.onElegirFecha,
    required this.onAgregar,
    required this.onEditar,
    required this.onEliminar,
    this.sacudidaFecha,
    this.sacudidaDireccion,
    super.key,
  });

  final CheckoutViewModel viewModel;
  final VoidCallback onElegirFecha;
  final VoidCallback onAgregar;
  final ValueChanged<DireccionCliente> onEditar;
  final ValueChanged<DireccionCliente> onEliminar;

  /// Cambia cuando al pagar falta la fecha o la hora: esa fila se sacude.
  final Object? sacudidaFecha;

  /// Cambia cuando al pagar falta una dirección con cobertura: la lista se
  /// sacude.
  final Object? sacudidaDireccion;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSeccion('Dirección de entrega'),
        // Al recargar (tras agregar, editar o borrar) el indicador y la
        // lista se funden y el alto de la sección se acomoda sin saltar.
        Sacudida(
          disparo: sacudidaDireccion,
          child: TamanoAnimado(
            child: CambioAnimado(
              tipo: TipoCambio.atravesar,
              alineacion: AlignmentDirectional.topStart,
              child: vm.cargandoDirecciones
                  ? KeyedSubtree(
                      key: const ValueKey('cargando'),
                      child: Container(
                        height: 90,
                        decoration: decoracionTarjeta(),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.pierVerde, strokeWidth: 2)),
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('direcciones'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...vm.direcciones.map((d) => _TarjetaDireccion(
                                key: ValueKey(d.id),
                                direccion: d,
                                seleccionada: vm.direccion?.id == d.id,
                                onElegir: () => vm.elegirDireccion(d),
                                onEditar: () => onEditar(d),
                                onEliminar: () => onEliminar(d),
                              )),
                          const SizedBox(height: 4),
                          _AgregarDireccion(onTap: onAgregar),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const TituloSeccion('¿Cuándo lo entregamos?'),
        CheckoutFechaHora(
          viewModel: vm,
          onElegirFecha: onElegirFecha,
          sacudida: sacudidaFecha,
        ),
      ],
    );
  }
}

/// "Agregar dirección": la tinta del toque va sobre su fondo verde claro.
class _AgregarDireccion extends StatelessWidget {
  const _AgregarDireccion({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pierVerde.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.pierVerde.withValues(alpha: 0.3)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
            child: Row(children: [
              Icon(LucideIcons.mapPinPlus, color: AppColors.pierVerde, size: 20),
              const SizedBox(width: 10),
              Text('Agregar dirección',
                  style: TextStyle(
                      color: AppColors.pierVerde, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TarjetaDireccion extends StatelessWidget {
  const _TarjetaDireccion({
    required this.direccion,
    required this.seleccionada,
    required this.onElegir,
    required this.onEditar,
    required this.onEliminar,
    super.key,
  });

  final DireccionCliente direccion;
  final bool seleccionada;
  final VoidCallback onElegir;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final d = direccion;
    final sel = seleccionada;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // El borde de la elegida se anima; la tinta del toque (también la de
      // editar y borrar) va encima del fondo blanco.
      child: AnimatedContainer(
        duration: AppMovimiento.duracion(context, AppMovimiento.corta),
        curve: AppMovimiento.curvaEstandar,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel
                ? AppColors.pierVerde
                : AppColors.textSecondary.withValues(alpha: 0.15),
            width: sel ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onElegir,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // El radio se rellena con un pop.
                  CambioAnimado(
                    tipo: TipoCambio.escalar,
                    alineacion: Alignment.center,
                    child: Icon(
                      sel ? LucideIcons.circleDot : LucideIcons.circle,
                      key: ValueKey(sel),
                      color: sel
                          ? AppColors.pierVerde
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(d.alias,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            if (!d.tieneCobertura)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Sin cobertura',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600)),
                              )
                            else
                              Text('\$${d.tarifa!.toStringAsFixed(0)} envío',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.pierVerde,
                                      fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(d.lineaResumen,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (d.referencias != null)
                          Text('Ref: ${d.referencias}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  _Accion(icon: LucideIcons.pencil, onTap: onEditar),
                  const SizedBox(width: 4),
                  _Accion(
                      icon: LucideIcons.trash2,
                      onTap: onEliminar,
                      color: AppColors.error),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 17, color: color ?? AppColors.textSecondary),
      ),
    );
  }
}

/// Fecha (abre el calendario) y hora (lista según el día).
class CheckoutFechaHora extends StatelessWidget {
  const CheckoutFechaHora({
    required this.viewModel,
    required this.onElegirFecha,
    this.sacudida,
    super.key,
  });

  final CheckoutViewModel viewModel;
  final VoidCallback onElegirFecha;

  /// Cambia cuando al pagar falta la fecha o la hora: la fila se sacude.
  final Object? sacudida;

  @override
  Widget build(BuildContext context) {
    final fecha = viewModel.fecha;
    final textoFecha =
        fecha == null ? 'Fecha' : DateFormat('dd/MM/yyyy').format(fecha);
    return Sacudida(
      disparo: sacudida,
      child: Row(
        children: [
          Expanded(
            // Tarjeta debajo y tinta encima: la onda del toque se ve.
            child: Container(
              height: 56,
              decoration: decoracionTarjeta(),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onElegirFecha,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar,
                            size: 20, color: AppColors.pierVerde),
                        const SizedBox(width: 10),
                        // La fecha elegida rueda a su lugar.
                        CambioAnimado(
                          tipo: TipoCambio.subir,
                          child: Text(
                            textoFecha,
                            key: ValueKey(textoFecha),
                            style: TextStyle(
                              color: fecha == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: decoracionTarjeta(),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  icon: Icon(LucideIcons.chevronDown, color: AppColors.pierVerde),
                  hint: Row(children: [
                    Icon(LucideIcons.clock, size: 20, color: AppColors.pierVerde),
                    const SizedBox(width: 10),
                    const Text('Hora'),
                  ]),
                  value: viewModel.hora,
                  items: viewModel.horarios
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: viewModel.elegirHora,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
