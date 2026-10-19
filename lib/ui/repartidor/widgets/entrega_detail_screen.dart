// lib/ui/repartidor/widgets/entrega_detail_screen.dart
//
// Detalle de una entrega (MVVM, Fase 5): cliente, dirección y resumen de
// cobro (entrega_detail_partes.dart) y, mientras siga activa, los botones:
// «Salir en camino» -> «Marcar entregado», entregar directo desde asignada,
// «Avisar que llegué» en camino y «Reportar» en ambos estados. El estado
// vive en EntregaDetailViewModel; al entregar o reportar se cierra con true.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/entrega_model.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/repartidor/view_model/entrega_detail_view_model.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/confirmar_entrega_screen.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/entrega_detail_partes.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/movimiento_repartidor.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/reportar_fallo_sheet.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class EntregaDetailScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo
  /// con [entrega].
  const EntregaDetailScreen({
    required this.entrega,
    super.key,
    this.alCambiar,
    this.viewModel,
  });

  final EntregaRepartidor entrega;

  /// Se llama (y se espera) cuando la entrega cambia de estado, para que el
  /// panel del repartidor se ponga al día.
  final Future<void> Function()? alCambiar;
  final EntregaDetailViewModel? viewModel;

  @override
  State<EntregaDetailScreen> createState() => _EntregaDetailScreenState();
}

class _EntregaDetailScreenState extends State<EntregaDetailScreen> {
  late final EntregaDetailViewModel _vm = widget.viewModel ??
      EntregaDetailViewModel(
        repo: context.read(),
        entrega: widget.entrega,
        alCambiar: widget.alCambiar,
      );

  EntregaRepartidor get _entrega => _vm.entrega;

  // Avisos de llegada que el backend aceptó: cada uno hace sonar la campana
  // del botón una vez.
  int _llegadasAvisadas = 0;

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  /// Abre [uri] fuera de la app; si no se puede, avisa con [error].
  Future<void> _abrir(
    Uri uri,
    String error, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    bool abierto;
    try {
      abierto = await launchUrl(uri, mode: mode);
    } on Exception {
      abierto = false;
    }
    if (!abierto && mounted) mostrarAviso(context, error);
  }

  Future<void> _salirEnCamino() async {
    final r = await _vm.salirEnCamino();
    if (mounted) mostrarAviso(context, r.mensaje, ok: r.ok);
  }

  Future<void> _avisarLlegada() async {
    final r = await _vm.avisarLlegada();
    if (!mounted) return;
    mostrarAviso(context, r.mensaje, ok: r.ok);
    if (r.ok) setState(() => _llegadasAvisadas++);
  }

  Future<void> _marcarEntregado() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmarEntregaScreen(
          entrega: _entrega,
          alCambiar: widget.alCambiar,
        ),
      ),
    );
    if ((ok ?? false) && mounted) Navigator.pop(context, true);
  }

  Future<void> _reportarProblema() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: AppMovimiento.estiloHoja(context),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReportarFalloSheet(
        entrega: _entrega,
        alCambiar: widget.alCambiar,
      ),
    );
    if ((ok ?? false) && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final llamada = _vm.uriLlamada;
        final whatsapp = _vm.uriWhatsapp;
        return Scaffold(
          backgroundColor: AppColors.pierArena,
          appBar: AppBar(title: Text(_entrega.numero)),
          // Las tarjetas se arman de arriba abajo mientras llega la página
          // (el número y el estado aterrizan volando desde la lista); lo que
          // se construye al hacer scroll ya llega quieto.
          body: SafeArea(
            top: false,
            child: AmbitoEntradas(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  EntradaSuave(
                    id: 'cliente',
                    retraso: AppMovimiento.trasEmpuje,
                    child: ClienteCard(entrega: _entrega, estado: _vm.estado),
                  ),
                  const SizedBox(height: 16),
                  EntradaSuave(
                    id: 'direccion',
                    retraso: AppMovimiento.trasEmpuje,
                    child: DireccionCard(
                      direccion: _entrega.direccion,
                      onComoLlegar: () =>
                          _abrir(_vm.uriComoLlegar, 'No se pudo abrir el mapa'),
                      onLlamar: llamada == null
                          ? null
                          : () => _abrir(llamada, 'No se pudo abrir el marcador',
                              mode: LaunchMode.platformDefault),
                      onWhatsapp: whatsapp == null
                          ? null
                          : () => _abrir(whatsapp, 'No se pudo abrir WhatsApp'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  EntradaSuave(
                    id: 'resumen',
                    retraso: AppMovimiento.trasEmpuje,
                    child: ResumenCard(entrega: _entrega),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _vm.puedeAccionar ? _acciones() : null,
        );
      },
    );
  }

  Widget _acciones() {
    final asignada = _vm.estado == EstadoEntrega.asignada;
    // La barra sube desde abajo junto con las tarjetas. Al salir en camino
    // sus botones cambian con un fundido a través y su alto se ajusta sin
    // saltos (una entrega finalizada no tiene barra).
    return EntradaSuave(
      orden: 1,
      retraso: AppMovimiento.trasEmpuje,
      desplazamiento: const Offset(0, AppMovimiento.distanciaLarga),
      child: SafeArea(
        child: TamanoSuave(
          alineacion: Alignment.bottomCenter,
          child: CambioEnVista(
            clave: asignada,
            tipo: TipoCambio.atravesar,
            alineacion: Alignment.bottomCenter,
            child: _botones(asignada: asignada, saliendo: _vm.saliendo),
          ),
        ),
      ),
    );
  }

  Widget _botones({required bool asignada, required bool saliendo}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En camino: avisar al cliente que ya llegaste (el backend
            // manda push + email, sin cambiar el estado).
            if (!asignada) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _vm.avisandoLlegada ? null : _avisarLlegada,
                  // La campana suena una vez cuando el cliente ya fue avisado.
                  icon: Campaneo(
                    disparo: _llegadasAvisadas == 0 ? null : _llegadasAvisadas,
                    child: IconoCargando(
                      icono: LucideIcons.bellRing,
                      cargando: _vm.avisandoLlegada,
                    ),
                  ),
                  label: Text(_vm.avisandoLlegada
                      ? 'Avisando…'
                      : 'Llegué al domicilio (avisar al cliente)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.estadoEnCamino,
                    side: const BorderSide(color: AppColors.estadoEnCamino),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saliendo ? null : _reportarProblema,
                    icon: const Icon(LucideIcons.triangleAlert, size: 18),
                    label: const Text('Reportar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: asignada
                      ? ElevatedButton.icon(
                          onPressed: saliendo ? null : _salirEnCamino,
                          icon: IconoCargando(
                            icono: LucideIcons.truck,
                            cargando: saliendo,
                            color: Colors.white,
                          ),
                          label: Text(
                              saliendo ? 'Actualizando…' : 'Salir en camino'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.estadoEnCamino,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _marcarEntregado,
                          icon: const Icon(Icons.check_circle_outline,
                              size: 18),
                          label: const Text('Marcar entregado'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                ),
              ],
            ),
            // Asignada: el backend permite entregar directo (repartidor
            // que acepta estando ya en la zona) sin "salir en camino".
            if (asignada)
              TextButton.icon(
                onPressed: saliendo ? null : _marcarEntregado,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label:
                    const Text('¿Ya estás en el domicilio? Marcar entregado'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.pierVerde,
                ),
              ),
          ],
        ),
      );
}
