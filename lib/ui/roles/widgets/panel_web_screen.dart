// lib/ui/roles/widgets/panel_web_screen.dart
//
// Pantalla para los roles internos (empleado, gerencia, direccion_general).
// Estos roles operan desde el panel web; la app móvil no tiene sus vistas.
// Se les da la bienvenida con su identidad de rol y se les invita a abrir el
// sitio web para tener una mejor perspectiva de su trabajo.
//
// Movimiento (una sola vez, al llegar con context.go): el ícono del rol cae
// con un rebote y un halo se abre a su alrededor; luego el saludo, el
// panel, la tarjeta, el botón y la dirección suben en cascada.
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Datos de presentación de cada rol interno (título, acento, icono).
class _RolInfo {
  const _RolInfo({
    required this.panel,
    required this.descripcion,
    required this.icono,
    required this.acento,
    required this.acentoOscuro,
  });

  /// Deriva la info a partir del rol del backend.
  factory _RolInfo.from(String? rol) {
    switch (rol) {
      case 'gerencia':
        return const _RolInfo(
          panel: 'Panel de Gerencia',
          descripcion:
              'Supervisión de operaciones, usuarios y reportes del negocio.',
          icono: LucideIcons.chartLine,
          acento: Color(0xFF2A4060),
          acentoOscuro: Color(0xFF1A2744),
        );
      case 'direccion_general':
        return const _RolInfo(
          panel: 'Panel de Dirección',
          descripcion:
              'Control general, configuración y estrategia de Pier Repostería.',
          icono: LucideIcons.award,
          acento: Color(0xFF5A3D7A),
          acentoOscuro: Color(0xFF2D1B4E),
        );
      case 'empleado':
      default:
        return _RolInfo(
          panel: 'Panel de Operación',
          descripcion:
              'Gestión de productos, pedidos, promociones y atención diaria.',
          icono: LucideIcons.store,
          acento: AppColors.pierVerde,
          acentoOscuro: AppColors.pierVerdeOscuro,
        );
    }
  }

  final String panel;
  final String descripcion;
  final IconData icono;
  final Color acento;
  final Color acentoOscuro;
}

class PanelWebScreen extends StatelessWidget {
  const PanelWebScreen({super.key});

  String _primerNombre(Map<String, dynamic>? user) {
    final n = (user?['nombre']?.toString() ?? '').trim();
    if (n.isEmpty) return '';
    return n.split(' ').first;
  }

  Future<void> _abrirSitio(BuildContext context) async {
    final uri = Uri.parse(BusinessInfo.sitioWeb);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el sitio web'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();
    final info = _RolInfo.from(auth.rol);
    final nombre = _primerNombre(auth.currentUser);
    // Se llega con context.go: la cascada espera el fundido de la página.
    const retraso = AppMovimiento.trasRaiz;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [info.acentoOscuro, info.acento],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                // Cerrar sesión arriba a la derecha
                EntradaSuave(
                  retraso: retraso,
                  desplazamiento: Offset.zero,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _cerrarSesion(context),
                      icon: const Icon(LucideIcons.logOut,
                          size: 18, color: Colors.white),
                      label: const Text(
                        'Cerrar sesión',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const Spacer(),

                // Icono del rol: cae con un rebote y un halo se abre.
                _IconoRol(icono: info.icono, retraso: retraso),
                const SizedBox(height: 24),

                // Saludo
                EntradaSuave(
                  orden: 1,
                  retraso: retraso,
                  child: Text(
                    nombre.isEmpty ? '¡Hola!' : '¡Hola, $nombre!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                EntradaSuave(
                  orden: 2,
                  retraso: retraso,
                  child: Text(
                    info.panel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Tarjeta con el mensaje principal
                EntradaSuave(
                  orden: 3,
                  retraso: retraso,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Icon(LucideIcons.globe,
                            size: 30, color: info.acento),
                        const SizedBox(height: 12),
                        const Text(
                          'Es necesario que te dirijas al sitio web '
                          'para poder tener una mejor perspectiva.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          info.descripcion,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Botón: abrir sitio web
                EntradaSuave(
                  orden: 4,
                  retraso: retraso,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirSitio(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: info.acentoOscuro,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(LucideIcons.externalLink, size: 20),
                      label: const Text(
                        'Abrir sitio web',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                EntradaSuave(
                  orden: 5,
                  retraso: retraso,
                  desplazamiento: Offset.zero,
                  child: Text(
                    BusinessInfo.sitioWeb.replaceFirst('https://', ''),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El ícono del rol en su círculo: cae de 0.7 a su tamaño con un rebote y,
/// al asentarse, un halo blanco se abre y se apaga una vez. Arranca cuando
/// la página ya se ve; con movimiento reducido aparece quieto y sin halo.
class _IconoRol extends StatefulWidget {
  const _IconoRol({required this.icono, required this.retraso});

  final IconData icono;
  final Duration retraso;

  @override
  State<_IconoRol> createState() => _IconoRolState();
}

class _IconoRolState extends State<_IconoRol>
    with SingleTickerProviderStateMixin {
  static const double _diametro = 110;
  static const Duration _caida = Duration(milliseconds: 520);
  static const Duration _halo = Duration(milliseconds: 900);

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: widget.retraso + _halo + const Duration(milliseconds: 260),
  );
  bool _preparada = false;

  late final Interval _tramoCaida = _tramo(Duration.zero, _caida);
  late final Interval _tramoHalo = _tramo(
    const Duration(milliseconds: 260),
    _halo,
  );

  // El tramo del reloj que va de [espera] a [espera] + [duracion] (después
  // del retraso de la página).
  Interval _tramo(Duration espera, Duration duracion) {
    final total = _control.duration!.inMicroseconds;
    final inicio = (widget.retraso + espera).inMicroseconds / total;
    final fin = (widget.retraso + espera + duracion).inMicroseconds / total;
    return Interval(inicio, clampDouble(fin, 0, 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    if (AppMovimiento.reducido(context)) {
      _control.value = 1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _control.forward().ignore();
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circulo = Container(
      width: _diametro,
      height: _diametro,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Icon(widget.icono, size: 54, color: Colors.white),
    );
    final halo = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
    return AnimatedBuilder(
      animation: _control,
      builder: (context, _) {
        final valor = _control.value;
        final caida = _tramoCaida.transform(valor);
        final h = _tramoHalo.transform(valor);
        // El halo solo se ve mientras se abre (antes y después, nada).
        final veHalo = valor > _tramoHalo.begin && valor < _tramoHalo.end;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: veHalo ? 0.35 * (1 - h) : 0,
                  child: Transform.scale(
                    scale: 1 + 0.6 * AppMovimiento.curvaEntrada.transform(h),
                    child: halo,
                  ),
                ),
              ),
            ),
            Opacity(
              // Aparece en el primer 40 % de la caída.
              opacity: Curves.easeOut.transform(clampDouble(caida * 2.5, 0, 1)),
              child: Transform.scale(
                scale: 0.7 + 0.3 * AppMovimiento.curvaRebote.transform(caida),
                child: circulo,
              ),
            ),
          ],
        );
      },
    );
  }
}
