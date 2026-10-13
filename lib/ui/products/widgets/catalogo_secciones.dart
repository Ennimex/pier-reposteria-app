// lib/ui/products/widgets/catalogo_secciones.dart
//
// Secciones del catálogo: encabezado verde con carrito y buscador, chips de
// categoría y estado vacío. Pintan lo que expone el ProductsViewModel; la
// pantalla las repinta cuando cambia.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/products/view_model/products_view_model.dart';
import 'package:pier_pasteleria/ui/products/widgets/catalogo_sheets.dart';
import 'package:pier_pasteleria/ui/products/widgets/movimiento_catalogo.dart';
import 'package:provider/provider.dart';

IconData _iconoDeCategoria(String nombre) {
  switch (nombre.toLowerCase()) {
    case 'todos': return LucideIcons.layoutGrid;
    case 'pasteles': return LucideIcons.cake;
    case 'roscas': return LucideIcons.donut;
    case 'pays': return LucideIcons.chartPie;
    case 'postres': return LucideIcons.cookie;
    case 'cafetería':
    case 'cafeteria': return LucideIcons.coffee;
    case 'bebidas': return LucideIcons.cupSoda;
    case 'panes': return LucideIcons.croissant;
    default: return LucideIcons.sandwich;
  }
}

/// Encabezado verde: nombre de la tienda, carrito con contador y buscador
/// (con ordenar y filtrar mientras no haya texto).
class CatalogoHeader extends StatelessWidget {
  const CatalogoHeader({
    required this.viewModel,
    required this.buscador,
    required this.cantidadCarrito,
    super.key,
  });

  final ProductsViewModel viewModel;
  final TextEditingController buscador;
  final int cantidadCarrito;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pierVerde,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 20, bottom: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pier Repostería',
                      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Artesanal & Gourmet',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
              PresionEscala(
                escala: AppMovimiento.escalaPresionChica,
                child: GestureDetector(
                  onTap: () => context.read<NavigationProvider>().setSelectedIndex(2),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.shoppingCart, color: Colors.white, size: 22),
                      ),
                      // Como la de la barra: aparece creciendo, rebota solo
                      // cuando sube y se encoge al vaciarse el carrito.
                      Positioned(
                        right: -6, top: -6,
                        child: InsigniaCarrito(
                          cantidad: cantidadCarrito,
                          color: AppColors.pierDorado,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buscador(context),
        ],
      ),
    );
  }

  Widget _buscador(BuildContext context) {
    final vm = viewModel;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: buscador,
        onChanged: vm.buscar,
        decoration: InputDecoration(
          hintText: 'Busca tu antojo...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 15),
          prefixIcon: const Icon(LucideIcons.search, color: AppColors.textSecondary, size: 22),
          // Ordenar/filtrar ↔ borrar: el que llega crece con un rebote y el
          // que se va se apaga, pegados al borde derecho del buscador.
          suffixIcon: CambioAnimado(
            tipo: TipoCambio.escalar,
            alineacion: AlignmentDirectional.centerEnd,
            child: vm.busqueda.isNotEmpty
                ? IconButton(
                    key: const ValueKey('borrar'),
                    icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 18),
                    onPressed: () {
                      buscador.clear();
                      vm.limpiarBusqueda();
                    })
                : Row(
                    key: const ValueKey('ordenarFiltrar'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(LucideIcons.arrowUpDown, color: AppColors.textSecondary, size: 20),
                          onPressed: () => mostrarOrdenCatalogo(context, vm), tooltip: 'Ordenar'),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: IconoColorAnimado(LucideIcons.slidersHorizontal,
                                color: vm.hayFiltrosDeOpciones ? AppColors.pierVerde : Colors.grey, tamano: 20),
                            onPressed: () => mostrarFiltrosCatalogo(context, vm), tooltip: 'Filtrar'),
                          // El punto de "hay filtros" aparece con un pop y se
                          // encoge al quitarlos.
                          Positioned(right: 8, top: 8,
                              child: IgnorePointer(
                                child: AnimatedScale(
                                  scale: vm.hayFiltrosDeOpciones ? 1 : 0,
                                  duration: AppMovimiento.duracion(context, AppMovimiento.corta),
                                  curve: vm.hayFiltrosDeOpciones
                                      ? AppMovimiento.curvaRebote
                                      : AppMovimiento.curvaSalida,
                                  child: Container(width: 8, height: 8,
                                      decoration: BoxDecoration(color: AppColors.pierVerde, shape: BoxShape.circle)),
                                ),
                              )),
                        ],
                      ),
                    ],
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// Fila deslizable de chips de categoría. Al cambiar de categoría (con un
/// toque o desde el inicio) el chip elegido se desliza al centro de la fila.
class CatalogoCategorias extends StatefulWidget {
  const CatalogoCategorias({required this.viewModel, super.key});

  final ProductsViewModel viewModel;

  @override
  State<CatalogoCategorias> createState() => _CatalogoCategoriasState();
}

class _CatalogoCategoriasState extends State<CatalogoCategorias> {
  late String _categoria = widget.viewModel.categoria;

  // El chip elegido en el último cuadro, si la fila lo construyó.
  BuildContext? _chipElegido;

  @override
  void didUpdateWidget(CatalogoCategorias oldWidget) {
    super.didUpdateWidget(oldWidget);
    final categoria = widget.viewModel.categoria;
    if (categoria == _categoria) return;
    _categoria = categoria;
    // Después del cuadro: el chip ya se pintó como elegido.
    WidgetsBinding.instance.addPostFrameCallback((_) => _centrarElegido());
  }

  void _centrarElegido() {
    final chip = _chipElegido;
    if (!mounted || chip == null || !chip.mounted) return;
    Scrollable.ensureVisible(
      chip,
      alignment: 0.5,
      duration: AppMovimiento.duracion(context, AppMovimiento.media),
      curve: AppMovimiento.curvaEstandar,
    ).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final categorias = viewModel.nombresCategorias;
    _chipElegido = null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categorias.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final nombre = categorias[i];
            final sel = viewModel.categoria == nombre;
            // Builder: el contexto propio del chip (el de itemBuilder es el
            // de toda la lista) para poder llevarlo a la vista.
            return Builder(builder: (chip) {
              if (sel) _chipElegido = chip;
              return PresionEscala(
                escala: AppMovimiento.escalaPresionChica,
                child: GestureDetector(
                  onTap: () => viewModel.seleccionarCategoria(nombre),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.pierVerde : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.2)),
                    ),
                    // Ícono y texto cambian de color junto con el fondo (antes
                    // saltaban mientras el fondo se rellenaba).
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconoColorAnimado(_iconoDeCategoria(nombre), tamano: 13,
                            color: sel ? Colors.white : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        TextoEstiloAnimado(nombre,
                            estilo: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                                color: sel ? Colors.white : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              );
            });
          },
        ),
      ),
    );
  }
}

/// "Sin resultados" con botón para limpiar los filtros (también es lo que se
/// ve si el catálogo no pudo cargar). Entra en cascada: el círculo crece con
/// un rebote, los textos y el botón suben uno tras otro y al final la lupa
/// «busca» una vez de lado a lado.
class CatalogoVacio extends StatefulWidget {
  const CatalogoVacio({required this.onLimpiar, super.key});

  final VoidCallback onLimpiar;

  @override
  State<CatalogoVacio> createState() => _CatalogoVacioState();
}

class _CatalogoVacioState extends State<CatalogoVacio>
    with SingleTickerProviderStateMixin {
  static const Animatable<double> _vaivenLupa = Vaiven(amplitud: 0.03);
  static final Animatable<double> _escalaCirculo =
      Tween<double>(begin: 0.85, end: 1);

  // Un solo controlador para los cuatro bloques, con un tramo por bloque.
  late final AnimationController _control;
  final List<Animation<double>> _opacidades = <Animation<double>>[];
  final List<Animation<double>> _subidas = <Animation<double>>[];
  late Animation<double> _circulo;
  late Animation<double> _lupa;
  bool _preparado = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparado) return;
    _preparado = true;
    // Construido con la pestaña oculta (la primera visita al catálogo):
    // espera a que la pestaña empiece a verse.
    final espera = TickerMode.getValuesNotifier(context).value.enabled
        ? Duration.zero
        : AppMovimiento.trasPestana;
    final total = espera + AppMovimiento.entrada + AppMovimiento.enfasis;
    _control.duration = total;
    Animation<double> tramo(Duration desde, Duration duracion, Curve curva) {
      double fraccion(Duration d) =>
          (espera + d).inMicroseconds / total.inMicroseconds;
      return _control.drive(CurveTween(
          curve: Interval(fraccion(desde), fraccion(desde + duracion),
              curve: curva)));
    }

    for (var i = 0; i < 4; i++) {
      final desde = AppMovimiento.retrasoCascada(i);
      // El fundido termina antes que la subida: ya se lee mientras asienta.
      _opacidades.add(tramo(desde, AppMovimiento.entrada * 0.6, Curves.easeOut));
      _subidas.add(tramo(desde, AppMovimiento.entrada, AppMovimiento.curvaEntrada));
    }
    _circulo = tramo(Duration.zero, AppMovimiento.entrada, AppMovimiento.curvaRebote);
    _lupa = tramo(AppMovimiento.entrada, AppMovimiento.enfasis, Curves.linear);
    if (AppMovimiento.reducido(context)) {
      _control.value = 1;
      return;
    }
    // Desde un post-frame: en una pestaña oculta el ticker está en pausa y
    // la entrada se ve la primera vez que se abre el catálogo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _control.forward().ignore();
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  /// El bloque [i] de la cascada: aparece y sube [AppMovimiento.distancia].
  Widget _bloque(int i, Widget hijo) => FadeTransition(
        opacity: _opacidades[i],
        // Los lectores de pantalla lo leen desde el primer cuadro.
        alwaysIncludeSemantics: true,
        child: AnimatedBuilder(
          animation: _subidas[i],
          child: hijo,
          builder: (_, bloque) => Transform.translate(
            offset: Offset(0, AppMovimiento.distancia * (1 - _subidas[i].value)),
            child: bloque,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _bloque(
            0,
            ScaleTransition(
              scale: _circulo.drive(_escalaCirculo),
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(color: AppColors.pierVerde.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: RotationTransition(
                  turns: _lupa.drive(_vaivenLupa),
                  child: Icon(LucideIcons.searchX, size: 48, color: AppColors.pierVerde),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _bloque(
            1,
            const Text('Sin resultados',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          _bloque(
            2,
            const Text('Intenta con otros términos\no ajusta los filtros',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 24),
          _bloque(
            3,
            ElevatedButton.icon(
              onPressed: widget.onLimpiar,
              icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
              label: const Text('Limpiar filtros', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
