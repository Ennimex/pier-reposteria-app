// lib/ui/reviews/widgets/product_reviews_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/create_review_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class ProductReviewsScreen extends StatefulWidget {
  final Product product;
  const ProductReviewsScreen({super.key, required this.product});

  @override
  State<ProductReviewsScreen> createState() =>
      _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  final _resenasRepo = ResenasRepository();

  List<Map<String, dynamic>> _resenas = [];
  bool _isLoading = true;
  int _filtroEstrellas = 0;
  String _orden = 'recientes';
  final Set<String> _likedIds = {};

  double get _ratingPromedio {
    if (_resenas.isEmpty) return 0;
    final suma = _resenas.fold<double>(
        0,
        (s, r) =>
            s + (double.tryParse(r['rating']?.toString() ?? '0') ?? 0));
    return suma / _resenas.length;
  }

  Map<int, int> get _distribucion {
    final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _resenas) {
      final stars =
          (double.tryParse(r['rating']?.toString() ?? '0') ?? 0).round();
      if (dist.containsKey(stars)) dist[stars] = dist[stars]! + 1;
    }
    return dist;
  }

  List<Map<String, dynamic>> get _filtradas {
    var lista = _filtroEstrellas == 0
        ? List<Map<String, dynamic>>.from(_resenas)
        : _resenas.where((r) {
            final s =
                (double.tryParse(r['rating']?.toString() ?? '0') ?? 0)
                    .round();
            return s == _filtroEstrellas;
          }).toList();

    switch (_orden) {
      case 'mejor':
        lista.sort((a, b) =>
            (double.tryParse(b['rating']?.toString() ?? '0') ?? 0)
                .compareTo(
                    double.tryParse(a['rating']?.toString() ?? '0') ??
                        0));
      case 'peor':
        lista.sort((a, b) =>
            (double.tryParse(a['rating']?.toString() ?? '0') ?? 0)
                .compareTo(
                    double.tryParse(b['rating']?.toString() ?? '0') ??
                        0));
      default:
        break;
    }
    return lista;
  }

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ ProductReviewsScreen: ${widget.product.nombre}');
    _cargarResenas();
  }

  Future<void> _cargarResenas() async {
    setState(() => _isLoading = true);
    final result = await _resenasRepo.porProducto(widget.product.id);
    if (!mounted) return;
    if (result['success'] == true) {
      final lista =
          List<Map<String, dynamic>>.from(result['resenas'] ?? []);
      setState(() => _resenas = lista);
      PierLog.info(
          '✅ Reseñas cargadas: ${lista.length} para ${widget.product.nombre}');
    } else {
      PierLog.error('Error al cargar reseñas: ${result['message']}');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleLike(Map<String, dynamic> resena) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final id = resena['id'].toString();
    final yaLiked = _likedIds.contains(id);
    final currentCount =
        int.tryParse(resena['util_count']?.toString() ?? '0') ?? 0;

    // Optimistic update
    setState(() {
      if (yaLiked) {
        _likedIds.remove(id);
        resena['util_count'] = currentCount - 1;
      } else {
        _likedIds.add(id);
        resena['util_count'] = currentCount + 1;
      }
    });

    final result = await _resenasRepo.like(id);
    if (!mounted) return;

    if (result['success'] != true) {
      PierLog.error('Error al dar like a reseña $id');
      setState(() {
        if (yaLiked) {
          _likedIds.add(id);
          resena['util_count'] = currentCount;
        } else {
          _likedIds.remove(id);
          resena['util_count'] = currentCount;
        }
      });
    } else {
      PierLog.info(
          'Like ${yaLiked ? 'removido' : 'agregado'} en reseña $id');
    }
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Hoy';
      if (diff.inDays == 1) return 'Ayer';
      if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
      if (diff.inDays < 14) return 'Hace 1 semana';
      if (diff.inDays < 30)
        return 'Hace ${(diff.inDays / 7).floor()} semanas';
      const months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final filtradas = _filtradas;

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
                  GestureDetector(
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                  GestureDetector(
                    onTap: () {
                      PierLog.nav('→ CreateReviewScreen desde reviews');
                      if (auth.isAuthenticated) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CreateReviewScreen(
                                  product: widget.product)),
                        ).then((_) => _cargarResenas());
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde))
                  : RefreshIndicator(
                      onRefresh: _cargarResenas,
                      color: AppColors.pierVerde,
                      child: CustomScrollView(
                        slivers: [

                          // ── RESUMEN ────────────────────────────
                          SliverToBoxAdapter(
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
                              child: _resenas.isEmpty
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
                                  : _buildResumen(),
                            ),
                          ),

                          // ── FILTROS ────────────────────────────
                          if (_resenas.isNotEmpty)
                            SliverToBoxAdapter(
                                child: _buildFiltros()),

                          // ── LISTA ──────────────────────────────
                          if (_resenas.isEmpty)
                            SliverFillRemaining(
                                child: _buildEmptyState())
                          else if (filtradas.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Text(
                                    'No hay opiniones de $_filtroEstrellas estrella${_filtroEstrellas == 1 ? '' : 's'}',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 32),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child:
                                        _buildReviewCard(filtradas[i]),
                                  ),
                                  childCount: filtradas.length,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── RESUMEN ──────────────────────────────────────────────────────
  Widget _buildResumen() {
    final dist = _distribucion;
    final total = _resenas.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              _ratingPromedio.toStringAsFixed(1),
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
                  (i) => Icon(
                        i < _ratingPromedio.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 16,
                        color: AppColors.pierDorado,
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: AppColors.textSecondary
                              .withValues(alpha: 0.1),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                                  AppColors.pierDorado),
                          minHeight: 8,
                        ),
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
            GestureDetector(
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
                    Text(
                      _orden == 'recientes'
                          ? 'Recientes'
                          : _orden == 'mejor'
                              ? 'Mejor'
                              : 'Peor',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 3),
                    const Icon(LucideIcons.chevronDown,
                        size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int value) {
    final sel = _filtroEstrellas == value;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstrellas = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    sel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  void _showOrdenSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Ordenar por',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ...[
              ('Más recientes', 'recientes',
                  LucideIcons.clock),
              ('Mejor calificación', 'mejor',
                  LucideIcons.thumbsUp),
              ('Peor calificación', 'peor',
                  LucideIcons.thumbsDown),
            ].map((t) {
              final sel = _orden == t.$2;
              return GestureDetector(
                onTap: () {
                  setState(() => _orden = t.$2);
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
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── CARD DE RESEÑA ───────────────────────────────────────────────
  Widget _buildReviewCard(Map<String, dynamic> r) {
    final apellido = (r['autor_apellido'] ?? '') as String;
    final nombre =
        '${r['autor_nombre'] ?? ''} ${apellido.isNotEmpty ? '${apellido[0]}.' : ''}'
            .trim();
    final rating =
        double.tryParse(r['rating']?.toString() ?? '5') ?? 5.0;
    final titulo = r['titulo']?.toString() ?? '';
    final comentario = r['comentario']?.toString() ?? '';
    final verificada = r['verificada'] == true;

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
                    Text(_formatFecha(r['created_at']),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _toggleLike(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _likedIds.contains(r['id'].toString())
                        ? AppColors.pierVerde.withValues(alpha: 0.1)
                        : AppColors.textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            _likedIds.contains(r['id'].toString())
                                ? AppColors.pierVerde
                                    .withValues(alpha: 0.3)
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _likedIds.contains(r['id'].toString())
                            ? LucideIcons.thumbsUp
                            : LucideIcons.thumbsUp,
                        size: 14,
                        color: _likedIds.contains(r['id'].toString())
                            ? AppColors.pierVerde
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        (int.tryParse(r['util_count']?.toString() ??
                                    '0') ??
                                0)
                            .toString(),
                        style: TextStyle(
                            fontSize: 12,
                            color: _likedIds
                                    .contains(r['id'].toString())
                                ? AppColors.pierVerde
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.messageSquare,
                size: 46,
                color: AppColors.pierVerde.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          const Text('Sin opiniones aún',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Sé el primero en calificar\neste producto.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}