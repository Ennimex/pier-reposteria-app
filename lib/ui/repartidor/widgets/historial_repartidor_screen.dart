// lib/ui/repartidor/widgets/historial_repartidor_screen.dart
//
// Pestaña «Historial» (MVVM, Fase 5): entregas finalizadas hoy (entregadas y
// fallidas) y el total del día. Los datos vienen del RepartidorViewModel
// del shell.
//
// Movimiento: la pestaña se construye oculta; la primera vez que se abre,
// las finalizadas entran en cascada, su barra de estado se traza de
// izquierda a derecha y el total del día sube al final. Después solo entra
// lo nuevo (una entrega que se acaba de cerrar), nunca lo que ya se vio.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/entrega_model.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/repartidor/view_model/repartidor_view_model.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/entregas_tarjetas.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/movimiento_repartidor.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:provider/provider.dart';

class HistorialRepartidorScreen extends StatelessWidget {
  const HistorialRepartidorScreen({required this.viewModel, super.key});

  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return PrimeraVista(
      builder: (context, vista, _) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final historial = viewModel.historial;
          return Column(
            children: [
              // ── HEADER ──────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial',
                      style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Entregas finalizadas hoy',
                      style:
                          TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                // La primera carga ocurre con la pestaña oculta: el cambio
                // llega resuelto y no se repite al abrirla.
                child: CambioEnVista(
                  clave: viewModel.cargando,
                  child: viewModel.cargando
                      ? Center(
                          child: CircularProgressIndicator(
                              color: AppColors.pierVerde))
                      : RefreshIndicator(
                          color: AppColors.pierVerde,
                          onRefresh: viewModel.recargar,
                          // Vacío ↔ lista sin fundido: nunca dos Scrollables
                          // a la vez bajo el mismo RefreshIndicator.
                          child: historial.isEmpty
                              ? _SinHistorial(vista: vista)
                              : _ListaHistorial(
                                  historial: historial,
                                  viewModel: viewModel,
                                  vista: vista,
                                ),
                        ),
                ),
              ),
              Aparicion(
                visible: historial.isNotEmpty,
                duracion: conMovimiento(context)
                    ? AppMovimiento.corta
                    : Duration.zero,
                child: vista
                    // El total del día sube desde abajo, el último.
                    ? EntradaSuave(
                        retraso: AppMovimiento.trasPestana,
                        orden: 3,
                        desplazamiento:
                            const Offset(0, AppMovimiento.distanciaLarga),
                        child: _TotalDiaBar(viewModel: viewModel),
                      )
                    : _TotalDiaBar(viewModel: viewModel),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SinHistorial extends StatelessWidget {
  const _SinHistorial({required this.vista});

  /// La pestaña ya se vio: el mensaje entra con su cascada.
  final bool vista;

  @override
  Widget build(BuildContext context) {
    const icono =
        Icon(LucideIcons.history, size: 60, color: AppColors.textSecondary);
    const texto = Text(
      'Aún no hay entregas finalizadas hoy',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        color: AppColors.textSecondary,
      ),
    );
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (vista)
                    const EntradaSuave(
                      retraso: AppMovimiento.trasPestana,
                      escalaInicial: 0.85,
                      child: icono,
                    )
                  else
                    icono,
                  const SizedBox(height: 16),
                  if (vista)
                    const EntradaSuave(
                      retraso: AppMovimiento.trasPestana,
                      orden: 1,
                      child: texto,
                    )
                  else
                    texto,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Las finalizadas. Cada fila entra una sola vez: la primera vez que la
/// pestaña se ve entran todas en cascada y después solo las que el
/// repartidor no había visto (lo que aparece al hacer scroll llega quieto).
class _ListaHistorial extends StatefulWidget {
  const _ListaHistorial({
    required this.historial,
    required this.viewModel,
    required this.vista,
  });

  final List<EntregaRepartidor> historial;
  final RepartidorViewModel viewModel;
  final bool vista;

  @override
  State<_ListaHistorial> createState() => _ListaHistorialState();
}

class _ListaHistorialState extends State<_ListaHistorial> {
  // Entregas que ya estaban en la lista cuando el repartidor la vio.
  final Set<String> _vistas = <String>{};

  @override
  Widget build(BuildContext context) {
    final historial = widget.historial;
    if (widget.vista &&
        historial.any((e) => !_vistas.contains(e.id))) {
      // Tras este cuadro, todo lo que hay cuenta como visto.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _vistas.addAll(widget.historial.map((e) => e.id));
      });
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: historial.length,
      // Se pregunta al construir cada fila (también las que llegan con el
      // scroll), no al construir la lista.
      itemBuilder: (_, i) => _fila(i),
      // Una entrega que llega arriba no remonta las filas de abajo.
      findChildIndexCallback: (clave) {
        final i = clave is ValueKey<String>
            ? historial.indexWhere((e) => e.id == clave.value)
            : -1;
        return i < 0 ? null : i;
      },
    );
  }

  Widget _fila(int i) {
    final historial = widget.historial;
    final entrega = historial[i];
    final nueva = widget.vista && !_vistas.contains(entrega.id);
    // Escalón: cuántas filas nuevas van antes que esta.
    var orden = 0;
    if (nueva) {
      for (var j = 0; j < i; j++) {
        if (!_vistas.contains(historial[j].id)) orden++;
      }
    }
    final item = _HistorialItem(
      entrega: entrega,
      viewModel: widget.viewModel,
      trazar: nueva,
      retrasoBarra: AppMovimiento.trasPestana +
          AppMovimiento.retrasoCascada(orden) +
          AppMovimiento.rapida,
    );
    // El separador va con su fila (antes ListView.separated): la línea
    // aparece junto con la entrega que separa.
    final fila = i == 0
        ? item
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const Divider(height: 28), item],
          );
    return KeyedSubtree(
      key: ValueKey<String>(entrega.id),
      child: widget.vista
          ? EntradaSuave(
              retraso: AppMovimiento.trasPestana,
              orden: orden,
              animar: nueva,
              child: fila,
            )
          : fila,
    );
  }
}

class _HistorialItem extends StatelessWidget {
  const _HistorialItem({
    required this.entrega,
    required this.viewModel,
    required this.trazar,
    required this.retrasoBarra,
  });

  final EntregaRepartidor entrega;
  final RepartidorViewModel viewModel;

  /// La barra de estado se traza al montarse (fila que entra).
  final bool trazar;
  final Duration retrasoBarra;

  @override
  Widget build(BuildContext context) {
    final entregada = entrega.estado == EstadoEntrega.entregada;
    final color = entregada ? AppColors.pierVerde : AppColors.error;

    return PresionEscala(
      child: GestureDetector(
        onTap: () => abrirEntrega(context, entrega, viewModel),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Ceñido al texto: el número vuela al detalle.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: HeroEntrega(
                      etiqueta: HeroEntrega.numero(entrega.id),
                      child: Text(
                        entrega.numero,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                _BarraEstado(
                  color: color,
                  trazar: trazar,
                  retraso: retrasoBarra,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entrega.clienteNombreCompleto,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            IconoTexto(
              icono: LucideIcons.mapPin,
              texto: entrega.direccion.colonia ?? 'Sin colonia',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: IconoTexto(
                    icono: LucideIcons.clock,
                    texto: entrega.finalizadoAt != null
                        ? formatHora(entrega.finalizadoAt!)
                        : '—',
                    tamanoTexto: 13,
                  ),
                ),
                Text(
                  entregada ? formatMoneyMxn(entrega.total) : 'Fallida',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// La barra de color de una finalizada (verde entregada, roja fallida). La
/// de una fila que entra se traza de izquierda a derecha, como un trazo de
/// «hecho»; en reposo es la misma barra de siempre.
class _BarraEstado extends StatelessWidget {
  const _BarraEstado({
    required this.color,
    required this.trazar,
    required this.retraso,
  });

  final Color color;
  final bool trazar;
  final Duration retraso;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 10,
      child: ProgresoAnimado(
        valor: 1,
        desdeCero: trazar,
        retraso: retraso,
        curva: AppMovimiento.curvaEntrada,
        builder: (context, avance, _) => FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: avance,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalDiaBar extends StatelessWidget {
  const _TotalDiaBar({required this.viewModel});

  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final entregas = viewModel.entregadasCount;
    final fallos = viewModel.fallidasCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierVerde,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total del día',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoneyMxn(viewModel.totalDia),
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$entregas entrega${entregas == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$fallos fallo${fallos == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
