// lib/ui/public/widgets/legal_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/utils/config_format.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _configRepo = ConfiguracionRepository();

  // Textos del panel (configuracion/legales, misma fuente que Legales.tsx).
  // null = usar las secciones por defecto de la app.
  String? _privacidad;
  String? _terminos;
  String? _reembolsos;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarLegales();
  }

  /// GET /configuracion/legales → privacidad, terminos, reembolsos (texto
  /// plano con saltos de línea). Vacío o error → textos por defecto.
  Future<void> _cargarLegales() async {
    final r = await _configRepo.seccion('legales');
    if (!mounted || r['success'] != true) return;
    final cfg = r['config'];
    if (cfg is! Map) return;
    setState(() {
      _privacidad = configTexto(cfg['privacidad']);
      _terminos = configTexto(cfg['terminos']);
      _reembolsos = configTexto(cfg['reembolsos']);
    });
  }

  /// Convierte el texto del panel en tarjetas: bloques separados por línea en
  /// blanco (o una tarjeta por línea si no hay bloques). Si un bloque tiene
  /// varias líneas y la primera es corta y no termina en punto ni es viñeta,
  /// esa línea es el título de la tarjeta. Si el texto viene como un solo
  /// párrafo sin saltos (así está capturado hoy en el panel), se reparte una
  /// tarjeta por oración para no pintar un bloque corrido.
  static List<_LegalSection> _seccionesDesde(String texto) {
    final normal = texto.replaceAll('\r\n', '\n').trim();
    if (!normal.contains('\n')) {
      // Corte tras . ! ? seguido de espacio y mayúscula (no parte "C.P. 43000"
      // ni decimales). Probado con los 3 textos reales del panel: 5/7/5 tarjetas.
      final oraciones = normal
          .split(RegExp(r'(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÑ¿¡])'))
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .toList();
      return oraciones.map((o) => _LegalSection(content: o)).toList();
    }
    var bloques = normal.split(RegExp(r'\n\s*\n'));
    if (bloques.length == 1) bloques = normal.split('\n');
    final out = <_LegalSection>[];
    for (final b in bloques) {
      final lineas = b
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lineas.isEmpty) continue;
      final primera = lineas.first;
      final esTitulo = lineas.length > 1 &&
          primera.length <= 60 &&
          !primera.endsWith('.') &&
          !primera.startsWith('-') &&
          !primera.startsWith('•');
      out.add(esTitulo
          ? _LegalSection(
              title: primera.replaceFirst(RegExp(r':\$'), ''),
              content: lineas.sublist(1).join('\n'))
          : _LegalSection(content: lineas.join('\n')));
    }
    return out;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
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
                    icon: LucideIcons.shieldAlert,
                    title: 'Aviso de Privacidad',
                    sections: _privacidad != null
                        ? _seccionesDesde(_privacidad!)
                        : [
                      _LegalSection(
                        title: 'Responsable del Tratamiento',
                        content:
                            '${BusinessInfo.marca}, con domicilio en ${BusinessInfo.direccionCompleta}.\nEmail: ${BusinessInfo.email}',
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
                            'Puede ejercer sus derechos de Acceso, Rectificación, Cancelación u Oposición enviando un correo a ${BusinessInfo.email}.\nTiempo de respuesta: Máximo 20 días hábiles.',
                      ),
                      _LegalSection(
                        title: 'Conservación',
                        content:
                            'La información se conservará por un periodo máximo de 5 años tras su última interacción.',
                      ),
                    ],
                  ),
                  _buildContent(
                    icon: LucideIcons.fileText,
                    title: 'Términos y Condiciones',
                    sections: _terminos != null
                        ? _seccionesDesde(_terminos!)
                        : [
                      _LegalSection(
                        title: 'Proceso de Compra',
                        content:
                            'Todos los precios incluyen impuestos. La transacción se confirma una vez procesado el pago.',
                      ),
                      _LegalSection(
                        title: 'Entregas y Envíos',
                        content:
                            'Puedes recoger tu pedido en la sucursal de ${BusinessInfo.ciudad} o solicitar envío a domicilio en las colonias con cobertura. El costo de envío se calcula según la colonia y se muestra antes de pagar.',
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
                    icon: LucideIcons.undo2,
                    title: 'Política de Devoluciones',
                    sections: _reembolsos != null
                        ? _seccionesDesde(_reembolsos!)
                        : [
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
                  style: TextStyle(
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
                      if (s.title.isNotEmpty) ...[
                        Text(s.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                      ],
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
              Icon(LucideIcons.mail,
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
                  Text(BusinessInfo.email,
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
  const _LegalSection({this.title = '', required this.content});
}