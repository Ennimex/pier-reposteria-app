// lib/ui/public/widgets/faq_screen.dart
//
// Movimiento: los chips llegan desde la derecha y las preguntas suben en
// cascada después del push; elegir una categoría centra su chip (fondo y
// texto cambian juntos) y vuelve a repartir las preguntas de esa categoría
// (las que no son se van al instante, sin animación de salida); una
// pregunta se abre con la curva enfática, su tarjeta se eleva y la
// respuesta sube mientras aparece.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';
import 'package:pier_reposteria/domain/models/pregunta_frecuente.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/public/view_model/faq_view_model.dart';
import 'package:pier_reposteria/ui/public/widgets/contact_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/movimiento_contenido.dart';
import 'package:provider/provider.dart';

class FAQScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const FAQScreen({super.key, this.viewModel});

  final FaqViewModel? viewModel;

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  // El State solo es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final FaqViewModel _vm =
      widget.viewModel ?? FaqViewModel(repo: context.read<ConfiguracionRepository>());

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildPantalla(context),
    );
  }

  Widget _buildPantalla(BuildContext context) {
    final categorias = _vm.categorias;
    final categoria = _vm.categoriaSeleccionada;
    final preguntas = _vm.filtradas;
    // Al llegar la página, las preguntas esperan a que termine el push; al
    // cambiar de categoría entran de inmediato.
    final espera = esperaDePagina(context);
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
                  const Text('Preguntas Frecuentes',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── FILTROS DE CATEGORÍA ─────────────────────────────
            // La fila llega desde la derecha; cada chip se hunde al tocarlo
            // y su fondo, borde y texto cambian juntos.
            EntradaSuave(
              retraso: espera,
              desplazamiento: const Offset(AppMovimiento.distanciaLarga, 0),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: categorias.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = categorias[i];
                    final sel = categoria == cat;
                    // El contexto propio del chip (el de itemBuilder es el
                    // de la lista) para centrarlo a él.
                    return Builder(
                      builder: (chip) => PresionEscala(
                        escala: AppMovimiento.escalaPresionChica,
                        child: GestureDetector(
                          onTap: () {
                            _vm.seleccionarCategoria(cat);
                            centrarEnSuFila(chip);
                          },
                          child: AnimatedContainer(
                            duration: AppMovimiento.duracion(
                                chip, AppMovimiento.corta),
                            curve: AppMovimiento.curvaEstandar,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.pierVerde : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel
                                      ? AppColors.pierVerde
                                      : AppColors.textSecondary
                                          .withValues(alpha: 0.2)),
                            ),
                            child: TextoColorSuave(cat,
                                estilo: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? Colors.white
                                        : AppColors.textSecondary)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── LISTA ────────────────────────────────────────────
            // Una lista por categoría: al cambiarla, la anterior se va de
            // golpe (sin animación de salida), la nueva empieza arriba y sus
            // preguntas suben en cascada, todas cerradas. Las del panel
            // reemplazan a las de la app en su lugar, sin volver a entrar.
            // La lista arma y desarma sus filas según el scroll: el ámbito
            // hace que cada pregunta entre una sola vez (las que llegan al
            // bajar aparecen ya en su lugar y volver no repite la entrada).
            Expanded(
              child: AmbitoEntradas(
                generacion: categoria,
                child: ListView(
                  key: ValueKey<String>(categoria),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    for (var i = 0; i < preguntas.length; i++)
                      Padding(
                        key: ValueKey<String>('$categoria|$i'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: EntradaSuave(
                          id: '$categoria|$i',
                          // Un escalón detrás de los chips.
                          retraso: espera + AppMovimiento.paso,
                          child: _TarjetaPregunta(pregunta: preguntas[i]),
                        ),
                      ),
                    const SizedBox(height: 16),
                    EntradaSuave(
                      key: ValueKey<String>('$categoria|contacto'),
                      id: '$categoria|contacto',
                      retraso: espera + AppMovimiento.paso,
                      child: _buildContactBanner(context),
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

  Widget _buildContactBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pierVerde,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(LucideIcons.messageCircle,
            color: Colors.white, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿No encontraste tu respuesta?',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 2),
              Text('Nuestro equipo te ayuda',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12)),
            ],
          ),
        ),
        PresionEscala(
          escala: AppMovimiento.escalaPresionChica,
          child: GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ContactScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Contactar',
                  style: TextStyle(
                      color: AppColors.pierVerde,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Una pregunta: se abre con la curva enfática de la casa, la tarjeta se
/// eleva un poco mientras está abierta (sombra más marcada y un filo verde,
/// sin cambiar su tamaño) y la respuesta sube mientras aparece. La respuesta
/// se arma de nuevo en cada apertura, así que su entrada se repite cada vez.
class _TarjetaPregunta extends StatefulWidget {
  const _TarjetaPregunta({required this.pregunta});

  final PreguntaFrecuente pregunta;

  @override
  State<_TarjetaPregunta> createState() => _TarjetaPreguntaState();
}

class _TarjetaPreguntaState extends State<_TarjetaPregunta> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final faq = widget.pregunta;
    final radio = BorderRadius.circular(14);
    return AnimatedContainer(
      duration: AppMovimiento.duracion(context, AppMovimiento.corta),
      curve: AppMovimiento.curvaEstandar,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radio,
        boxShadow: [
          // Mismo desenfoque: solo cambian el tono y la caída de la sombra.
          BoxShadow(
              color: Colors.black.withValues(alpha: _abierta ? 0.08 : 0.04),
              blurRadius: 8,
              offset: Offset(0, _abierta ? 5 : 3))
        ],
      ),
      // El filo va encima (no ocupa espacio): abrir no mueve nada.
      foregroundDecoration: BoxDecoration(
        borderRadius: radio,
        border: Border.all(
            color: AppColors.pierVerde.withValues(alpha: _abierta ? 0.25 : 0)),
      ),
      // Material propio: sin él la onda del ExpansionTile queda tapada por el
      // fondo blanco del Container (aserción de ListTile en debug).
      child: Material(
        color: Colors.transparent,
        borderRadius: radio,
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent),
          child: ExpansionTile(
            expansionAnimationStyle: AppMovimiento.estiloExpansion(context),
            onExpansionChanged: (abierta) =>
                setState(() => _abierta = abierta),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor: AppColors.pierVerde,
            collapsedIconColor:
                AppColors.textSecondary.withValues(alpha: 0.6),
            title: Text(
              faq.pregunta,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary),
            ),
            children: [
              EntradaSuave(
                retraso: AppMovimiento.paso,
                duracion: AppMovimiento.media,
                desplazamiento: const Offset(0, AppMovimiento.distanciaCorta),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pierArena,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    faq.respuesta,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
