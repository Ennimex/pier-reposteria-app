// lib/ui/public/widgets/about_us_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/utils/config_format.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  final _configRepo = ConfiguracionRepository();

  // Textos por defecto de la app. Si Dirección los captura en el panel
  // (configuracion/nosotros, misma fuente que Nosotros.tsx) se reemplazan.
  String _historiaTitulo = 'Nuestra Historia';
  String _historia =
      'Pier Repostería nació en el corazón de Huejutla de Reyes como un pequeño sueño familiar. Lo que comenzó en una cocina casera, horneando con recetas de la abuela, hoy es un referente de sabor y tradición en la Huasteca Hidalguense.';
  String _mision =
      'Crear momentos inolvidables a través de sabores auténticos y una calidad artesanal inigualable.';
  String _vision =
      'Ser la pastelería líder en la región, reconocida por nuestra innovación constante sin perder la esencia tradicional.';
  List<(String, IconData)> _valores = const [
    ('Calidad Artesanal',        LucideIcons.handshake),
    ('Ingredientes Frescos',     LucideIcons.leaf),
    ('Atención Personalizada',   Icons.favorite_outline_rounded),
    ('Tradición e Innovación',   Icons.star_outline_rounded),
  ];
  List<(String, String)> _stats = const [
    ('100%', 'Artesanal'),
    ('+ 5 años', 'Experiencia'),
    ('❤️', 'Con amor'),
  ];

  // Iconos que rotan para los valores capturados en el panel (como los
  // VALUE_ICONS de la web: corazón, premio, comunidad, chispa)
  static const List<IconData> _iconosValores = [
    Icons.favorite_outline_rounded,
    LucideIcons.award,
    LucideIcons.users,
    LucideIcons.sparkles,
  ];

  @override
  void initState() {
    super.initState();
    _cargarConfig();
  }

  /// GET /configuracion/nosotros → historia{titulo, contenido, fundacion},
  /// mision, valores[], estadisticas[{numero, label}]; `vision` se lee si
  /// existe. timeline/equipo de la web no se muestran en la app. Cualquier
  /// campo ausente o vacío conserva el texto por defecto.
  Future<void> _cargarConfig() async {
    final r = await _configRepo.seccion('nosotros');
    if (!mounted || r['success'] != true) return;
    final cfg = r['config'];
    if (cfg is! Map) return;

    final historia = parseConfigValor(cfg['historia']);
    String? titulo, contenido, fundacion;
    if (historia is Map) {
      titulo = configTexto(historia['titulo']);
      contenido = configTexto(historia['contenido']);
      fundacion = configTexto(historia['fundacion']);
    } else {
      contenido = configTexto(historia);
    }
    final mision = configTexto(cfg['mision']);
    final vision = configTexto(cfg['vision']);

    final valoresRaw = parseConfigValor(cfg['valores']);
    List<(String, IconData)>? valores;
    if (valoresRaw is List) {
      final v = <(String, IconData)>[];
      for (final x in valoresRaw) {
        final t = x.toString().trim();
        if (t.isNotEmpty) {
          v.add((t, _iconosValores[v.length % _iconosValores.length]));
        }
      }
      if (v.isNotEmpty) valores = v;
    }

    final statsRaw = parseConfigValor(cfg['estadisticas']);
    List<(String, String)>? stats;
    if (statsRaw is List) {
      final lista = <(String, String)>[];
      for (final x in statsRaw) {
        if (x is! Map) continue;
        final n = configTexto(x['numero']);
        final l = configTexto(x['label']);
        if (n != null && l != null) lista.add((n, l));
      }
      if (lista.isNotEmpty) stats = lista.take(4).toList();
    }
    // Sin estadísticas capturadas pero con año de fundación: los años de
    // experiencia se calculan (la web muestra "Desde <fundacion>")
    if (stats == null && fundacion != null) {
      final anio = int.tryParse(fundacion);
      final actual = DateTime.now().year;
      if (anio != null && anio > 1900 && anio < actual) {
        stats = [
          ('100%', 'Artesanal'),
          ('+ ${actual - anio} años', 'Experiencia'),
          ('❤️', 'Con amor'),
        ];
      }
    }

    setState(() {
      if (titulo != null) _historiaTitulo = titulo;
      if (contenido != null) _historia = contenido;
      if (mision != null) _mision = mision;
      if (vision != null) _vision = vision;
      if (valores != null) _valores = valores;
      if (stats != null) _stats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: CustomScrollView(
        slivers: [
          // ── HERO ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1464349095431-e9a21285b5f3?w=600&fit=crop',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.pierVerdeOscuro,
                      child: const Icon(LucideIcons.store,
                          color: Colors.white54, size: 60),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                  // Botón back
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.chevronLeft,
                            size: 16, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  // Título sobre imagen
                  Positioned(
                    bottom: 24, left: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.pierDorado,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('ARTESANAL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                        ),
                        const SizedBox(height: 8),
                        Text(_historiaTitulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── CONTENIDO ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── HISTORIA ────────────────────────────────────
                  Text(
                    _historia,
                    style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.6),
                  ),
                  const SizedBox(height: 28),

                  // ── MISIÓN Y VISIÓN ──────────────────────────────
                  _buildInfoCard(
                    icon: LucideIcons.flag,
                    title: 'Misión',
                    content: _mision,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: LucideIcons.eye,
                    title: 'Visión',
                    content: _vision,
                  ),
                  const SizedBox(height: 28),

                  // ── VALORES ──────────────────────────────────────
                  const Text('Nuestros Valores',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  ..._valores.map((v) => _buildValueTile(v.$1, v.$2)),

                  const SizedBox(height: 28),

                  // ── SUCURSAL ──────────────────────────────────────
                  const Text('Encuéntranos',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 14),
                  _buildBranchCard(),

                  const SizedBox(height: 28),

                  // ── STATS ─────────────────────────────────────────
                  Row(children: [
                    for (var i = 0; i < _stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      _buildStat(_stats[i].$1, _stats[i].$2),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.pierVerde, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(content,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueTile(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.pierDorado.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.pierDorado, size: 18),
        ),
        const SizedBox(width: 12),
        Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
      ]),
    );
  }

  Widget _buildBranchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pierVerdeOscuro,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.pierVerdeOscuro.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(LucideIcons.store,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(BusinessInfo.sucursal,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              SizedBox(height: 3),
              Text('${BusinessInfo.calle}\n${BusinessInfo.ciudad}',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.4)),
              SizedBox(height: 4),
              Text(BusinessInfo.horario,
                  style: TextStyle(
                      color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.pierVerde)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}