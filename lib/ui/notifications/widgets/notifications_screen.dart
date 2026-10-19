// lib/ui/notifications/widgets/notifications_screen.dart
//
// «Notificaciones» (MVVM, Fase 5): encabezado con «Leer todas», título con
// cuántas faltan por leer y la lista agrupada en Hoy, Ayer y Anteriores
// (tarjetas en notificaciones_partes.dart). Tocar una la marca como leída.
// El estado vive en NotificationsViewModel; si el backend rechaza algo se
// avisa con un SnackBar.
//
// Movimiento: carga, error, vacío y lista cambian con un fundido a través;
// las tarjetas entran una sola vez (las que llegan por el sondeo con la
// pantalla abierta también entran, arriba, sin repetir las demás); «Leer
// todas» y la insignia aparecen y se van con suavidad y el número rueda.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/state/notification_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/notifications/view_model/notifications_view_model.dart';
import 'package:pier_reposteria/ui/notifications/widgets/notificaciones_partes.dart';
import 'package:pier_reposteria/ui/orders/widgets/movimiento_pedidos.dart';
import 'package:pier_reposteria/utils/logger.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const NotificationsScreen({super.key, this.viewModel});

  final NotificationsViewModel? viewModel;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsViewModel _vm = widget.viewModel ??
      NotificationsViewModel(
          notificaciones: context.read<NotificationProvider>());

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ NotificationsScreen');
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  /// Corre [accion]; si el backend la rechazó muestra el motivo y, si salió
  /// bien y hay [exito], lo confirma.
  Future<void> _hacer(Future<String?> Function() accion,
      {String? exito}) async {
    final motivo = await accion();
    final texto = motivo ?? exito;
    if (texto == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: motivo == null ? AppColors.pierVerde : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _explorarMenu() {
    Navigator.pop(context);
    context.read<NavigationProvider>().goCatalogo();
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _encabezado(context),
              _titulo(),
              Expanded(child: _cuerpo()),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
  Widget _encabezado(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          PresionEscala(
            escala: AppMovimiento.escalaPresionChica,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(LucideIcons.chevronLeft,
                    size: 16, color: AppColors.textPrimary),
              ),
            ),
          ),
          const Spacer(),
          // Aparece con un fundido cuando hay algo por leer y, cuando ya no
          // queda nada, se apaga y sale del árbol.
          CambioAnimado(
            alineacion: AlignmentDirectional.centerEnd,
            child: _vm.noLeidas > 0
                ? KeyedSubtree(
                    key: const ValueKey('leer-todas'),
                    child: PresionEscala(
                      escala: AppMovimiento.escalaPresionChica,
                      child: GestureDetector(
                        onTap: () => _hacer(_vm.marcarTodas,
                            exito: 'Todas marcadas como leídas'),
                        child: Text('Leer todas',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.pierVerde,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('sin-leer-todas')),
          ),
        ],
      ),
    );
  }

  // ── TÍTULO + BADGE ────────────────────────────────────────────────
  Widget _titulo() {
    final noLeidas = _vm.noLeidas;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          const Flexible(
            child: Text('Notificaciones',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ),
          // La insignia aparece (y se va) con un pop y su número rueda: hacia
          // abajo al leer, hacia arriba si llega una nueva.
          CambioAnimado(
            tipo: TipoCambio.escalar,
            child: noLeidas > 0
                ? Padding(
                    key: const ValueKey('insignia'),
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TamanoSuave(
                        alineacion: Alignment.center,
                        child: ContadorRodante(
                            valor: noLeidas,
                            texto: '$noLeidas',
                            alineacion: Alignment.center,
                            estilo: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('sin-insignia')),
          ),
        ],
      ),
    );
  }

  // ── LISTA ─────────────────────────────────────────────────────────
  /// Carga, error, vacío o lista. Cambian con un fundido a través: lo que se
  /// va se apaga rápido y sale del árbol.
  Widget _cuerpo() {
    final (estado, contenido) = _estadoDelCuerpo();
    return CambioAnimado(
      tipo: TipoCambio.atravesar,
      child: KeyedSubtree(key: ValueKey(estado), child: contenido),
    );
  }

  (String, Widget) _estadoDelCuerpo() {
    if (_vm.cargando) {
      return (
        'cargando',
        Center(child: CircularProgressIndicator(color: AppColors.pierVerde)),
      );
    }
    final error = _vm.errorCarga;
    if (error != null) {
      return (
        'error',
        AvisoNotificaciones(
          icono: LucideIcons.wifiOff,
          titulo: 'Algo salió mal',
          texto: error,
          boton: 'Reintentar',
          iconoBoton: LucideIcons.refreshCw,
          onPressed: _vm.cargar,
        ),
      );
    }
    if (_vm.notificaciones.isEmpty) {
      return (
        'vacia',
        AvisoNotificaciones(
          icono: LucideIcons.bellOff,
          titulo: 'Sin notificaciones',
          texto: 'Aquí aparecerán tus pedidos, promociones y novedades de '
              'Pier Repostería.',
          boton: 'Explorar Menú',
          iconoBoton: LucideIcons.cake,
          onPressed: _explorarMenu,
          mecerIcono: true,
        ),
      );
    }
    return ('lista', _lista());
  }

  /// La lista agrupada. Cada separador y cada tarjeta entra una sola vez:
  /// las que ya se vieron no se repiten al refrescar ni con el sondeo, y las
  /// que llegan con la pantalla abierta entran como una tanda nueva. Solo
  /// las primeras posiciones animan; lo que se construye al hacer scroll
  /// llega quieto.
  Widget _lista() {
    final espera = esperaDeLlegada(context);
    final hijos = <Widget>[];
    // Cada elemento lleva su Key: una notificación que llega arriba no
    // reconstruye a las demás.
    Widget entrada(String id, Widget hijo) => EntradaSuave(
          key: ValueKey(id),
          id: id,
          retraso: espera,
          animar: hijos.length < _posicionesAnimadas,
          child: hijo,
        );
    for (final grupo in _vm.grupos) {
      // ── SEPARADOR DE GRUPO ─────────
      hijos.add(entrada(
        'grupo-${grupo.titulo}',
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(grupo.titulo,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
          ),
        ),
      ));
      for (final n in grupo.notificaciones) {
        hijos.add(entrada(
          'notificacion-${n.id}',
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NotificacionTarjeta(
              notificacion: n,
              cuando: _vm.cuando(n),
              onTap: () => _hacer(() => _vm.marcarLeida(n)),
            ),
          ),
        ));
      }
    }
    return RefreshIndicator(
      onRefresh: () => _hacer(_vm.refrescar),
      color: AppColors.pierVerde,
      child: AmbitoEntradas(
        soloPrimeraTanda: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: hijos,
        ),
      ),
    );
  }

  /// Posiciones de la lista que entran animadas (lo que cabe en pantalla).
  static const int _posicionesAnimadas = 8;
}
