import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'contact_screen.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({Key? key}) : super(key: key);

  final List<Map<String, String>> _faqs = const [
    // --- PEDIDOS ---
    {
      'question': '¿Ofrecen servicio de entrega a domicilio?',
      'answer': 'Actualmente, Pastelería Pier NO ofrece servicio de envíos a domicilio. Todos los pedidos realizados a través de la app deben recogerse directamente en la sucursal seleccionada en Huejutla de Reyes.'
    },
    {
      'question': '¿Puedo cancelar mi pedido después de pagarlo?',
      'answer': 'Puedes solicitar la cancelación únicamente ANTES de que el producto comience a ser elaborado. Si el proceso de producción ya inició, no será posible cancelar. Tampoco generamos cargos si la cancelación es por falta de insumos de nuestra parte.'
    },
    {
      'question': '¿Con cuánto tiempo de anticipación debo pedir?',
      'answer': 'Recomendamos realizar tus pedidos con anticipación (mínimo 24 horas) para garantizar disponibilidad. Nuestros productos son artesanales y elaborados el mismo día para asegurar su calidad.'
    },

    // --- DEVOLUCIONES ---
    {
      'question': '¿Cuál es su política de devoluciones?',
      'answer': 'Las devoluciones aplican únicamente el MISMO DÍA de la compra. Es requisito indispensable presentar al menos la mitad (50%) del producto en buenas condiciones para validar la incidencia.'
    },
    {
      'question': '¿Cuánto tardan en realizar un reembolso?',
      'answer': 'Si tu devolución es aprobada, el reembolso se gestionará en un máximo de 3 horas hábiles posteriores a la validación. El costo es absorbido por nosotros si se cumplen las condiciones.'
    },
    {
      'question': '¿Qué cubren sus garantías?',
      'answer': 'Garantizamos la frescura y calidad el día de la compra. La garantía NO cubre daños ocasionados por mal manejo, falta de refrigeración o transporte realizado por el cliente.'
    },

    // --- SEGURIDAD Y PAGOS ---
    {
      'question': '¿Es seguro ingresar mis datos?',
      'answer': 'Sí. Implementamos cifrado de datos (TLS/SSL) y servidores seguros. Pastelería Pier NO almacena datos financieros sensibles (números de tarjeta o CVV); todas las transacciones se procesan mediante pasarelas seguras.'
    },
    {
      'question': '¿Qué métodos de pago aceptan?',
      'answer': 'Aceptamos pagos en efectivo (solo en sucursal) y pagos electrónicos en la app mediante tarjeta de crédito o débito (principalmente Santander).'
    },

    // --- UBICACIÓN ---
    {
      'question': '¿Dónde están ubicados?',
      'answer': 'Nuestra matriz se encuentra en Calle Allende, Colonia Tahuizán, Huejutla de Reyes, Hidalgo, C.P. 43000.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Preguntas Frecuentes'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header visual
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pierVerde,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.help_outline, color: Colors.white, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Resuelve tus dudas sobre pedidos, pagos y seguridad.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          ..._faqs.map((faq) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: ExpansionTile(
              iconColor: AppColors.pierVerde,
              textColor: AppColors.pierVerde,
              title: Text(
                faq['question']!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    faq['answer']!,
                    style: TextStyle(color: Colors.grey[700], height: 1.5),
                  ),
                ),
              ],
            ),
          )).toList(),

          const SizedBox(height: 30),
          
          Column(
            children: [
              const Text('¿No encontraste tu respuesta?', style: TextStyle(color: Colors.grey)),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactScreen()));
                },
                child: const Text('Contáctanos', style: TextStyle(color: AppColors.pierVerde, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}