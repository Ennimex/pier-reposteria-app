// lib/ui/pedidos_personal/widgets/pedidos_del_dia_dialogos.dart
//
// Diálogos de «Pedidos del día» (#137), con los textos de la web
// (GestionPedidos.tsx): confirmar marcar listo, entregar o volver a enviar;
// el motivo para cancelar o rechazar (5 a 300 caracteres) y la lista de
// repartidores para asignar (los no disponibles no se pueden elegir).
import 'package:flutter/material.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/domain/models/pedido_del_dia.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/pedidos_personal/view_model/pedidos_del_dia_view_model.dart';

/// Título, texto y botón de una confirmación.
class ConfirmacionPedido {
  const ConfirmacionPedido(this.titulo, this.texto, this.boton);

  factory ConfirmacionPedido.listo(PedidoDelDia p) => ConfirmacionPedido(
        'Marcar como listo',
        p.esDomicilio
            ? 'Le avisaremos al cliente que su pedido está listo; quedará en '
                'espera de repartidor.'
            : 'Le avisaremos al cliente, con notificación y correo, que ya '
                'puede pasar por su pedido.',
        'Marcar listo',
      );

  static const entregar = ConfirmacionPedido(
    'Entregar al cliente',
    'Confirma que el cliente ya recibió su pedido. Pasará a Historial como '
        'completado y le avisaremos que se entregó.',
    'Entregar',
  );

  static const volverAEnviar = ConfirmacionPedido(
    'Volver a enviar',
    'El pedido regresa a Listo para asignarle repartidor otra vez. Le '
        'avisaremos al cliente que su pedido está listo.',
    'Volver a Listo',
  );

  final String titulo;
  final String texto;
  final String boton;
}

/// true si la persona confirmó.
Future<bool> confirmarAccion(
  BuildContext context,
  ConfirmacionPedido c,
) async {
  final si = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(c.titulo),
      content: Text(c.texto),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.pierVerde),
          onPressed: () => Navigator.pop(context, true),
          child: Text(c.boton),
        ),
      ],
    ),
  );
  return si ?? false;
}

/// Lo que dice el diálogo del motivo.
class MotivoPedido {
  const MotivoPedido(this.titulo, this.aviso, this.boton);

  factory MotivoPedido.cancelar(String numero) => MotivoPedido(
        'Cancelar el pedido $numero',
        'Si el pedido está pagado se generará la solicitud de reembolso, que '
            'revisa gerencia; si tiene repartidor, se le retira la entrega.',
        'Cancelar pedido',
      );

  factory MotivoPedido.rechazar(String numero) => MotivoPedido(
        'Rechazar el pedido $numero',
        'Se cancelará, se generará la solicitud de reembolso y le avisaremos '
            'al cliente.',
        'Rechazar y reembolsar',
      );

  final String titulo;
  final String aviso;
  final String boton;
}

/// El motivo escrito (ya validado), o null si se arrepintió.
Future<String?> pedirMotivo(BuildContext context, MotivoPedido m) =>
    showDialog<String>(
      context: context,
      builder: (_) => _DialogoMotivo(m),
    );

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo(this.m);

  final MotivoPedido m;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _texto = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _aceptar() {
    final error = PedidosDelDiaViewModel.validarMotivo(_texto.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _texto.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.m.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.m.aviso, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _texto,
            maxLength: 300,
            maxLines: 3,
            minLines: 1,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Motivo',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _aceptar,
          child: Text(widget.m.boton),
        ),
      ],
    );
  }
}

/// El id del repartidor elegido, o null si se arrepintió. Si la lista no
/// carga, lo dice en la hoja.
Future<int?> elegirRepartidor(
  BuildContext context,
  Future<List<RepartidorDisponible>> Function() cargar,
) =>
    showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HojaRepartidores(cargar),
    );

class _HojaRepartidores extends StatefulWidget {
  const _HojaRepartidores(this.cargar);

  final Future<List<RepartidorDisponible>> Function() cargar;

  @override
  State<_HojaRepartidores> createState() => _HojaRepartidoresState();
}

class _HojaRepartidoresState extends State<_HojaRepartidores> {
  late final Future<List<RepartidorDisponible>> _lista = widget.cargar();
  int? _elegido;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FutureBuilder<List<RepartidorDisponible>>(
          future: _lista,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final error = snap.error;
            if (error != null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error is ApiException
                    ? error.message
                    : 'No se pudieron cargar los repartidores'),
              );
            }
            final repartidores = snap.data ?? const [];
            if (repartidores.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay repartidores registrados'),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Asignar repartidor',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                RadioGroup<int>(
                  groupValue: _elegido,
                  onChanged: (v) => setState(() => _elegido = v),
                  child: Column(children: [
                    for (final r in repartidores)
                      RadioListTile<int>(
                        value: r.id,
                        enabled: r.disponible,
                        title: Text(r.nombre),
                        subtitle: Text(r.disponible
                            ? (r.entregasActivas == 0
                                ? 'Sin entregas activas'
                                : '${r.entregasActivas} entregas activas')
                            : 'No disponible'),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pierVerde),
                  onPressed: _elegido == null
                      ? null
                      : () => Navigator.pop(context, _elegido),
                  child: const Text('Asignar'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
