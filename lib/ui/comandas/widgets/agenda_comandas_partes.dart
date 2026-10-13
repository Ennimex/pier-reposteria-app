// lib/ui/comandas/widgets/agenda_comandas_partes.dart
//
// Piezas de la agenda de comandas (#127): tarjeta de comanda con su color de
// urgencia y las firmas de hornos y decoración, sección de pendientes del
// área y avisos. Sin montos: hornos y decoración no los reciben.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/comandas/widgets/comandas_formato.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

/// Pendientes que se ven antes de «Ver las N pendientes».
const pendientesVisibles = 3;

/// Aviso flotante (rojo por defecto).
void avisoComandas(BuildContext context, String mensaje, {Color? color}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: color ?? AppColors.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Cierra la sesión y vuelve al login; con [mensaje] (la cuenta se
/// desactivó o cambió) lo avisa allá.
Future<void> salirDeComandas(BuildContext context, {String? mensaje}) async {
  final avisos = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  await context.read<AuthProvider>().logout();
  router.go(AppRoutes.login);
  if (mensaje != null) {
    avisos.showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Tarjeta de una comanda en la agenda. Con [mostrarDia] dice cuánto falta
/// (en la sección de pendientes, que no va agrupada por día).
class TarjetaComanda extends StatelessWidget {
  const TarjetaComanda(
    this.comanda, {
    super.key,
    this.mostrarDia = false,
    this.alTocar,
  });

  final ResumenComanda comanda;
  final bool mostrarDia;

  /// Abre el detalle de la comanda.
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final c = comanda;
    final hora = horaLegible(c.horaEntrega);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: alTocar,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: c.semaforo?.color ?? Colors.grey.shade300,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${c.folio}',
                            style: const TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mostrarDia
                                  ? '${textoDiasRestantes(c.diasRestantes)} · $hora'
                                  : hora,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _ChipEstado(c),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.clienteNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (c.resumen.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          c.resumen,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final area in AreaProduccion.values)
                            ChipFirma(area: area, firma: c.firma(area)),
                          if (c.numImagenes > 0)
                            _IconoTexto(
                              LucideIcons.image,
                              c.numImagenes == 1
                                  ? '1 foto'
                                  : '${c.numImagenes} fotos',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Urgencia si está activa; si no, «Entregada» o «Cancelada».
class _ChipEstado extends StatelessWidget {
  const _ChipEstado(this.comanda);

  final ResumenComanda comanda;

  @override
  Widget build(BuildContext context) {
    final semaforo = comanda.semaforo;
    final color = semaforo?.color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        semaforo?.etiqueta ?? comanda.estado.etiqueta,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: semaforo == Semaforo.vencida ? semaforo!.color : color,
        ),
      ),
    );
  }
}

/// «Hornos: confirmó» · «Decoración: pendiente» · «…: falta re-confirmar».
class ChipFirma extends StatelessWidget {
  const ChipFirma({required this.area, required this.firma, super.key});

  final AreaProduccion area;
  final FirmaArea firma;

  @override
  Widget build(BuildContext context) {
    final (icono, texto, color) = switch (firma.estado) {
      EstadoFirma.vigente => (
        LucideIcons.circleCheck,
        'confirmó',
        const Color(0xFF15803D),
      ),
      EstadoFirma.refirmar => (
        LucideIcons.rotateCw,
        'falta re-confirmar',
        const Color(0xFFB45309),
      ),
      EstadoFirma.pendiente => (
        LucideIcons.clock,
        'pendiente',
        AppColors.textSecondary,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${area.etiqueta}: $texto',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconoTexto extends StatelessWidget {
  const _IconoTexto(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(
        texto,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
}

/// Lo que mi área no ha confirmado, la más urgente primero.
class SeccionPendientes extends StatelessWidget {
  const SeccionPendientes({
    required this.area,
    required this.pendientes,
    required this.verTodas,
    required this.alAlternar,
    required this.alAbrir,
    super.key,
  });

  final AreaProduccion area;
  final List<ResumenComanda> pendientes;
  final bool verTodas;
  final VoidCallback alAlternar;
  final ValueChanged<ResumenComanda> alAbrir;

  @override
  Widget build(BuildContext context) {
    final total = pendientes.length;
    final visibles = verTodas
        ? pendientes
        : pendientes.take(pendientesVisibles).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: area.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: area.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clipboardCheck, size: 18, color: area.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pendientes de tu confirmación ($total)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: area.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Tu área está al día',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          for (final c in visibles)
            TarjetaComanda(c, mostrarDia: true, alTocar: () => alAbrir(c)),
          if (total > pendientesVisibles)
            Center(
              child: TextButton(
                onPressed: alAlternar,
                child: Text(
                  verTodas ? 'Ver menos' : 'Ver las $total pendientes',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Estado sin lista: vacío o error (con acción opcional).
class EstadoAgenda extends StatelessWidget {
  const EstadoAgenda({
    required this.icono,
    required this.titulo,
    super.key,
    this.detalle,
    this.accion,
    this.alAccion,
  });

  final IconData icono;
  final String titulo;
  final String? detalle;
  final String? accion;
  final VoidCallback? alAccion;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    child: Column(
      children: [
        Icon(icono, size: 44, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (detalle != null) ...[
          const SizedBox(height: 6),
          Text(
            detalle!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
        if (accion != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: alAccion, child: Text(accion!)),
        ],
      ],
    ),
  );
}
