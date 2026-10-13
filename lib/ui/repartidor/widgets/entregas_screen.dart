// lib/ui/repartidor/widgets/entregas_screen.dart
//
// Pestaña «Mis entregas» (MVVM, Fase 5): disponibilidad, el pool de pedidos
// que se pueden tomar y las entregas en curso. Los datos vienen del
// RepartidorViewModel del shell; las tarjetas están en entregas_tarjetas.dart.
//
// Movimiento: del indicador a la lista con un fundido; la primera carga
// entra en cascada una sola vez (recargar, jalar para refrescar o volver del
// detalle no la repiten); lo que llega o se va después abre o cierra su
// espacio sin saltos, y la entrega recién tomada brilla una vez en «En
// curso».
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entregas_tarjetas.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/movimiento_repartidor.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:provider/provider.dart';

class EntregasScreen extends StatelessWidget {
  const EntregasScreen({required this.viewModel, super.key});

  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final user = context.watch<AuthProvider>().currentUser;

    return Column(
      children: [
        // ── HEADER ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              const Text(
                'Mis entregas',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              InicialesAvatar(
                iniciales: inicialesDe(
                  user?['nombre']?.toString() ?? '',
                  user?['apellido']?.toString() ?? '',
                ),
                size: 44,
                background: AppColors.pierVerde,
                foreground: Colors.white,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListenableBuilder(
            listenable: viewModel,
            // Del indicador a la lista con un fundido (las tarjetas traen su
            // propia cascada).
            builder: (context, _) => CambioEnVista(
              clave: viewModel.cargando,
              child: viewModel.cargando
                  ? Center(
                      child:
                          CircularProgressIndicator(color: AppColors.pierVerde))
                  : RefreshIndicator(
                      color: AppColors.pierVerde,
                      onRefresh: viewModel.recargar,
                      child: _ListaEntregas(viewModel: viewModel),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// La lista de la pestaña. Cada hijo de primer nivel lleva Key (el aviso de
/// error y el pool son condicionales: sin Keys los elementos se cruzarían de
/// lugar al recargar) y vive en un AmbitoEntradas: la primera carga es una
/// cascada y lo que se construye después llega quieto. Lo que entra o sale
/// más tarde lo animan Aparicion y ColumnaAnimada.
class _ListaEntregas extends StatefulWidget {
  const _ListaEntregas({required this.viewModel});

  final RepartidorViewModel viewModel;

  @override
  State<_ListaEntregas> createState() => _ListaEntregasState();
}

class _ListaEntregasState extends State<_ListaEntregas> {
  // El aviso que se apaga conserva su texto.
  String _ultimoError = '';

  // Entregas en curso de la última vez y las que acaban de llegar (brillan
  // al montarse; la marca dura un cuadro).
  Set<String>? _activasPrevias;
  Set<String> _nuevas = const <String>{};

  // Recargas que fallaron a la vista: cada una sacude el aviso al aparecer
  // (el de la primera carga no: ya entra con la cascada).
  bool? _habiaError;
  int _fallos = 0;

  void _detectarNuevas(List<EntregaRepartidor> activas) {
    final ids = <String>{for (final e in activas) e.id};
    final previas = _activasPrevias;
    _activasPrevias = ids;
    if (previas == null || setEquals(previas, ids)) return;
    _nuevas = ids.difference(previas);
    if (_nuevas.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nuevas = const <String>{};
    });
  }

  void _detectarFallo({required bool hayError}) {
    final habia = _habiaError;
    _habiaError = hayError;
    if (habia == false && hayError && seVe(context)) _fallos++;
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final error = vm.errorCarga;
    if (error != null) _ultimoError = error;
    _detectarNuevas(vm.activas);
    _detectarFallo(hayError: error != null);
    // Abrir o cerrar espacios: inmediato si no se ve o con menos movimiento.
    final espacio =
        conMovimiento(context) ? AppMovimiento.corta : Duration.zero;

    return AmbitoEntradas(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // El aviso de error abre su espacio y, si llega al recargar, se
          // sacude; al resolverse se apaga y lo cierra.
          KeyedSubtree(
            key: const ValueKey<String>('error'),
            child: Sacudida(
              disparo: _fallos == 0 ? null : _fallos,
              child: Aparicion(
                visible: error != null,
                duracion: espacio,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: EntradaSuave(
                    id: 'error',
                    child: _ErrorCarga(mensaje: _ultimoError),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            key: const ValueKey<String>('disponibilidad'),
            padding: const EdgeInsets.only(bottom: 20),
            child: EntradaSuave(
              id: 'disponibilidad',
              child: _DisponibilidadCard(viewModel: vm),
            ),
          ),

          // ── Pool de pedidos disponibles para tomar ──
          KeyedSubtree(
            key: const ValueKey<String>('disponibles'),
            child: Aparicion(
              visible: vm.disponibles.isNotEmpty,
              duracion: espacio,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EntradaSuave(
                        id: 'titulo-disponibles',
                        child: TituloSeccion(
                          'Disponibles',
                          count: vm.disponibles.length,
                        ),
                      ),
                    ),
                    // El pedido que alguien toma cierra su espacio.
                    ColumnaAnimada(
                      children: [
                        for (final p in vm.disponibles)
                          Padding(
                            key: ValueKey<String>('disp-${p.pedidoId}'),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: EntradaSuave(
                              id: 'disp-${p.pedidoId}',
                              child: DisponibleCard(pedido: p, viewModel: vm),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Mis entregas en curso ──
          Padding(
            key: const ValueKey<String>('titulo-curso'),
            padding: const EdgeInsets.only(bottom: 12),
            child: EntradaSuave(
              id: 'titulo-curso',
              child: TituloSeccion('En curso', count: vm.activas.length),
            ),
          ),
          KeyedSubtree(
            key: const ValueKey<String>('curso'),
            // Del estado vacío a las tarjetas (o entre sus dos versiones)
            // con un fundido a través; el alto se ajusta sin saltos.
            child: TamanoSuave(
              recorte: Clip.none,
              child: CambioEnVista(
                clave: vm.activas.isEmpty
                    ? 'vacio-${vm.disponible}'
                    : 'tarjetas',
                tipo: TipoCambio.atravesar,
                alineacion: AlignmentDirectional.topCenter,
                child: vm.activas.isEmpty
                    ? EntradaSuave(
                        id: 'vacio',
                        child: _EmptyState(disponible: vm.disponible),
                      )
                    // La entrega que llega abre su espacio y brilla; la que
                    // se va lo cierra.
                    : ColumnaAnimada(
                        children: [
                          for (final e in vm.activas)
                            Padding(
                              key: ValueKey<String>('curso-${e.id}'),
                              padding: const EdgeInsets.only(bottom: 16),
                              child: EntradaSuave(
                                id: 'curso-${e.id}',
                                child: EntregaCard(
                                  entrega: e,
                                  viewModel: vm,
                                  nueva: _nuevas.contains(e.id),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisponibilidadCard extends StatelessWidget {
  const _DisponibilidadCard({required this.viewModel});

  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final n = viewModel.activas.length;
    final s = n == 1 ? '' : 's';
    final subtitulo = !viewModel.disponible
        ? 'No estás recibiendo entregas'
        : n == 0
            ? 'Sin entregas activas por ahora'
            : 'Tienes $n entrega$s activa$s para hoy';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierDorado.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Disponible para entregas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SwitchDisponible(viewModel: viewModel),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // El rayo y la pausa se cambian con un pop; el subtítulo sube
              // en su lugar.
              SizedBox.square(
                dimension: 18,
                child: CambioEnVista(
                  clave: viewModel.disponible,
                  tipo: TipoCambio.escalar,
                  alineacion: Alignment.center,
                  child: Icon(
                    viewModel.disponible
                        ? LucideIcons.zap
                        : LucideIcons.circlePause,
                    size: 18,
                    color: AppColors.pierVerde,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                // Ventanita del renglón: el texto que sale no pisa el título.
                child: ClipRect(
                  child: CambioEnVista(
                    clave: subtitulo,
                    tipo: TipoCambio.subir,
                    child: Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aviso de que la última carga de entregas falló.
class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.wifiOff, size: 20, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$mensaje. Desliza hacia abajo para reintentar.',
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.disponible});

  final bool disponible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                disponible ? LucideIcons.truck : LucideIcons.circlePause,
                size: 46,
                color: AppColors.pierVerde.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              disponible ? 'Sin entregas por ahora' : 'No estás disponible',
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              disponible
                  ? 'Toma un pedido de "Disponibles"\ny aparecerá aquí.'
                  : 'Actívate arriba para tomar\nnuevas entregas.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
