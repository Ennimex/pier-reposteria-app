// lib/presentation/screens/public/legal_screen.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('Marco Legal',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),

            // ── TABS ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicator: BoxDecoration(
                    color: AppColors.pierVerde,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: 'Privacidad'),
                    Tab(text: 'Términos'),
                    Tab(text: 'Devoluciones'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── CONTENIDO ────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildContent(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Aviso de Privacidad',
                    sections: [
                      _LegalSection(
                        title: 'Responsable del Tratamiento',
                        content:
                            'Pastelería Pier, con domicilio en Calle Allende, Col. Tahuizán, Huejutla de Reyes, Hgo., C.P. 43000.\nEmail: pierreposteria@gmail.com',
                      ),
                      _LegalSection(
                        title: 'Datos que Recopilamos',
                        content:
                            '• Identificación: Nombre, teléfono, correo electrónico.\n• Acceso digital: Usuario y contraseñas.\n• Transaccionales: Historial de pedidos.\n\nImportante: No almacenamos datos financieros sensibles (tarjetas, CVV).',
                      ),
                      _LegalSection(
                        title: 'Finalidades',
                        content:
                            '• Primarias: Gestión de pedidos y atención a clientes.\n• Secundarias: Envío de promociones (solo con consentimiento).',
                      ),
                      _LegalSection(
                        title: 'Derechos ARCO',
                        content:
                            'Puede ejercer sus derechos de Acceso, Rectificación, Cancelación u Oposición enviando un correo a pierreposteria@gmail.com.\nTiempo de respuesta: Máximo 20 días hábiles.',
                      ),
                      _LegalSection(
                        title: 'Conservación',
                        content:
                            'La información se conservará por un periodo máximo de 5 años tras su última interacción.',
                      ),
                    ],
                  ),
                  _buildContent(
                    icon: Icons.description_outlined,
                    title: 'Términos y Condiciones',
                    sections: [
                      _LegalSection(
                        title: 'Proceso de Compra',
                        content:
                            'Todos los precios incluyen impuestos. La transacción se confirma una vez procesado el pago.',
                      ),
                      _LegalSection(
                        title: 'Política de NO Envíos',
                        content:
                            'Pier NO ofrece servicio de envíos a domicilio. Todos los pedidos deben recogerse en la sucursal de Huejutla de Reyes.',
                      ),
                      _LegalSection(
                        title: 'Cancelaciones',
                        content:
                            'El cliente puede cancelar únicamente ANTES de que inicie la elaboración. Nos reservamos el derecho de cancelar por falta de insumos, sin cargo al cliente.',
                      ),
                      _LegalSection(
                        title: 'Marco Legal',
                        content:
                            'Para la interpretación de estos términos, las partes se someten a las leyes vigentes en México y a los tribunales de Huejutla de Reyes, Hidalgo.',
                      ),
                    ],
                  ),
                  _buildContent(
                    icon: Icons.assignment_return_outlined,
                    title: 'Política de Devoluciones',
                    sections: [
                      _LegalSection(
                        title: 'Condiciones de Devolución',
                        content:
                            '• Aplica únicamente el MISMO DÍA de la compra.\n• Debe presentarse al menos el 50% del producto.\n• No aplica en productos manipulados incorrectamente por el cliente.',
                      ),
                      _LegalSection(
                        title: 'Reembolsos',
                        content:
                            'Se gestionan en un máximo de 3 horas hábiles posteriores a la aprobación. Si el error es nuestro, absorbemos el costo total.',
                      ),
                      _LegalSection(
                        title: 'Garantía',
                        content:
                            'La garantía de frescura es válida únicamente el día de la entrega o recolección.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required IconData icon,
    required String title,
    required List<_LegalSection> sections,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de sección
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.pierVerde.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(icon, color: AppColors.pierVerde, size: 22),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerdeOscuro)),
            ]),
          ),
          const SizedBox(height: 16),

          // Secciones
          ...sections.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(s.content,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5)),
                    ],
                  ),
                ),
              )),

          // Footer contacto
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Icon(Icons.email_outlined,
                  color: AppColors.pierVerde, size: 18),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Dudas legales?',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  const Text('pierreposteria@gmail.com',
                      style: TextStyle(
                          color: AppColors.pierVerde,
                          fontSize: 12)),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String content;
  const _LegalSection({required this.title, required this.content});
}