// lib/ui/comandas/widgets/agenda_comandas_screen.dart
//
// Agenda de comandas (#127), inicio de hornos y decoración en la app: las
// comandas por día con su urgencia y las firmas de cada área, los pendientes
// de mi área, cuatro vistas y búsqueda por folio o cliente. Se actualiza al
// jalar hacia abajo y al volver a la app. Si el backend rechaza la sesión
// (cuenta desactivada o cambiada), la cierra y vuelve al login.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/comandas/view_model/agenda_comandas_view_model.dart';
import 'package:pier_pasteleria/ui/comandas/widgets/agenda_comandas_partes.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Espera tras la última tecla antes de buscar (como la web).
const _esperaBusqueda = Duration(milliseconds: 400);

enum _Opcion { sitioWeb, cerrarSesion }

class AgendaComandasScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo
  /// con el área del rol en sesión.
  const AgendaComandasScreen({super.key, this.viewModel});

  final AgendaComandasViewModel? viewModel;

  @override
  State<AgendaComandasScreen> createState() => _AgendaComandasScreenState();
}

class _AgendaComandasScreenState extends State<AgendaComandasScreen>
    with WidgetsBindingObserver {
  late final AgendaComandasViewModel _vm = widget.viewModel ??
      AgendaComandasViewModel(
        repo: context.read(),
        area: AreaProduccion.deRol(context.read<AuthProvider>().rol),
      );
  Timer? _espera;
  bool _verTodas = false;
  bool _saliendo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm.addListener(_revisarSesion);
    unawaited(_vm.cargar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_vm.recargar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _espera?.cancel();
    _vm
      ..removeListener(_revisarSesion)
      ..dispose();
    super.dispose();
  }

  void _buscar(String texto) {
    _espera?.cancel();
    _espera = Timer(_esperaBusqueda, () => unawaited(_vm.buscar(texto)));
  }

  void _revisarSesion() {
    if (!_vm.sesionInvalida || _saliendo) return;
    _saliendo = true;
    unawaited(_cerrarSesion(mensaje: _vm.error));
  }

  Future<void> _cerrarSesion({String? mensaje}) async {
    final avisos = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    await context.read<AuthProvider>().logout();
    router.go(AppRoutes.login);
    if (mensaje != null) {
      avisos.showSnackBar(SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _abrirSitio() async {
    final ok = await launchUrl(Uri.parse(BusinessInfo.sitioWeb),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo abrir el sitio web'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final area = _vm.area;
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(
        backgroundColor: AppColors.pierVerde,
        foregroundColor: Colors.white,
        title: Text(area == null ? 'Comandas' : 'Comandas · ${area.etiqueta}'),
        actions: [
          PopupMenuButton<_Opcion>(
            tooltip: 'Más opciones',
            icon: const Icon(LucideIcons.ellipsisVertical),
            onSelected: (o) => unawaited(switch (o) {
              _Opcion.sitioWeb => _abrirSitio(),
              _Opcion.cerrarSesion => _cerrarSesion(),
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: _Opcion.sitioWeb, child: Text('Abrir sitio web')),
              PopupMenuItem(
                  value: _Opcion.cerrarSesion, child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: _buscar,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por folio o cliente',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _vm,
              builder: (context, _) => Column(
                children: [
                  _SelectorVistas(
                      vista: _vm.vista, alCambiar: _vm.cambiarVista),
                  Expanded(child: _contenido()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_vm.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_vm.tieneDatos && _vm.error != null) {
      return SingleChildScrollView(
        child: EstadoAgenda(
          icono: LucideIcons.circleAlert,
          titulo: 'No pudimos cargar las comandas',
          detalle: _vm.error,
          accion: 'Reintentar',
          alAccion: () => unawaited(_vm.cargar()),
        ),
      );
    }
    final area = _vm.area;
    final pendientes = _vm.pendientes;
    final grupos = _vm.grupos;
    return RefreshIndicator(
      onRefresh: _vm.recargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_vm.error != null) _AvisoError(_vm.error!),
          if (area != null &&
              pendientes != null &&
              !_vm.vista.esHistorica &&
              _vm.busqueda.isEmpty)
            SeccionPendientes(
              area: area,
              pendientes: pendientes,
              verTodas: _verTodas,
              alAlternar: () => setState(() => _verTodas = !_verTodas),
            ),
          if (grupos.isEmpty)
            EstadoAgenda(
              icono: LucideIcons.inbox,
              titulo: _vm.busqueda.isEmpty
                  ? 'No hay comandas en esta vista'
                  : 'Sin resultados para «${_vm.busqueda}»',
            ),
          for (final grupo in grupos) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                grupo.titulo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: grupo.dias < 0 && !_vm.vista.esHistorica
                      ? AppColors.error
                      : AppColors.textPrimary,
                ),
              ),
            ),
            for (final c in grupo.comandas) TarjetaComanda(c),
          ],
        ],
      ),
    );
  }
}

class _SelectorVistas extends StatelessWidget {
  const _SelectorVistas({required this.vista, required this.alCambiar});

  final VistaAgenda vista;
  final ValueChanged<VistaAgenda> alCambiar;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            for (final v in VistaAgenda.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(v.etiqueta),
                  selected: v == vista,
                  onSelected: (_) => alCambiar(v),
                  selectedColor: AppColors.pierVerde.withValues(alpha: 0.18),
                ),
              ),
          ],
        ),
      );
}

class _AvisoError extends StatelessWidget {
  const _AvisoError(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('No se pudo actualizar: $mensaje',
            style: const TextStyle(color: AppColors.error)),
      );
}
