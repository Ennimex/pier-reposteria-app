// lib/presentation/screens/public/about_us_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/business_info.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                        const Text('Nuestra Historia',
                            style: TextStyle(
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
                  const Text(
                    'Pier Repostería nació en el corazón de Huejutla de Reyes como un pequeño sueño familiar. Lo que comenzó en una cocina casera, horneando con recetas de la abuela, hoy es un referente de sabor y tradición en la Huasteca Hidalguense.',
                    style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.6),
                  ),
                  const SizedBox(height: 28),

                  // ── MISIÓN Y VISIÓN ──────────────────────────────
                  _buildInfoCard(
                    icon: LucideIcons.flag,
                    title: 'Misión',
                    content:
                        'Crear momentos inolvidables a través de sabores auténticos y una calidad artesanal inigualable.',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: LucideIcons.eye,
                    title: 'Visión',
                    content:
                        'Ser la pastelería líder en la región, reconocida por nuestra innovación constante sin perder la esencia tradicional.',
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
                  ...[
                    ('Calidad Artesanal',        LucideIcons.handshake),
                    ('Ingredientes Frescos',     LucideIcons.leaf),
                    ('Atención Personalizada',   Icons.favorite_outline_rounded),
                    ('Tradición e Innovación',   Icons.star_outline_rounded),
                  ].map((v) => _buildValueTile(v.$1, v.$2)),

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
                    _buildStat('100%', 'Artesanal'),
                    const SizedBox(width: 12),
                    _buildStat('+ 5 años', 'Experiencia'),
                    const SizedBox(width: 12),
                    _buildStat('❤️', 'Con amor'),
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
              style: const TextStyle(
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