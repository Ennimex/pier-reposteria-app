import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Marco Legal'),
          backgroundColor: AppColors.pierVerde,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppColors.pierDorado,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabs: [
              Tab(text: 'Privacidad'),
              Tab(text: 'Términos'),
              Tab(text: 'Devoluciones'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LegalContent(
              title: 'Aviso de Privacidad Integral',
              content: '''
En cumplimiento con la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP), Pastelería Pier hace de su conocimiento los términos bajo los cuales se tratarán sus datos personales.

1. Responsable del Tratamiento
Pastelería Pier, con domicilio en Calle Allende, Colonia Tahuizán, Huejutla de Reyes, Hidalgo, C.P. 43000.
Email: pierreposteria@gmail.com

2. Datos que Recopilamos
• Identificación: Nombre completo, teléfono, correo electrónico.
• Acceso digital: Usuario y contraseñas.
• Transaccionales: Historial de pedidos.
IMPORTANTE: No recopilamos ni almacenamos datos financieros sensibles (tarjetas, CVV).

3. Finalidades
• Primarias: Gestión de pedidos, entregas y atención a clientes.
• Secundarias: Envío de promociones (solo con consentimiento).

4. Derechos ARCO
Puede ejercer sus derechos de Acceso, Rectificación, Cancelación u Oposición enviando un correo a pierreposteria@gmail.com.
• Tiempo de respuesta: Máximo 20 días hábiles.

5. Conservación
La información se conservará por un periodo máximo de 5 años tras su última interacción.
              ''',
            ),
            _LegalContent(
              title: 'Términos y Condiciones',
              content: '''
Al utilizar nuestros servicios digitales, usted acepta los siguientes términos, regidos por la Ley Federal de Protección al Consumidor.

1. Proceso de Compra
Todos los precios incluyen impuestos. La transacción se considera confirmada una vez procesado el pago.

2. Política de NO Envíos
Actualmente, Pastelería Pier NO ofrece servicio de envíos a domicilio. Todos los pedidos deben ser recolectados en la sucursal seleccionada (Tahuizán o Centro).

3. Cancelaciones
El cliente puede cancelar su pedido únicamente ANTES de que inicie su elaboración. Nos reservamos el derecho de cancelar pedidos por falta de insumos (sin cargo para el cliente).

4. Marco Legal
Para la interpretación de estos términos, las partes se someten a las leyes vigentes en México y a los tribunales de Huejutla de Reyes, Hidalgo.
              ''',
            ),
            _LegalContent(
              title: 'Política de Devoluciones',
              content: '''
Garantizamos la frescura y calidad de nuestros productos.

1. Condiciones de Devolución
• Aplica únicamente el MISMO DÍA de la compra.
• Debe presentarse al menos el 50% del producto para validar la incidencia.
• No aplica en productos manipulados incorrectamente por el cliente (falta de refrigeración, caídas).

2. Reembolsos
• Se gestionan en un máximo de 3 horas hábiles posteriores a la aprobación.
• Si el error es nuestro, absorbemos el costo total.

3. Garantía
La garantía de frescura es válida únicamente el día de la entrega/recolección.
              ''',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  final String title;
  final String content;

  // ignore: unused_element_parameter
  const _LegalContent({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.pierVerde),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.pierVerdeOscuro),
                ),
              ),
            ],
          ),
          const Divider(thickness: 1, height: 30),
          Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
          ),
          const SizedBox(height: 40),
          
          // Footer de contacto legal
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: const [
                Text("¿Dudas legales?", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("pierreposteria@gmail.com", style: TextStyle(color: AppColors.pierVerde)),
              ],
            ),
          )
        ],
      ),
    );
  }
}