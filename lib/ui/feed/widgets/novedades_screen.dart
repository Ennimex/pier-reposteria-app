// lib/ui/feed/widgets/novedades_screen.dart
//
// Novedades (#175): todas las publicaciones de Pier con sus promociones
// intercaladas y, al acabarse, las sugerencias (FeedSliver). Se abre con
// «Ver todo» desde el Inicio y usa su mismo FeedViewModel: «Me encanta» y los
// comentarios se ven igual en las dos pantallas. Pide la siguiente página al
// acercarse al final, también si lo cargado no alcanza a llenar la pantalla.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_reposteria/ui/feed/widgets/feed_sliver.dart';
import 'package:pier_reposteria/utils/logger.dart';
import 'package:provider/provider.dart';

class NovedadesScreen extends StatefulWidget {
  const NovedadesScreen({required this.viewModel, super.key});

  /// El del Inicio, que es su dueño: esta pantalla no lo libera.
  final FeedViewModel viewModel;

  @override
  State<NovedadesScreen> createState() => _NovedadesScreenState();
}

class _NovedadesScreenState extends State<NovedadesScreen> {
  final _control = ScrollController();

  /// Margen (px) antes del final en el que se pide la siguiente página.
  static const _margenCargarMas = 1500.0;

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ NovedadesScreen');
    widget.viewModel.addListener(_alCambiar);
    _alCambiar();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_alCambiar);
    _control.dispose();
    super.dispose();
  }

  /// Después de pintar lo que llegó, revisa si ya se ve casi el final.
  void _alCambiar() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _quizaCargarMas());

  /// Pide más si falta poco para el final. Tras un error espera a que la
  /// persona toque «Reintentar».
  void _quizaCargarMas() {
    if (!mounted ||
        !_control.hasClients ||
        widget.viewModel.errorMas != null) {
      return;
    }
    if (_control.position.extentAfter < _margenCargarMas) {
      unawaited(widget.viewModel.cargarMas());
    }
  }

  bool _alDesplazar(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical) _quizaCargarMas();
    return false;
  }

  /// Agrega desde una promoción o sugerencia y lo avisa.
  Future<void> _agregarAlCarrito(Product producto, double precio) async {
    final avisos = ScaffoldMessenger.of(context);
    final error = await context
        .read<CartProvider>()
        .addItem(producto, 1, 'chico', precio);
    avisos.showSnackBar(SnackBar(
      content: Text(error ?? 'Se agregó al carrito'),
      backgroundColor: error == null ? AppColors.pierVerde : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(
        title: const Text('Novedades de Pier',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: widget.viewModel.recargar,
        color: AppColors.pierVerde,
        child: NotificationListener<ScrollNotification>(
          onNotification: _alDesplazar,
          child: CustomScrollView(
            controller: _control,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              FeedSliver(
                viewModel: widget.viewModel,
                alAgregar: _agregarAlCarrito,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
