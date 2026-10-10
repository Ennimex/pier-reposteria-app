// lib/ui/checkout/widgets/checkout_entrega.dart
//
// Entrega del checkout: "¿Cómo lo quieres?" (recoger o domicilio), la
// sucursal o las direcciones del cliente, y fecha y hora. Leen y modifican
// el CheckoutViewModel; abrir el calendario y la hoja de dirección, y
// confirmar el borrado, lo hace la pantalla por callbacks.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/domain/models/direccion_model.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_partes.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

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

class _ModalidadCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
          child: Column(
            children: [
              Icon(icon,
                  color: seleccionada ? AppColors.pierVerde : AppColors.textSecondary,
                  size: 28),
              const SizedBox(height: 8),
              Text(titulo,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: seleccionada ? AppColors.pierVerde : AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(sub,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
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
    super.key,
  });

  final CheckoutViewModel viewModel;
  final VoidCallback onElegirFecha;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSeccion('¿Dónde recoges?'),
        Container(
          decoration: decoracionTarjeta(),
          child: ListTile(
            // Pin de ubicación animado (Lottie local, paleta Pier)
            leading: Lottie.asset(
              'assets/lottie/store_location.json',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
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
        CheckoutFechaHora(viewModel: viewModel, onElegirFecha: onElegirFecha),
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
    super.key,
  });

  final CheckoutViewModel viewModel;
  final VoidCallback onElegirFecha;
  final VoidCallback onAgregar;
  final ValueChanged<DireccionCliente> onEditar;
  final ValueChanged<DireccionCliente> onEliminar;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSeccion('Dirección de entrega'),
        if (vm.cargandoDirecciones)
          Container(
            height: 90,
            decoration: decoracionTarjeta(),
            child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.pierVerde, strokeWidth: 2)),
          )
        else ...[
          ...vm.direcciones.map((d) => _TarjetaDireccion(
                direccion: d,
                seleccionada: vm.direccion?.id == d.id,
                onElegir: () => vm.elegirDireccion(d),
                onEditar: () => onEditar(d),
                onEliminar: () => onEliminar(d),
              )),
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAgregar,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.pierVerde.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.pierVerde.withValues(alpha: 0.3)),
                ),
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
        ],
        const SizedBox(height: 24),
        const TituloSeccion('¿Cuándo lo entregamos?'),
        CheckoutFechaHora(viewModel: vm, onElegirFecha: onElegirFecha),
      ],
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onElegir,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
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
            child: Row(
              children: [
                Icon(
                  sel ? LucideIcons.circleDot : LucideIcons.circle,
                  color: sel
                      ? AppColors.pierVerde
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 22,
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
                                color: AppColors.textSecondary.withValues(alpha: 0.8)),
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
    super.key,
  });

  final CheckoutViewModel viewModel;
  final VoidCallback onElegirFecha;

  @override
  Widget build(BuildContext context) {
    final fecha = viewModel.fecha;
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onElegirFecha,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: decoracionTarjeta(),
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 20, color: AppColors.pierVerde),
                    const SizedBox(width: 10),
                    Text(
                      fecha == null ? 'Fecha' : DateFormat('dd/MM/yyyy').format(fecha),
                      style: TextStyle(
                        color: fecha == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
    );
  }
}
