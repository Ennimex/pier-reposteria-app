import 'package:flutter/material.dart';
import '/../core/constants/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Datos simulados (Mock Data)
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'title': '¡Tu pedido PED-4829 está listo!',
      'body': 'Ya puedes pasar a recoger tu pedido en la Sucursal Principal.',
      'time': 'Hace 5 min',
      'type': 'order', // order, promo, alert
      'isRead': false,
    },
    {
      'id': 2,
      'title': 'Reembolso Aprobado',
      'body': 'Tu solicitud REEM-001 ha sido procesada exitosamente.',
      'time': 'Hace 2 hrs',
      'type': 'alert',
      'isRead': false,
    },
    {
      'id': 3,
      'title': 'Descuento especial en Cheesecakes',
      'body': 'Solo por hoy, aprovecha 15% de descuento en todos los cheesecakes.',
      'time': 'Ayer',
      'type': 'promo',
      'isRead': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: AppColors.pierVerde),
            tooltip: 'Marcar todas como leídas',
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n['isRead'] = true;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Todas marcadas como leídas')),
              );
            },
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(child: Text("No tienes notificaciones"))
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                return _buildNotificationItem(notif);
              },
            ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif) {
    final bool isRead = notif['isRead'];
    
    // Icono y color según tipo
    IconData icon;
    Color color;
    switch (notif['type']) {
      case 'order':
        icon = Icons.inventory_2;
        color = AppColors.pierVerde;
        break;
      case 'alert':
        icon = Icons.info;
        color = Colors.orange;
        break;
      case 'promo':
        icon = Icons.local_offer;
        color = AppColors.pierDorado;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Dismissible(
      key: Key(notif['id'].toString()),
      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (direction) {
        setState(() {
          _notifications.removeAt(_notifications.indexOf(notif));
        });
      },
      child: Container(
        color: isRead ? Colors.white : AppColors.pierArena.withValues(alpha: 0.3 * 255), // Fondo destacado si no leído
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1 * 255),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            notif['title'],
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notif['body'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                notif['time'],
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          onTap: () {
            // Marcar como leída al tocar
            if (!isRead) {
              setState(() {
                notif['isRead'] = true;
              });
            }
            // Aquí navegaríamos al detalle (Pedido, Promo, etc.)
          },
        ),
      ),
    );
  }
}