// lib/ui/public/widgets/faq_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/utils/config_format.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/public/widgets/contact_screen.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  String _categoriaSeleccionada = 'Todas';
  final _configRepo = ConfiguracionRepository();

  /// 'Todas' + categorías presentes en las preguntas. Las conocidas van en
  /// su orden de siempre; las que capture el panel se agregan al final.
  List<String> get _categorias {
    const conocidas = ['Pedidos', 'Pagos', 'Devoluciones', 'Seguridad', 'Ubicación'];
    final presentes = _faqs
        .map((f) => f['categoria'] ?? '')
        .where((c) => c.isNotEmpty)
        .toSet();
    return [
      'Todas',
      ...conocidas.where(presentes.contains),
      ...presentes.where((c) => !conocidas.contains(c)),
    ];
  }

  // Preguntas por defecto de la app. Si Dirección captura preguntas en el
  // panel (configuracion/faq, clave `preguntas`, misma fuente que FAQ.tsx de
  // la web), se reemplazan por esas.
  static final List<Map<String, String>> _faqsDefault = [
    {
      'categoria': 'Pedidos',
      'question': '¿Ofrecen servicio de entrega a domicilio?',
      'answer':
          'Sí. Al finalizar tu pedido puedes elegir recoger en nuestra sucursal de ${BusinessInfo.ciudad} o envío a domicilio en las colonias con cobertura. El costo de envío se calcula automáticamente según tu colonia.',
    },
    {
      'categoria': 'Pedidos',
      'question': '¿Puedo cancelar mi pedido después de pagarlo?',
      'answer':
          'Puedes solicitar cancelación únicamente ANTES de que el producto comience a elaborarse. Si el proceso ya inició, no es posible cancelar.',
    },
    {
      'categoria': 'Pedidos',
      'question': '¿Con cuánto tiempo de anticipación debo pedir?',
      'answer':
          'Recomendamos un mínimo de 24 horas de anticipación. Nuestros productos son artesanales y elaborados el mismo día para garantizar su frescura.',
    },
    {
      'categoria': 'Devoluciones',
      'question': '¿Cuál es su política de devoluciones?',
      'answer':
          'Las devoluciones aplican únicamente el MISMO DÍA de la compra. Es requisito presentar al menos el 50% del producto en buenas condiciones.',
    },
    {
      'categoria': 'Devoluciones',
      'question': '¿Cuánto tardan en realizar un reembolso?',
      'answer':
          'Si tu devolución es aprobada, el reembolso se gestiona en un máximo de 3 horas hábiles posteriores a la validación.',
    },
    {
      'categoria': 'Devoluciones',
      'question': '¿Qué cubre la garantía del producto?',
      'answer':
          'Garantizamos frescura y calidad el día de la compra. No cubre daños por mal manejo, falta de refrigeración o transporte del cliente.',
    },
    {
      'categoria': 'Seguridad',
      'question': '¿Es seguro ingresar mis datos en la app?',
      'answer':
          'Sí. Implementamos cifrado TLS/SSL. Pier NO almacena datos financieros sensibles. Todas las transacciones se procesan mediante pasarelas seguras.',
    },
    {
      'categoria': 'Pagos',
      'question': '¿Qué métodos de pago aceptan?',
      'answer':
          'Aceptamos pagos en efectivo (solo en sucursal) y pagos electrónicos en la app mediante tarjeta de crédito o débito.',
    },
    {
      'categoria': 'Ubicación',
      'question': '¿Dónde están ubicados?',
      'answer':
          '${BusinessInfo.direccionCompleta}. Abierto ${BusinessInfo.horario}.',
    },
  ];

  List<Map<String, String>> _faqs = _faqsDefault;

  @override
  void initState() {
    super.initState();
    _cargarFaqs();
  }

  /// Espejo de FAQ.tsx: GET /configuracion/faq → config.preguntas
  /// [{categoria, pregunta, respuesta}]. Sin datos o con error se conservan
  /// las preguntas por defecto.
  Future<void> _cargarFaqs() async {
    final r = await _configRepo.seccion('faq');
    if (!mounted || r['success'] != true) return;
    final cfg = r['config'];
    if (cfg is! Map) return;
    final preguntas = parseConfigValor(cfg['preguntas']);
    if (preguntas is! List) return;
    final lista = <Map<String, String>>[];
    for (final item in preguntas) {
      if (item is! Map) continue;
      final q = (item['pregunta'] ?? '').toString().trim();
      final a = (item['respuesta'] ?? '').toString().trim();
      if (q.isEmpty || a.isEmpty) continue;
      final cat = (item['categoria'] ?? '').toString().trim();
      lista.add({
        'categoria': cat.isEmpty ? 'General' : cat,
        'question': q,
        'answer': a,
      });
    }
    if (lista.isEmpty) return;
    setState(() {
      _faqs = lista;
      if (!_categorias.contains(_categoriaSeleccionada)) {
        _categoriaSeleccionada = 'Todas';
      }
    });
  }

  List<Map<String, String>> get _filtradas {
    if (_categoriaSeleccionada == 'Todas') return _faqs;
    return _faqs
        .where((f) => f['categoria'] == _categoriaSeleccionada)
        .toList();
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
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categorias.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categorias[i];
                  final sel = _categoriaSeleccionada == cat;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _categoriaSeleccionada = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
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
                      child: Text(cat,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : AppColors.textSecondary)),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── LISTA ────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  ..._filtradas.map((faq) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildFAQCard(faq),
                      )),
                  const SizedBox(height: 16),
                  _buildContactBanner(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQCard(Map<String, String> faq) {
    return Container(
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
      child: Theme(
        data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.pierVerde,
          collapsedIconColor:
              AppColors.textSecondary.withValues(alpha: 0.6),
          title: Text(
            faq['question']!,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.pierArena,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                faq['answer']!,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5),
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
        GestureDetector(
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
      ]),
    );
  }
}