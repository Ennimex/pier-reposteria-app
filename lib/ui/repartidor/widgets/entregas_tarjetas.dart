// lib/ui/repartidor/widgets/entregas_tarjetas.dart
//
// Tarjetas de la pestaña «Mis entregas»: título de sección con contador,
// entrega en curso (abre el detalle) y pedido del pool con «Tomar entrega».
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entrega_detail_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/movimiento_repartidor.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';

/// Abre el detalle de [entrega]; lo que cambie ahí recarga el panel.
Future<bool?> abrirEntrega(
  BuildContext context,
  EntregaRepartidor entrega,
  RepartidorViewModel viewModel,
) =>
    Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => EntregaDetailScreen(
          entrega: entrega,
          alCambiar: viewModel.recargar,
        ),
      ),
    );

/// Número de pedido en Playfair (tarjetas del panel).
class NumeroPedido extends StatelessWidget {
  const NumeroPedido(this.numero, {super.key, this.tamano = 18});

  final String numero;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Text(
      numero,
      style: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: tamano,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Monto en verde y negritas.
class MontoVerde extends StatelessWidget {
  const MontoVerde(this.monto, {super.key});

  final double monto;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatMoneyMxn(monto),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.pierVerde,
      ),
    );
  }
}

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.title, {required this.count, super.key});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        _PildoraConteo(cantidad: count),
      ],
    );
  }
}

/// Píldora con la cantidad de una sección (sin nada en 0): aparece
/// creciendo, se va encogiéndose y da un salto solo cuando la cantidad SUBE
/// (una entrega nueva en curso). El número nunca cuenta: cambia de golpe.
/// Montarse con una cantidad no anima, y lo que cambia sin que se vea
/// tampoco.
class _PildoraConteo extends StatefulWidget {
  const _PildoraConteo({required this.cantidad});

  final int cantidad;

  @override
  State<_PildoraConteo> createState() => _PildoraConteoState();
}

class _PildoraConteoState extends State<_PildoraConteo>
    with TickerProviderStateMixin {
  static final Animatable<double> _salto = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.25,
          end: 1,
        ).chain(CurveTween(curve: AppMovimiento.curvaRebote)),
        weight: 65,
      ),
    ],
  );

  late final AnimationController _presencia;
  late final CurvedAnimation _escalaPresencia;
  late final AnimationController _rebote;

  // La píldora que se va conserva su último número (no muestra «0»).
  late int _numero = widget.cantidad;

  @override
  void initState() {
    super.initState();
    _presencia = AnimationController(
      vsync: this,
      duration: AppMovimiento.media,
      reverseDuration: AppMovimiento.rapida,
      value: widget.cantidad > 0 ? 1 : 0,
    )..addStatusListener(_alCambiarPresencia);
    _escalaPresencia = CurvedAnimation(
      parent: _presencia,
      curve: AppMovimiento.curvaRebote,
      reverseCurve: Curves.easeIn,
    );
    _rebote = AnimationController(vsync: this, duration: AppMovimiento.enfasis);
  }

  @override
  void didUpdateWidget(_PildoraConteo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nueva = widget.cantidad;
    final vieja = oldWidget.cantidad;
    if (nueva == vieja) return;
    if (nueva > 0) _numero = nueva;
    final animar = conMovimiento(context);
    if (nueva > 0 && vieja <= 0) {
      if (animar) {
        _presencia.forward().ignore();
      } else {
        _presencia.value = 1;
      }
    } else if (nueva <= 0 && vieja > 0) {
      if (animar) {
        _presencia.reverse().ignore();
      } else {
        _presencia.value = 0;
      }
    } else if (nueva > vieja && animar) {
      _rebote.forward(from: 0).ignore();
    }
  }

  void _alCambiarPresencia(AnimationStatus estado) {
    // Al terminar de encogerse sale del árbol.
    if (estado.isDismissed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _escalaPresencia.dispose();
    _presencia.dispose();
    _rebote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_presencia.isDismissed) return const SizedBox.shrink();
    return ScaleTransition(
      scale: _escalaPresencia,
      child: ScaleTransition(
        scale: _rebote.drive(_salto),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.pierVerde.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_numero',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.pierVerde,
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrega en curso; al tocarla abre su detalle. Se hunde al tocarla, su
/// número y su estado vuelan al detalle y, si acaba de llegar ([nueva]: la
/// entrega recién tomada), un contorno dorado brilla una vez.
class EntregaCard extends StatelessWidget {
  const EntregaCard({
    required this.entrega,
    required this.viewModel,
    this.nueva = false,
    super.key,
  });

  final EntregaRepartidor entrega;
  final RepartidorViewModel viewModel;

  /// Llegó a «En curso» después de la primera carga (solo cuenta al
  /// montarse la tarjeta).
  final bool nueva;

  @override
  Widget build(BuildContext context) {
    return PresionEscala(
      child: GestureDetector(
        onTap: () => abrirEntrega(context, entrega, viewModel),
        child: ContornoDorado(activo: nueva, child: _tarjeta()),
      ),
    );
  }

  Widget _tarjeta() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.pierDorado.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Ceñido al texto: el Hero vuela del tamaño del número.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: HeroEntrega(
                      etiqueta: HeroEntrega.numero(entrega.id),
                      child: NumeroPedido(entrega.numero),
                    ),
                  ),
                ),
                HeroEntrega(
                  etiqueta: HeroEntrega.estado(entrega.id),
                  child: EstadoEntregaChip(estado: entrega.estado),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              entrega.clienteNombreCompleto,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entrega.direccion.colonia ?? 'Sin colonia',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: IconoTexto(
                    icono: LucideIcons.clock,
                    texto: formatHorarioEntrega(entrega.horarioEntrega),
                    tamanoIcono: 18,
                    separacion: 6,
                    unaLinea: true,
                  ),
                ),
                const SizedBox(width: 8),
                if (entrega.metodoPago != null) ...[
                  _MetodoPago(efectivo: entrega.esEfectivo),
                  const SizedBox(width: 10),
                ],
                MontoVerde(entrega.total),
              ],
            ),
          ],
        ),
      );
}

class _MetodoPago extends StatelessWidget {
  const _MetodoPago({required this.efectivo});

  final bool efectivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        efectivo ? 'Efectivo' : 'Tarjeta',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Pedido del pool con botón para tomarlo.
class DisponibleCard extends StatelessWidget {
  const DisponibleCard({
    required this.pedido,
    required this.viewModel,
    super.key,
  });

  final PedidoDisponible pedido;
  final RepartidorViewModel viewModel;

  Future<void> _aceptar(BuildContext context) async {
    final resultado = await viewModel.aceptar(pedido);
    if (!context.mounted) return;
    mostrarAviso(context, resultado.mensaje, ok: resultado.ok);
  }

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final aceptando = viewModel.aceptando(p);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierVerde.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.pierVerde.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: NumeroPedido(p.numero)),
              MontoVerde(p.total),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.clienteNombreCompleto,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          IconoTexto(
            icono: LucideIcons.mapPin,
            texto: p.direccion.colonia ?? 'Sin colonia',
            tamanoTexto: 15,
          ),
          if (p.horarioEntrega != null) ...[
            const SizedBox(height: 4),
            IconoTexto(
              icono: LucideIcons.clock,
              texto: formatHorarioEntrega(p.horarioEntrega),
              unaLinea: true,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: aceptando ? null : () => _aceptar(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: IconoCargando(
                icono: LucideIcons.check,
                cargando: aceptando,
                tamano: 20,
                color: Colors.white,
              ),
              label: Text(aceptando ? 'Tomando…' : 'Tomar entrega'),
            ),
          ),
        ],
      ),
    );
  }
}
