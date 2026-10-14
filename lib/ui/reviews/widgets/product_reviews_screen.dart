// lib/ui/reviews/widgets/product_reviews_screen.dart
//
// Movimiento: del indicador al contenido con un fundido a través. El
// resumen entra primero: sus estrellas se encienden en fila y las barras de
// la distribución se llenan una tras otra (los números no se animan); luego
// llegan los filtros desde la derecha y las opiniones en cascada. Un filtro
// o un orden nuevo vuelve a repartir las opiniones (las que no son se van al
// instante, sin animación de salida) y centra su chip. «Útil» se hunde al
// tocarlo; al marcarlo, el pulgar da el pop con destello verde del detalle
// del producto y cambia de color junto con la píldora, y la cuenta rueda.
// Recargar no repite las entradas, y la opinión que el cliente acaba de
// publicar llega con un aro dorado.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/domain/models/resena_producto.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/public/widgets/movimiento_contenido.dart';
import 'package:pier_pasteleria/ui/reviews/view_model/product_reviews_view_model.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/create_review_screen.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

class ProductReviewsScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const ProductReviewsScreen({
    required this.product,
    super.key,
    this.viewModel,
  });

  final Product product;
  final ProductReviewsViewModel? viewModel;

  @override
  State<ProductReviewsScreen> createState() =>
      _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final ProductReviewsViewModel _vm = widget.viewModel ??
      ProductReviewsViewModel(
        repo: context.read<ResenasRepository>(),
        productoId: widget.product.id,
      );

  // El resumen y los filtros entran (y las barras se llenan) solo la
  // primera vez que aparecen; una recarga los muestra ya en su lugar.
  bool _resumenVisto = false;
  bool _filtrosVistos = false;

  // Opiniones ya vistas: la que aparezca después (la que el cliente acaba
  // de publicar) se resalta una vez.
  Set<String>? _conocidas;

  // La opinión que el cliente acaba de marcar «útil» con un toque: solo su
  // pulgar destella. Si el toque era para desmarcar y el backend devuelve
  // la marca, no hay nada que celebrar.
  String? _marcadaConToque;

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ ProductReviewsScreen: ${widget.product.nombre}');
    unawaited(_vm.cargar());
  }

  /// La opinión que no estaba la vez anterior. Solo una: una llegada se
  /// resalta; un cambio en bloque (la primera carga, recuperarse de un error)
  /// no.
  Set<String> _nuevas(List<ResenaProducto> lista) {
    final ids = {for (final r in lista) r.id};
    final conocidas = _conocidas;
    if (conocidas == null) {
      _conocidas = ids;
      return const <String>{};
    }
    final nuevas = ids.difference(conocidas);
    conocidas.addAll(ids);
    return nuevas.length == 1 ? nuevas : const <String>{};
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _irALogin() {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => const LoginScreen()))
        .ignore();
  }

  void _toggleLike(ResenaProducto resena) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _irALogin();
      return;
    }
    _marcadaConToque = _vm.esUtil(resena.id) ? null : resena.id;
    unawaited(_vm.alternarUtil(resena.id));
  }

  String _formatFecha(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    if (diff.inDays < 14) return 'Hace 1 semana';
    if (diff.inDays < 30) {
      return 'Hace ${(diff.inDays / 7).floor()} semanas';
    }
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildContenido(),
    );
  }

  Widget _buildContenido() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final resenas = _vm.resenas;
    final filtradas = _vm.filtradas;
    final filtroEstrellas = _vm.filtroEstrellas;
    final orden = _vm.orden;

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  PresionEscala(
                    escala: AppMovimiento.escalaPresionChica,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Opiniones',
                            style: TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text(widget.product.nombre,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  PresionEscala(
                    escala: AppMovimiento.escalaPresionChica,
                    child: GestureDetector(
                      onTap: () {
                        PierLog.nav('→ CreateReviewScreen desde reviews');
                        if (auth.isAuthenticated) {
                          unawaited(Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => CreateReviewScreen(
                                    product: widget.product)),
                          ).then((_) => _vm.cargar()));
                        } else {
                          _irALogin();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.pierVerde,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.pencil,
                                color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text('Escribir',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Indicador ↔ contenido con un fundido a través (recargar
            // también pasa por el indicador, como antes). El ámbito queda
            // afuera: las opiniones ya vistas no vuelven a entrar al
            // recargar; un filtro o un orden nuevo las reparte otra vez.
            Expanded(
              child: AmbitoEntradas(
                generacion: '$filtroEstrellas|$orden',
                child: CambioAnimado(
                  tipo: TipoCambio.atravesar,
                  child: _vm.cargando
                      ? KeyedSubtree(
                          key: const ValueKey('cargando'),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.pierVerde)),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('contenido'),
                          child: _buildCuerpo(
                              resenas, filtradas, filtroEstrellas, orden),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resumen, filtros y opiniones. Lo que se arma durante el push espera a
  /// que llegue la página; lo que llega después entra de inmediato.
  Widget _buildCuerpo(
    List<ResenaProducto> resenas,
    List<ResenaProducto> filtradas,
    int filtroEstrellas,
    OrdenResenas orden,
  ) {
    final espera = esperaDePagina(context);
    // El resumen y los filtros entran solo la primera vez que aparecen.
    final animarResumen = !_resumenVisto;
    _resumenVisto = true;
    final animarFiltros = resenas.isNotEmpty && !_filtrosVistos;
    if (resenas.isNotEmpty) _filtrosVistos = true;
    // En la primera llegada las opiniones esperan al resumen y a los
    // filtros; después de un filtro o un orden nuevo entran de inmediato.
    final esperaLista = animarResumen
        ? espera + AppMovimiento.retrasoCascada(2)
        : Duration.zero;
    final nuevas = _nuevas(resenas);
    final llave = '$filtroEstrellas|$orden';

    return RefreshIndicator(
      onRefresh: _vm.cargar,
      color: AppColors.pierVerde,
      child: CustomScrollView(
        slivers: [

          // ── RESUMEN ────────────────────────────
          SliverToBoxAdapter(
            child: EntradaSuave(
              retraso: espera,
              animar: animarResumen,
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                    16, 0, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: resenas.isEmpty
                    ? const Center(
                        child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                            'Aún no hay calificaciones',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14)),
                      ))
                    : _buildResumen(
                        animar: animarResumen, espera: espera),
              ),
            ),
          ),

          // ── FILTROS ────────────────────────────
          // Llegan desde la derecha, justo después del resumen.
          if (resenas.isNotEmpty)
            SliverToBoxAdapter(
              child: EntradaSuave(
                orden: 1,
                retraso: espera,
                animar: animarFiltros,
                desplazamiento:
                    const Offset(AppMovimiento.distanciaLarga, 0),
                child: _buildFiltros(),
              ),
            ),

          // ── LISTA ──────────────────────────────
          if (resenas.isEmpty)
            SliverFillRemaining(
                child: _buildEmptyState(esperaLista))
          else if (filtradas.isEmpty)
            SliverToBoxAdapter(
              child: EntradaSuave(
                key: ValueKey<String>('sin-$llave'),
                id: 'sin-$llave',
                retraso: esperaLista,
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'No hay opiniones de $filtroEstrellas estrella${filtroEstrellas == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            )
          else
            // Una lista por filtro y orden: la anterior se va de golpe (sin
            // animación de salida) y la nueva entra en cascada.
            SliverPadding(
              key: ValueKey<String>(llave),
              padding: const EdgeInsets.fromLTRB(
                  16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final r = filtradas[i];
                    return EntradaSuave(
                      key: ValueKey<String>(r.id),
                      id: r.id,
                      retraso: esperaLista,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(bottom: 12),
                        child: ResaltadoUnaVez(
                          activo: nuevas.contains(r.id),
                          radio: BorderRadius.circular(16),
                          child: _buildReviewCard(r),
                        ),
                      ),
                    );
                  },
                  childCount: filtradas.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── RESUMEN ──────────────────────────────────────────────────────
  // La primera vez, las estrellas se encienden en fila mientras la tarjeta
  // llega y las barras se llenan una tras otra, de 5★ a 1★. El promedio y
  // los conteos no se animan.
  Widget _buildResumen({required bool animar, required Duration espera}) {
    final dist = _vm.distribucion;
    final total = _vm.resenas.length;
    final promedio = _vm.promedio;
    // Las piezas esperan a que la tarjeta empiece a verse.
    final esperaPiezas = espera + AppMovimiento.retrasoCascada(2);

    return Row(
      children: [
        Column(
          children: [
            Text(
              promedio.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                  5,
                  (i) => PopAlEntrar(
                        animar: animar,
                        retraso:
                            esperaPiezas + AppMovimiento.retrasoCascada(i),
                        child: Icon(
                          i < promedio.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 16,
                          color: AppColors.pierDorado,
                        ),
                      )),
            ),
            const SizedBox(height: 4),
            Text('$total reseña${total == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [5, 4, 3, 2, 1].map((star) {
              final count = dist[star] ?? 0;
              final pct = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      child: Text('$star',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      // Se llena desde cero, una barra tras otra; sin
                      // entrada, aparece ya llena.
                      child: BarraRelleno(
                        fraccion: pct,
                        color: AppColors.pierDorado,
                        fondo: AppColors.textSecondary.withValues(alpha: 0.1),
                        grosor: 8,
                        duracion:
                            animar ? AppMovimiento.relleno : Duration.zero,
                        retraso: esperaPiezas +
                            AppMovimiento.retrasoCascada(5 - star),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      child: Text('$count',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── FILTROS ──────────────────────────────────────────────────────
  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Todas', 0),
            const SizedBox(width: 8),
            ...List.generate(5, (i) {
              final star = 5 - i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _filterChip('$star ★', star),
              );
            }),
            Container(
              width: 1, height: 28,
              color: AppColors.textSecondary.withValues(alpha: 0.2),
              margin: const EdgeInsets.only(right: 8),
            ),
            PresionEscala(
              escala: AppMovimiento.escalaPresionChica,
              child: GestureDetector(
                onTap: _showOrdenSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.textSecondary
                            .withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.arrowUpDown,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      // El orden elegido cambia con un fundido y el chip
                      // ajusta su ancho con suavidad.
                      TamanoSuave(
                        alineacion: AlignmentDirectional.centerStart,
                        child: CambioAnimado(
                          child: Text(
                            switch (_vm.orden) {
                              OrdenResenas.recientes => 'Recientes',
                              OrdenResenas.mejor => 'Mejor',
                              OrdenResenas.peor => 'Peor',
                            },
                            key: ValueKey(_vm.orden),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(LucideIcons.chevronDown,
                          size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // El chip se hunde al tocarlo, su fondo, borde y texto cambian juntos y
  // se centra en su fila.
  Widget _filterChip(String label, int value) {
    final sel = _vm.filtroEstrellas == value;
    return Builder(
      builder: (chip) => PresionEscala(
        escala: AppMovimiento.escalaPresionChica,
        child: GestureDetector(
          onTap: () {
            _vm.filtrar(value);
            centrarEnSuFila(chip);
          },
          child: AnimatedContainer(
            duration: AppMovimiento.duracion(chip, AppMovimiento.corta),
            curve: AppMovimiento.curvaEstandar,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.pierVerde : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel
                      ? AppColors.pierVerde
                      : AppColors.textSecondary.withValues(alpha: 0.2)),
            ),
            child: TextoColorSuave(label,
                estilo: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        sel ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }

  void _showOrdenSheet() {
    unawaited(showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      // Sube con la curva de la casa y sus opciones llegan en cascada.
      sheetAnimationStyle: AppMovimiento.estiloHoja(context),
      builder: (hoja) {
        final espera = esperaDePagina(hoja);
        final opciones = [
          ('Más recientes', OrdenResenas.recientes,
              LucideIcons.clock),
          ('Mejor calificación', OrdenResenas.mejor,
              LucideIcons.thumbsUp),
          ('Peor calificación', OrdenResenas.peor,
              LucideIcons.thumbsDown),
        ];
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24,
              MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              EntradaSuave(
                retraso: espera,
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ordenar por',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < opciones.length; i++)
                EntradaSuave(
                  orden: i + 1,
                  retraso: espera,
                  child: _opcionOrden(opciones[i]),
                ),
            ],
          ),
        );
      },
    ));
  }

  /// Una opción de la hoja de orden: se hunde al tocarla.
  Widget _opcionOrden((String, OrdenResenas, IconData) t) {
    final sel = _vm.orden == t.$2;
    return PresionEscala(
      child: GestureDetector(
        onTap: () {
          _vm.ordenar(t.$2);
          Navigator.pop(context);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.pierVerde.withValues(alpha: 0.08)
                : AppColors.textSecondary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: sel
                ? Border.all(
                    color: AppColors.pierVerde
                        .withValues(alpha: 0.3))
                : null,
          ),
          child: Row(children: [
            Icon(t.$3,
                size: 18,
                color: sel
                    ? AppColors.pierVerde
                    : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
                child: Text(t.$1,
                    style: TextStyle(
                        fontWeight: sel
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: sel
                            ? AppColors.pierVerde
                            : AppColors.textPrimary))),
            if (sel)
              Icon(Icons.check_circle_rounded,
                  color: AppColors.pierVerde, size: 18),
          ]),
        ),
      ),
    );
  }

  // ── CARD DE RESEÑA ───────────────────────────────────────────────
  Widget _buildReviewCard(ResenaProducto r) {
    final nombre = r.autor;
    final rating = r.rating;
    final titulo = r.titulo;
    final comentario = r.comentario;
    final verificada = r.verificada;
    final util = _vm.esUtil(r.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── AUTOR + RATING ─────────────────────────────────
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.pierArena,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    nombre.length >= 2
                        ? nombre.substring(0, 2).toUpperCase()
                        : nombre.isNotEmpty
                            ? nombre[0]
                            : '?',
                    style: TextStyle(
                        color: AppColors.pierDoradoOscuro,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    Text(_formatFecha(r.creadaEn),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.pierDorado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Icon(Icons.star_rounded,
                      color: AppColors.pierDorado, size: 13),
                  const SizedBox(width: 4),
                  Text(rating.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.pierDoradoOscuro)),
                ]),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (verificada) ...[
            Row(children: [
              Icon(LucideIcons.badgeCheck,
                  size: 14, color: AppColors.pierVerde),
              const SizedBox(width: 4),
              Text('Compra verificada',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.pierVerde,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
          ],

          if (titulo.isNotEmpty) ...[
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
          ],

          Text(comentario,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5)),

          const SizedBox(height: 12),

          // «Útil»: la píldora se hunde al tocarla y cambia de color junto
          // con el pulgar y la cuenta; al marcarla, el pulgar da el pop con
          // destello verde del «útil» del detalle del producto y la cuenta
          // rueda (también hacia abajo si el backend la revierte).
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PresionEscala(
                escala: AppMovimiento.escalaPresionChica,
                child: GestureDetector(
                  onTap: () => _toggleLike(r),
                  child: AnimatedContainer(
                    duration:
                        AppMovimiento.duracion(context, AppMovimiento.corta),
                    curve: AppMovimiento.curvaEstandar,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: util
                          ? AppColors.pierVerde.withValues(alpha: 0.1)
                          : AppColors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              util
                                  ? AppColors.pierVerde
                                      .withValues(alpha: 0.3)
                                  : AppColors.textSecondary
                                      .withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DestelloAlMarcar(
                          activo: util,
                          porToque: _marcadaConToque == r.id,
                          color: AppColors.pierVerde,
                          child: IconoColorSuave(
                            LucideIcons.thumbsUp,
                            tamano: 14,
                            color: util
                                ? AppColors.pierVerde
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        EstiloTextoSuave(
                          estilo: TextStyle(
                              fontSize: 12,
                              color: util
                                  ? AppColors.pierVerde
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600),
                          child: CuentaRodante(valor: r.utilCount),
                        ),
                      ],
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

  // El círculo crece apenas mientras aparece y los textos suben detrás de
  // él; una sola vez (una recarga no lo repite).
  Widget _buildEmptyState(Duration espera) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EntradaSuave(
            id: 'vacio-icono',
            retraso: espera,
            escalaInicial: 0.85,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.messageSquare,
                  size: 46,
                  color: AppColors.pierVerde.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 20),
          EntradaSuave(
            id: 'vacio-titulo',
            retraso: espera,
            child: const Text('Sin opiniones aún',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          EntradaSuave(
            id: 'vacio-texto',
            retraso: espera,
            child: const Text('Sé el primero en calificar\neste producto.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
